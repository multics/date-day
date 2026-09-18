import CoreLocation
import Foundation
import MapKit

enum WeatherLocationError: LocalizedError {
    case permissionDenied
    case locationUnavailable
    case requestInProgress
    case manualLocationRequired

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            "Location access is off. Enable it in System Settings or select a manual location."
        case .locationUnavailable:
            "Date Day could not determine the current location."
        case .requestInProgress:
            "A location request is already in progress."
        case .manualLocationRequired:
            "Search for and select a city."
        }
    }
}

@MainActor
final class WeatherLocationService: NSObject, @preconcurrency CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation, Error>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    var authorizationStatus: CLAuthorizationStatus {
        manager.authorizationStatus
    }

    func requestLocation() async throws -> CLLocation {
        guard continuation == nil else {
            throw WeatherLocationError.requestInProgress
        }

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                continueLocationRequest()
            }
        } onCancel: { [weak self] in
            Task { @MainActor in
                self?.cancelRequest()
            }
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard continuation != nil else {
            return
        }
        continueLocationRequest()
    }

    func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        guard let location = locations.last else {
            finish(with: .failure(WeatherLocationError.locationUnavailable))
            return
        }
        finish(with: .success(location))
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        finish(with: .failure(error))
    }

    private func continueLocationRequest() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        case .denied, .restricted:
            finish(with: .failure(WeatherLocationError.permissionDenied))
        @unknown default:
            finish(with: .failure(WeatherLocationError.locationUnavailable))
        }
    }

    private func finish(with result: Result<CLLocation, Error>) {
        let continuation = continuation
        self.continuation = nil
        continuation?.resume(with: result)
    }

    private func cancelRequest() {
        finish(with: .failure(CancellationError()))
    }
}

@MainActor
final class WeatherStore {
    private static let snapshotDefaultsKey = "weatherSnapshot"
    private static let snapshotLocationModeDefaultsKey =
        "weatherSnapshotLocationMode"

    private let client = WeatherClient()
    private let locationService = WeatherLocationService()
    private var refreshTask: Task<Void, Never>?
    private var refreshTimer: Timer?
    private var refreshAfterCurrentTask = false
    private var snapshotLocationMode: WeatherLocationMode?

    private(set) var snapshot: WeatherSnapshot?
    private(set) var errorDescription: String?
    private(set) var isRefreshing = false

    init() {
        if
            let data = UserDefaults.standard.data(
                forKey: Self.snapshotDefaultsKey
            ),
            let cached = try? JSONDecoder().decode(
                WeatherSnapshot.self,
                from: data
            )
        {
            snapshot = cached
        }
        snapshotLocationMode = UserDefaults.standard
            .string(forKey: Self.snapshotLocationModeDefaultsKey)
            .flatMap(WeatherLocationMode.init(rawValue:))
    }

    var displaySnapshot: WeatherSnapshot? {
        let settings = WeatherPreference.state
        guard
            settings.isEnabled,
            snapshotLocationMode == settings.locationMode,
            let snapshot
        else {
            return nil
        }

        if
            settings.locationMode == .manual,
            snapshot.locationName != settings.manualLocation?.name
        {
            return nil
        }
        return snapshot
    }

    var authorizationDescription: String {
        switch locationService.authorizationStatus {
        case .notDetermined:
            "Not requested"
        case .authorizedAlways, .authorizedWhenInUse:
            "Granted"
        case .denied:
            "Denied"
        case .restricted:
            "Restricted"
        @unknown default:
            "Unavailable"
        }
    }

    var statusDescription: String {
        if !WeatherPreference.state.isEnabled {
            return "Weather is off."
        }
        if isRefreshing {
            return "Refreshing weather…"
        }
        if let errorDescription {
            return errorDescription
        }
        if let snapshot {
            return "Last updated \(Self.shortTimeFormatter.string(from: snapshot.fetchedAt))."
        }
        return "Weather has not loaded."
    }

    func start() {
        applySettings()
    }

    func stop() {
        refreshTimer?.invalidate()
        refreshAfterCurrentTask = false
        refreshTask?.cancel()
    }

    func applySettings() {
        refreshTimer?.invalidate()
        refreshTimer = nil

        let settings = WeatherPreference.state
        guard settings.isEnabled else {
            refreshAfterCurrentTask = false
            refreshTask?.cancel()
            if refreshTask == nil {
                isRefreshing = false
                notifyChange()
            }
            return
        }

        let timer = Timer(timeInterval: settings.refreshInterval, repeats: true) {
            [weak self] _ in
            Task { @MainActor in
                self?.refresh(force: true)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer

        if refreshTask != nil {
            refreshAfterCurrentTask = true
            notifyChange()
            return
        }
        refresh(force: false)
    }

    func refreshNow() {
        refresh(force: true)
    }

    func refreshAfterWake() {
        refresh(force: false)
    }

    func refreshAfterSystemTimeZoneChange() {
        guard WeatherPreference.state.locationMode == .automatic else {
            return
        }
        refresh(force: true)
    }

    func searchLocations(named query: String) async throws -> [WeatherLocation] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            throw WeatherClientError.locationNotFound
        }

        let languageCode = String(
            LocalePreference.currentLocale.identifier.prefix(2)
        )
        return try await client.searchLocations(
            named: trimmedQuery,
            languageCode: languageCode
        )
    }

    private func refresh(force: Bool) {
        let settings = WeatherPreference.state
        guard settings.isEnabled, refreshTask == nil else {
            return
        }

        if
            !force,
            let snapshot = displaySnapshot,
            Date.now.timeIntervalSince(snapshot.fetchedAt) < settings.refreshInterval
        {
            notifyChange()
            return
        }

        isRefreshing = true
        errorDescription = nil
        notifyChange()

        refreshTask = Task { [weak self] in
            guard let self else {
                return
            }

            do {
                let location = try await self.resolveLocation(using: settings)
                try Task.checkCancellation()
                let snapshot = try await self.client.fetchWeather(for: location)
                try Task.checkCancellation()
                self.finishRefresh(
                    with: .success(snapshot),
                    locationMode: settings.locationMode
                )
            } catch is CancellationError {
                self.finishCancelledRefresh()
            } catch {
                self.finishRefresh(
                    with: .failure(error),
                    locationMode: settings.locationMode
                )
            }
        }
    }

    private func resolveLocation(
        using settings: WeatherPreference.State
    ) async throws -> WeatherLocation {
        switch settings.locationMode {
        case .manual:
            guard let manualLocation = settings.manualLocation else {
                throw WeatherLocationError.manualLocationRequired
            }
            return manualLocation
        case .automatic:
            let location = try await locationService.requestLocation()
            let name = await locationName(for: location)
            return WeatherLocation(
                name: name,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            ).roundedForWeather
        }
    }

    private func locationName(for location: CLLocation) async -> String {
        do {
            guard let request = MKReverseGeocodingRequest(location: location) else {
                return "Current Location"
            }
            request.preferredLocale = LocalePreference.currentLocale
            let mapItems = try await request.mapItems
            return mapItems.first?.addressRepresentations?.cityName
                ?? mapItems.first?.addressRepresentations?.regionName
                ?? "Current Location"
        } catch {
            return "Current Location"
        }
    }

    private func finishRefresh(
        with result: Result<WeatherSnapshot, Error>,
        locationMode: WeatherLocationMode
    ) {
        refreshTask = nil
        isRefreshing = false

        switch result {
        case .success(let snapshot):
            self.snapshot = snapshot
            snapshotLocationMode = locationMode
            errorDescription = nil
            if let data = try? JSONEncoder().encode(snapshot) {
                UserDefaults.standard.set(data, forKey: Self.snapshotDefaultsKey)
            }
            UserDefaults.standard.set(
                locationMode.rawValue,
                forKey: Self.snapshotLocationModeDefaultsKey
            )
        case .failure(let error):
            errorDescription = error.localizedDescription
        }
        notifyChange()
        runPendingRefreshIfNeeded()
    }

    private func finishCancelledRefresh() {
        refreshTask = nil
        isRefreshing = false
        notifyChange()
        runPendingRefreshIfNeeded()
    }

    private func runPendingRefreshIfNeeded() {
        guard refreshAfterCurrentTask else {
            return
        }
        refreshAfterCurrentTask = false
        refresh(force: true)
    }

    private func notifyChange() {
        NotificationCenter.default.post(
            name: .dateDayWeatherDidChange,
            object: nil
        )
    }

    private static let shortTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()
}
