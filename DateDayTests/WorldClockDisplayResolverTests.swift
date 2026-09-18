import Foundation
import Testing

@MainActor
struct WorldClockDisplayResolverTests {
    private let legacySystemClock = WorldClockConfiguration(
        id: UUID(),
        label: "CA",
        timeZoneIdentifier: nil
    )
    private let californiaClock = WorldClockConfiguration(
        id: UUID(),
        label: "CA",
        timeZoneIdentifier: "America/Los_Angeles"
    )
    private let beijingClock = WorldClockConfiguration(
        id: UUID(),
        label: "BJ",
        timeZoneIdentifier: "Asia/Shanghai"
    )

    @Test
    func movesTheCurrentTimeZoneClockFirst() {
        let utcClock = WorldClockConfiguration(
            id: UUID(),
            label: "UTC",
            timeZoneIdentifier: "UTC"
        )
        let state = WorldClockPreference.State(
            showsClocks: true,
            clocks: [californiaClock, beijingClock, utcClock]
        )

        let clocks = WorldClockDisplayResolver.visibleClocks(
            from: state,
            currentTimeZoneIdentifier: "Asia/Shanghai"
        )

        #expect(clocks.map(\.label) == ["BJ", "CA", "UTC"])
    }

    @Test
    func keepsConfiguredOrderWhenNoClockMatches() {
        let state = WorldClockPreference.State(
            showsClocks: true,
            clocks: [californiaClock, beijingClock]
        )

        let clocks = WorldClockDisplayResolver.visibleClocks(
            from: state,
            currentTimeZoneIdentifier: "Europe/London"
        )

        #expect(clocks.map(\.label) == ["CA", "BJ"])
    }

    @Test
    func materializesThePreviousZoneFromTravelPreferences() {
        let state = WorldClockPreference.State(
            showsClocks: true,
            clocks: [legacySystemClock, beijingClock],
            systemTimeZoneIdentifier: "Asia/Shanghai",
            previousSystemTimeZoneIdentifier: "America/Los_Angeles",
            labelsByTimeZoneIdentifier: [
                "America/Los_Angeles": "CA",
                "Asia/Shanghai": "BJ",
            ]
        )

        let migrated = WorldClockMigration.materializeLegacySystemClock(
            in: state,
            currentTimeZoneIdentifier: "Asia/Shanghai"
        )

        #expect(migrated.clocks.map(\.label) == ["CA", "BJ"])
        #expect(migrated.clocks.map(\.timeZoneIdentifier) == [
            "America/Los_Angeles",
            "Asia/Shanghai",
        ])
    }

    @Test
    func retainsThreeConfiguredClocks() {
        let utcClock = WorldClockConfiguration(
            id: UUID(),
            label: "UTC",
            timeZoneIdentifier: "UTC"
        )
        let state = WorldClockPreference.State(
            showsClocks: true,
            clocks: [californiaClock, beijingClock, utcClock],
            systemTimeZoneIdentifier: "America/Los_Angeles",
            labelsByTimeZoneIdentifier: [
                "America/Los_Angeles": "CA",
                "Asia/Shanghai": "BJ",
                "UTC": "UTC",
            ]
        )

        let clocks = WorldClockDisplayResolver.visibleClocks(
            from: state,
            currentTimeZoneIdentifier: "America/Los_Angeles"
        )

        #expect(clocks.map(\.label) == ["CA", "BJ", "UTC"])
    }

    @Test
    func decodesPreferencesWrittenByEarlierVersions() throws {
        let data = Data(
            #"{"showsClocks":true,"clocks":[{"id":"1414F125-9DA8-4278-AA08-D30F133B127F","label":"CA"}]}"#.utf8
        )

        let state = try JSONDecoder().decode(
            WorldClockPreference.State.self,
            from: data
        )

        #expect(state.showsClocks)
        #expect(state.clocks.first?.label == "CA")
        #expect(state.systemTimeZoneIdentifier == nil)
        #expect(state.previousSystemTimeZoneIdentifier == nil)
        #expect(state.labelsByTimeZoneIdentifier.isEmpty)
    }
}
