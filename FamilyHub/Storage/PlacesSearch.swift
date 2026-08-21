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
        completer.resultTypes = .address
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

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let mapped = completer.results.prefix(8).map {
            AreaSuggestion(title: $0.title, subtitle: $0.subtitle)
        }
        Task { @MainActor in
            self.suggestions = Array(mapped)
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {}
}

@MainActor
final class PlacesSearch: ObservableObject {
    @Published var places: [NearbyPlace] = []
    @Published var mode: PlaceMode = .takeout
    @Published var isLoading = false
    @Published var message: String?
    @Published var userLocation: CLLocation?
    @Published var areaName = "Current location"

    private let locator = LocationFinder()
    private let maxMeters: CLLocationDistance = 24140
    private let foodCategories: Set<MKPointOfInterestCategory> = [
        .restaurant, .cafe, .bakery, .brewery, .winery, .nightlife
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
            if let mark = try? await CLGeocoder().reverseGeocodeLocation(location).first {
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
            await fill(around: location)
        } catch {
            message = "Could not find that city or zip."
        }
    }

    func setMode(_ mode: PlaceMode) async {
        self.mode = mode
        await load()
    }

    private func fill(around location: CLLocation) async {
        let queries = [
            "restaurants", "fast food", "pizza", "coffee", "burgers",
            "mexican food", "chinese food", "thai food", "italian restaurant",
            "breakfast", "sandwiches", "barbecue", "wings", "seafood", "diner", "cafe"
        ]
        var seen = Set<String>()
        var result: [NearbyPlace] = []
        await withTaskGroup(of: [NearbyPlace].self) { group in
            group.addTask { (try? await self.searchPOIs(around: location)) ?? [] }
            for query in queries {
                group.addTask { (try? await self.searchNamed(query, around: location)) ?? [] }
            }
            for await batch in group {
                for item in batch where seen.insert(item.id).inserted {
                    result.append(item)
                }
            }
        }
        places = result.sorted { ($0.distance ?? .greatestFiniteMagnitude) < ($1.distance ?? .greatestFiniteMagnitude) }
        if places.isEmpty {
            message = "No restaurants found near \(areaName)."
        }
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

    private func mapItem(_ item: MKMapItem, around location: CLLocation) -> NearbyPlace? {
        guard let name = item.name, !name.isEmpty else { return nil }
        guard isFood(item) else { return nil }
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
