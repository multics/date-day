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

enum WorldClockDisplayResolver {
    static func visibleClocks(
        from state: WorldClockPreference.State,
        currentTimeZoneIdentifier: String = TimeZone.autoupdatingCurrent.identifier
    ) -> [WorldClockConfiguration] {
        guard state.showsClocks else {
            return []
        }

        let clocks = Array(state.clocks.prefix(3))
        let matchingClocks = clocks.filter {
            $0.timeZoneIdentifier == currentTimeZoneIdentifier
        }
        let otherClocks = clocks.filter {
            $0.timeZoneIdentifier != currentTimeZoneIdentifier
        }
        return matchingClocks + otherClocks
    }

    static func suggestedLabel(for timeZoneIdentifier: String) -> String {
        guard timeZoneIdentifier != "UTC" else {
            return "UTC"
        }

        return timeZoneIdentifier
            .split(separator: "/")
            .last
            .map(String.init)?
            .replacingOccurrences(of: "_", with: " ")
            ?? "Local"
    }
}

enum WorldClockMigration {
    static func materializeLegacySystemClock(
        in state: WorldClockPreference.State,
        currentTimeZoneIdentifier: String
    ) -> WorldClockPreference.State {
        guard let legacyIndex = state.clocks.firstIndex(where: \.isSystemTimeZone) else {
            return state
        }

        var migrated = state
        let hasCurrentClock = state.clocks.contains {
            $0.timeZoneIdentifier == currentTimeZoneIdentifier
        }
        let recordedIdentifier = state.systemTimeZoneIdentifier
        let previousIdentifier = state.previousSystemTimeZoneIdentifier
        let materializedIdentifier: String

        if
            hasCurrentClock,
            let previousIdentifier,
            previousIdentifier != currentTimeZoneIdentifier
        {
            materializedIdentifier = previousIdentifier
        } else if
            let recordedIdentifier,
            recordedIdentifier != currentTimeZoneIdentifier
        {
            materializedIdentifier = recordedIdentifier
        } else {
            materializedIdentifier = currentTimeZoneIdentifier
        }

        migrated.clocks[legacyIndex].timeZoneIdentifier = materializedIdentifier
        migrated.clocks[legacyIndex].label =
            state.labelsByTimeZoneIdentifier[materializedIdentifier]
                ?? migrated.clocks[legacyIndex].label
        return migrated
    }
}

@MainActor
enum WorldClockPreference {
    struct State: Codable, Equatable {
        var showsClocks: Bool
        var clocks: [WorldClockConfiguration]
        var systemTimeZoneIdentifier: String?
        var previousSystemTimeZoneIdentifier: String?
        var labelsByTimeZoneIdentifier: [String: String]

        init(
            showsClocks: Bool,
            clocks: [WorldClockConfiguration],
            systemTimeZoneIdentifier: String? = nil,
            previousSystemTimeZoneIdentifier: String? = nil,
            labelsByTimeZoneIdentifier: [String: String] = [:]
        ) {
            self.showsClocks = showsClocks
            self.clocks = clocks
            self.systemTimeZoneIdentifier = systemTimeZoneIdentifier
            self.previousSystemTimeZoneIdentifier = previousSystemTimeZoneIdentifier
            self.labelsByTimeZoneIdentifier = labelsByTimeZoneIdentifier
        }

        private enum CodingKeys: String, CodingKey {
            case showsClocks
            case clocks
            case systemTimeZoneIdentifier
            case previousSystemTimeZoneIdentifier
            case labelsByTimeZoneIdentifier
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            showsClocks = try container.decode(Bool.self, forKey: .showsClocks)
            clocks = try container.decode(
                [WorldClockConfiguration].self,
                forKey: .clocks
            )
            systemTimeZoneIdentifier = try container.decodeIfPresent(
                String.self,
                forKey: .systemTimeZoneIdentifier
            )
            previousSystemTimeZoneIdentifier = try container.decodeIfPresent(
                String.self,
                forKey: .previousSystemTimeZoneIdentifier
            )
            labelsByTimeZoneIdentifier = try container.decodeIfPresent(
                [String: String].self,
                forKey: .labelsByTimeZoneIdentifier
            ) ?? [:]
        }
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
        WorldClockDisplayResolver.visibleClocks(
            from: state
        )
    }

    static func update(_ change: (inout State) -> Void) {
        var updatedState = state
        change(&updatedState)
        updatedState = normalized(updatedState)
        captureLabels(in: &updatedState)
        save(updatedState)
    }

    static func migrateLegacySystemClock() {
        let currentIdentifier = TimeZone.autoupdatingCurrent.identifier
        var updatedState = WorldClockMigration.materializeLegacySystemClock(
            in: state,
            currentTimeZoneIdentifier: currentIdentifier
        )
        let previousState = state
        updatedState.systemTimeZoneIdentifier = currentIdentifier
        captureLabels(in: &updatedState)

        guard updatedState != previousState else {
            return
        }
        save(updatedState)
    }

    static func makeClock() -> WorldClockConfiguration {
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
                timeZoneIdentifier: TimeZone.autoupdatingCurrent.identifier
            ),
        ]
    )

    private static func normalized(_ state: State) -> State {
        return State(
            showsClocks: state.showsClocks,
            clocks: Array(state.clocks.prefix(3)),
            systemTimeZoneIdentifier: state.systemTimeZoneIdentifier,
            previousSystemTimeZoneIdentifier: state.previousSystemTimeZoneIdentifier,
            labelsByTimeZoneIdentifier: state.labelsByTimeZoneIdentifier
        )
    }

    private static func captureLabels(in state: inout State) {
        for clock in state.clocks {
            guard let timeZoneIdentifier = clock.timeZoneIdentifier else {
                continue
            }
            state.labelsByTimeZoneIdentifier[timeZoneIdentifier] = clock.label
        }
    }

    private static func save(_ state: State) {
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }

        NotificationCenter.default.post(
            name: .dateDayWorldClocksDidChange,
            object: nil
        )
    }
}
