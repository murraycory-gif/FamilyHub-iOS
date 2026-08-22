import CoreLocation
import Foundation

struct PlaceHour: Identifiable, Hashable {
    var id: String { day }
    var day: String
    var time: String
}

@MainActor
final class PlaceFacts: ObservableObject {
    @Published var hours: [PlaceHour] = []
    @Published var openLabel: String?
    @Published var isOpen: Bool?
    @Published var cuisine: String?
    @Published var website: URL?
    @Published var phone: String?
    @Published var loaded = false

    func load(name: String, address: String?, coordinate: CLLocationCoordinate2D?, fallbackURL: URL?, fallbackPhone: String?) async {
        website = fallbackURL
        phone = fallbackPhone
        async let overpass = Self.overpass(name: name, coordinate: coordinate)
        async let nominatim = Self.nominatim(name: name, address: address, coordinate: coordinate)
        let overpassTags = await overpass
        let nominatimTags = await nominatim
        let tags = overpassTags ?? nominatimTags
        if let tags {
            if let raw = tags["opening_hours"], !raw.isEmpty {
                hours = OSMHours.rows(raw)
                isOpen = OSMHours.isOpenNow(raw)
                openLabel = isOpen == true ? "Open now" : isOpen == false ? "Closed now" : nil
            }
            if let cuisine = tags["cuisine"], !cuisine.isEmpty {
                self.cuisine = cuisine.replacingOccurrences(of: "_", with: " ").capitalized
            }
            if website == nil, let site = tags["website"] ?? tags["contact:website"], let url = URL(string: site) {
                website = url
            }
            if (phone ?? "").isEmpty, let value = tags["phone"] ?? tags["contact:phone"] {
                phone = value
            }
        }
        if website == nil { website = fallbackURL }
        if hours.isEmpty, let fallbackURL {
            website = fallbackURL
        }
        loaded = true
    }

    private static func overpass(name: String, coordinate: CLLocationCoordinate2D?) async -> [String: String]? {
        guard let coordinate else { return nil }
        let safe = name.replacingOccurrences(of: "\"", with: "")
        let data = """
        [out:json][timeout:8];
        nwr(around:150,\(coordinate.latitude),\(coordinate.longitude))[name~"\(safe)",i];
        out tags 8;
        """
        var comps = URLComponents(string: "https://overpass-api.de/api/interpreter")!
        comps.queryItems = [URLQueryItem(name: "data", value: data)]
        guard let url = comps.url, let json = await fetchJSON(url) else { return nil }
        return firstTags(json)
    }

    private static func nominatim(name: String, address: String?, coordinate: CLLocationCoordinate2D?) async -> [String: String]? {
        if let coordinate {
            var comps = URLComponents(string: "https://nominatim.openstreetmap.org/reverse")!
            comps.queryItems = [
                URLQueryItem(name: "lat", value: "\(coordinate.latitude)"),
                URLQueryItem(name: "lon", value: "\(coordinate.longitude)"),
                URLQueryItem(name: "format", value: "json"),
                URLQueryItem(name: "extratags", value: "1")
            ]
            if let url = comps.url, let json = await fetchJSON(url),
               let extras = json["extratags"] as? [String: String], !extras.isEmpty {
                return extras
            }
        }
        var comps = URLComponents(string: "https://nominatim.openstreetmap.org/search")!
        comps.queryItems = [
            URLQueryItem(name: "q", value: [name, address].compactMap { $0 }.joined(separator: " ")),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "extratags", value: "1"),
            URLQueryItem(name: "limit", value: "3")
        ]
        guard let url = comps.url, let data = await fetch(url),
              let rows = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else { return nil }
        for row in rows {
            if let extras = row["extratags"] as? [String: String], !extras.isEmpty { return extras }
        }
        return nil
    }

    private static func firstTags(_ json: [String: Any]) -> [String: String]? {
        guard let elements = json["elements"] as? [[String: Any]] else { return nil }
        for element in elements {
            if let tags = element["tags"] as? [String: String], tags["opening_hours"] != nil || tags["website"] != nil {
                return tags
            }
        }
        return elements.first?["tags"] as? [String: String]
    }

    private static func fetchJSON(_ url: URL) async -> [String: Any]? {
        guard let data = await fetch(url) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    private static func fetch(_ url: URL) async -> Data? {
        var request = URLRequest(url: url)
        request.setValue("HUB/1.0 (family organizer)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 8
        return try? await URLSession.shared.data(for: request).0
    }
}

enum OSMHours {
    private static let order = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
    private static let map: [String: String] = [
        "Mo": "Monday", "Tu": "Tuesday", "We": "Wednesday", "Th": "Thursday",
        "Fr": "Friday", "Sa": "Saturday", "Su": "Sunday"
    ]
    private static let codes = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

    static func rows(_ raw: String) -> [PlaceHour] {
        if raw.contains("24/7") {
            return order.map { PlaceHour(day: $0, time: "Open 24 hours") }
        }
        var byDay: [String: String] = [:]
        for chunk in raw.split(separator: ";") {
            let part = chunk.trimmingCharacters(in: .whitespaces)
            guard let space = part.firstIndex(of: " ") else { continue }
            let days = String(part[..<space])
            let times = prettyTime(String(part[part.index(after: space)...]))
            for day in expand(days) { byDay[day] = times }
        }
        return order.compactMap { day in
            guard let time = byDay[day] else { return nil }
            return PlaceHour(day: day, time: time)
        }
    }

    static func isOpenNow(_ raw: String) -> Bool? {
        if raw.contains("24/7") { return true }
        let weekday = Calendar.current.component(.weekday, from: Date())
        let names = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        let today = names[weekday - 1]
        guard let row = rows(raw).first(where: { $0.day == today }) else { return nil }
        if row.time.lowercased().contains("closed") { return false }
        if row.time.lowercased().contains("24") { return true }
        return nil
    }

    private static func expand(_ token: String) -> [String] {
        if token.contains("-"), let dash = token.firstIndex(of: "-") {
            let start = String(token[..<dash])
            let end = String(token[token.index(after: dash)...])
            guard let a = codes.firstIndex(of: start), let b = codes.firstIndex(of: end), a <= b else { return [] }
            return codes[a...b].compactMap { map[$0] }
        }
        if token.contains(",") {
            return token.split(separator: ",").compactMap { map[String($0)] }
        }
        return map[token].map { [$0] } ?? []
    }

    private static func prettyTime(_ raw: String) -> String {
        raw.split(separator: ",").map { piece -> String in
            let part = piece.trimmingCharacters(in: .whitespaces)
            if part == "off" { return "Closed" }
            let bits = part.split(separator: "-")
            guard bits.count == 2 else { return part }
            return "\(clock(String(bits[0]))) – \(clock(String(bits[1])))"
        }.joined(separator: ", ")
    }

    private static func clock(_ value: String) -> String {
        let bits = value.split(separator: ":")
        guard let hour = Int(bits.first ?? ""), bits.count >= 2 else { return value }
        let minute = Int(bits[1].prefix(2)) ?? 0
        var h = hour % 24
        let suffix = h >= 12 ? "PM" : "AM"
        if h == 0 { h = 12 }
        if h > 12 { h -= 12 }
        if minute == 0 { return "\(h) \(suffix)" }
        return String(format: "%d:%02d \(suffix)", h, minute)
    }
}

enum PlaceMenus {
    static func url(for name: String, website: URL?) -> URL? {
        let n = name.lowercased()
        if n.contains("starbucks") { return URL(string: "https://www.starbucks.com/menu") }
        if n.contains("mcdonald") { return URL(string: "https://www.mcdonalds.com/us/en-us/full-menu.html") }
        if n.contains("chipotle") { return URL(string: "https://www.chipotle.com/menu") }
        if n.contains("panera") { return URL(string: "https://www.panerabread.com/en-us/menu.html") }
        if n.contains("dunkin") { return URL(string: "https://www.dunkindonuts.com/en/menu") }
        if n.contains("subway") { return URL(string: "https://www.subway.com/en-us/menunutrition/menu") }
        if n.contains("chick-fil") || n.contains("chick fil") { return URL(string: "https://www.chick-fil-a.com/menu") }
        if n.contains("wendy") { return URL(string: "https://www.wendys.com/menu") }
        if n.contains("taco bell") { return URL(string: "https://www.tacobell.com/food") }
        if n.contains("popeyes") { return URL(string: "https://www.popeyes.com/menu") }
        if n.contains("domino") { return URL(string: "https://www.dominos.com/en/pages/order/menu") }
        if n.contains("pizza hut") { return URL(string: "https://www.pizzahut.com/menu") }
        if n.contains("panda") { return URL(string: "https://www.pandaexpress.com/menu") }
        if n.contains("olive garden") { return URL(string: "https://www.olivegarden.com/menu") }
        if n.contains("applebee") { return URL(string: "https://www.applebees.com/en/menu") }
        if n.contains("chili") { return URL(string: "https://www.chilis.com/menu") }
        return website
    }
}
