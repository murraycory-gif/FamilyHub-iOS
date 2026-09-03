import Foundation
import CoreLocation
import UIKit

enum PlaceImages {
    private static var memory: [String: UIImage] = [:]
    private static let lock = NSLock()

    static func photo(name: String, address: String?, coordinate: CLLocationCoordinate2D? = nil, website: URL? = nil) async -> UIImage? {
        let key = query(name: name, address: address).lowercased()
        if let cached = cached(key) { return cached }
        let image = await firstPhoto(name: name, address: address, coordinate: coordinate, website: website)
        if let image { store(image, key: key) }
        return image
    }

import Foundation
import CoreLocation
import MapKit
import UIKit

enum PlaceImages {
    private static var memory: [String: UIImage] = [:]
    private static let lock = NSLock()

    static func photo(name: String, address: String?, coordinate: CLLocationCoordinate2D? = nil, website: URL? = nil) async -> UIImage? {
        let key = query(name: name, address: address).lowercased()
        if let cached = cached(key) { return cached }
        let image = await firstPhoto(name: name, address: address, coordinate: coordinate, website: website)
        if let image { store(image, key: key) }
        return image
    }

    private static func firstPhoto(name: String, address: String?, coordinate: CLLocationCoordinate2D?, website: URL?) async -> UIImage? {
        if let image = await openGraph(website) { return image }
        if let image = await lookAround(coordinate) { return image }
        if let image = await mapShot(coordinate) { return image }
        if let image = await nominatimExact(name: name, address: address) { return image }
        return nil
    }

    private static func lookAround(_ coordinate: CLLocationCoordinate2D?) async -> UIImage? {
        guard let coordinate else { return nil }
        let request = MKLookAroundSceneRequest(coordinate: coordinate)
        guard let scene = try? await request.scene else { return nil }
        let options = MKLookAroundSnapshotter.Options()
        options.size = CGSize(width: 800, height: 500)
        let shot = MKLookAroundSnapshotter(scene: scene, options: options)
        return try? await shot.snapshot.image
    }

    private static func mapShot(_ coordinate: CLLocationCoordinate2D?) async -> UIImage? {
        guard let coordinate else { return nil }
        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(center: coordinate, latitudinalMeters: 160, longitudinalMeters: 160)
        options.size = CGSize(width: 800, height: 500)
        options.pointOfInterestFilter = .includingAll
        options.traitCollection = UITraitCollection(userInterfaceStyle: .light)
        let shot = MKMapSnapshotter(options: options)
        return await withCheckedContinuation { cont in
            shot.start { snapshot, _ in
                cont.resume(returning: snapshot?.image)
            }
        }
    }

    private static func nominatimExact(name: String, address: String?) async -> UIImage? {
        let q = query(name: name, address: address)
        var comps = URLComponents(string: "https://nominatim.openstreetmap.org/search")!
        comps.queryItems = [
            URLQueryItem(name: "q", value: q),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "extratags", value: "1"),
            URLQueryItem(name: "limit", value: "3")
        ]
        guard let url = comps.url, let data = await data(url),
              let rows = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else { return nil }
        let needle = name.lowercased()
        for row in rows {
            let display = (row["display_name"] as? String ?? "").lowercased()
            guard display.contains(needle) else { continue }
            let extras = row["extratags"] as? [String: String] ?? [:]
            if let imageURL = extras["image"], let image = await download(imageURL) { return image }
        }
        return nil
    }

    private enum Shot {
        case photo(UIImage)
        case miss
        case timeout
        static func from(_ image: UIImage?) -> Shot {
            if let image { return .photo(image) }
            return .miss
        }
    }

    private static func query(name: String, address: String?) -> String {
        var parts = [name]
        if let address, !address.isEmpty {
            let bits = address.replacingOccurrences(of: ",", with: " ").split(separator: " ").map(String.init)
            if let city = bits.last(where: { $0.rangeOfCharacter(from: .letters) != nil && $0.count > 2 && $0.rangeOfCharacter(from: .decimalDigits) == nil }) {
                parts.append(city)
            } else if bits.count >= 2 {
                parts.append(bits.suffix(2).joined(separator: " "))
            }
        }
        return parts.joined(separator: " ")
    }

    private static func wikipedia(_ name: String, _ address: String?) async -> UIImage? {
        let titles = [name, query(name: name, address: address)]
        for title in titles {
            let slug = title.replacingOccurrences(of: " ", with: "_")
                .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? title
            if let url = URL(string: "https://en.wikipedia.org/api/rest_v1/page/summary/\(slug)"),
               let json = await json(url),
               let thumb = json["thumbnail"] as? [String: Any],
               let source = thumb["source"] as? String,
               let image = await download(source) {
                return image
            }
        }
        var comps = URLComponents(string: "https://en.wikipedia.org/w/api.php")!
        comps.queryItems = [
            URLQueryItem(name: "action", value: "query"),
            URLQueryItem(name: "generator", value: "search"),
            URLQueryItem(name: "gsrsearch", value: query(name: name, address: address)),
            URLQueryItem(name: "prop", value: "pageimages"),
            URLQueryItem(name: "pithumbsize", value: "800"),
            URLQueryItem(name: "format", value: "json")
        ]
        guard let url = comps.url, let json = await json(url),
              let queryObj = json["query"] as? [String: Any],
              let pages = queryObj["pages"] as? [String: [String: Any]]
        else { return nil }
        for page in pages.values {
            if let thumb = page["thumbnail"] as? [String: Any],
               let source = thumb["source"] as? String,
               let image = await download(source) {
                return image
            }
        }
        return nil
    }

    private static func commonsGeo(_ coordinate: CLLocationCoordinate2D?) async -> UIImage? {
        guard let coordinate else { return nil }
        var comps = URLComponents(string: "https://commons.wikimedia.org/w/api.php")!
        comps.queryItems = [
            URLQueryItem(name: "action", value: "query"),
            URLQueryItem(name: "list", value: "geosearch"),
            URLQueryItem(name: "gscoord", value: "\(coordinate.latitude)|\(coordinate.longitude)"),
            URLQueryItem(name: "gsradius", value: "120"),
            URLQueryItem(name: "gsnamespace", value: "6"),
            URLQueryItem(name: "gslimit", value: "8"),
            URLQueryItem(name: "format", value: "json")
        ]
        guard let url = comps.url, let json = await json(url),
              let queryObj = json["query"] as? [String: Any],
              let rows = queryObj["geosearch"] as? [[String: Any]]
        else { return nil }
        for row in rows {
            guard let title = row["title"] as? String else { continue }
            let file = title.replacingOccurrences(of: " ", with: "_")
                .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? title
            if let image = await download("https://commons.wikimedia.org/wiki/Special:FilePath/\(file)?width=800") {
                return image
            }
        }
        return nil
    }

    private static func nominatim(_ query: String) async -> UIImage? {
        var comps = URLComponents(string: "https://nominatim.openstreetmap.org/search")!
        comps.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "extratags", value: "1"),
            URLQueryItem(name: "limit", value: "4")
        ]
        guard let url = comps.url, let data = await data(url),
              let rows = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else { return nil }
        for row in rows {
            let extras = row["extratags"] as? [String: String] ?? [:]
            if let imageURL = extras["image"], let image = await download(imageURL) { return image }
            if let wiki = extras["wikipedia"] {
                let title = wiki.replacingOccurrences(of: "en:", with: "")
                if let image = await wikipedia(title, nil) { return image }
            }
            if let dataID = extras["wikidata"],
               let fileURL = URL(string: "https://www.wikidata.org/wiki/Special:EntityData/\(dataID).json"),
               let json = await json(fileURL),
               let entities = json["entities"] as? [String: Any],
               let entity = entities[dataID] as? [String: Any],
               let claims = entity["claims"] as? [String: Any],
               let p18 = claims["P18"] as? [[String: Any]],
               let mainsnak = p18.first?["mainsnak"] as? [String: Any],
               let datavalue = mainsnak["datavalue"] as? [String: Any],
               let fileName = datavalue["value"] as? String {
                let path = fileName.replacingOccurrences(of: " ", with: "_")
                    .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? fileName
                if let image = await download("https://commons.wikimedia.org/wiki/Special:FilePath/\(path)?width=800") {
                    return image
                }
            }
        }
        return nil
    }

    private static func duckDuckGo(_ query: String) async -> UIImage? {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        guard let home = URL(string: "https://duckduckgo.com/?q=\(encoded)&iax=images&ia=images"),
              let htmlData = await data(home),
              let html = String(data: htmlData, encoding: .utf8),
              let vqd = vqdToken(in: html)
        else { return nil }
        var comps = URLComponents(string: "https://duckduckgo.com/i.js")!
        comps.queryItems = [
            URLQueryItem(name: "l", value: "us-en"),
            URLQueryItem(name: "o", value: "json"),
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "vqd", value: vqd),
            URLQueryItem(name: "f", value: ",,,"),
            URLQueryItem(name: "p", value: "1")
        ]
        guard let url = comps.url, let data = await data(url),
              let decoded = try? JSONDecoder().decode(DDG.self, from: data)
        else { return nil }
        for hit in decoded.results ?? [] {
            if (hit.width ?? 400) < 180 { continue }
            if let image = await download(hit.image) { return image }
        }
        return nil
    }

    private static func bing(_ query: String) async -> UIImage? {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urls = [
            "https://www.bing.com/images/async?q=\(encoded)&first=1&count=10&mmasync=1",
            "https://www.bing.com/images/search?q=\(encoded)&form=HDRSC2"
        ]
        for raw in urls {
            guard let url = URL(string: raw), let data = await data(url),
                  let html = String(data: data, encoding: .utf8)
            else { continue }
            let patterns = [
                #"murl":"(https:[^&]+)""#,
                #"murl":"(https:[^"]+)""#,
                #"murl":"(https?:\\/\\/[^&]+)"#
            ]
            for pattern in patterns {
                guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
                let range = NSRange(html.startIndex..., in: html)
                for match in regex.matches(in: html, range: range).prefix(8) {
                    guard let r = Range(match.range(at: 1), in: html) else { continue }
                    let link = String(html[r])
                        .replacingOccurrences(of: "\\/", with: "/")
                        .replacingOccurrences(of: "&", with: "&")
                    if let image = await download(link) { return image }
                }
            }
        }
        return nil
    }

    private static func openGraph(_ website: URL?) async -> UIImage? {
        guard let website, let htmlData = await data(website),
              let html = String(data: htmlData, encoding: .utf8)
        else { return nil }
        let patterns = [
            #"<meta[^>]+property=["']og:image["'][^>]+content=["']([^"']+)["']"#,
            #"<meta[^>]+content=["']([^"']+)["'][^>]+property=["']og:image["']"#
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
               let range = Range(match.range(at: 1), in: html) {
                var link = String(html[range])
                if link.hasPrefix("//") { link = "https:" + link }
                if let image = await download(link) { return image }
            }
        }
        return nil
    }

    private static func download(_ raw: String) async -> UIImage? {
        let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: cleaned) else { return nil }
        guard let data = await data(url), let image = UIImage(data: data), image.size.width > 60 else { return nil }
        return image
    }

    private static func json(_ url: URL) async -> [String: Any]? {
        guard let data = await data(url) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    private static func data(_ url: URL) async -> Data? {
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("HUB/1.0 (family organizer)", forHTTPHeaderField: "Api-User-Agent")
        request.timeoutInterval = 4
        return try? await URLSession.shared.data(for: request).0
    }

    private static func vqdToken(in html: String) -> String? {
        let patterns = [#"vqd='([^']+)'"#, #"vqd=([0-9-]+)"#, #"vqd\":\"([^\"]+)\""#]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
               let range = Range(match.range(at: 1), in: html) {
                return String(html[range])
            }
        }
        return nil
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
        lock.lock(); memory[key] = image; lock.unlock()
        if let data = image.jpegData(compressionQuality: 0.82), let url = diskURL(key) {
            try? data.write(to: url, options: .atomic)
        }
    }

    private static func diskURL(_ key: String) -> URL? {
        guard let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
        let folder = dir.appendingPathComponent("PlacePhotosV2", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let safe = key.replacingOccurrences(of: "/", with: "-")
        return folder.appendingPathComponent(safe + ".jpg")
    }

    private static let userAgent = "Mozilla/5.0 (iPad; CPU OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"

    private struct DDG: Decodable {
        var results: [Hit]?
        struct Hit: Decodable {
            var image: String
            var width: Int?
            var height: Int?
        }
    }
}
