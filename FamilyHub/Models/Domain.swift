import Foundation

// MARK: - Enums

enum MemberRole: String, Codable, CaseIterable, Identifiable {
    case parent
    case child
    case dog
    case cat
    case bird

    var id: String { rawValue }

    var label: String {
        switch self {
        case .parent: return "Parent"
        case .child: return "Kid"
        case .dog: return "Dog"
        case .cat: return "Cat"
        case .bird: return "Bird"
        }
    }

    var isPet: Bool {
        switch self {
        case .dog, .cat, .bird: return true
        default: return false
        }
    }

    var defaultEmoji: String {
        switch self {
        case .parent: return "😎"
        case .child: return "🌟"
        case .dog: return "🐶"
        case .cat: return "🐱"
        case .bird: return "🐦"
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

    static let groups: [(title: String, emojis: [String])] = [
        ("Faces", ["😎", "🤠", "🥳", "🤓", "😇", "🤩", "😍", "🤗", "😴", "🧐", "👻", "👽", "🤖", "🎃", "😈", "🦸", "🧙", "🧚"]),
        ("Dogs", ["🐶", "🐕", "🦮", "🐩", "🐺", "🦴", "🌭"]),
        ("Cats", ["🐱", "🐈", "🐈‍⬛", "🦁", "🐯", "🐆"]),
        ("Birds", ["🐦", "🐤", "🐣", "🐥", "🦅", "🦉", "🐧", "🦆", "🦢", "🦜", "🦩", "🦚"]),
        ("Animals", ["🦊", "🐼", "🐻", "🐨", "🐸", "🦄", "🐲", "🐙", "🦋", "🐵", "🐮", "🐷", "🐰", "🐹", "🐭", "🐢", "🦖", "🦕", "🐳", "🐬"]),
        ("Sports", ["⚽️", "🏀", "🏈", "🎾", "🏐", "⚾️", "🏉", "🎱", "🏓", "⛳️", "🏒", "🥍", "🏸", "🥊", "🏅", "🏆"]),
        ("Play", ["🚀", "🌟", "⚡️", "🌈", "🎯", "🎮", "🎸", "🎨", "📚", "🎤", "🎧", "🎹", "🛹", "🚴", "🏊", "🧩", "🪁", "🧸", "🎲", "🎬", "🎪", "🪄", "👑", "💎"]),
        ("Food", ["🍕", "🌮", "🍔", "🍟", "🍦", "🧁", "🍩", "🍪", "🍎", "🍓", "🍉", "🍇", "🍿", "🥨", "🍣", "🥑"])
    ]

    static var emojis: [String] { groups.flatMap(\.emojis) }

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
    /// FamilyHub-created events have no source.
    var sourceID: UUID?
    var externalID: String?

    static func make(
        title: String,
        startAt: Date,
        endAt: Date? = nil,
        allDay: Bool = false,
        location: String = "",
        notes: String = "",
        memberID: UUID? = nil,
        sourceID: UUID? = nil,
        externalID: String? = nil
    ) -> CalendarEvent {
        CalendarEvent(
            id: UUID(),
            title: title,
            startAt: startAt,
            endAt: endAt,
            allDay: allDay,
            location: location,
            notes: notes,
            memberID: memberID,
            sourceID: sourceID,
            externalID: externalID
        )
    }

    var isImported: Bool { sourceID != nil }
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
    var calendarSources: [CalendarSource]?
    var recipes: [Recipe]?
    var dinners: [DinnerPlan]?
    var shoppingItems: [ShoppingItem]?
}

struct ShoppingItem: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var isChecked: Bool
    var createdAt: Date

    static func make(name: String) -> ShoppingItem {
        ShoppingItem(id: UUID(), name: name, isChecked: false, createdAt: Date())
    }
}

struct Recipe: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var kind: RecipeKind
    var notes: String
    var ingredients: [String]
    var instructions: String
    var imageURL: String
    var catalogID: String

    static func make(
        name: String,
        kind: RecipeKind,
        notes: String = "",
        ingredients: [String] = [],
        instructions: String = "",
        imageURL: String = "",
        catalogID: String = ""
    ) -> Recipe {
        Recipe(
            id: UUID(),
            name: name,
            kind: kind,
            notes: notes,
            ingredients: ingredients,
            instructions: instructions,
            imageURL: imageURL,
            catalogID: catalogID
        )
    }

    enum CodingKeys: String, CodingKey {
        case id, name, kind, notes, ingredients, instructions, imageURL, catalogID
    }

    init(id: UUID, name: String, kind: RecipeKind, notes: String, ingredients: [String], instructions: String, imageURL: String, catalogID: String) {
        self.id = id
        self.name = name
        self.kind = kind
        self.notes = notes
        self.ingredients = ingredients
        self.instructions = instructions
        self.imageURL = imageURL
        self.catalogID = catalogID
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        kind = try c.decode(RecipeKind.self, forKey: .kind)
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        ingredients = try c.decodeIfPresent([String].self, forKey: .ingredients) ?? []
        instructions = try c.decodeIfPresent(String.self, forKey: .instructions) ?? ""
        imageURL = try c.decodeIfPresent(String.self, forKey: .imageURL) ?? ""
        catalogID = try c.decodeIfPresent(String.self, forKey: .catalogID) ?? ""
    }
}

enum RecipeKind: String, Codable, CaseIterable, Identifiable {
    case recipe
    case cooked

    var id: String { rawValue }

    var label: String {
        switch self {
        case .recipe: return "Recipe"
        case .cooked: return "Already made"
        }
    }
}

struct DinnerPlan: Identifiable, Codable, Hashable {
    var id: UUID
    var day: Date
    var recipeID: UUID?
    var note: String
    var placeName: String?
    var placeAddress: String?
    var placePhone: String?
    var placeURL: String?
    var placeKind: String?

    static func make(
        day: Date,
        recipeID: UUID? = nil,
        note: String = "",
        placeName: String? = nil,
        placeAddress: String? = nil,
        placePhone: String? = nil,
        placeURL: String? = nil,
        placeKind: String? = nil
    ) -> DinnerPlan {
        DinnerPlan(
            id: UUID(),
            day: Calendar.current.startOfDay(for: day),
            recipeID: recipeID,
            note: note,
            placeName: placeName,
            placeAddress: placeAddress,
            placePhone: placePhone,
            placeURL: placeURL,
            placeKind: placeKind
        )
    }
}

enum CalendarBrand: String, Codable, CaseIterable, Identifiable {
    case icloud
    case google
    case outlook
    case exchange
    case subscribed
    case ics
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .icloud: return "iCloud"
        case .google: return "Google"
        case .outlook: return "Outlook"
        case .exchange: return "Exchange"
        case .subscribed: return "Subscribed"
        case .ics: return "Calendar link"
        case .other: return "Other"
        }
    }

    var symbol: String {
        switch self {
        case .icloud: return "icloud.fill"
        case .google: return "g.circle.fill"
        case .outlook: return "envelope.fill"
        case .exchange: return "building.2.fill"
        case .subscribed, .ics: return "link"
        case .other: return "calendar"
        }
    }

    var detail: String {
        switch self {
        case .icloud: return "Calendars signed into this iPad with your Apple ID"
        case .google: return "Gmail and Google Calendar accounts on this iPad"
        case .outlook: return "Outlook and Microsoft 365 calendars on this iPad"
        case .exchange: return "Work or school Exchange calendars"
        case .subscribed: return "Calendars you subscribed to in the Calendar app"
        case .ics: return "A secret or public .ics link"
        case .other: return "Any other calendar on this iPad"
        }
    }

    static let featured: [CalendarBrand] = [.icloud, .google, .outlook]

    static func infer(sourceTitle: String, typeName: String) -> CalendarBrand {
        let hay = (sourceTitle + " " + typeName).lowercased()
        if hay.contains("icloud") || hay.contains("mobileme") { return .icloud }
        if hay.contains("google") || hay.contains("gmail") || hay.contains("googlemail") { return .google }
        if hay.contains("outlook") || hay.contains("hotmail") || hay.contains("live.com") || hay.contains("office 365") || hay.contains("microsoft") {
            return .outlook
        }
        if hay.contains("exchange") { return .exchange }
        if hay.contains("subscribed") || hay.contains("caldav") && hay.contains("subscribe") { return .subscribed }
        if typeName.lowercased().contains("exchange") { return .exchange }
        if typeName.lowercased().contains("subscribed") { return .subscribed }
        if typeName.lowercased().contains("caldav") && sourceTitle.lowercased().contains("icloud") { return .icloud }
        return .other
    }
}

struct CalendarSource: Identifiable, Codable, Hashable {
    var id: UUID
    var brand: CalendarBrand
    var title: String
    var account: String
    var isEnabled: Bool
    var eventKitID: String?
    var icsURL: String?
    var memberID: UUID?
    var lastSyncedAt: Date?
    var colorHex: String

    static func make(
        brand: CalendarBrand,
        title: String,
        account: String = "",
        eventKitID: String? = nil,
        icsURL: String? = nil,
        colorHex: String = "3B82F6"
    ) -> CalendarSource {
        CalendarSource(
            id: UUID(),
            brand: brand,
            title: title,
            account: account,
            isEnabled: false,
            eventKitID: eventKitID,
            icsURL: icsURL,
            memberID: nil,
            lastSyncedAt: nil,
            colorHex: colorHex
        )
    }
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

    var symbolName: String { WeatherIcon.symbol(for: code, isDay: true) }
}

struct WeatherNow: Hashable {
    var temp: Int
    var feelsLike: Int
    var code: Int
    var isDay: Bool

    var symbolName: String { WeatherIcon.symbol(for: code, isDay: isDay) }
    var condition: String { WeatherIcon.condition(for: code, isDay: isDay) }
}

struct WeatherHour: Identifiable, Hashable {
    var at: Date
    var temp: Int
    var code: Int
    var precip: Int
    var isDay: Bool

    var id: TimeInterval { at.timeIntervalSince1970 }
    var symbolName: String { WeatherIcon.symbol(for: code, isDay: isDay) }
}

enum WeatherIcon {
    static func symbol(for code: Int, isDay: Bool = true) -> String {
        switch code {
        case 0: return isDay ? "sun.max.fill" : "moon.stars.fill"
        case 1, 2: return isDay ? "cloud.sun.fill" : "cloud.moon.fill"
        case 3: return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82:
            return isDay ? "cloud.rain.fill" : "cloud.moon.rain.fill"
        case 71, 73, 75, 77, 85, 86: return "cloud.snow.fill"
        case 95, 96, 99: return "cloud.bolt.rain.fill"
        default: return isDay ? "cloud.sun.fill" : "cloud.moon.fill"
        }
    }

    static func condition(for code: Int, isDay: Bool = true) -> String {
        switch code {
        case 0: return isDay ? "Clear" : "Clear Night"
        case 1: return isDay ? "Mostly Clear" : "Mostly Clear"
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
        default: return isDay ? "Partly Cloudy" : "Clear Night"
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
