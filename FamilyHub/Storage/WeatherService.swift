import CoreLocation
import Foundation

@MainActor
final class WeatherLoader: ObservableObject {
    @Published var days: [WeatherDay] = []
    @Published var hours: [WeatherHour] = []
    @Published var now: WeatherNow?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchResults: [WeatherPlace] = []

    private let locator = LocationFinder()

    func forecastDay(on date: Date) -> WeatherDay? {
        let stamp = DateFormatter()
        stamp.dateFormat = "yyyy-MM-dd"
        stamp.locale = Locale(identifier: "en_US_POSIX")
        let iso = stamp.string(from: date)
        return days.first { $0.dateISO == iso }
    }

    func hoursOn(_ date: Date) -> [WeatherHour] {
        guard let range = CalendarMath.dayRange(date) else { return [] }
        var ofDay = hours.filter { CalendarMath.occurs($0.at, in: range) }
        if Calendar.current.isDateInToday(date) {
            ofDay = ofDay.filter { $0.at >= Date().addingTimeInterval(-20 * 60) }
        } else {
            ofDay = ofDay.filter { hour in
                let h = Calendar.current.component(.hour, from: hour.at)
                return h >= 6
            }
        }
        return ofDay
    }

    func hoursForTile(on date: Date, count: Int = 5) -> [WeatherHour] {
        if Calendar.current.isDateInToday(date) {
            let start = Date().addingTimeInterval(-20 * 60)
            return Array(hours.filter { $0.at >= start }.prefix(count))
        }
        return Array(hoursOn(date).prefix(count))
    }

    func load(place: WeatherPlace, units: HubUnits = .us) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let bundle = try await WeatherAPI.forecast(for: place, units: units)
            days = bundle.days
            hours = bundle.hours
            now = bundle.now
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
        let location = CLLocation(latitude: latitude, longitude: longitude)
        if let marks = try? await CLGeocoder().reverseGeocodeLocation(location),
           let mark = marks.first {
            let city = mark.locality ?? mark.subLocality ?? mark.name
            let region = mark.administrativeArea
            let label = [city, region].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
            if !label.isEmpty {
                return WeatherPlace(label: label, latitude: latitude, longitude: longitude)
            }
        }
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

    static func forecast(for place: WeatherPlace, units: HubUnits = .us) async throws -> WeatherBundle {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(place.latitude)),
            URLQueryItem(name: "longitude", value: String(place.longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,apparent_temperature,weather_code,is_day,relative_humidity_2m,wind_speed_10m,precipitation"),
            URLQueryItem(name: "hourly", value: "temperature_2m,weather_code,precipitation_probability,is_day,uv_index"),
            URLQueryItem(name: "daily", value: "weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,sunrise,sunset,uv_index_max,wind_speed_10m_max"),
            URLQueryItem(name: "temperature_unit", value: units.temperature.api),
            URLQueryItem(name: "wind_speed_unit", value: units.wind.rawValue),
            URLQueryItem(name: "precipitation_unit", value: units.precipitation.api),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "forecast_days", value: "16"),
        ]
        let (data, _) = try await URLSession.shared.data(from: components.url!)
        return try JSONDecoder().decode(ForecastResponse.self, from: data).bundle()
    }
}

struct WeatherBundle {
    var now: WeatherNow
    var hours: [WeatherHour]
    var days: [WeatherDay]
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
    var current: Current
    var hourly: Hourly
    var daily: Daily

    struct Current: Decodable {
        var temperature_2m: Double
        var apparent_temperature: Double
        var weather_code: Int
        var is_day: Int
        var relative_humidity_2m: Int?
        var wind_speed_10m: Double?
        var precipitation: Double?
    }

    struct Hourly: Decodable {
        var time: [String]
        var temperature_2m: [Double]
        var weather_code: [Int]
        var precipitation_probability: [Int]?
        var is_day: [Int]?
        var uv_index: [Double]?
    }

    struct Daily: Decodable {
        var time: [String]
        var weather_code: [Int]
        var temperature_2m_max: [Double]
        var temperature_2m_min: [Double]
        var precipitation_probability_max: [Int]?
        var sunrise: [String]?
        var sunset: [String]?
        var uv_index_max: [Double]?
        var wind_speed_10m_max: [Double]?
    }

    func bundle() -> WeatherBundle {
        let dayStamp = DateFormatter()
        dayStamp.dateFormat = "yyyy-MM-dd"
        dayStamp.locale = Locale(identifier: "en_US_POSIX")
        let weekday = DateFormatter()
        weekday.dateFormat = "EEE"
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withColonSeparatorInTime]
        let loose = DateFormatter()
        loose.dateFormat = "yyyy-MM-dd'T'HH:mm"
        loose.locale = Locale(identifier: "en_US_POSIX")

        func parseHour(_ raw: String) -> Date {
            iso.date(from: raw) ?? loose.date(from: raw) ?? Date()
        }
        func asInt(_ value: Double) -> Int {
            guard value.isFinite else { return 0 }
            return Int(value.rounded())
        }

        let sunriseDates = (daily.sunrise ?? []).map(parseHour)
        let sunsetDates = (daily.sunset ?? []).map(parseHour)
        let sunIsUp: Bool = {
            if let rise = sunriseDates.first, let set = sunsetDates.first {
                let nowDate = Date()
                return nowDate >= rise && nowDate < set
            }
            return current.is_day == 1
        }()

        let nowHourIndex = hourly.time.indices.first { index in
            abs(parseHour(hourly.time[index]).timeIntervalSinceNow) < 45 * 60
        }
        let nowUV: Int = {
            if let idx = nowHourIndex, let uvs = hourly.uv_index, idx < uvs.count {
                return asInt(uvs[idx])
            }
            return asInt(daily.uv_index_max?.first ?? 0)
        }()

        let precipNow = current.precipitation ?? 0
        var code = current.weather_code
        let rainCodes: Set<Int> = [51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82]
        if precipNow < 0.1, rainCodes.contains(code) {
            let pop = nowHourIndex.flatMap { idx in hourly.precipitation_probability?[idx] } ?? 0
            if pop < 40 {
                code = 2
            }
        }

        let now = WeatherNow(
            temp: asInt(current.temperature_2m),
            feelsLike: asInt(current.apparent_temperature),
            code: code,
            isDay: sunIsUp,
            humidity: current.relative_humidity_2m ?? 0,
            windMph: asInt(current.wind_speed_10m ?? 0),
            uv: nowUV,
            precip: asInt(current.precipitation ?? 0)
        )

        let start = Date().addingTimeInterval(-30 * 60)
        let hours: [WeatherHour] = zip(hourly.time.indices, hourly.time).compactMap { index, raw in
            guard hourly.temperature_2m.indices.contains(index),
                  hourly.weather_code.indices.contains(index)
            else { return nil }
            let at = parseHour(raw)
            guard at >= start else { return nil }
            let hourIsDay: Bool
            if let flags = hourly.is_day, flags.indices.contains(index) {
                hourIsDay = flags[index] == 1
            } else if let rise = sunriseDates.first, let set = sunsetDates.first {
                hourIsDay = at >= rise && at < set
            } else {
                let hour = Calendar.current.component(.hour, from: at)
                hourIsDay = hour >= 6 && hour < 20
            }
            let pop = hourly.precipitation_probability.flatMap { $0.indices.contains(index) ? $0[index] : nil } ?? 0
            return WeatherHour(
                at: at,
                temp: asInt(hourly.temperature_2m[index]),
                code: hourly.weather_code[index],
                precip: pop,
                isDay: hourIsDay
            )
        }
        .prefix(384)
        .map { $0 }

        let days: [WeatherDay] = zip(daily.time.indices, daily.time).compactMap { index, isoDay in
            guard daily.temperature_2m_max.indices.contains(index),
                  daily.temperature_2m_min.indices.contains(index),
                  daily.weather_code.indices.contains(index)
            else { return nil }
            let date = dayStamp.date(from: isoDay) ?? Date()
            return WeatherDay(
                dateISO: isoDay,
                weekday: weekday.string(from: date),
                high: asInt(daily.temperature_2m_max[index]),
                low: asInt(daily.temperature_2m_min[index]),
                code: daily.weather_code[index],
                precip: daily.precipitation_probability_max.flatMap { $0.indices.contains(index) ? $0[index] : nil } ?? 0,
                uv: asInt(daily.uv_index_max.flatMap { $0.indices.contains(index) ? $0[index] : nil } ?? 0),
                windMph: asInt(daily.wind_speed_10m_max.flatMap { $0.indices.contains(index) ? $0[index] : nil } ?? 0),
                sunrise: sunriseDates.indices.contains(index) ? sunriseDates[index] : nil,
                sunset: sunsetDates.indices.contains(index) ? sunsetDates[index] : nil
            )
        }

        return WeatherBundle(now: now, hours: hours, days: days)
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
        if let cached = manager.location, abs(cached.timestamp.timeIntervalSinceNow) < 1800 {
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
