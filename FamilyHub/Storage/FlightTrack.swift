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
        let blob = "\(event.title) \(event.location) \(event.notes)"
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

    static func trackURL(_ flight: TrackedFlight) -> URL? {
        URL(string: "https://flightaware.com/live/flight/\(flight.airline)\(flight.number)")
    }
}