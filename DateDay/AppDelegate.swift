import AppKit
import Darwin
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSMenuItemValidation {
    private var singletonLockFileDescriptor: Int32 = -1
    private var statusItem: NSStatusItem?
    private var timeZoneItems: [NSMenuItem] = []
    private var isChangingTimeZone = false
    private let timeZoneAuthorization = TimeZoneAuthorization()
    private var updateTimer: Timer?
    private var settingsWindowController: SettingsWindowController?
    private let weatherStore = WeatherStore()
    private let weatherLocationItem = NSMenuItem()
    private let weatherObservedItem = NSMenuItem()
    private let weatherConditionsItem = NSMenuItem()
    private let weatherRefreshItem = NSMenuItem(
        title: "Refresh Weather Now",
        action: nil,
        keyEquivalent: "r"
    )
    private let weatherSeparator = NSMenuItem.separator()
    private let launchAtLoginItem = NSMenuItem(
        title: "Launch at Login",
        action: nil,
        keyEquivalent: ""
    )
    private let launchAtLoginMessage = NSMenuItem(
        title: "Approval is required in System Settings.",
        action: nil,
        keyEquivalent: ""
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard acquireSingletonLock() else {
            activateExistingInstance()
            NSApp.terminate(nil)
            return
        }

        WorldClockPreference.migrateLegacySystemClock()
        configureStatusItem()
        observeSystemChanges()
        startUpdateTimer()
        weatherStore.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        updateTimer?.invalidate()
        weatherStore.stop()
        NotificationCenter.default.removeObserver(self)
        if singletonLockFileDescriptor >= 0 {
            Darwin.close(singletonLockFileDescriptor)
            singletonLockFileDescriptor = -1
        }
    }

    private func acquireSingletonLock() -> Bool {
        let lockURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("com.yongtian.DateDay.lock")
        let descriptor = Darwin.open(
            lockURL.path,
            O_CREAT | O_RDWR | O_EXLOCK | O_NONBLOCK,
            S_IRUSR | S_IWUSR
        )
        guard descriptor >= 0 else {
            return !hasAnotherRunningInstance
        }
        singletonLockFileDescriptor = descriptor
        return true
    }

    private var hasAnotherRunningInstance: Bool {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            return false
        }
        let currentProcessIdentifier = ProcessInfo.processInfo.processIdentifier
        return NSRunningApplication.runningApplications(
            withBundleIdentifier: bundleIdentifier
        ).contains {
            $0.processIdentifier != currentProcessIdentifier
                && !$0.isTerminated
        }
    }

    private func activateExistingInstance() {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            return
        }
        let currentProcessIdentifier = ProcessInfo.processInfo.processIdentifier
        NSRunningApplication.runningApplications(
            withBundleIdentifier: bundleIdentifier
        ).first {
            $0.processIdentifier != currentProcessIdentifier
                && !$0.isTerminated
        }?.activate()
    }

    func menuWillOpen(_ menu: NSMenu) {
        refreshTimeZoneMenu()
        refreshLaunchAtLoginStatus()
        refreshWeatherMenu()
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.autosaveName = "DateDayStatusItem"

        if let button = item.button {
            button.title = ""
            button.imagePosition = .imageOnly
            button.imageScaling = .scaleNone
            button.toolTip = "Date Day"
            button.setAccessibilityLabel("Date, clocks, and weather")
        }

        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(.separator())

        weatherLocationItem.isEnabled = false
        menu.addItem(weatherLocationItem)
        weatherObservedItem.isEnabled = false
        menu.addItem(weatherObservedItem)
        weatherConditionsItem.isEnabled = false
        menu.addItem(weatherConditionsItem)

        weatherRefreshItem.target = self
        weatherRefreshItem.action = #selector(refreshWeather)
        menu.addItem(weatherRefreshItem)
        menu.addItem(weatherSeparator)

        launchAtLoginItem.target = self
        launchAtLoginItem.action = #selector(toggleLaunchAtLogin)
        menu.addItem(launchAtLoginItem)

        launchAtLoginMessage.isEnabled = false
        menu.addItem(launchAtLoginMessage)
        menu.addItem(.separator())

        let settingsItem = NSMenuItem(
            title: "Settings…",
            action: #selector(showSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        let aboutItem = NSMenuItem(
            title: "About Date Day",
            action: #selector(showAboutSettings),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit Date Day",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        item.menu = menu
        statusItem = item

        updateDate()
        refreshWeatherMenu()
        refreshLaunchAtLoginStatus()
    }

    private func observeSystemChanges() {
        let notifications: [Notification.Name] = [
            NSLocale.currentLocaleDidChangeNotification,
            .NSSystemClockDidChange,
            .NSCalendarDayChanged,
            .dateDayLocalePreferenceDidChange,
            .dateDayWorldClocksDidChange,
        ]

        for name in notifications {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleSystemChange),
                name: name,
                object: nil
            )
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSystemTimeZoneChange),
            name: .NSSystemTimeZoneDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWeatherPreferenceChange),
            name: .dateDayWeatherPreferenceDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWeatherStateChange),
            name: .dateDayWeatherDidChange,
            object: nil
        )
    }

    @objc nonisolated private func handleSystemChange() {
        Task { @MainActor [weak self] in
            self?.updateDate()
        }
    }

    @objc nonisolated private func handleSystemTimeZoneChange() {
        Task { @MainActor [weak self] in
            self?.weatherStore.refreshAfterSystemTimeZoneChange()
            self?.settingsWindowController?.refreshForSystemChange()
            self?.updateDate()
        }
    }

    @objc nonisolated private func handleWake() {
        Task { @MainActor [weak self] in
            self?.weatherStore.refreshAfterWake()
            self?.settingsWindowController?.refreshForSystemChange()
            self?.updateDate()
        }
    }

    @objc nonisolated private func handleWeatherPreferenceChange() {
        Task { @MainActor [weak self] in
            self?.weatherStore.applySettings()
            self?.settingsWindowController?.refreshForWeatherChange()
            self?.updateDate()
        }
    }

    @objc nonisolated private func handleWeatherStateChange() {
        Task { @MainActor [weak self] in
            self?.settingsWindowController?.refreshForWeatherChange()
            self?.refreshWeatherMenu()
            self?.updateDate()
        }
    }

    private func startUpdateTimer() {
        let timer = Timer(
            timeInterval: 1,
            target: self,
            selector: #selector(updateDate),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(timer, forMode: .common)
        updateTimer = timer
    }

    @objc private func updateDate() {
        let now = Date.now
        let locale = LocalePreference.currentLocale
        let clocks = WorldClockPreference.visibleClocks
        let weather = weatherStore.displaySnapshot

        let image = StatusContentRenderer.image(
            date: now,
            locale: locale,
            clocks: clocks,
            weather: weather
        )

        guard let statusItem, let button = statusItem.button else {
            return
        }

        statusItem.length = image.size.width
        button.image = image
        let dateDescription = DateDayFormatter.string(
            for: now,
            locale: locale,
            timeZone: .autoupdatingCurrent
        )
        let clockDescriptions = clocks.map { clock in
            let time = DateDayFormatter.timeString(
                for: now,
                locale: locale,
                timeZone: clock.timeZone
            )
            return "\(clock.label) \(time)"
        }
        let weatherDescription = weather.map {
            "\($0.conditionDescription), \($0.celsiusText), \($0.fahrenheitText)"
        }
        var accessibilityDescriptions = [dateDescription]
        accessibilityDescriptions.append(contentsOf: clockDescriptions)
        if let weatherDescription {
            accessibilityDescriptions.append(weatherDescription)
        }
        button.setAccessibilityValue(
            accessibilityDescriptions.joined(separator: ", ")
        )
    }

    private func refreshTimeZoneMenu() {
        guard let menu = statusItem?.menu else { return }
        timeZoneItems.forEach { menu.removeItem($0) }
        timeZoneItems = []
        let now = Date.now
        for (index, clock) in WorldClockPreference.visibleClocks.enumerated() {
            let identifier = clock.timeZone.identifier
            let time = DateDayFormatter.timeString(
                for: now, locale: LocalePreference.currentLocale, timeZone: clock.timeZone
            )
            let item = NSMenuItem(
                title: "\(clock.label)  \(time)",
                action: #selector(selectSystemTimeZone(_:)), keyEquivalent: ""
            )
            item.target = self
            item.representedObject = identifier
            item.toolTip = "Set the Mac time zone to \(identifier)"
            menu.insertItem(item, at: index)
            timeZoneItems.append(item)
        }
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        guard menuItem.action == #selector(selectSystemTimeZone(_:)) else { return true }
        return menuItem.representedObject as? String != TimeZone.autoupdatingCurrent.identifier
    }

    @objc private func selectSystemTimeZone(_ sender: NSMenuItem) {
        guard let identifier = sender.representedObject as? String else { return }
        changeSystemTimeZone(to: identifier)
    }

    private func changeSystemTimeZone(to identifier: String) {
        guard !isChangingTimeZone,
              identifier != TimeZone.autoupdatingCurrent.identifier,
              TimeZone.knownTimeZoneIdentifiers.contains(identifier) else { return }
        isChangingTimeZone = true
        NSApp.activate(ignoringOtherApps: true)
        Task { [weak self] in
            guard let self else { return }
            defer { self.isChangingTimeZone = false }
            do {
                try await self.timeZoneAuthorization.change(to: identifier)
                NSTimeZone.resetSystemTimeZone()
                self.handleSystemTimeZoneChange()
            } catch {
                self.showError(error)
            }
        }
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
            refreshLaunchAtLoginStatus()
        } catch {
            refreshLaunchAtLoginStatus()
            showError(error)
        }
    }

    private func refreshLaunchAtLoginStatus() {
        let status = SMAppService.mainApp.status
        launchAtLoginItem.state = status == .enabled ? .on : .off
        launchAtLoginMessage.isHidden = status != .requiresApproval
    }

    @objc private func showSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(
                weatherStore: weatherStore
            )
        }
        settingsWindowController?.showWindow(nil)
    }

    @objc private func showAboutSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(
                weatherStore: weatherStore
            )
        }
        settingsWindowController?.showAbout()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    @objc private func refreshWeather() {
        weatherStore.refreshNow()
        refreshWeatherMenu()
    }

    private func refreshWeatherMenu() {
        let isEnabled = WeatherPreference.state.isEnabled
        let weatherItems = [
            weatherLocationItem,
            weatherObservedItem,
            weatherConditionsItem,
            weatherRefreshItem,
            weatherSeparator,
        ]
        for item in weatherItems {
            item.isHidden = !isEnabled
        }

        guard isEnabled else {
            return
        }

        weatherRefreshItem.title = weatherStore.isRefreshing
            ? "Refreshing Weather…"
            : "Refresh Weather Now"
        weatherRefreshItem.isEnabled = !weatherStore.isRefreshing

        guard let snapshot = weatherStore.displaySnapshot else {
            weatherLocationItem.title = "Weather"
            weatherObservedItem.title = weatherStore.statusDescription
            weatherConditionsItem.isHidden = true
            return
        }

        weatherLocationItem.title = snapshot.locationName
        let weatherTimeZone = TimeZone(identifier: snapshot.timeZoneIdentifier)
            ?? .autoupdatingCurrent
        let observedTime = DateDayFormatter.timeString(
            for: snapshot.observedAt,
            locale: LocalePreference.currentLocale,
            timeZone: weatherTimeZone
        )
        weatherObservedItem.title = weatherStore.errorDescription == nil
            ? "Observed \(observedTime)"
            : "Observed \(observedTime) · Update failed"
        weatherConditionsItem.title = "\(snapshot.conditionDescription) · Humidity \(snapshot.relativeHumidity)%"
        weatherConditionsItem.isHidden = false
    }

    private func showError(_ error: Error) {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert(error: error)
        alert.runModal()
    }
}
