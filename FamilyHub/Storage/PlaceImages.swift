import Foundation
import CoreLocation
import UIKit

enum PlaceImages {
    /// Name, address, and distance come from MapKit. MapKit does not hand the app a
    /// downloadable place photo, and this build does not call any other places service.
    /// Callers show a name tile when this returns nil.
    static func photo(name: String, address: String?, coordinate: CLLocationCoordinate2D? = nil, website: URL? = nil) async -> UIImage? {
        nil
    }
}
