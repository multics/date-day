import Foundation

extension Notification.Name {
    static let dateDayWeatherPreferenceDidChange = Notification.Name(
        "DateDayWeatherPreferenceDidChange"
    )
    static let dateDayWeatherDidChange = Notification.Name(
        "DateDayWeatherDidChange"
    )
}

enum WeatherLocationMode: String, Codable, CaseIterable {
    case automatic
    case manual
}

struct WeatherLocation: Codable, Equatable, Sendable {
    let name: String
    let latitude: Double
    let longitude: Double

    var roundedForWeather: WeatherLocation {
        WeatherLocation(
            name: name,
            latitude: (latitude * 100).rounded() / 100,
            longitude: (longitude * 100).rounded() / 100
        )
    }
}

struct WeatherSnapshot: Codable, Equatable, Sendable {
    let locationName: String
    let timeZoneIdentifier: String
    let temperatureCelsius: Double
    let relativeHumidity: Int
    let weatherCode: Int
    let observedAt: Date
    let fetchedAt: Date

    var celsiusValueText: String {
        String(Int(temperatureCelsius.rounded()))
    }

    var fahrenheitValueText: String {
        let fahrenheit = temperatureCelsius * 9 / 5 + 32
        return String(Int(fahrenheit.rounded()))
    }

    var celsiusText: String {
        "\(celsiusValueText)°C"
    }

    var fahrenheitText: String {
        "\(fahrenheitValueText)°F"
    }

    var conditionDescription: String {
        switch weatherCode {
        case 0:
            "Clear"
        case 1:
            "Mostly clear"
        case 2:
            "Partly cloudy"
        case 3:
            "Overcast"
        case 45, 48:
            "Fog"
        case 51, 53, 55, 56, 57:
            "Drizzle"
        case 61, 63, 65, 66, 67:
            "Rain"
        case 71, 73, 75, 77:
            "Snow"
        case 80, 81, 82:
            "Rain showers"
        case 85, 86:
            "Snow showers"
        case 95, 96, 99:
            "Thunderstorm"
        default:
            "Current conditions"
        }
    }

    var conditionSymbolName: String {
        switch weatherCode {
        case 0, 1:
            "sun.max.fill"
        case 2:
            "cloud.sun.fill"
        case 3:
            "cloud.fill"
        case 45, 48:
            "cloud.fog.fill"
        case 51, 53, 55:
            "cloud.drizzle.fill"
        case 56, 57, 66, 67:
            "cloud.sleet.fill"
        case 61, 63, 65:
            "cloud.rain.fill"
        case 71, 73, 75, 77, 85, 86:
            "cloud.snow.fill"
        case 80, 81, 82:
            "cloud.heavyrain.fill"
        case 95, 96, 99:
            "cloud.bolt.rain.fill"
        default:
            "cloud.fill"
        }
    }
}

@MainActor
enum WeatherPreference {
    struct State: Codable, Equatable {
        var isEnabled: Bool
        var locationMode: WeatherLocationMode
        var manualLocation: WeatherLocation?
        var refreshInterval: TimeInterval
    }

    static let refreshIntervals: [TimeInterval] = [5, 10, 30, 60].map {
        $0 * 60
    }

    private static let defaultsKey = "weatherConfiguration"
    private static let defaultState = State(
        isEnabled: false,
        locationMode: .automatic,
        manualLocation: nil,
        refreshInterval: 30 * 60
    )

    static var state: State {
        guard
            let data = UserDefaults.standard.data(forKey: defaultsKey),
            let decoded = try? JSONDecoder().decode(State.self, from: data)
        else {
            return defaultState
        }

        var normalized = decoded
        if !refreshIntervals.contains(normalized.refreshInterval) {
            normalized.refreshInterval = defaultState.refreshInterval
        }
        return normalized
    }

    static func update(_ change: (inout State) -> Void) {
        var updatedState = state
        change(&updatedState)

        guard let data = try? JSONEncoder().encode(updatedState) else {
            return
        }
        UserDefaults.standard.set(data, forKey: defaultsKey)
        NotificationCenter.default.post(
            name: .dateDayWeatherPreferenceDidChange,
            object: nil
        )
    }
}
