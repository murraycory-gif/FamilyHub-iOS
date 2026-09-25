import Foundation
import UIKit

enum RecipeThumbs {
    /// Stock and keyword photos are never a substitute for the recipe's own image.
    static func url(for name: String) -> URL? { nil }
    static func smallURL(for name: String) -> URL? { nil }
    static func heroURL(for name: String) -> URL? { nil }

    static func owned(_ raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), let host = url.host?.lowercased() else { return nil }
        if host == "unsplash.com" || host.hasSuffix(".unsplash.com") { return nil }
        if url.scheme != "https" && url.scheme != "http" { return nil }
        return url
    }
}

enum RecipePhotoLoader {
    enum Quality { case card, hero }

    private static let memory: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 80
        cache.totalCostLimit = 24 * 1024 * 1024
        return cache
    }()
    private static let gate = PhotoGate(limit: 2)
    private static let folder: URL = {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("RecipePhotosV1", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    static func cached(url: URL) -> UIImage? {
        let key = url.absoluteString as NSString
        if let hit = memory.object(forKey: key) { return hit }
        let file = folder.appendingPathComponent(fileName(url.absoluteString) + ".jpg")
        guard let data = try? Data(contentsOf: file), let image = UIImage(data: data) else { return nil }
        memory.setObject(image, forKey: key, cost: data.count)
        return image
    }

    static func image(from url: URL) async -> UIImage? {
        if let hit = cached(url: url) { return hit }
        return await gate.run {
            if let hit = cached(url: url) { return hit }
            var request = URLRequest(url: url)
            request.timeoutInterval = 10
            request.setValue("HUB/1.0", forHTTPHeaderField: "User-Agent")
            guard let (data, response) = try? await URLSession.shared.data(for: request),
                  (response as? HTTPURLResponse)?.statusCode ?? 200 < 400,
                  let image = UIImage(data: data),
                  image.size.width > 40
            else { return nil }
            let key = url.absoluteString as NSString
            memory.setObject(image, forKey: key, cost: data.count)
            if let jpeg = image.jpegData(compressionQuality: 0.92) {
                try? jpeg.write(to: folder.appendingPathComponent(fileName(url.absoluteString) + ".jpg"), options: .atomic)
            }
            return image
        }
    }

    private static func fileName(_ raw: String) -> String {
        var hash: UInt64 = 5381
        for byte in raw.utf8 {
            hash = ((hash << 5) &+ hash) &+ UInt64(byte)
        }
        return String(hash, radix: 16)
    }
}

private actor PhotoGate {
    private var running = 0
    private let limit: Int
    init(limit: Int) { self.limit = limit }
    func run<T>(_ work: () async -> T) async -> T {
        while running >= limit {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        running += 1
        defer { running -= 1 }
        return await work()
    }
}
