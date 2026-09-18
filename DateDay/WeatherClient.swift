import Foundation

enum WeatherClientError: LocalizedError {
    case invalidRequest
    case invalidResponse
    case locationNotFound

    var errorDescription: String? {
        switch self {
        case .invalidRequest:
            "Date Day could not create the weather request."
        case .invalidResponse:
            "The weather service returned an invalid response."
        case .locationNotFound:
            "No matching location was found."
        }
    }
}

struct WeatherClient: Sendable {
    private struct ForecastResponse: Decodable {
        struct Current: Decodable {
            let time: TimeInterval
            let temperature: Double
            let humidity: Int
            let weatherCode: Int

            private enum CodingKeys: String, CodingKey {
                case time
                case temperature = "temperature_2m"
                case humidity = "relative_humidity_2m"
                case weatherCode = "weather_code"
            }
        }

        let current: Current
        let timezone: String
    }

    private struct GeocodingResponse: Decodable {
        struct Result: Decodable {
            let name: String
            let latitude: Double
            let longitude: Double
            let country: String?
            let administrativeArea: String?

            private enum CodingKeys: String, CodingKey {
                case name
                case latitude
                case longitude
                case country
                case administrativeArea = "admin1"
            }
        }

        let results: [Result]?
    }

    func fetchWeather(for location: WeatherLocation) async throws -> WeatherSnapshot {
        let roundedLocation = location.roundedForWeather
        guard let url = Self.forecastURL(for: roundedLocation) else {
            throw WeatherClientError.invalidRequest
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        try Self.validate(response)
        return try Self.decodeSnapshot(
            from: data,
            locationName: location.name,
            fetchedAt: .now
        )
    }

    func searchLocations(
        named query: String,
        languageCode: String
    ) async throws -> [WeatherLocation] {
        guard let url = Self.geocodingURL(
            query: query,
            languageCode: languageCode
        ) else {
            throw WeatherClientError.invalidRequest
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        try Self.validate(response)
        let decoded = try JSONDecoder().decode(GeocodingResponse.self, from: data)
        let locations = (decoded.results ?? []).map { result in
            let displayName = [
                result.name,
                result.administrativeArea == result.name
                    ? nil
                    : result.administrativeArea,
                result.country,
            ]
                .compactMap { $0 }
                .joined(separator: ", ")
            return WeatherLocation(
                name: displayName,
                latitude: result.latitude,
                longitude: result.longitude
            )
        }

        guard !locations.isEmpty else {
            throw WeatherClientError.locationNotFound
        }
        return locations
    }

    static func forecastURL(for location: WeatherLocation) -> URL? {
        var components = URLComponents(
            string: "https://api.open-meteo.com/v1/forecast"
        )
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(location.latitude)),
            URLQueryItem(name: "longitude", value: String(location.longitude)),
            URLQueryItem(
                name: "current",
                value: "temperature_2m,relative_humidity_2m,weather_code"
            ),
            URLQueryItem(name: "temperature_unit", value: "celsius"),
            URLQueryItem(name: "timeformat", value: "unixtime"),
            URLQueryItem(name: "timezone", value: "auto"),
        ]
        return components?.url
    }

    static func decodeSnapshot(
        from data: Data,
        locationName: String,
        fetchedAt: Date
    ) throws -> WeatherSnapshot {
        let response = try JSONDecoder().decode(ForecastResponse.self, from: data)
        return WeatherSnapshot(
            locationName: locationName,
            timeZoneIdentifier: response.timezone,
            temperatureCelsius: response.current.temperature,
            relativeHumidity: response.current.humidity,
            weatherCode: response.current.weatherCode,
            observedAt: Date(timeIntervalSince1970: response.current.time),
            fetchedAt: fetchedAt
        )
    }

    private static func geocodingURL(
        query: String,
        languageCode: String
    ) -> URL? {
        var components = URLComponents(
            string: "https://geocoding-api.open-meteo.com/v1/search"
        )
        components?.queryItems = [
            URLQueryItem(name: "name", value: query),
            URLQueryItem(name: "count", value: "5"),
            URLQueryItem(name: "language", value: languageCode),
            URLQueryItem(name: "format", value: "json"),
        ]
        return components?.url
    }

    private static func validate(_ response: URLResponse) throws {
        guard
            let response = response as? HTTPURLResponse,
            200..<300 ~= response.statusCode
        else {
            throw WeatherClientError.invalidResponse
        }
    }
}
