import Foundation

extension Notification.Name {
    static let dateDayWorldClocksDidChange = Notification.Name(
        "DateDayWorldClocksDidChange"
    )
}

struct WorldClockConfiguration: Codable, Equatable, Identifiable {
    let id: UUID
    var label: String
    var timeZoneIdentifier: String?

    var isSystemTimeZone: Bool {
        timeZoneIdentifier == nil
    }

    var timeZone: TimeZone {
        guard let timeZoneIdentifier else {
            return .autoupdatingCurrent
        }
        return TimeZone(identifier: timeZoneIdentifier) ?? .gmt
    }
}

@MainActor
enum WorldClockPreference {
    struct State: Codable, Equatable {
        var showsClocks: Bool
        var clocks: [WorldClockConfiguration]
    }

    static let timeZoneIdentifiers = TimeZone.knownTimeZoneIdentifiers.sorted()

    private static let defaultsKey = "worldClockConfiguration"

    static var state: State {
        guard
            let data = UserDefaults.standard.data(forKey: defaultsKey),
            let decoded = try? JSONDecoder().decode(State.self, from: data)
        else {
            return defaultState
        }

        return normalized(decoded)
    }

    static var visibleClocks: [WorldClockConfiguration] {
        state.showsClocks ? state.clocks : []
    }

    static func update(_ change: (inout State) -> Void) {
        var updatedState = state
        change(&updatedState)
        updatedState = normalized(updatedState)

        if let data = try? JSONEncoder().encode(updatedState) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }

        NotificationCenter.default.post(
            name: .dateDayWorldClocksDidChange,
            object: nil
        )
    }

    static func makeSecondaryClock() -> WorldClockConfiguration {
        WorldClockConfiguration(
            id: UUID(),
            label: "UTC",
            timeZoneIdentifier: "UTC"
        )
    }

    private static let defaultState = State(
        showsClocks: false,
        clocks: [
            WorldClockConfiguration(
                id: UUID(),
                label: "Local",
                timeZoneIdentifier: nil
            ),
        ]
    )

    private static func normalized(_ state: State) -> State {
        let systemClock = state.clocks.first(where: \.isSystemTimeZone)
            ?? defaultState.clocks[0]
        let secondaryClocks = state.clocks
            .filter { !$0.isSystemTimeZone }
            .prefix(2)

        return State(
            showsClocks: state.showsClocks,
            clocks: [systemClock] + secondaryClocks
        )
    }
}
