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
        var request = URLRequest(url: url, timeoutInterval: 12)
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        return data
    }
}
