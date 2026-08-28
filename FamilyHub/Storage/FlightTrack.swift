import Foundation

enum FlightParse {
    static let airlines: [String: String] = [
        "UA": "United", "AA": "American", "DL": "Delta", "WN": "Southwest",
        "B6": "JetBlue", "AS": "Alaska", "NK": "Spirit", "F9": "Frontier",
        "G4": "Allegiant", "HA": "Hawaiian", "SY": "Sun Country",
        "AC": "Air Canada", "BA": "British Airways", "LH": "Lufthansa",
        "AF": "Air France", "EK": "Emirates", "QR": "Qatar", "TK": "Turkish",
        "LX": "Swiss", "IB": "Iberia", "KL": "KLM", "VS": "Virgin Atlantic",
        "AM": "Aeromexico",
    ]

    static func airlineName(_ code: String) -> String {
        airlines[code.uppercased()] ?? code.uppercased()
    }

    static func from(event: CalendarEvent) -> TrackedFlight? {
        let blob = String("\(event.title) \(event.location) \(event.notes)".prefix(400))
        guard let flight = flightCode(in: blob) else { return nil }
        let route = airports(in: blob)
        let arrive = event.endAt.flatMap { end in
            end > event.startAt ? end : nil
        }
        return TrackedFlight(
            id: event.id,
            airline: flight.airline,
            number: flight.number,
            origin: route?.origin ?? "",
            destination: route?.dest ?? "",
            departAt: event.startAt,
            arriveAt: arrive,
            eventID: event.id,
            memberID: event.memberID,
            notes: event.location
        )
    }

    private static let codeRegex = try! NSRegularExpression(
        pattern: #"\b(?:FLIGHT\s+)?([A-Z]{2})\s*-?\s*(\d{2,4})\b"#
    )
    private static let airportRegex = try! NSRegularExpression(
        pattern: #"\b([A-Z]{3})\s*(?:TO|-|–|—|/|→)\s*([A-Z]{3})\b"#
    )

    static func flightCode(in text: String) -> (airline: String, number: String)? {
        let upper = text.uppercased()
        let range = NSRange(upper.startIndex..., in: upper)
        guard let match = codeRegex.firstMatch(in: upper, range: range),
              let a = Range(match.range(at: 1), in: upper),
              let n = Range(match.range(at: 2), in: upper)
        else { return nil }
        return (String(upper[a]), String(upper[n]))
    }

    static func airports(in text: String) -> (origin: String, dest: String)? {
        let upper = text.uppercased()
        let range = NSRange(upper.startIndex..., in: upper)
        guard let match = airportRegex.firstMatch(in: upper, range: range),
              let a = Range(match.range(at: 1), in: upper),
              let b = Range(match.range(at: 2), in: upper)
        else { return nil }
        return (String(upper[a]), String(upper[b]))
    }

    static func flights(
        on day: Date,
        events: [CalendarEvent],
        extra: [TrackedFlight],
        calendar: Calendar = .current
    ) -> [TrackedFlight] {
        let fromCal = events.compactMap(from(event:))
        var seen = Set(extra.map { "\($0.airline)-\($0.number)-\(calendar.startOfDay(for: $0.departAt).timeIntervalSince1970)" })
        var all = extra
        for item in fromCal {
            let key = "\(item.airline)-\(item.number)-\(calendar.startOfDay(for: item.departAt).timeIntervalSince1970)"
            if seen.insert(key).inserted { all.append(item) }
        }
        return all
            .filter { calendar.isDate($0.departAt, inSameDayAs: day) }
            .sorted { $0.departAt < $1.departAt }
    }

    static func isLive(_ flight: TrackedFlight, now: Date = Date()) -> Bool {
        let land = flight.arriveAt ?? flight.departAt.addingTimeInterval(6 * 3600)
        return now < land.addingTimeInterval(30 * 60)
    }

    static func phase(_ flight: TrackedFlight, now: Date = Date()) -> String {
        let land = flight.arriveAt ?? flight.departAt.addingTimeInterval(6 * 3600)
        if now >= land { return "Landed" }
        if now >= flight.departAt { return "En route" }
        if flight.departAt.timeIntervalSince(now) <= 3 * 3600 { return "Soon" }
        return "Scheduled"
    }

    static func countdown(_ flight: TrackedFlight, now: Date = Date()) -> String {
        let land = flight.arriveAt ?? flight.departAt.addingTimeInterval(6 * 3600)
        guard flight.departAt.timeIntervalSince1970.isFinite, land.timeIntervalSince1970.isFinite else { return "—" }
        if now >= land { return "Arrived" }
        let target = now >= flight.departAt ? land : flight.departAt
        let minutes = max(1, Int((target.timeIntervalSince(now) / 60).rounded()))
        let hours = minutes / 60
        let mins = minutes % 60
        let label = now >= flight.departAt ? "Lands" : "Departs"
        if hours >= 24 { return "\(label) in \(hours / 24)d" }
        if hours >= 1 { return "\(label) in \(hours)h \(mins)m" }
        return "\(label) in \(mins)m"
    }

    static func progress(_ flight: TrackedFlight, now: Date = Date()) -> Double {
        let land = flight.arriveAt ?? flight.departAt.addingTimeInterval(6 * 3600)
        let span = land.timeIntervalSince(flight.departAt)
        guard span > 0 else { return now >= land ? 1 : 0 }
        return min(1, max(0, now.timeIntervalSince(flight.departAt) / span))
    }

    static func duration(_ flight: TrackedFlight) -> String {
        let land = flight.arriveAt ?? flight.departAt.addingTimeInterval(6 * 3600)
        let minutes = max(0, Int(land.timeIntervalSince(flight.departAt) / 60))
        let hours = minutes / 60
        let mins = minutes % 60
        if hours == 0 { return "\(mins)m" }
        return "\(hours)h \(mins)m"
    }

    static func trackURL(_ flight: TrackedFlight) -> URL? {
        URL(string: "https://flightaware.com/live/flight/\(flight.airline)\(flight.number)")
    }
}

struct FlightPing: Equatable {
    var latitude: Double
    var longitude: Double
    var altitudeFt: Int?
    var speedKts: Int?
    var heading: Double?
    var onGround: Bool
}

enum FlightLive {
    private static let icao: [String: String] = [
        "UA": "UAL", "AA": "AAL", "DL": "DAL", "WN": "SWA",
        "B6": "JBU", "AS": "ASA", "NK": "NKS", "F9": "FFT",
        "G4": "AAY", "HA": "HAL", "SY": "SCX", "AC": "ACA",
        "BA": "BAW", "LH": "DLH", "AF": "AFR", "EK": "UAE",
        "QR": "QTR", "TK": "THY", "LX": "SWR", "IB": "IBE",
        "KL": "KLM", "VS": "VIR", "AM": "AMX",
    ]

    static func callsigns(for flight: TrackedFlight) -> [String] {
        let n = flight.number.trimmingCharacters(in: CharacterSet.whitespaces)
        var signs = ["\(flight.airline)\(n)"]
        if let prefix = icao[flight.airline.uppercased()] {
            signs.insert("\(prefix)\(n)", at: 0)
        }
        return signs
    }

    static func ping(_ flight: TrackedFlight) async -> FlightPing? {
        for sign in callsigns(for: flight) {
            if let hit = await fetch(sign) { return hit }
        }
        return nil
    }

    private static func fetch(_ callsign: String) async -> FlightPing? {
        let encoded = callsign.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? callsign
        let urls = [
            "https://api.adsb.lol/v2/callsign/\(encoded)",
            "https://opendata.adsb.fi/api/v2/callsign/\(encoded)",
        ]
        for raw in urls {
            guard let url = URL(string: raw) else { continue }
            var request = URLRequest(url: url)
            request.timeoutInterval = 8
            request.setValue("FamilyHub/1.0", forHTTPHeaderField: "User-Agent")
            guard let data = try? await URLSession.shared.data(for: request).0,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { continue }
            let rows = json["ac"] as? [[String: Any]] ?? []
            guard let row = rows.first else { continue }
            let lat = number(row["lat"])
            let lon = number(row["lon"])
            guard let lat, let lon else { continue }
            let alt = number(row["alt_baro"]) ?? number(row["alt_geom"])
            let speed = number(row["gs"])
            let heading = number(row["true_heading"]) ?? number(row["track"])
            let ground = (row["alt_baro"] as? String)?.lowercased() == "ground" || (alt ?? 1) <= 0
            return FlightPing(
                latitude: lat,
                longitude: lon,
                altitudeFt: alt.map { Int($0) },
                speedKts: speed.map { Int($0) },
                heading: heading,
                onGround: ground
            )
        }
        return nil
    }

    private static func number(_ value: Any?) -> Double? {
        if let n = value as? Double { return n }
        if let n = value as? Int { return Double(n) }
        if let n = value as? NSNumber { return n.doubleValue }
        if let s = value as? String { return Double(s) }
        return nil
    }
}