import Foundation
import Security

enum HubHTTP {
    static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 12
        config.timeoutIntervalForResource = 20
        config.waitsForConnectivity = true
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.urlCache = URLCache(memoryCapacity: 8 * 1024 * 1024, diskCapacity: 40 * 1024 * 1024)
        return URLSession(configuration: config)
    }()

    static func data(from url: URL) async throws -> Data {
        let (status, data) = try await response(from: url)
        if !(200...299).contains(status) {
            throw URLError(.badServerResponse)
        }
        return data
    }

    static func response(from url: URL) async throws -> (Int, Data) {
        let request = URLRequest(url: url, timeoutInterval: 12)
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        return (status, data)
    }
}

enum ICSLink {
    static func normalize(_ raw: String) -> String {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = text.lowercased()
        if lower.hasPrefix("webcal://") {
            return "https://" + text.dropFirst("webcal://".count)
        }
        if lower.hasPrefix("webcals://") {
            return "https://" + text.dropFirst("webcals://".count)
        }
        if lower.hasPrefix("http://") {
            return "https://" + text.dropFirst("http://".count)
        }
        return text
    }

    static func httpsURL(from raw: String) -> URL? {
        guard let url = URL(string: normalize(raw)), url.scheme?.lowercased() == "https" else { return nil }
        return url
    }

    /// Only a successful calendar body may replace imported events.
    static func calendarText(status: Int, data: Data) -> String? {
        guard (200...299).contains(status) else { return nil }
        let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) ?? ""
        guard text.contains("BEGIN:VCALENDAR") else { return nil }
        return text
    }
}

enum HubJoinCode {
    /// Households created before this change keep their 6-character code.
    static let legacyLength = 6
    static let length = 20
    static let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
    static let maxIssuesPerHour = 5

    static func make() -> String {
        var bytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        if status != errSecSuccess {
            return String((0..<length).map { _ in alphabet[Int.random(in: 0..<alphabet.count)] })
        }
        return String(bytes.map { alphabet[Int($0) % alphabet.count] })
    }

    static func normalized(_ raw: String) -> String {
        raw.replacingOccurrences(of: " ", with: "").uppercased()
    }

    static func isAcceptable(_ raw: String) -> Bool {
        let clean = normalized(raw)
        guard clean.count == legacyLength || clean.count == length else { return false }
        return clean.allSatisfy { alphabet.contains($0) }
    }
}

enum HubFilePrivacy {
    /// Regenerable or redundant copies stay off iCloud and computer backup.
    static func excludeFromBackup(_ url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var copy = url
        try? copy.setResourceValues(values)
        protectUntilFirstUnlock(url)
    }

    /// Available after the first unlock, which is when HUB reads hub.json.
    static func protectUntilFirstUnlock(_ url: URL) {
        try? FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: url.path
        )
    }
}
