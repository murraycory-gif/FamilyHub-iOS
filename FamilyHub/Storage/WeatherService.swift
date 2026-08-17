import CoreLocation
import Foundation

@MainActor
final class WeatherLoader: ObservableObject {
    @Published var days: [WeatherDay] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchResults: [WeatherPlace] = []

    private let locator = LocationFinder()

    func load(place: WeatherPlace) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            days = try await WeatherAPI.forecast(for: place)
        } catch {
            errorMessage = "Could not load weather."
        }
    }

    func search(query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            searchResults = []
            return
        }
        do {
            searchResults = try await WeatherAPI.searchPlaces(trimmed)
        } catch {
            searchResults = []
        }
    }

    func placeFromCurrentLocation() async throws -> WeatherPlace {
        let location = try await locator.current()
        return try await WeatherAPI.reverseGeocode(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
    }
}

enum WeatherAPI {
    static func searchPlaces(_ query: String) async throws -> [WeatherPlace] {
        var components = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")!
        components.queryItems = [
            URLQueryItem(name: "name", value: query),
            URLQueryItem(name: "count", value: "6"),
            URLQueryItem(name: "language", value: "en"),
            URLQueryItem(name: "format", value: "json"),
        ]
        let (data, _) = try await URLSession.shared.data(from: components.url!)
        let decoded = try JSONDecoder().decode(GeocodeSearch.self, from: data)
        return (decoded.results ?? []).map(\.place)
    }

    static func reverseGeocode(latitude: Double, longitude: Double) async throws -> WeatherPlace {
        var components = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/reverse")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "language", value: "en"),
            URLQueryItem(name: "format", value: "json"),
        ]
        let (data, _) = try await URLSession.shared.data(from: components.url!)
        if let decoded = try? JSONDecoder().decode(GeocodeSearch.self, from: data),
           let first = decoded.results?.first {
            return first.place
        }
        return WeatherPlace(
            label: "Current location",
            latitude: latitude,
            longitude: longitude
        )
    }

    static func forecast(for place: WeatherPlace) async throws -> [WeatherDay] {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(place.latitude)),
            URLQueryItem(name: "longitude", value: String(place.longitude)),
            URLQueryItem(name: "daily", value: "weather_code,temperature_2m_max,temperature_2m_min"),
            URLQueryItem(name: "temperature_unit", value: "fahrenheit"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "forecast_days", value: "7"),
        ]
        let (data, _) = try await URLSession.shared.data(from: components.url!)
        let decoded = try JSONDecoder().decode(ForecastResponse.self, from: data)
        return decoded.days()
    }
}

private struct GeocodeSearch: Decodable {
    var results: [GeocodeHit]?
}

private struct GeocodeHit: Decodable {
    var name: String
    var latitude: Double
    var longitude: Double
    var admin1: String?
    var country_code: String?

    var place: WeatherPlace {
        var parts = [name]
        if let admin1, !admin1.isEmpty { parts.append(admin1) }
        if let country_code, country_code != "US" { parts.append(country_code) }
        return WeatherPlace(label: parts.joined(separator: ", "), latitude: latitude, longitude: longitude)
    }
}

private struct ForecastResponse: Decodable {
    var daily: Daily

    struct Daily: Decodable {
        var time: [String]
        var weather_code: [Int]
        var temperature_2m_max: [Double]
        var temperature_2m_min: [Double]
    }

    func days() -> [WeatherDay] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let weekday = DateFormatter()
        weekday.dateFormat = "EEE"
        return zip(daily.time.indices, daily.time).map { index, iso in
            let date = formatter.date(from: iso) ?? Date()
            return WeatherDay(
                dateISO: iso,
                weekday: weekday.string(from: date),
                high: Int(daily.temperature_2m_max[index].rounded()),
                low: Int(daily.temperature_2m_min[index].rounded()),
                code: daily.weather_code[index]
            )
        }
    }
}

final class LocationFinder: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation, Error>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func current() async throws -> CLLocation {
        if let cached = manager.location, abs(cached.timestamp.timeIntervalSinceNow) < 300 {
            return cached
        }
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let status = manager.authorizationStatus
            if status == .notDetermined {
                manager.requestWhenInUseAuthorization()
            } else if status == .denied || status == .restricted {
                continuation.resume(throwing: LocationError.denied)
                self.continuation = nil
            } else {
                manager.requestLocation()
            }
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        case .denied, .restricted:
            continuation?.resume(throwing: LocationError.denied)
            continuation = nil
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        continuation?.resume(returning: location)
        continuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}

enum LocationError: LocalizedError {
    case denied

    var errorDescription: String? {
        "Location access is off. Search a city or ZIP instead."
    }
}
