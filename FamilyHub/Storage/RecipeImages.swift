import Foundation
import UIKit

enum RecipeImages {
    private static var memory: [String: UIImage] = [:]
    private static let lock = NSLock()

    static func photo(url: URL?, name: String) async -> UIImage? {
        let key = (name.isEmpty ? url?.absoluteString : name).map { $0.lowercased() } ?? ""
        if !key.isEmpty, let cached = cached(key) { return cached }
        if let url, let cached = cached(url.absoluteString.lowercased()) { return cached }

        if let url, let image = await download(url.absoluteString, timeout: 4) {
            store(image, key: key.isEmpty ? url.absoluteString.lowercased() : key)
            return image
        }

        let query = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return nil }

        let image = await firstPhoto(query)
        if let image { store(image, key: key) }
        return image
    }

    private static func firstPhoto(_ name: String) async -> UIImage? {
        await withTaskGroup(of: Shot.self) { group in
            group.addTask { .from(await mealDB(name)) }
            group.addTask { .from(await wikipedia(name)) }
            group.addTask { .from(await commons(name)) }
            group.addTask { .from(await duckDuckGo("\(name) food dish")) }
            group.addTask {
                try? await Task.sleep(for: .seconds(6))
                return .timeout
            }
            var remaining = 4
            while let shot = await group.next() {
                switch shot {
                case .photo(let image):
                    group.cancelAll()
                    return image
                case .timeout:
                    group.cancelAll()
                    return nil
                case .miss:
                    remaining -= 1
                    if remaining <= 0 {
                        group.cancelAll()
                        return nil
                    }
                }
            }
            return nil
        }
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

    private static func mealDB(_ name: String) async -> UIImage? {
        let words = name.split(separator: " ").prefix(3).joined(separator: " ")
        let query = words.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? words
        guard let url = URL(string: "https://www.themealdb.com/api/json/v1/1/search.php?s=\(query)"),
              let json = await json(url),
              let meals = json["meals"] as? [[String: Any]]
        else { return nil }
        for meal in meals.prefix(3) {
            if let thumb = meal["strMealThumb"] as? String, let image = await download(thumb) {
                return image
            }
        }
        return nil
    }

    private static func wikipedia(_ name: String) async -> UIImage? {
        let titles = [name, "\(name) (food)", name.replacingOccurrences(of: " and ", with: " ")]
        for title in titles {
            let slug = title.replacingOccurrences(of: " ", with: "_")
                .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? title
            if let url = URL(string: "https://en.wikipedia.org/api/rest_v1/page/summary/\(slug)"),
               let json = await json(url, agent: true),
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
            URLQueryItem(name: "gsrsearch", value: "\(name) dish food"),
            URLQueryItem(name: "prop", value: "pageimages"),
            URLQueryItem(name: "pithumbsize", value: "800"),
            URLQueryItem(name: "format", value: "json")
        ]
        guard let url = comps.url, let json = await json(url, agent: true),
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

    private static func commons(_ name: String) async -> UIImage? {
        var comps = URLComponents(string: "https://commons.wikimedia.org/w/api.php")!
        comps.queryItems = [
            URLQueryItem(name: "action", value: "query"),
            URLQueryItem(name: "generator", value: "search"),
            URLQueryItem(name: "gsrsearch", value: "\(name) food"),
            URLQueryItem(name: "gsrnamespace", value: "6"),
            URLQueryItem(name: "gsrlimit", value: "6"),
            URLQueryItem(name: "prop", value: "imageinfo"),
            URLQueryItem(name: "iiprop", value: "url"),
            URLQueryItem(name: "iiurlwidth", value: "800"),
            URLQueryItem(name: "format", value: "json")
        ]
        guard let url = comps.url, let json = await json(url, agent: true),
              let queryObj = json["query"] as? [String: Any],
              let pages = queryObj["pages"] as? [String: [String: Any]]
        else { return nil }
        for page in pages.values {
            if let infos = page["imageinfo"] as? [[String: Any]] {
                let source = (infos.first?["thumburl"] as? String) ?? (infos.first?["url"] as? String)
                if let source, let image = await download(source) { return image }
            }
        }
        return nil
    }

    private static func duckDuckGo(_ query: String) async -> UIImage? {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        guard let home = URL(string: "https://duckduckgo.com/?q=\(encoded)&iax=images&ia=images"),
              let htmlData = await data(home),
              let html = String(data: htmlData, encoding: .utf8),
              let range = html.range(of: "vqd="),
              let token = html[range.upperBound...].split(separator: "&").first
                .map({ $0.trimmingCharacters(in: CharacterSet(charactersIn: "\"' ")) })
        else { return nil }
        var comps = URLComponents(string: "https://duckduckgo.com/i.js")!
        comps.queryItems = [
            URLQueryItem(name: "l", value: "us-en"),
            URLQueryItem(name: "o", value: "json"),
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "vqd", value: String(token.prefix(80))),
            URLQueryItem(name: "f", value: ",,,"),
            URLQueryItem(name: "p", value: "1")
        ]
        guard let url = comps.url, let data = await data(url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]]
        else { return nil }
        for hit in results.prefix(8) {
            if let imageURL = hit["image"] as? String, let image = await download(imageURL) {
                return image
            }
        }
        return nil
    }

    private static func cached(_ key: String) -> UIImage? {
        lock.lock()
        let memoryHit = memory[key]
        lock.unlock()
        if let memoryHit { return memoryHit }
        let file = folder.appendingPathComponent(key.hashed)
        guard let data = try? Data(contentsOf: file), let image = UIImage(data: data) else { return nil }
        lock.lock()
        memory[key] = image
        lock.unlock()
        return image
    }

    private static func store(_ image: UIImage, key: String) {
        lock.lock()
        memory[key] = image
        lock.unlock()
        if let data = image.jpegData(compressionQuality: 0.82) {
            try? data.write(to: folder.appendingPathComponent(key.hashed), options: .atomic)
        }
    }

    private static var folder: URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("RecipePhotos", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static func json(_ url: URL, agent: Bool = false) async -> [String: Any]? {
        guard let data = await data(url, agent: agent) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    private static func download(_ raw: String, timeout: TimeInterval = 8) async -> UIImage? {
        guard let url = URL(string: raw) else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        request.setValue("HUB/1.0", forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode ?? 200 < 400,
              let image = UIImage(data: data),
              image.size.width > 40
        else { return nil }
        return image
    }

    private static func data(_ url: URL, agent: Bool = true) async -> Data? {
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        if agent { request.setValue("HUB/1.0 (family hub recipe photos)", forHTTPHeaderField: "User-Agent") }
        return try? await URLSession.shared.data(for: request).0
    }
}

private extension String {
    var hashed: String {
        String(abs(hashValue))
    }
}
