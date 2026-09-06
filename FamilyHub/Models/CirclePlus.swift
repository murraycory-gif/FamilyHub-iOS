import Foundation

struct EventComment: Identifiable, Codable, Hashable {
    var id: UUID
    var eventID: UUID
    var memberID: UUID?
    var text: String
    var createdAt: Date

    static func make(eventID: UUID, memberID: UUID?, text: String) -> EventComment {
        EventComment(id: UUID(), eventID: eventID, memberID: memberID, text: text, createdAt: Date())
    }
}

struct CirclePlace: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var kind: Kind
    var latitude: Double
    var longitude: Double
    var radiusMeters: Double
    var memberIDs: [UUID]
    var notifyLeave: Bool
    var notifyArrive: Bool

    enum Kind: String, Codable, CaseIterable, Identifiable {
        case home, school, work, practice, other
        var id: String { rawValue }
        var label: String {
            switch self {
            case .home: return "Home"
            case .school: return "School"
            case .work: return "Work"
            case .practice: return "Practice"
            case .other: return "Place"
            }
        }
        var symbol: String {
            switch self {
            case .home: return "house.fill"
            case .school: return "graduationcap.fill"
            case .work: return "briefcase.fill"
            case .practice: return "sportscourt.fill"
            case .other: return "mappin.circle.fill"
            }
        }
    }

    static func make(name: String, kind: Kind, lat: Double, lon: Double, radius: Double = 120, members: [UUID] = []) -> CirclePlace {
        CirclePlace(id: UUID(), name: name, kind: kind, latitude: lat, longitude: lon, radiusMeters: radius, memberIDs: members, notifyLeave: true, notifyArrive: true)
    }
}

struct PlacePing: Identifiable, Codable, Hashable {
    var id: UUID
    var placeID: UUID
    var memberID: UUID
    var arrived: Bool
    var at: Date
}

struct HubDocument: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var kind: Kind
    var memberID: UUID?
    var notes: String
    var fileName: String?
    var createdAt: Date

    enum Kind: String, Codable, CaseIterable, Identifiable {
        case insurance, sports, school, medical, shots, other
        var id: String { rawValue }
        var label: String {
            switch self {
            case .insurance: return "Insurance"
            case .sports: return "Sports form"
            case .school: return "School"
            case .medical: return "Medical"
            case .shots: return "Shots"
            case .other: return "File"
            }
        }
        var symbol: String {
            switch self {
            case .insurance: return "shield.fill"
            case .sports: return "figure.run"
            case .school: return "graduationcap.fill"
            case .medical: return "cross.case.fill"
            case .shots: return "syringe.fill"
            case .other: return "doc.fill"
            }
        }
    }

    static func make(title: String, kind: Kind, memberID: UUID? = nil, notes: String = "") -> HubDocument {
        HubDocument(id: UUID(), title: title, kind: kind, memberID: memberID, notes: notes, fileName: nil, createdAt: Date())
    }
}

struct CustodyHouse: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var colorHex: String
    var weekdays: [Int]
    var kidIDs: [UUID]

    static func make(name: String, colorHex: String, weekdays: [Int], kids: [UUID]) -> CustodyHouse {
        CustodyHouse(id: UUID(), name: name, colorHex: colorHex, weekdays: weekdays, kidIDs: kids)
    }
}

struct QuietHours: Identifiable, Codable, Hashable {
    var id: UUID
    var memberID: UUID
    var startMinute: Int
    var endMinute: Int
    var enabled: Bool

    static func make(memberID: UUID, start: Int = 21 * 60, end: Int = 7 * 60) -> QuietHours {
        QuietHours(id: UUID(), memberID: memberID, startMinute: start, endMinute: end, enabled: true)
    }
}

struct RecapPhoto: Identifiable, Codable, Hashable {
    var id: UUID
    var weekStart: Date
    var memberID: UUID?
    var caption: String
    var createdAt: Date
}

struct ChoreProof: Identifiable, Codable, Hashable {
    var id: UUID
    var assignmentID: UUID
    var note: String
    var createdAt: Date
}

enum CircleXP {
    static func points(for assignment: ChoreAssignment, chore: Chore?) -> Int {
        let base = max(5, (chore?.rewardCents ?? 0) / 25)
        return assignment.status == .approved || assignment.status == .paid ? base : 0
    }

    static func total(memberID: UUID, assignments: [ChoreAssignment], chores: [Chore]) -> Int {
        assignments.filter { $0.memberID == memberID }.reduce(0) { sum, row in
            sum + points(for: row, chore: chores.first(where: { $0.id == row.choreID }))
        }
    }

    static func streak(memberID: UUID, assignments: [ChoreAssignment]) -> Int {
        let days = Set(assignments.filter {
            $0.memberID == memberID && ($0.status == .done || $0.status == .approved || $0.status == .paid)
        }.map { Calendar.current.startOfDay(for: $0.dueOn) })
        var streak = 0
        var cursor = Calendar.current.startOfDay(for: Date())
        while days.contains(cursor) {
            streak += 1
            guard let prior = Calendar.current.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prior
        }
        return streak
    }

    static func level(xp: Int) -> Int { max(1, xp / 40 + 1) }
}

enum GrocerySend {
    static func instacartURL(items: [String]) -> URL? {
        let q = items.prefix(12).joined(separator: ",").addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "https://www.instacart.com/store?search=\(q)")
    }

    static func amazonFreshURL(items: [String]) -> URL? {
        let q = items.prefix(8).joined(separator: " ").addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "https://www.amazon.com/s?k=\(q)&i=amazonfresh")
    }
}

enum QuickAdd {
    struct Draft {
        var title: String
        var startAt: Date
        var location: String
        var allDay: Bool
    }

    static func parse(_ raw: String, now: Date = Date()) -> Draft? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count >= 3 else { return nil }
        var work = text
        var location = ""
        if let at = work.range(of: " at ", options: .caseInsensitive) {
            location = work[at.upperBound...].trimmingCharacters(in: .whitespaces)
            work = String(work[..<at.lowerBound])
        }
        let cal = Calendar.current
        var day = cal.startOfDay(for: now)
        let lower = work.lowercased()
        let weekdays = [
            "sunday": 1, "monday": 2, "tuesday": 3, "wednesday": 4,
            "thursday": 5, "friday": 6, "saturday": 7,
            "sun": 1, "mon": 2, "tue": 3, "wed": 4, "thu": 5, "fri": 6, "sat": 7
        ]
        for (name, weekday) in weekdays where lower.contains(name) {
            let current = cal.component(.weekday, from: now)
            var delta = weekday - current
            if delta <= 0 { delta += 7 }
            day = cal.date(byAdding: .day, value: delta, to: day) ?? day
            work = work.replacingOccurrences(of: name, with: "", options: .caseInsensitive)
            break
        }
        if lower.contains("tomorrow") {
            day = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: now)) ?? day
            work = work.replacingOccurrences(of: "tomorrow", with: "", options: .caseInsensitive)
        }
        var hour = 17
        var minute = 0
        var allDay = true
        if let match = work.range(of: #"\b(\d{1,2})(?::(\d{2}))?\s*(am|pm)?\b"#, options: .regularExpression) {
            let token = String(work[match]).lowercased()
            let digits = token.split { !$0.isNumber }.compactMap { Int($0) }
            hour = digits.first ?? 17
            if digits.count > 1 { minute = digits[1] }
            if token.contains("pm"), hour < 12 { hour += 12 }
            if token.contains("am"), hour == 12 { hour = 0 }
            allDay = false
            work.removeSubrange(match)
        }
        let title = work.replacingOccurrences(of: "  ", with: " ").trimmingCharacters(in: .whitespaces)
        guard title.isEmpty == false else { return nil }
        let start = allDay ? day : (cal.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day)
        return Draft(title: title, startAt: start, location: location, allDay: allDay)
    }
}

enum LeaveBy {
    static func minutesUntil(_ event: CalendarEvent, travel: Int = 20, now: Date = Date()) -> Int? {
        let leave = event.startAt.addingTimeInterval(TimeInterval(-travel * 60))
        let delta = Int(leave.timeIntervalSince(now) / 60)
        return delta
    }
}
