import Foundation
import Testing

struct WeatherTests {
    @Test
    func formatsCelsiusAndFahrenheitFromOneMeasurement() {
        let snapshot = makeSnapshot(temperatureCelsius: 25.5)

        #expect(snapshot.celsiusValueText == "26")
        #expect(snapshot.fahrenheitValueText == "78")
        #expect(snapshot.celsiusText == "26°C")
        #expect(snapshot.fahrenheitText == "78°F")
    }

    @Test
    func selectsFamiliarSymbolsForWeatherConditions() {
        #expect(makeSnapshot(weatherCode: 0).conditionSymbolName == "sun.max.fill")
        #expect(makeSnapshot(weatherCode: 2).conditionSymbolName == "cloud.sun.fill")
        #expect(makeSnapshot(weatherCode: 51).conditionSymbolName == "cloud.drizzle.fill")
        #expect(makeSnapshot(weatherCode: 67).conditionSymbolName == "cloud.sleet.fill")
        #expect(makeSnapshot(weatherCode: 75).conditionSymbolName == "cloud.snow.fill")
        #expect(makeSnapshot(weatherCode: 95).conditionSymbolName == "cloud.bolt.rain.fill")
    }

    @Test
    func roundsCoordinatesBeforeSendingThem() {
        let location = WeatherLocation(
            name: "Beijing",
            latitude: 40.03607835060093,
            longitude: 116.4204528308149
        ).roundedForWeather

        #expect(location.latitude == 40.04)
        #expect(location.longitude == 116.42)
    }

    @Test
    func decodesAnOpenMeteoCurrentWeatherResponse() throws {
        let data = Data(
            #"{"timezone":"Asia/Shanghai","current":{"time":1788776100,"temperature_2m":24.5,"relative_humidity_2m":66,"weather_code":51}}"#.utf8
        )
        let fetchedAt = Date(timeIntervalSince1970: 1_788_776_200)

        let snapshot = try WeatherClient.decodeSnapshot(
            from: data,
            locationName: "Beijing",
            fetchedAt: fetchedAt
        )

        #expect(snapshot.locationName == "Beijing")
        #expect(snapshot.timeZoneIdentifier == "Asia/Shanghai")
        #expect(snapshot.temperatureCelsius == 24.5)
        #expect(snapshot.relativeHumidity == 66)
        #expect(snapshot.conditionDescription == "Drizzle")
        #expect(snapshot.observedAt.timeIntervalSince1970 == 1_788_776_100)
        #expect(snapshot.fetchedAt == fetchedAt)
    }

    private func makeSnapshot(
        temperatureCelsius: Double = 25.5,
        weatherCode: Int = 3
    ) -> WeatherSnapshot {
        WeatherSnapshot(
            locationName: "Beijing",
            timeZoneIdentifier: "Asia/Shanghai",
            temperatureCelsius: temperatureCelsius,
            relativeHumidity: 59,
            weatherCode: weatherCode,
            observedAt: .now,
            fetchedAt: .now
        )
    }
}
