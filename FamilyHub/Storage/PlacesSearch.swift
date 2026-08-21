import Combine
import CoreLocation
import Foundation
import MapKit

enum PlaceMode: String, CaseIterable, Identifiable, Codable {
    case sitdown
    case takeout
    case delivery

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sitdown: return "Eating out"
        case .takeout: return "Take out"
        case .delivery: return "Delivery"
        }
    }

    var symbol: String {
        switch self {
        case .sitdown: return "fork.knife"
        case .takeout: return "bag.fill"
        case .delivery: return "bicycle"
        }
    }
}

struct NearbyPlace: Identifiable, Hashable, Codable {
    var id: String
    var name: String
    var category: String
    var address: String
    var phone: String
    var url: URL?
    var latitude: Double
    var longitude: Double
    var distance: CLLocationDistance?
    var mode: PlaceMode

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var distanceLabel: String? {
        guard let distance = distance else { return nil }
        let miles = distance / 1609.34
        if miles < 0.1 { return "Nearby" }
        return String(format: "%.1f mi", miles)
    }

    static func == (lhs: NearbyPlace, rhs: NearbyPlace) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct AreaSuggestion: Identifiable, Hashable {
    var id: String { title + subtitle }
    var title: String
    var subtitle: String
    var query: String {
        [title, subtitle].filter { !$0.isEmpty }.joined(separator: ", ")
    }
}

final class AreaCompleter: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var suggestions: [AreaSuggestion] = []
    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.resultTypes = .pointOfInterest
        completer.delegate = self
    }

    func update(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count < 2 {
            suggestions = []
            return
        }
        completer.queryFragment = trimmed
    }

    func clear() { suggestions = [] }

    func setRegion(_ location: CLLocation) {
        completer.region = MKCoordinateRegion(
            center: location.coordinate,
            latitudinalMeters: 32000,
            longitudinalMeters: 32000
        )
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let mapped = completer.results.prefix(8).map {
            AreaSuggestion(title: $0.title, subtitle: $0.subtitle)
        }
        DispatchQueue.main.async { self.suggestions = mapped }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {}
}

@MainActor
final class PlacesSearch: ObservableObject {
    @Published var places: [NearbyPlace] = []
    @Published var mode: PlaceMode = .sitdown
    @Published var isLoading = false
    @Published var message: String?
    @Published var userLocation: CLLocation?
    @Published var areaName = "Current location"

    private var searchCenter: CLLocation?
    private let locator = LocationFinder()
    private let maxMeters: CLLocationDistance = 24140
    private static var cacheLocation: CLLocation?
    private static var cacheName = ""
    private static var cachePlaces: [NearbyPlace] = []
    private static var cacheURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("eatout-cache.json")
    }
    private let takeoutNames = [
        "mcdonald", "burger king", "wendy", "taco bell", "kfc", "chick-fil-a", "chick fil a",
        "subway", "dunkin", "starbucks", "popeyes", "arby", "sonic", "dairy queen",
        "domino", "pizza hut", "little caesar", "papa john", "chipotle", "panda express",
        "five guys", "jimmy john", "culver", "portillo", "white castle",
        "raising cane", "jersey mike", "panera", "wingstop"
    ]

    func load() async { await useHere() }
    func loadAll() async { await useHere() }

    func useHere() async {
        isLoading = true
        message = nil
        defer { isLoading = false }
        do {
            let location = try await locator.current()
            userLocation = location
            searchCenter = location
            if let cached = loadCache(near: location) {
                places = cached
                areaName = Self.cacheName.isEmpty ? "Current location" : Self.cacheName
                isLoading = false
                Task { await reloadAll(around: location) }
                return
            }
            areaName = "Current location"
            Task { await nameArea(location) }
            await reloadAll(around: location)
        } catch {
            message = "Turn on location, or type a city or zip."
        }
    }

    private func nameArea(_ location: CLLocation) async {
        guard let marks = try? await CLGeocoder().reverseGeocodeLocation(location),
              let mark = marks.first else { return }
        let name = [mark.locality, mark.administrativeArea, mark.postalCode]
            .compactMap { $0 }
            .joined(separator: ", ")
        if name.isEmpty == false {
            areaName = name
            Self.cacheName = name
        }
    }

    func searchArea(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            await useHere()
            return
        }
        isLoading = true
        message = nil
        defer { isLoading = false }
        do {
            let query = trimmed.count == 5 && trimmed.allSatisfy({ $0.isNumber }) ? trimmed + ", USA" : trimmed
            let marks = try await CLGeocoder().geocodeAddressString(query)
            guard let location = marks.first?.location else {
                message = "Could not find that city or zip."
                return
            }
            let place = marks.first
            areaName = [place?.locality, place?.administrativeArea, place?.postalCode]
                .compactMap { $0 }
                .joined(separator: ", ")
            if areaName.isEmpty { areaName = trimmed }
            searchCenter = location
            await reloadAll(around: location)
        } catch {
            message = "Could not find that city or zip."
        }
    }

    func searchMaps(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let location = searchCenter ?? userLocation else {
            if trimmed.isEmpty { await useHere() }
            return
        }
        if trimmed.isEmpty {
            await reloadAll(around: location)
            return
        }
        isLoading = true
        message = nil
        defer { isLoading = false }
        do {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = trimmed
            request.region = MKCoordinateRegion(
                center: location.coordinate,
                latitudinalMeters: 32000,
                longitudinalMeters: 32000
            )
            let response = try await MKLocalSearch(request: request).start()
            let mapped = response.mapItems.compactMap { item in
                self.place(from: item, around: location, requireFood: false)
            }
            places = sortedPlaces(mapped)
            if places.isEmpty {
                message = "No places matching \(trimmed) near \(areaName)."
            }
        } catch {
            message = "Could not search Maps right now."
        }
    }

    private func reloadAll(around location: CLLocation) async {
        message = nil
        async let restaurants = searchNamed("restaurants", around: location, requireFood: false)
        async let fast = searchNamed("fast food", around: location, requireFood: false)
        async let pizza = searchNamed("pizza", around: location, requireFood: false)
        async let coffee = searchNamed("coffee", around: location, requireFood: false)
        async let tacos = searchNamed("tacos", around: location, requireFood: false)
        async let poi = searchPOIs(around: location)
        async let osm = searchOSM(around: location)

        var seen = Set<String>()
        var result: [NearbyPlace] = []
        let batches = [
            (try? await restaurants) ?? [],
            (try? await fast) ?? [],
            (try? await pizza) ?? [],
            (try? await coffee) ?? [],
            (try? await tacos) ?? [],
            (try? await poi) ?? [],
            (try? await osm) ?? []
        ]
        for batch in batches {
            merge(batch, into: &result, seen: &seen)
        }
        places = sortedPlaces(result)
        saveCache(places, near: location)
        if places.isEmpty {
            message = "No restaurants found near \(areaName)."
        }
    }

    private func loadCache(near location: CLLocation) -> [NearbyPlace]? {
        if let memoryAt = Self.cacheLocation,
           memoryAt.distance(from: location) < 4000,
           Self.cachePlaces.isEmpty == false {
            return Self.cachePlaces.map { item in
                var copy = item
                copy.distance = location.distance(from: CLLocation(latitude: item.latitude, longitude: item.longitude))
                return copy
            }
        }
        guard let data = try? Data(contentsOf: Self.cacheURL),
              let saved = try? JSONDecoder().decode(PlaceDiskCache.self, from: data) else { return nil }
        let cachedAt = CLLocation(latitude: saved.lat, longitude: saved.lon)
        guard cachedAt.distance(from: location) < 4000, saved.places.isEmpty == false else { return nil }
        Self.cacheLocation = cachedAt
        Self.cacheName = saved.areaName
        Self.cachePlaces = saved.places
        areaName = saved.areaName
        return saved.places.map { item in
            var copy = item
            copy.distance = location.distance(from: CLLocation(latitude: item.latitude, longitude: item.longitude))
            return copy
        }
    }

    private func saveCache(_ items: [NearbyPlace], near location: CLLocation) {
        Self.cacheLocation = location
        Self.cachePlaces = items
        Self.cacheName = areaName
        let saved = PlaceDiskCache(lat: location.coordinate.latitude, lon: location.coordinate.longitude, areaName: areaName, places: items)
        if let data = try? JSONEncoder().encode(saved) {
            try? data.write(to: Self.cacheURL, options: .atomic)
        }
    }

    private func merge(_ batch: [NearbyPlace], into result: inout [NearbyPlace], seen: inout Set<String>) {
        for item in batch {
            let fuzzy = item.name.lowercased() + String(format: "-%.3f-%.3f", item.coordinate.latitude, item.coordinate.longitude)
            if seen.insert(item.id).inserted && seen.insert(fuzzy).inserted {
                result.append(item)
            }
        }
    }

    private func sortedPlaces(_ items: [NearbyPlace]) -> [NearbyPlace] {
        var seen = Set<String>()
        let unique = items.filter { seen.insert($0.id).inserted }
        return unique.sorted { left, right in
            (left.distance ?? .greatestFiniteMagnitude) < (right.distance ?? .greatestFiniteMagnitude)
        }
    }

    private func searchOSM(around location: CLLocation) async throws -> [NearbyPlace] {
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude
        let radius = Int(maxMeters)
        let query = "[out:json][timeout:6];(node[\"amenity\"=\"restaurant\"](around:\(radius),\(lat),\(lon));node[\"amenity\"=\"fast_food\"](around:\(radius),\(lat),\(lon));node[\"amenity\"=\"cafe\"](around:\(radius),\(lat),\(lon));way[\"amenity\"=\"restaurant\"](around:\(radius),\(lat),\(lon));way[\"amenity\"=\"fast_food\"](around:\(radius),\(lat),\(lon)););out center tags;"
        let endpoints = [
            "https://overpass-api.de/api/interpreter",
            "https://overpass.kumi.systems/api/interpreter"
        ]
        var lastError: Error?
        for endpoint in endpoints {
            do {
                return try await fetchOSM(endpoint: endpoint, query: query, around: location)
            } catch {
                lastError = error
            }
        }
        throw lastError ?? URLError(.cannotConnectToHost)
    }

    private func fetchOSM(endpoint: String, query: String, around location: CLLocation) async throws -> [NearbyPlace] {
        guard let url = URL(string: endpoint) else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 6
        request.setValue("HUB/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        let encoded = query.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed) ?? query
        request.httpBody = Data("data=\(encoded)".utf8)
        let pair = try await URLSession.shared.data(for: request)
        guard let http = pair.1 as? HTTPURLResponse, http.statusCode >= 200, http.statusCode < 300 else {
            throw URLError(.badServerResponse)
        }
        let decoded = try JSONDecoder().decode(OSMResponse.self, from: pair.0)
        return decoded.elements.compactMap { element in
            element.asPlace(around: location, maxMeters: self.maxMeters, takeoutNames: self.takeoutNames)
        }
    }

    private func searchPOIs(around location: CLLocation) async throws -> [NearbyPlace] {
        let request = MKLocalPointsOfInterestRequest(center: location.coordinate, radius: 15000)
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: [.restaurant, .cafe, .bakery, .brewery])
        let response = try await MKLocalSearch(request: request).start()
        return response.mapItems.compactMap { item in
            self.place(from: item, around: location, requireFood: true)
        }
    }

    private func searchNamed(_ query: String, around location: CLLocation, requireFood: Bool = true) async throws -> [NearbyPlace] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = MKCoordinateRegion(
            center: location.coordinate,
            latitudinalMeters: 24000,
            longitudinalMeters: 24000
        )
        let response = try await MKLocalSearch(request: request).start()
        return response.mapItems.compactMap { item in
            self.place(from: item, around: location, requireFood: requireFood)
        }
    }

    private func place(from item: MKMapItem, around location: CLLocation, requireFood: Bool) -> NearbyPlace? {
        guard let name = item.name, name.isEmpty == false else { return nil }
        let lower = name.lowercased()
        if requireFood {
            let allowed = takeoutNames.contains(where: { lower.contains($0) })
                || item.pointOfInterestCategory == .restaurant
                || item.pointOfInterestCategory == .cafe
                || item.pointOfInterestCategory == .bakery
                || item.pointOfInterestCategory == .brewery
            if allowed == false { return nil }
        } else {
            if lower.contains("splash pad") || lower.contains("forest preserve") { return nil }
        }
        let coord = item.placemark.coordinate
        if CLLocationCoordinate2DIsValid(coord) == false { return nil }
        let distance = location.distance(from: CLLocation(latitude: coord.latitude, longitude: coord.longitude))
        if distance > maxMeters { return nil }
        let takeout = takeoutNames.contains(where: { lower.contains($0) })
            || item.pointOfInterestCategory == .cafe
            || item.pointOfInterestCategory == .bakery
        let address = [
            item.placemark.subThoroughfare,
            item.placemark.thoroughfare,
            item.placemark.locality
        ].compactMap { $0 }.joined(separator: " ")
        return NearbyPlace(
            id: "\(lower)-\(String(format: "%.4f", coord.latitude))-\(String(format: "%.4f", coord.longitude))",
            name: name,
            category: takeout ? PlaceMode.takeout.title : PlaceMode.sitdown.title,
            address: address,
            phone: item.phoneNumber ?? "",
            url: item.url,
            latitude: coord.latitude,
            longitude: coord.longitude,
            distance: distance,
            mode: takeout ? .takeout : .sitdown
        )
    }
}

private struct PlaceDiskCache: Codable {
    var lat: Double
    var lon: Double
    var areaName: String
    var places: [NearbyPlace]
}

private struct OSMResponse: Decodable {
    var elements: [OSMElement]
}

private struct OSMElement: Decodable {
    var type: String?
    var id: Int64?
    var lat: Double?
    var lon: Double?
    var center: OSMCenter?
    var tags: [String: String]?

    struct OSMCenter: Decodable {
        var lat: Double
        var lon: Double
    }

    func asPlace(around location: CLLocation, maxMeters: CLLocationDistance, takeoutNames: [String]) -> NearbyPlace? {
        let tags = self.tags ?? [:]
        let name = (tags["name"] ?? "").trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        if name.isEmpty { return nil }
        let resolvedLat = self.lat ?? center?.lat
        let resolvedLon = self.lon ?? center?.lon
        guard let resolvedLat = resolvedLat, let resolvedLon = resolvedLon else { return nil }
        let distance = location.distance(from: CLLocation(latitude: resolvedLat, longitude: resolvedLon))
        if distance > maxMeters { return nil }
        let amenity = (tags["amenity"] ?? tags["shop"] ?? "").lowercased()
        let cuisine = (tags["cuisine"] ?? "").replacingOccurrences(of: "_", with: " ")
        let lower = name.lowercased()
        var takeout = false
        if amenity == "fast_food" || amenity == "cafe" || amenity == "ice_cream" {
            takeout = true
        }
        if takeoutNames.contains(where: { lower.contains($0) }) {
            takeout = true
        }
        let street = [tags["addr:housenumber"], tags["addr:street"]].compactMap { $0 }.joined(separator: " ")
        let city = tags["addr:city"] ?? ""
        let address = [street, city].filter { $0.isEmpty == false }.joined(separator: " ")
        let phone = tags["phone"] ?? tags["contact:phone"] ?? ""
        var website: URL?
        if let raw = tags["website"] ?? tags["contact:website"] {
            website = URL(string: raw)
        }
        let ident = "osm-\(type ?? "n")-\(id ?? 0)"
        return NearbyPlace(
            id: ident,
            name: name,
            category: cuisine.isEmpty ? amenity.replacingOccurrences(of: "_", with: " ") : cuisine,
            address: address,
            phone: phone,
            url: website,
            latitude: resolvedLat,
            longitude: resolvedLon,
            distance: distance,
            mode: takeout ? .takeout : .sitdown
        )
    }
}
