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
        var seen = Set<String>()
        var result: [NearbyPlace] = []
        let poi = (try? await searchPOIs(around: location)) ?? []
        let named = (try? await searchNamed("restaurants \(areaName)", around: location, mode: .sitdown)) ?? []
        let takeout = (try? await searchNamed("takeout \(areaName)", around: location, mode: .takeout)) ?? []
        for item in poi + named + takeout {
            guard seen.insert(item.id).inserted else { continue }
            guard (item.distance ?? 0) <= maxMeters else { continue }
            result.append(item)
        }
        places = result.sorted { ($0.distance ?? .greatestFiniteMagnitude) < ($1.distance ?? .greatestFiniteMagnitude) }
        if places.isEmpty {
            message = "No restaurants found near \(areaName)."
        }
    }

    private func searchPOIs(around location: CLLocation) async throws -> [NearbyPlace] {
        let request = MKLocalPointsOfInterestRequest(center: location.coordinate, radius: 15000)
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: [.restaurant, .cafe, .bakery, .brewery])
        let response = try await MKLocalSearch(request: request).start()
        return response.mapItems.compactMap { item in
            mapItem(item, around: location, mode: sitOrTakeout(item))
        }
    }

    private func searchNamed(_ query: String, around location: CLLocation, mode: PlaceMode) async throws -> [NearbyPlace] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = .pointOfInterest
        request.region = MKCoordinateRegion(
            center: location.coordinate,
            latitudinalMeters: 20000,
            longitudinalMeters: 20000
        )
        let response = try await MKLocalSearch(request: request).start()
        return response.mapItems.compactMap { mapItem($0, around: location, mode: mode) }
    }

    private func sitOrTakeout(_ item: MKMapItem) -> PlaceMode {
        switch item.pointOfInterestCategory {
        case .cafe, .bakery: return .takeout
        default: return .sitdown
        }
    }

    private func mapItem(_ item: MKMapItem, around location: CLLocation, mode: PlaceMode) -> NearbyPlace? {
        guard let name = item.name, !name.isEmpty else { return nil }
        let coord = item.placemark.coordinate
        guard CLLocationCoordinate2DIsValid(coord) else { return nil }
        let distance = location.distance(from: CLLocation(latitude: coord.latitude, longitude: coord.longitude))
        guard distance <= maxMeters else { return nil }
        return NearbyPlace(
            id: "\(name)-\(coord.latitude)-\(coord.longitude)",
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
}
