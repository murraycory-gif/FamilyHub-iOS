import Foundation
import CoreLocation
import UIKit

enum PlaceImages {
    private static var memory: [String: UIImage] = [:]
    private static var misses: Set<String> = []
    private static let lock = NSLock()

    /// A photo only when it is tied to this place. Map snapshots and unmatched hits return nil.
    static func photo(name: String, address: String?, coordinate: CLLocationCoordinate2D? = nil, website: URL? = nil) async -> UIImage? {
        let key = cacheKey(name: name, coordinate: coordinate)
        if let cached = cached(key) { return cached }
        if missed(key) { return nil }
        guard let image = await googlePlacePhoto(name: name, coordinate: coordinate) else {
            markMiss(key)
            return nil
        }
        store(image, key: key)
        return image
    }

    private static func googlePlacePhoto(name: String, coordinate: CLLocationCoordinate2D?) async -> UIImage? {
        let key = HubKeychain.loadPlacesPhotoKey()
        guard key.isEmpty == false, let coordinate else { return nil }
        let needle = normalize(name)
        guard needle.count >= 3 else { return nil }
        guard let match = await searchText(name: name, coordinate: coordinate, apiKey: key) else { return nil }
        let found = normalize(match.name)
        let sameName = found == needle || found.hasPrefix(needle + " ") || needle.hasPrefix(found + " ")
        guard sameName, match.meters <= 200, let photo = match.photoName else { return nil }
        return await media(photoName: photo, apiKey: key)
    }

    private struct PlaceHit {
        var name: String
        var meters: CLLocationDistance
        var photoName: String?
    }

    private static func searchText(name: String, coordinate: CLLocationCoordinate2D, apiKey: String) async -> PlaceHit? {
        guard let url = URL(string: "https://places.googleapis.com/v1/places:searchText") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 8
        request.setValue(apiKey, forHTTPHeaderField: "X-Goog-Api-Key")
        request.setValue("places.displayName,places.location,places.photos", forHTTPHeaderField: "X-Goog-FieldMask")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "textQuery": name,
            "pageSize": 5,
            "locationBias": [
                "circle": [
                    "center": ["latitude": coordinate.latitude, "longitude": coordinate.longitude],
                    "radius": 200.0
                ]
            ]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode ?? 500 < 400,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let places = json["places"] as? [[String: Any]]
        else { return nil }
        let origin = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        var best: PlaceHit?
        for place in places {
            let display = (place["displayName"] as? [String: Any])?["text"] as? String ?? ""
            let loc = place["location"] as? [String: Any]
            let lat = loc?["latitude"] as? Double
            let lon = loc?["longitude"] as? Double
            guard let lat, let lon else { continue }
            let meters = origin.distance(from: CLLocation(latitude: lat, longitude: lon))
            let photos = place["photos"] as? [[String: Any]]
            let photoName = photos?.first?["name"] as? String
            let hit = PlaceHit(name: display, meters: meters, photoName: photoName)
            if best == nil || hit.meters < (best?.meters ?? .greatestFiniteMagnitude) {
                best = hit
            }
        }
        return best
    }

    private static func media(photoName: String, apiKey: String) async -> UIImage? {
        var comps = URLComponents(string: "https://places.googleapis.com/v1/\(photoName)/media")
        comps?.queryItems = [
            URLQueryItem(name: "maxHeightPx", value: "800"),
            URLQueryItem(name: "key", value: apiKey)
        ]
        guard let url = comps?.url else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode ?? 500 < 400,
              let image = UIImage(data: data),
              image.size.width > 40
        else { return nil }
        return image
    }

    private static func normalize(_ name: String) -> String {
        let folded = name.lowercased()
        let cleaned = folded.map { $0.isLetter || $0.isNumber ? $0 : " " }
        return String(cleaned).split(separator: " ").joined(separator: " ")
    }

    private static func cacheKey(name: String, coordinate: CLLocationCoordinate2D?) -> String {
        let pin: String
        if let coordinate {
            pin = String(format: "%.4f,%.4f", coordinate.latitude, coordinate.longitude)
        } else {
            pin = "nopin"
        }
        return normalize(name) + "|" + pin
    }

    private static func missed(_ key: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return misses.contains(key)
    }

    private static func markMiss(_ key: String) {
        lock.lock(); misses.insert(key); lock.unlock()
    }

    private static func cached(_ key: String) -> UIImage? {
        lock.lock(); defer { lock.unlock() }
        if let image = memory[key] { return image }
        if let url = diskURL(key), let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
            memory[key] = image
            return image
        }
        return nil
    }

    private static func store(_ image: UIImage, key: String) {
        lock.lock(); memory[key] = image; misses.remove(key); lock.unlock()
        if let data = image.jpegData(compressionQuality: 0.82), let url = diskURL(key) {
            try? data.write(to: url, options: .atomic)
        }
    }

    private static func diskURL(_ key: String) -> URL? {
        guard let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
        let folder = dir.appendingPathComponent("PlacePhotosV3", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var hash: UInt64 = 5381
        for byte in key.utf8 { hash = ((hash << 5) &+ hash) &+ UInt64(byte) }
        return folder.appendingPathComponent(String(hash, radix: 16) + ".jpg")
    }
}
