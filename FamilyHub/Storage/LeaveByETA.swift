import CoreLocation
import MapKit

enum LeaveByETA {
    static let fallbackMinutes = 20

    /// Drive time in minutes from MapKit. Nil when location or the network is unavailable.
    static func driveMinutes(from origin: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) async -> Int? {
        guard CLLocationCoordinate2DIsValid(origin), CLLocationCoordinate2DIsValid(destination) else { return nil }
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: origin))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = .automobile
        let route = try? await MKDirections(request: request).calculate()
        guard let seconds = route?.routes.first?.expectedTravelTime, seconds > 60 else { return nil }
        return min(180, max(1, Int((seconds / 60).rounded())))
    }
}
