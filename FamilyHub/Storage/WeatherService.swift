import CoreLocation
import Foundation
import MapKit
import WeatherKit

@MainActor
final class WeatherLoader: ObservableObject {
    @Published var days: [WeatherDay] = []
    @Published var hours: [WeatherHour] = []
    @Published var now: WeatherNow?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchResults: [WeatherPlace] = []

    private let locator = LocationFinder()

    private static let dayStamp: DateFormatter = {
        let stamp = DateFormatter()
        stamp.dateFormat = "yyyy-MM-dd"
        stamp.locale = Locale(identifier: "en_US_POSIX")
        return stamp
    }()

    func forecastDay(on date: Date) -> WeatherDay? {
        days.first { $0.dateISO == Self.dayStamp.string(from: date) }
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
            errorMessage = "Weather unavailable"
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
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = .address
        let response = try await MKLocalSearch(request: request).start()
        return response.mapItems.prefix(6).compactMap { item in
            let coord = item.placemark.coordinate
            let city = item.placemark.locality ?? item.name ?? ""
            guard !city.isEmpty else { return nil }
            let region = item.placemark.administrativeArea
            let label = [city, region].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
            return WeatherPlace(label: label, latitude: coord.latitude, longitude: coord.longitude)
        }
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
        return WeatherPlace(label: "Current location", latitude: latitude, longitude: longitude)
    }

    static func forecast(for place: WeatherPlace, units: HubUnits = .us) async throws -> WeatherBundle {
        let location = CLLocation(latitude: place.latitude, longitude: place.longitude)
        let weather = try await WeatherService.shared.weather(for: location)
        return WeatherKitMap.bundle(weather, units: units)
    }

    static func attribution() async -> (name: String, legal: URL?) {
        guard let attribution = try? await WeatherService.shared.attribution else {
            return ("Weather", nil)
        }
        return (attribution.serviceName, attribution.legalPageURL)
    }
}

struct WeatherBundle {
    var now: WeatherNow
    var hours: [WeatherHour]
    var days: [WeatherDay]
}

private enum WeatherKitMap {
    static func bundle(_ weather: Weather, units: HubUnits) -> WeatherBundle {
        let current = weather.currentWeather
        let tempUnit: UnitTemperature = units.temperature == .celsius ? .celsius : .fahrenheit
        let speedUnit: UnitSpeed = {
            switch units.wind {
            case .kmh: return .kilometersPerHour
            case .ms: return .metersPerSecond
            case .kn: return .knots
            case .mph: return .milesPerHour
            }
        }()
        let nowChance = weather.hourlyForecast.forecast.min {
            abs($0.date.timeIntervalSinceNow) < abs($1.date.timeIntervalSinceNow)
        }
        let now = WeatherNow(
            temp: Int(current.temperature.converted(to: tempUnit).value.rounded()),
            feelsLike: Int(current.apparentTemperature.converted(to: tempUnit).value.rounded()),
            code: code(current.condition),
            isDay: current.isDaylight,
            humidity: Int((current.humidity * 100).rounded()),
            windMph: Int(current.wind.speed.converted(to: speedUnit).value.rounded()),
            uv: current.uvIndex.value,
            precip: Int(((nowChance?.precipitationChance ?? 0) * 100).rounded())
        )
        let start = Date().addingTimeInterval(-30 * 60)
        let hours: [WeatherHour] = weather.hourlyForecast.forecast.prefix(384).compactMap { hour in
            guard hour.date >= start else { return nil }
            return WeatherHour(
                at: hour.date,
                temp: Int(hour.temperature.converted(to: tempUnit).value.rounded()),
                code: code(hour.condition),
                precip: Int((hour.precipitationChance * 100).rounded()),
                isDay: hour.isDaylight
            )
        }
        let stamp = DateFormatter()
        stamp.dateFormat = "yyyy-MM-dd"
        stamp.locale = Locale(identifier: "en_US_POSIX")
        let weekday = DateFormatter()
        weekday.dateFormat = "EEE"
        let days: [WeatherDay] = weather.dailyForecast.forecast.map { day in
            WeatherDay(
                dateISO: stamp.string(from: day.date),
                weekday: weekday.string(from: day.date),
                high: Int(day.highTemperature.converted(to: tempUnit).value.rounded()),
                low: Int(day.lowTemperature.converted(to: tempUnit).value.rounded()),
                code: code(day.condition),
                precip: Int((day.precipitationChance * 100).rounded()),
                uv: day.uvIndex.value,
                windMph: Int(day.wind.speed.converted(to: speedUnit).value.rounded()),
                sunrise: day.sun.sunrise,
                sunset: day.sun.sunset
            )
        }
        return WeatherBundle(now: now, hours: hours, days: days)
    }

    static func code(_ condition: WeatherCondition) -> Int {
        switch condition {
        case .clear, .mostlyClear, .hot: return 0
        case .partlyCloudy, .windy: return 2
        case .cloudy, .mostlyCloudy, .blowingDust, .haze, .smoky: return 3
        case .foggy, .breezy: return 45
        case .drizzle, .freezingDrizzle: return 51
        case .rain, .sunShowers, .heavyRain: return 61
        case .freezingRain, .wintryMix: return 67
        case .snow, .flurries, .sunFlurries, .heavySnow, .blowingSnow, .blizzard: return 71
        case .sleet, .hail: return 77
        case .thunderstorms, .isolatedThunderstorms, .scatteredThunderstorms, .strongStorms: return 95
        case .frigid, .hurricane, .tropicalStorm: return 95
        default: return 3
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
        if let cached = manager.location, abs(cached.timestamp.timeIntervalSinceNow) < 1800 {
            return cached
        }
        return try await withThrowingTaskGroup(of: CLLocation.self) { group in
            group.addTask { try await self.requestOnce() }
            group.addTask {
                try await Task.sleep(for: .seconds(12))
                throw LocationError.timeout
            }
            guard let first = try await group.next() else { throw LocationError.timeout }
            group.cancelAll()
            return first
        }
    }

    private let resumeLock = NSLock()

    private func finish(_ body: (CheckedContinuation<CLLocation, Error>) -> Void) {
        resumeLock.lock()
        let current = continuation
        continuation = nil
        resumeLock.unlock()
        guard let current else { return }
        body(current)
    }

    private func requestOnce() async throws -> CLLocation {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                let status = manager.authorizationStatus
                if status == .notDetermined {
                    manager.requestWhenInUseAuthorization()
                } else if status == .denied || status == .restricted {
                    finish { $0.resume(throwing: LocationError.denied) }
                } else {
                    manager.requestLocation()
                }
            }
        } onCancel: {
            self.finish { $0.resume(throwing: CancellationError()) }
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        case .denied, .restricted:
            finish { $0.resume(throwing: LocationError.denied) }
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        finish { $0.resume(returning: location) }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        finish { $0.resume(throwing: error) }
    }
}

enum LocationError: LocalizedError {
    case denied
    case timeout

    var errorDescription: String? {
        switch self {
        case .denied:
            return "Location is off. Allow it in Settings, or type a city or ZIP."
        case .timeout:
            return "Could not find you yet. Try again or type a city or ZIP."
        }
    }
}
