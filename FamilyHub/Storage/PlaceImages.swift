import CoreLocation
import MapKit
import UIKit

enum PlaceImages {
    /// Place photos come only from MapKit Look Around. There is no Bing, DuckDuckGo, or other scrape.
    /// Callers show a name tile when Look Around has no scene.
    @MainActor
    static func photo(name: String, address: String?, coordinate: CLLocationCoordinate2D? = nil, website: URL? = nil) async -> UIImage? {
        guard let coordinate, CLLocationCoordinate2DIsValid(coordinate) else { return nil }
        let request = MKLookAroundSceneRequest(coordinate: coordinate)
        guard let scene = try? await request.scene else { return nil }
        let options = MKLookAroundSnapshotter.Options()
        options.size = CGSize(width: 960, height: 540)
        let snapshotter = MKLookAroundSnapshotter(scene: scene, options: options)
        return await withCheckedContinuation { continuation in
            snapshotter.getSnapshotWithCompletionHandler { snapshot, _ in
                continuation.resume(returning: snapshot?.image)
            }
        }
    }
}
