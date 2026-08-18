import Foundation

// MARK: - Enums

enum MemberRole: String, Codable, CaseIterable, Identifiable {
    case parent
    case child

    var id: String { rawValue }

    var label: String {
        switch self {
        case .parent: return "Parent"
        case .child: return "Kid"
        }
    }
}

enum ChoreCadence: String, Codable, CaseIterable, Identifiable {
    case once
    case daily
    case weekly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .once: return "One time"
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        }
    }
}

enum AssignmentStatus: String, Codable, CaseIterable, Identifiable {
    case pending
    case done
    case approved
    case paid

    var id: String { rawValue }

    var label: String {
        switch self {
        case .pending: return "To do"
        case .done: return "Waiting approval"
        case .approved: return "Earned"
        case .paid: return "Paid"
        }
    }
}

// MARK: - Money

enum Money {
    static func cents(_ value: Int) -> String {
        let sign = value < 0 ? "-" : ""
        let absValue = abs(value)
        return String(format: "%@ $%d.%02d", sign, absValue / 100, absValue % 100)
    }
}

// MARK: - Models

struct FamilyMember: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var role: MemberRole
    var colorHex: String
    var symbol: String
    var allowanceBalanceCents: Int

    static func make(name: String, role: MemberRole, colorHex: String, symbol: String) -> FamilyMember {
        FamilyMember(
            id: UUID(),
            name: name,
            role: role,
            colorHex: colorHex,
            symbol: symbol,
            allowanceBalanceCents: 0
        )
    }

    var displayEmoji: String {
        PersonStyle.emoji(fromStored: symbol)
    }
}

enum PersonStyle {
    static let colors: [String] = [
        "0F172A", "1E293B", "163A5F", "1D4E89", "2563EB", "3B82F6", "0EA5E9", "06B6D4",
        "0F766E", "14B8A6", "059669", "16A34A", "65A30D", "84CC16", "CA8A04", "F59E0B",
        "EA580C", "F97316", "DC2626", "EF4444", "E11D48", "F43F5E", "DB2777", "EC4899",
        "C026D3", "A855F7", "7C3AED", "8B5CF6", "4F46E5", "6366F1", "78716C", "A8A29E"
    ]

    static let emojis: [String] = [
        "😎", "🤠", "🥳", "🤓", "🦊", "🐼", "🦁", "🐯",
        "🐻", "🐨", "🐸", "🦄", "🐲", "🐙", "🦋", "🐶",
        "🐱", "🐵", "🐧", "🦉", "🚀", "🌟", "⚡️", "🌈",
        "🎯", "🏆", "⚽️", "🏀", "🏈", "🎾", "🏐", "🎮",
        "🎸", "🎨", "📚", "🎤", "🎧", "🎹", "🍕", "🌮",
        "🧁", "🍩", "🛹", "🚴", "🏊", "🧩", "🪁", "🧸"
    ]

    static func emoji(fromStored stored: String) -> String {
        if looksLikeEmoji(stored) { return stored }
        switch stored {
        case "person.fill": return "😎"
        case "figure.run": return "🏃"
        case "soccerball": return "⚽️"
        case "book.fill": return "📚"
        case "gamecontroller.fill": return "🎮"
        case "leaf.fill": return "🌿"
        default: return "🙂"
        }
    }

    static func looksLikeEmoji(_ value: String) -> Bool {
        guard let scalar = value.unicodeScalars.first else { return false }
        return scalar.value > 0x2000
    }
}

struct CalendarEvent: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var startAt: Date
    var endAt: Date?
    var allDay: Bool
    var location: String
    var notes: String
    /// `nil` means the whole household.
    var memberID: UUID?

    static func make(
        title: String,
        startAt: Date,
        endAt: Date? = nil,
        allDay: Bool = false,
        location: String = "",
        notes: String = "",
        memberID: UUID? = nil
    ) -> CalendarEvent {
        CalendarEvent(
            id: UUID(),
            title: title,
            startAt: startAt,
            endAt: endAt,
            allDay: allDay,
            location: location,
            notes: notes,
            memberID: memberID
        )
    }
}

struct ReminderItem: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var dueAt: Date?
    var isCompleted: Bool
    var memberID: UUID?

    static func make(title: String, dueAt: Date? = nil, memberID: UUID? = nil) -> ReminderItem {
        ReminderItem(id: UUID(), title: title, dueAt: dueAt, isCompleted: false, memberID: memberID)
    }
}

struct TodoItem: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var notes: String
    var isCompleted: Bool
    var dueAt: Date?
    var memberID: UUID?

    static func make(title: String, notes: String = "", dueAt: Date? = nil, memberID: UUID? = nil) -> TodoItem {
        TodoItem(
            id: UUID(),
            title: title,
            notes: notes,
            isCompleted: false,
            dueAt: dueAt,
            memberID: memberID
        )
    }
}

struct Chore: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var details: String
    var rewardCents: Int
    var cadence: ChoreCadence

    static func make(title: String, details: String = "", rewardCents: Int, cadence: ChoreCadence) -> Chore {
        Chore(id: UUID(), title: title, details: details, rewardCents: rewardCents, cadence: cadence)
    }
}

struct ChoreAssignment: Identifiable, Codable, Hashable {
    var id: UUID
    var choreID: UUID
    var memberID: UUID
    var dueOn: Date
    var status: AssignmentStatus
    var completedAt: Date?
    var approvedAt: Date?

    static func make(choreID: UUID, memberID: UUID, dueOn: Date) -> ChoreAssignment {
        ChoreAssignment(
            id: UUID(),
            choreID: choreID,
            memberID: memberID,
            dueOn: Calendar.current.startOfDay(for: dueOn),
            status: .pending,
            completedAt: nil,
            approvedAt: nil
        )
    }
}

struct LedgerEntry: Identifiable, Codable, Hashable {
    var id: UUID
    var memberID: UUID
    var amountCents: Int
    var reason: String
    var createdAt: Date
    var assignmentID: UUID?

    static func make(
        memberID: UUID,
        amountCents: Int,
        reason: String,
        assignmentID: UUID? = nil,
        at date: Date = Date()
    ) -> LedgerEntry {
        LedgerEntry(
            id: UUID(),
            memberID: memberID,
            amountCents: amountCents,
            reason: reason,
            createdAt: date,
            assignmentID: assignmentID
        )
    }
}

struct HubSnapshot: Codable {
    var householdName: String
    var members: [FamilyMember]
    var events: [CalendarEvent]
    var reminders: [ReminderItem]
    var todos: [TodoItem]
    var chores: [Chore]
    var assignments: [ChoreAssignment]
    var ledger: [LedgerEntry]
    var weatherPlace: WeatherPlace?
    var hubWidgets: [HubWidget]?
}

enum HubWidgetKind: String, Codable, CaseIterable, Identifiable {
    case cameras
    case weather
    case snapshot

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cameras: return "Cameras"
        case .weather: return "Weather"
        case .snapshot: return "Household"
        }
    }

    var symbol: String {
        switch self {
        case .cameras: return "video.fill"
        case .weather: return "cloud.sun.fill"
        case .snapshot: return "square.grid.2x2.fill"
        }
    }

    var detail: String {
        switch self {
        case .cameras: return "Security cameras for the house"
        case .weather: return "7-day forecast for your area"
        case .snapshot: return "Open chores, reminders, and to-dos"
        }
    }
}

struct HubWidget: Codable, Identifiable, Hashable {
    var id: UUID
    var kind: HubWidgetKind

    static func make(_ kind: HubWidgetKind) -> HubWidget {
        HubWidget(id: UUID(), kind: kind)
    }

    static let defaultSet: [HubWidget] = [
        .make(.cameras),
        .make(.weather),
        .make(.snapshot),
    ]
}

struct WeatherPlace: Codable, Hashable, Identifiable {
    var label: String
    var latitude: Double
    var longitude: Double

    var id: String { "\(latitude),\(longitude)" }

    static let chicago = WeatherPlace(label: "Chicago, IL", latitude: 41.8781, longitude: -87.6298)
}

struct WeatherDay: Identifiable, Hashable {
    var dateISO: String
    var weekday: String
    var high: Int
    var low: Int
    var code: Int
    var precip: Int

    var id: String { dateISO }

    var symbolName: String { WeatherIcon.symbol(for: code) }
}

struct WeatherNow: Hashable {
    var temp: Int
    var feelsLike: Int
    var code: Int
    var isDay: Bool

    var symbolName: String { WeatherIcon.symbol(for: code) }
    var condition: String { WeatherIcon.condition(for: code) }
}

struct WeatherHour: Identifiable, Hashable {
    var at: Date
    var temp: Int
    var code: Int
    var precip: Int

    var id: TimeInterval { at.timeIntervalSince1970 }
    var symbolName: String { WeatherIcon.symbol(for: code) }
}

enum WeatherIcon {
    static func symbol(for code: Int) -> String {
        switch code {
        case 0: return "sun.max.fill"
        case 1, 2: return "cloud.sun.fill"
        case 3: return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82: return "cloud.rain.fill"
        case 71, 73, 75, 77, 85, 86: return "cloud.snow.fill"
        case 95, 96, 99: return "cloud.bolt.rain.fill"
        default: return "cloud.sun.fill"
        }
    }

    static func condition(for code: Int) -> String {
        switch code {
        case 0: return "Clear"
        case 1: return "Mostly Clear"
        case 2: return "Partly Cloudy"
        case 3: return "Cloudy"
        case 45, 48: return "Foggy"
        case 51, 53, 55, 56, 57: return "Drizzle"
        case 61, 63, 66, 67: return "Rain"
        case 65: return "Heavy Rain"
        case 71, 73, 77, 85: return "Snow"
        case 75, 86: return "Heavy Snow"
        case 80, 81, 82: return "Showers"
        case 95, 96, 99: return "Thunderstorms"
        default: return "Partly Cloudy"
        }
    }
}

// MARK: - Chore engine (pure — unit tested)

enum ChoreEngine {
    static func complete(_ assignment: ChoreAssignment, at date: Date = Date()) -> ChoreAssignment {
        guard assignment.status == .pending else { return assignment }
        var next = assignment
        next.status = .done
        next.completedAt = date
        return next
    }

    static func reopen(_ assignment: ChoreAssignment) -> ChoreAssignment {
        guard assignment.status == .done else { return assignment }
        var next = assignment
        next.status = .pending
        next.completedAt = nil
        return next
    }

    static func approve(
        _ assignment: ChoreAssignment,
        chore: Chore,
        at date: Date = Date()
    ) -> (ChoreAssignment, LedgerEntry)? {
        guard assignment.status == .done else { return nil }
        var next = assignment
        next.status = .approved
        next.approvedAt = date
        let entry = LedgerEntry.make(
            memberID: assignment.memberID,
            amountCents: chore.rewardCents,
            reason: chore.title,
            assignmentID: assignment.id,
            at: date
        )
        return (next, entry)
    }

    static func markPaid(_ assignment: ChoreAssignment) -> ChoreAssignment {
        guard assignment.status == .approved else { return assignment }
        var next = assignment
        next.status = .paid
        return next
    }

    static func applyLedger(balance: Int, entry: LedgerEntry) -> Int {
        balance + entry.amountCents
    }
}

// MARK: - Calendar helpers

enum DayFilter: Equatable {
    case family
    case member(UUID)
}

enum CalendarMath {
    static func events(
        _ events: [CalendarEvent],
        on day: Date,
        filter: DayFilter,
        calendar: Calendar = .current
    ) -> [CalendarEvent] {
        events
            .filter { calendar.isDate($0.startAt, inSameDayAs: day) }
            .filter { event in
                switch filter {
                case .family:
                    return true
                case .member(let id):
                    return event.memberID == nil || event.memberID == id
                }
            }
            .sorted { $0.startAt < $1.startAt }
    }

    static func monthDays(containing date: Date, calendar: Calendar = .current) -> [Date] {
        guard let interval = calendar.dateInterval(of: .month, for: date) else { return [] }
        let first = interval.start
        let weekday = calendar.component(.weekday, from: first)
        let leading = weekday - calendar.firstWeekday
        let pad = leading >= 0 ? leading : leading + 7
        let start = calendar.date(byAdding: .day, value: -pad, to: first) ?? first
        return (0..<42).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }
}
