import CoreLocation
import Foundation

struct PlaceHour: Identifiable, Hashable {
    var id: String { day }
    var day: String
    var time: String
}

@MainActor
final class PlaceFacts: ObservableObject {
    @Published var hours: [PlaceHour] = []
    @Published var openLabel: String?
    @Published var isOpen: Bool?
    @Published var cuisine: String?
    @Published var website: URL?
    @Published var phone: String?
    @Published var loaded = false

    func load(name: String, address: String?, coordinate: CLLocationCoordinate2D?, fallbackURL: URL?, fallbackPhone: String?) async {
        website = fallbackURL
        phone = fallbackPhone
        loaded = true
    }
}
