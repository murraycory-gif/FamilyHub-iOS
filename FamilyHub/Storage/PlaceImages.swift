import Foundation
import UIKit

enum PlaceImages {
    private static var memory: [String: UIImage] = [:]

    static func photo(name: String, address: String?) async -> UIImage? {
        let key = query(name: name, address: address).lowercased()
        if let cached = memory[key] { return cached }
        let image = await withTimeout(seconds: 4) {
            if let photo = await duckDuckGo(key) { return photo }
            return await bing(key)
        }
        if let image { memory[key] = image }
        return image
    }

    private static func query(name: String, address: String?) -> String {
        var parts = [name]
        if let address, !address.isEmpty {
            let bits = address.replacingOccurrences(of: ",", with: " ").split(separator: " ").map(String.init)
            if bits.count >= 2 {
                parts.append(bits.suffix(2).joined(separator: " "))
            } else {
                parts.append(address)
            }
        }
        return parts.joined(separator: " ")
    }

    private static func duckDuckGo(_ query: String) async -> UIImage? {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        guard let home = URL(string: "https://duckduckgo.com/?q=\(encoded)&iax=images&ia=images") else { return nil }
        var homeReq = URLRequest(url: home)
        homeReq.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        homeReq.timeoutInterval = 4
        guard let (htmlData, _) = try? await URLSession.shared.data(for: homeReq),
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
        guard let url = comps.url else { return nil }
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("https://duckduckgo.com/", forHTTPHeaderField: "Referer")
        request.timeoutInterval = 4
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let decoded = try? JSONDecoder().decode(DDG.self, from: data)
        else { return nil }
        for hit in decoded.results ?? [] {
            if (hit.width ?? 400) < 220 { continue }
            if let image = await download(hit.image) { return image }
        }
        return nil
    }

    private static func bing(_ query: String) async -> UIImage? {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        guard let url = URL(string: "https://www.bing.com/images/search?q=\(encoded)&form=HDRSC2") else { return nil }
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 4
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let html = String(data: data, encoding: .utf8)
        else { return nil }
        let pattern = #"murl":"(https:[^&]+)""#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(html.startIndex..., in: html)
        for match in regex.matches(in: html, range: range).prefix(6) {
            guard let r = Range(match.range(at: 1), in: html) else { continue }
            let raw = String(html[r]).replacingOccurrences(of: "\\/", with: "/")
            if let image = await download(raw) { return image }
        }
        return nil
    }

    private static func download(_ raw: String) async -> UIImage? {
        guard let url = URL(string: raw) else { return nil }
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 4
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let image = UIImage(data: data),
              image.size.width > 80
        else { return nil }
        return image
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

    private static func withTimeout(seconds: Double, operation: @escaping () async -> UIImage?) async -> UIImage? {
        await withTaskGroup(of: UIImage?.self) { group in
            group.addTask { await operation() }
            group.addTask {
                try? await Task.sleep(for: .seconds(seconds))
                return nil
            }
            let value = await group.next() ?? nil
            group.cancelAll()
            return value
        }
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
