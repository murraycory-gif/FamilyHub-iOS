import Foundation

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
        return text
    }

    static func httpsURL(from raw: String) -> URL? {
        URL(string: normalize(raw))
    }

    /// Only a successful calendar body may replace imported events.
    static func calendarText(status: Int, data: Data) -> String? {
        guard (200...299).contains(status) else { return nil }
        let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) ?? ""
        guard text.contains("BEGIN:VCALENDAR") else { return nil }
        return text
    }
}
