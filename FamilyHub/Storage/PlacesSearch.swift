import CoreLocation
import Foundation
import MapKit

enum PlaceMode: String, CaseIterable, Identifiable {
    case takeout
    case sitdown

    var id: String { rawValue }

    var title: String {
        switch self {
        case .takeout: return "Takeout"
        case .sitdown: return "Sit down"
        }
    }
}

struct NearbyPlace: Identifiable, Hashable {
    var id: String
    var name: String
    var category: String
    var address: String
    var phone: String
    var url: URL?
    var coordinate: CLLocationCoordinate2D
    var distance: CLLocationDistance?
    var mode: PlaceMode

    var distanceLabel: String? {
        guard let distance else { return nil }
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

@MainActor
final class AreaCompleter: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var suggestions: [AreaSuggestion] = []
    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.resultTypes = [.pointOfInterest, .query]
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
        suggestions = completer.results.prefix(8).map {
            AreaSuggestion(title: $0.title, subtitle: $0.subtitle)
        }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {}
}

@MainActor
final class PlacesSearch: ObservableObject {
    @Published var places: [NearbyPlace] = []
    @Published var mode: PlaceMode = .takeout
    @Published var isLoading = false
    @Published var message: String?
    @Published var userLocation: CLLocation?
    @Published var areaName = "Current location"
    private var searchCenter: CLLocation?

    private let locator = LocationFinder()
    private let maxMeters: CLLocationDistance = 24140
    private let foodCategories: Set<MKPointOfInterestCategory> = [
        .restaurant, .cafe, .bakery, .brewery, .winery
    ]
    private let takeoutNames = [
        "mcdonald", "burger king", "wendy", "taco bell", "kfc", "chick-fil-a", "chick fil a",
        "subway", "dunkin", "starbucks", "popeyes", "arby", "sonic", "dairy queen",
        "domino", "pizza hut", "little caesar", "papa john", "chipotle", "panda express",
        "five guys", "jimmy john", "culver", "portillo", "white castle",
        "raising cane", "jersey mike", "panera", "wingstop", "drive-thru", "drive thru"
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
            if let marks = try? await CLGeocoder().reverseGeocodeLocation(location),
               let mark = marks.first {
                areaName = [mark.locality, mark.administrativeArea, mark.postalCode]
                    .compactMap { $0 }
                    .joined(separator: ", ")
            } else {
                areaName = "Current location"
            }
            if areaName.isEmpty { areaName = "Current location" }
            await fill(around: location)
        } catch {
            message = "Turn on location, or type a city or zip."
        }
    }

    func searchArea(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            await useHere()
            return
        }
        isLoading = true
        message = nil
        defer { isLoading = false }
        do {
            let query = trimmed.count == 5 && trimmed.allSatisfy(\.isNumber) ? trimmed + ", USA" : trimmed
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
            await fill(around: location)
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
            await fill(around: location)
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
            let mapped = response.mapItems.compactMap { mapItem($0, around: location, mapsStyle: true) }
            places = mapped.sorted { ($0.distance ?? .greatestFiniteMagnitude) < ($1.distance ?? .greatestFiniteMagnitude) }
            if places.isEmpty { message = "No places matching \"\(trimmed)\" near \(areaName)." }
        } catch {
            message = "Could not search Maps right now."
        }
    }

    private func fill(around location: CLLocation) async {
        message = nil
        var seen = Set<String>()
        var result: [NearbyPlace] = []

        let osm = (try? await searchOSM(around: location)) ?? []
        for item in osm where seen.insert(item.id).inserted {
            result.append(item)
        }
        places = result.sorted { ($0.distance ?? .greatestFiniteMagnitude) < ($1.distance ?? .greatestFiniteMagnitude) }

        let queries = [
            "restaurants", "fast food", "pizza", "coffee", "burgers",
            "mexican food", "chinese food", "thai food", "italian restaurant",
            "breakfast", "sandwiches", "barbecue", "wings", "seafood", "diner", "cafe"
        ]
        let extraPOI = (try? await searchPOIs(around: location)) ?? []
        let extraNamed: [NearbyPlace] = await {
            var batch: [NearbyPlace] = []
            for query in queries {
                batch.append(contentsOf: (try? await searchNamed(query, around: location)) ?? [])
            }
            return batch
        }()
        for item in extraPOI + extraNamed {
            let key = item.id
            let fuzzy = item.name.lowercased() + String(format: "-%.3f-%.3f", item.coordinate.latitude, item.coordinate.longitude)
            guard seen.insert(key).inserted, seen.insert(fuzzy).inserted else { continue }
            result.append(item)
        }
        places = result.sorted { ($0.distance ?? .greatestFiniteMagnitude) < ($1.distance ?? .greatestFiniteMagnitude) }
        if places.isEmpty {
            message = "No restaurants found near \(areaName)."
        }
    }

    private func searchOSM(around location: CLLocation) async throws -> [NearbyPlace] {
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude
        let radius = Int(maxMeters)
        let query = """
        [out:json][timeout:25];
        (
          nwr["amenity"="restaurant"](around:\(radius),\(lat),\(lon));
          nwr["amenity"="fast_food"](around:\(radius),\(lat),\(lon));
          nwr["amenity"="cafe"](around:\(radius),\(lat),\(lon));
          nwr["amenity"="bar"](around:\(radius),\(lat),\(lon));
          nwr["amenity"="pub"](around:\(radius),\(lat),\(lon));
          nwr["amenity"="ice_cream"](around:\(radius),\(lat),\(lon));
          nwr["amenity"="food_court"](around:\(radius),\(lat),\(lon));
          nwr["shop"="bakery"](around:\(radius),\(lat),\(lon));
        );
        out center tags;
        """
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
        request.timeoutInterval = 30
        request.setValue("HUB/1.0 (family hub)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        request.httpBody = Data("data=\(encoded)".utf8)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let decoded = try JSONDecoder().decode(OSMResponse.self, from: data)
        return decoded.elements.compactMap { $0.asPlace(around: location, maxMeters: maxMeters, takeoutNames: takeoutNames) }
    }

    private func searchPOIs(around location: CLLocation) async throws -> [NearbyPlace] {
        let request = MKLocalPointsOfInterestRequest(center: location.coordinate, radius: 20000)
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: Array(foodCategories))
        let response = try await MKLocalSearch(request: request).start()
        return response.mapItems.compactMap { mapItem($0, around: location) }
    }

    private func searchNamed(_ query: String, around location: CLLocation) async throws -> [NearbyPlace] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = .pointOfInterest
        request.region = MKCoordinateRegion(
            center: location.coordinate,
            latitudinalMeters: 24000,
            longitudinalMeters: 24000
        )
        let response = try await MKLocalSearch(request: request).start()
        return response.mapItems.compactMap { mapItem($0, around: location) }
    }

    private func mapItem(_ item: MKMapItem, around location: CLLocation, mapsStyle: Bool = false) -> NearbyPlace? {
        guard let name = item.name, !name.isEmpty else { return nil }
        if mapsStyle {
            let lower = name.lowercased()
            let blocked = ["splash pad", "forest preserve", "elementary school", "middle school", "high school"]
            if blocked.contains(where: { lower.contains($0) }) { return nil }
        } else {
            guard isFood(item) else { return nil }
        }
        let coord = item.placemark.coordinate
        guard CLLocationCoordinate2DIsValid(coord) else { return nil }
        let distance = location.distance(from: CLLocation(latitude: coord.latitude, longitude: coord.longitude))
        guard distance <= maxMeters else { return nil }
        let mode = sitOrTakeout(item)
        return NearbyPlace(
            id: "\(name.lowercased())-\(String(format: "%.4f", coord.latitude))-\(String(format: "%.4f", coord.longitude))",
            name: name,
            category: item.pointOfInterestCategory?.rawValue
                .replacingOccurrences(of: "MKPOICategory", with: "")
                .replacingOccurrences(of: "_", with: " ") ?? mode.title,
            address: [
                item.placemark.subThoroughfare,
                item.placemark.thoroughfare,
                item.placemark.locality
            ].compactMap { $0 }.joined(separator: " "),
            phone: item.phoneNumber ?? "",
            url: item.url,
            coordinate: coord,
            distance: distance,
            mode: mode
        )
    }

    private func isFood(_ item: MKMapItem) -> Bool {
        let name = (item.name ?? "").lowercased()
        if takeoutNames.contains(where: { name.contains($0) }) { return true }
        if let category = item.pointOfInterestCategory {
            return foodCategories.contains(category)
        }
        let blocked = ["park", "splash", "trail", "forest preserve", "library", "school", "church", "hospital", "clinic", "pharmacy"]
        if blocked.contains(where: { name.contains($0) }) { return false }
        return false
    }

    private func sitOrTakeout(_ item: MKMapItem) -> PlaceMode {
        let name = (item.name ?? "").lowercased()
        if takeoutNames.contains(where: { name.contains($0) }) { return .takeout }
        switch item.pointOfInterestCategory {
        case .cafe, .bakery: return .takeout
        default: return .sitdown
        }
    }
}

private struct OSMResponse: Decodable {
    var elements: [OSMElement]
}

private struct OSMElement: Decodable {
    var type: String
    var id: Int
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
        let name = tags["name"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !name.isEmpty else { return nil }
        let lat = self.lat ?? center?.lat
        let lon = self.lon ?? center?.lon
        guard let lat, let lon else { return nil }
        let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        let distance = location.distance(from: CLLocation(latitude: lat, longitude: lon))
        guard distance <= maxMeters else { return nil }
        let amenity = (tags["amenity"] ?? tags["shop"] ?? "").lowercased()
        let cuisine = tags["cuisine"]?.replacingOccurrences(of: "_", with: " ") ?? ""
        let lower = name.lowercased()
        let takeout = amenity == "fast_food" || amenity == "cafe" || amenity == "ice_cream" || amenity == "food_court"
            || takeoutNames.contains(where: { lower.contains($0) })
        let address = [
            [tags["addr:housenumber"], tags["addr:street"]].compactMap { $0 }.joined(separator: " "),
            tags["addr:city"]
        ].filter { !$0.isEmpty }.joined(separator: " ")
        let phone = tags["phone"] ?? tags["contact:phone"] ?? ""
        let website = tags["website"] ?? tags["contact:website"]
        return NearbyPlace(
            id: "osm-\(type)-\(id)",
            name: name,
            category: cuisine.isEmpty ? amenity.replacingOccurrences(of: "_", with: " ") : cuisine,
            address: address,
            phone: phone,
            url: website.flatMap(URL.init(string:)),
            coordinate: coord,
            distance: distance,
            mode: takeout ? .takeout : .sitdown
        )
    }
}
