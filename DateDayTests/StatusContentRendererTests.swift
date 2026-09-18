import AppKit
import Foundation
import Testing

@MainActor
struct StatusContentRendererTests {
    @Test
    func blinkingColonDoesNotChangeTheStatusItemSize() throws {
        let clock = WorldClockConfiguration(
            id: UUID(),
            label: "Current",
            timeZoneIdentifier: TimeZone.autoupdatingCurrent.identifier
        )
        let visibleDate = Date(timeIntervalSinceReferenceDate: 100)
        let hiddenDate = visibleDate.addingTimeInterval(1)

        let visibleImage = StatusContentRenderer.image(
            date: visibleDate,
            locale: Locale(identifier: "en_US"),
            clocks: [clock],
            weather: nil
        )
        let hiddenImage = StatusContentRenderer.image(
            date: hiddenDate,
            locale: Locale(identifier: "en_US"),
            clocks: [clock],
            weather: nil
        )

        #expect(visibleImage.size == hiddenImage.size)
        #expect(try #require(visibleImage.tiffRepresentation)
            != #require(hiddenImage.tiffRepresentation))
    }

    @Test
    func conditionIconsChangeWithoutChangingTheStatusItemSize() throws {
        let date = Date(timeIntervalSinceReferenceDate: 100)
        let clearImage = StatusContentRenderer.image(
            date: date,
            locale: Locale(identifier: "en_US"),
            clocks: [],
            weather: makeWeather(weatherCode: 0)
        )
        let rainImage = StatusContentRenderer.image(
            date: date,
            locale: Locale(identifier: "en_US"),
            clocks: [],
            weather: makeWeather(weatherCode: 61)
        )

        #expect(clearImage.size == rainImage.size)
        #expect(try #require(clearImage.tiffRepresentation)
            != #require(rainImage.tiffRepresentation))
    }

    private func makeWeather(weatherCode: Int) -> WeatherSnapshot {
        WeatherSnapshot(
            locationName: "Beijing",
            timeZoneIdentifier: "Asia/Shanghai",
            temperatureCelsius: 25,
            relativeHumidity: 59,
            weatherCode: weatherCode,
            observedAt: .now,
            fetchedAt: .now
        )
    }
}
