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

    var query: String {
        switch self {
        case .takeout: return "takeout restaurants"
        case .sitdown: return "sit down restaurants"
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
        if distance < 1000 { return String(format: "%.0f m", distance) }
        return String(format: "%.1f mi", distance / 1609.34)
    }

    static func == (lhs: NearbyPlace, rhs: NearbyPlace) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
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

    func load() async {
        await loadAll()
    }

    func loadAll() async {
        await useHere()
    }

    func useHere() async {
        isLoading = true
        message = nil
        defer { isLoading = false }
        do {
            let location = try await locator.current()
            userLocation = location
            areaName = "Current location"
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
            let marks = try await CLGeocoder().geocodeAddressString(trimmed)
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

    private func fill(around location: CLLocation) async {
        do {
            let takeout = try await search(mode: .takeout, around: location)
            let sitdown = try await search(mode: .sitdown, around: location)
            var seen = Set<String>()
            places = (takeout + sitdown).filter { seen.insert($0.id).inserted }
                .sorted { ($0.distance ?? .greatestFiniteMagnitude) < ($1.distance ?? .greatestFiniteMagnitude) }
            if places.isEmpty { message = "No places found nearby." }
        } catch {
            message = "Could not load restaurants."
        }
    }

    func setMode(_ mode: PlaceMode) async {
        self.mode = mode
        await load()
    }

    private func search(mode: PlaceMode, around location: CLLocation) async throws -> [NearbyPlace] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = mode.query
        request.resultTypes = .pointOfInterest
        request.region = MKCoordinateRegion(
            center: location.coordinate,
            latitudinalMeters: 8000,
            longitudinalMeters: 8000
        )
        let response = try await MKLocalSearch(request: request).start()
        return response.mapItems.compactMap { item -> NearbyPlace? in
            guard let name = item.name, !name.isEmpty else { return nil }
            let coord = item.placemark.coordinate
            let distance = location.distance(from: CLLocation(latitude: coord.latitude, longitude: coord.longitude))
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
        .sorted { ($0.distance ?? .greatestFiniteMagnitude) < ($1.distance ?? .greatestFiniteMagnitude) }
    }
}
