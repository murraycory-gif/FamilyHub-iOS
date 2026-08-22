import Foundation

// MARK: - Enums

enum MemberRole: String, Codable, CaseIterable, Identifiable {
    case parent
    case grandma
    case grandpa
    case aunt
    case uncle
    case cousin
    case friend
    case child
    case dog
    case cat
    case bird

    var id: String { rawValue }

    var label: String {
        switch self {
        case .parent: return "Parent"
        case .grandma: return "Grandma"
        case .grandpa: return "Grandpa"
        case .aunt: return "Aunt"
        case .uncle: return "Uncle"
        case .cousin: return "Cousin"
        case .friend: return "Friend"
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
        case .grandma: return "👵"
        case .grandpa: return "👴"
        case .aunt: return "👩"
        case .uncle: return "👨"
        case .cousin: return "🧒"
        case .friend: return "🤝"
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
    var birthday: Date?
    var email: String
    var phone: String

    enum CodingKeys: String, CodingKey {
        case id, name, role, colorHex, symbol, allowanceBalanceCents, birthday, email, phone
    }

    init(
        id: UUID,
        name: String,
        role: MemberRole,
        colorHex: String,
        symbol: String,
        allowanceBalanceCents: Int,
        birthday: Date? = nil,
        email: String = "",
        phone: String = ""
    ) {
        self.id = id
        self.name = name
        self.role = role
        self.colorHex = colorHex
        self.symbol = symbol
        self.allowanceBalanceCents = allowanceBalanceCents
        self.birthday = birthday
        self.email = email
        self.phone = phone
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        role = try c.decode(MemberRole.self, forKey: .role)
        colorHex = try c.decode(String.self, forKey: .colorHex)
        symbol = try c.decode(String.self, forKey: .symbol)
        allowanceBalanceCents = try c.decodeIfPresent(Int.self, forKey: .allowanceBalanceCents) ?? 0
        birthday = try c.decodeIfPresent(Date.self, forKey: .birthday)
        email = try c.decodeIfPresent(String.self, forKey: .email) ?? ""
        phone = try c.decodeIfPresent(String.self, forKey: .phone) ?? ""
    }

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

    var ageYears: Int? {
        guard let birthday else { return nil }
        return Calendar.current.dateComponents([.year], from: birthday, to: Date()).year
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
    var url: String
    var attendees: [String]
    var organizer: String
    var calendarName: String
    var alertLabel: String
    var recurrenceLabel: String
    var statusLabel: String
    var latitude: Double?
    var longitude: Double?

    enum CodingKeys: String, CodingKey {
        case id, title, startAt, endAt, allDay, location, notes, memberID, sourceID, externalID
        case url, attendees, organizer, calendarName, alertLabel, recurrenceLabel, statusLabel, latitude, longitude
    }

    init(
        id: UUID,
        title: String,
        startAt: Date,
        endAt: Date? = nil,
        allDay: Bool = false,
        location: String = "",
        notes: String = "",
        memberID: UUID? = nil,
        sourceID: UUID? = nil,
        externalID: String? = nil,
        url: String = "",
        attendees: [String] = [],
        organizer: String = "",
        calendarName: String = "",
        alertLabel: String = "",
        recurrenceLabel: String = "",
        statusLabel: String = "",
        latitude: Double? = nil,
        longitude: Double? = nil
    ) {
        self.id = id
        self.title = title
        self.startAt = startAt
        self.endAt = endAt
        self.allDay = allDay
        self.location = location
        self.notes = notes
        self.memberID = memberID
        self.sourceID = sourceID
        self.externalID = externalID
        self.url = url
        self.attendees = attendees
        self.organizer = organizer
        self.calendarName = calendarName
        self.alertLabel = alertLabel
        self.recurrenceLabel = recurrenceLabel
        self.statusLabel = statusLabel
        self.latitude = latitude
        self.longitude = longitude
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        startAt = try c.decode(Date.self, forKey: .startAt)
        endAt = try c.decodeIfPresent(Date.self, forKey: .endAt)
        allDay = try c.decodeIfPresent(Bool.self, forKey: .allDay) ?? false
        location = try c.decodeIfPresent(String.self, forKey: .location) ?? ""
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        memberID = try c.decodeIfPresent(UUID.self, forKey: .memberID)
        sourceID = try c.decodeIfPresent(UUID.self, forKey: .sourceID)
        externalID = try c.decodeIfPresent(String.self, forKey: .externalID)
        url = try c.decodeIfPresent(String.self, forKey: .url) ?? ""
        attendees = try c.decodeIfPresent([String].self, forKey: .attendees) ?? []
        organizer = try c.decodeIfPresent(String.self, forKey: .organizer) ?? ""
        calendarName = try c.decodeIfPresent(String.self, forKey: .calendarName) ?? ""
        alertLabel = try c.decodeIfPresent(String.self, forKey: .alertLabel) ?? ""
        recurrenceLabel = try c.decodeIfPresent(String.self, forKey: .recurrenceLabel) ?? ""
        statusLabel = try c.decodeIfPresent(String.self, forKey: .statusLabel) ?? ""
        latitude = try c.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try c.decodeIfPresent(Double.self, forKey: .longitude)
    }

    static func make(
        title: String,
        startAt: Date,
        endAt: Date? = nil,
        allDay: Bool = false,
        location: String = "",
        notes: String = "",
        memberID: UUID? = nil,
        sourceID: UUID? = nil,
        externalID: String? = nil,
        url: String = "",
        attendees: [String] = [],
        organizer: String = "",
        calendarName: String = "",
        alertLabel: String = "",
        recurrenceLabel: String = "",
        statusLabel: String = "",
        latitude: Double? = nil,
        longitude: Double? = nil
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
            externalID: externalID,
            url: url,
            attendees: attendees,
            organizer: organizer,
            calendarName: calendarName,
            alertLabel: alertLabel,
            recurrenceLabel: recurrenceLabel,
            statusLabel: statusLabel,
            latitude: latitude,
            longitude: longitude
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
    var listName: String
    var sourceID: UUID?
    var externalID: String?

    var isBills: Bool { listName.caseInsensitiveCompare("Bills Due") == .orderedSame }

    enum CodingKeys: String, CodingKey {
        case id, title, dueAt, isCompleted, memberID, listName, sourceID, externalID
    }

    init(
        id: UUID,
        title: String,
        dueAt: Date?,
        isCompleted: Bool,
        memberID: UUID?,
        listName: String = "",
        sourceID: UUID? = nil,
        externalID: String? = nil
    ) {
        self.id = id
        self.title = title
        self.dueAt = dueAt
        self.isCompleted = isCompleted
        self.memberID = memberID
        self.listName = listName
        self.sourceID = sourceID
        self.externalID = externalID
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        dueAt = try c.decodeIfPresent(Date.self, forKey: .dueAt)
        isCompleted = try c.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
        memberID = try c.decodeIfPresent(UUID.self, forKey: .memberID)
        listName = try c.decodeIfPresent(String.self, forKey: .listName) ?? ""
        sourceID = try c.decodeIfPresent(UUID.self, forKey: .sourceID)
        externalID = try c.decodeIfPresent(String.self, forKey: .externalID)
    }

    static func make(title: String, dueAt: Date? = nil, memberID: UUID? = nil) -> ReminderItem {
        ReminderItem(id: UUID(), title: title, dueAt: dueAt, isCompleted: false, memberID: memberID)
    }

    static func bill(from event: CalendarEvent, sourceID: UUID) -> ReminderItem {
        ReminderItem(
            id: UUID(),
            title: event.title,
            dueAt: event.startAt,
            isCompleted: false,
            memberID: nil,
            listName: "Bills Due",
            sourceID: sourceID,
            externalID: event.externalID
        )
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
    var units: HubUnits?
    var ownerID: UUID?
    var joinCode: String?
    var signedInMemberID: UUID?
    var notifyPrefs: HubNotifyPrefs?
}

struct ShoppingItem: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var isChecked: Bool
    var createdAt: Date
    var sourceDay: Date?
    var sourceRecipeID: UUID?

    enum CodingKeys: String, CodingKey {
        case id, name, isChecked, createdAt, sourceDay, sourceRecipeID
    }

    init(id: UUID, name: String, isChecked: Bool, createdAt: Date, sourceDay: Date? = nil, sourceRecipeID: UUID? = nil) {
        self.id = id
        self.name = name
        self.isChecked = isChecked
        self.createdAt = createdAt
        self.sourceDay = sourceDay
        self.sourceRecipeID = sourceRecipeID
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        isChecked = try c.decodeIfPresent(Bool.self, forKey: .isChecked) ?? false
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        sourceDay = try c.decodeIfPresent(Date.self, forKey: .sourceDay)
        sourceRecipeID = try c.decodeIfPresent(UUID.self, forKey: .sourceRecipeID)
    }

    static func make(name: String, sourceDay: Date? = nil, sourceRecipeID: UUID? = nil) -> ShoppingItem {
        ShoppingItem(id: UUID(), name: name, isChecked: false, createdAt: Date(), sourceDay: sourceDay, sourceRecipeID: sourceRecipeID)
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
    case family
    case recipe
    case cooked
    case side

    var id: String { rawValue }

    var label: String {
        switch self {
        case .family: return "Family recipe"
        case .recipe: return "Recipe"
        case .cooked: return "Already made"
        case .side: return "Side"
        }
    }
}

enum CookMethod: String, Codable, CaseIterable, Identifiable, Hashable {
    case oven
    case grill
    case stovetop
    case airFryer
    case deepFry
    case slowCooker
    case instantPot
    case smoker
    case broiler
    case microwave

    var id: String { rawValue }

    var label: String {
        switch self {
        case .oven: return "Oven"
        case .grill: return "Grill"
        case .stovetop: return "Stovetop"
        case .airFryer: return "Air fryer"
        case .deepFry: return "Deep fry"
        case .slowCooker: return "Crock pot"
        case .instantPot: return "Instant pot"
        case .smoker: return "Smoker"
        case .broiler: return "Broiler"
        case .microwave: return "Microwave"
        }
    }

    var symbol: String {
        switch self {
        case .oven: return "square.grid.3x3.fill"
        case .grill: return "flame.fill"
        case .stovetop: return "circle.hexagongrid.fill"
        case .airFryer: return "wind"
        case .deepFry: return "drop.fill"
        case .slowCooker: return "clock.fill"
        case .instantPot: return "gauge"
        case .smoker: return "smoke.fill"
        case .broiler: return "sun.max.fill"
        case .microwave: return "wave.3.right"
        }
    }

    var howTo: String {
        switch self {
        case .oven:
            return "Preheat 400°F. Use a sheet pan or baking dish. Cook until hot through and browned the way you like. Rest a few minutes before serving."
        case .grill:
            return "Preheat the grill to medium-high. Oil the grates. Cook over direct heat, flipping once. Move to indirect heat if it needs more time without burning."
        case .stovetop:
            return "Use a skillet or pot on medium-high. Add a little oil or butter. Cook, turning or stirring, until done. Lower the heat if it starts to scorch."
        case .airFryer:
            return "Preheat the air fryer to 375°F. Don’t crowd the basket. Cook, shaking or flipping halfway, until crisp and hot through."
        case .deepFry:
            return "Heat oil to 350°F. Fry in small batches so the oil stays hot. Drain on a rack or paper towel and salt while it’s hot."
        case .slowCooker:
            return "Add everything to the crock pot. Cook LOW 6–8 hours or HIGH 3–4 hours. Don’t lift the lid until the end."
        case .instantPot:
            return "Add liquid so it can pressurize. Seal and cook on High Pressure. Natural release 10 minutes, then quick release. Keep warm until you serve."
        case .smoker:
            return "Set the smoker to 225–250°F. Use a mild wood. Cook low and slow until tender. Rest before you slice or pull."
        case .broiler:
            return "Move the rack 6 inches from the broiler. Preheat on high. Broil, watching close, and flip once until browned and done."
        case .microwave:
            return "Use a microwave-safe dish. Cover loosely. Cook in short bursts, stirring between, until hot. Let it stand 1 minute."
        }
    }

    static func suggested(name: String, instructions: String = "") -> CookMethod {
        let text = (name + " " + instructions).lowercased()
        if text.contains("salad") || text.contains("slaw") || text.contains("sandwich") { return .stovetop }
        if text.contains("grill") || text.contains("burger") || text.contains("steak") { return .grill }
        if text.contains("smoke") || text.contains("brisket") { return .smoker }
        if text.contains("crock") || text.contains("slow cook") { return .slowCooker }
        if text.contains("air fry") { return .airFryer }
        if text.contains("deep fry") || text.contains("fried") { return .deepFry }
        if text.contains("skillet") || text.contains("saute") || text.contains("boil") { return .stovetop }
        if text.contains("broil") { return .broiler }
        return .oven
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
    var placeLatitude: Double?
    var placeLongitude: Double?
    var sideRecipeID: UUID?
    var servings: Int
    var cookMethod: String?
    var sideCookMethod: String?

    enum CodingKeys: String, CodingKey {
        case id, day, recipeID, note, placeName, placeAddress, placePhone, placeURL, placeKind, placeLatitude, placeLongitude, sideRecipeID, servings, cookMethod, sideCookMethod
    }

    init(
        id: UUID,
        day: Date,
        recipeID: UUID?,
        note: String,
        placeName: String?,
        placeAddress: String?,
        placePhone: String?,
        placeURL: String?,
        placeKind: String?,
        placeLatitude: Double? = nil,
        placeLongitude: Double? = nil,
        sideRecipeID: UUID? = nil,
        servings: Int = 4,
        cookMethod: String? = nil,
        sideCookMethod: String? = nil
    ) {
        self.id = id
        self.day = day
        self.recipeID = recipeID
        self.note = note
        self.placeName = placeName
        self.placeAddress = placeAddress
        self.placePhone = placePhone
        self.placeURL = placeURL
        self.placeKind = placeKind
        self.placeLatitude = placeLatitude
        self.placeLongitude = placeLongitude
        self.sideRecipeID = sideRecipeID
        self.servings = max(1, min(20, servings))
        self.cookMethod = cookMethod
        self.sideCookMethod = sideCookMethod
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        day = try c.decode(Date.self, forKey: .day)
        recipeID = try c.decodeIfPresent(UUID.self, forKey: .recipeID)
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
        placeName = try c.decodeIfPresent(String.self, forKey: .placeName)
        placeAddress = try c.decodeIfPresent(String.self, forKey: .placeAddress)
        placePhone = try c.decodeIfPresent(String.self, forKey: .placePhone)
        placeURL = try c.decodeIfPresent(String.self, forKey: .placeURL)
        placeKind = try c.decodeIfPresent(String.self, forKey: .placeKind)
        placeLatitude = try c.decodeIfPresent(Double.self, forKey: .placeLatitude)
        placeLongitude = try c.decodeIfPresent(Double.self, forKey: .placeLongitude)
        sideRecipeID = try c.decodeIfPresent(UUID.self, forKey: .sideRecipeID)
        servings = try c.decodeIfPresent(Int.self, forKey: .servings) ?? 4
        cookMethod = try c.decodeIfPresent(String.self, forKey: .cookMethod)
        sideCookMethod = try c.decodeIfPresent(String.self, forKey: .sideCookMethod)
    }

    static func make(
        day: Date,
        recipeID: UUID? = nil,
        note: String = "",
        placeName: String? = nil,
        placeAddress: String? = nil,
        placePhone: String? = nil,
        placeURL: String? = nil,
        placeKind: String? = nil,
        placeLatitude: Double? = nil,
        placeLongitude: Double? = nil,
        sideRecipeID: UUID? = nil,
        servings: Int = 4,
        cookMethod: String? = nil,
        sideCookMethod: String? = nil
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
            placeKind: placeKind,
            placeLatitude: placeLatitude,
            placeLongitude: placeLongitude,
            sideRecipeID: sideRecipeID,
            servings: servings,
            cookMethod: cookMethod,
            sideCookMethod: sideCookMethod
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

enum CalendarHubUse: String, Codable, CaseIterable, Identifiable {
    case familyCalendar
    case billsDue

    var id: String { rawValue }

    var label: String {
        switch self {
        case .familyCalendar: return "Family calendar"
        case .billsDue: return "Bills Due (reminders)"
        }
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
    var use: CalendarHubUse
    var useChosen: Bool

    init(
        id: UUID,
        brand: CalendarBrand,
        title: String,
        account: String,
        isEnabled: Bool,
        eventKitID: String?,
        icsURL: String?,
        memberID: UUID?,
        lastSyncedAt: Date?,
        colorHex: String,
        use: CalendarHubUse,
        useChosen: Bool
    ) {
        self.id = id
        self.brand = brand
        self.title = title
        self.account = account
        self.isEnabled = isEnabled
        self.eventKitID = eventKitID
        self.icsURL = icsURL
        self.memberID = memberID
        self.lastSyncedAt = lastSyncedAt
        self.colorHex = colorHex
        self.use = use
        self.useChosen = useChosen
    }

    enum CodingKeys: String, CodingKey {
        case id, brand, title, account, isEnabled, eventKitID, icsURL, memberID, lastSyncedAt, colorHex, use, useChosen
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        brand = try c.decode(CalendarBrand.self, forKey: .brand)
        title = try c.decode(String.self, forKey: .title)
        account = try c.decodeIfPresent(String.self, forKey: .account) ?? ""
        isEnabled = try c.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? false
        eventKitID = try c.decodeIfPresent(String.self, forKey: .eventKitID)
        icsURL = try c.decodeIfPresent(String.self, forKey: .icsURL)
        memberID = try c.decodeIfPresent(UUID.self, forKey: .memberID)
        lastSyncedAt = try c.decodeIfPresent(Date.self, forKey: .lastSyncedAt)
        colorHex = try c.decodeIfPresent(String.self, forKey: .colorHex) ?? "3B82F6"
        use = try c.decodeIfPresent(CalendarHubUse.self, forKey: .use) ?? (Self.looksLikeBills(title) ? .billsDue : .familyCalendar)
        useChosen = try c.decodeIfPresent(Bool.self, forKey: .useChosen) ?? false
    }

    static func looksLikeBills(_ title: String) -> Bool {
        let hay = title.lowercased()
        let keys = ["bill", "bills", "utilities", "utility", "payments", "payment", "invoice", "invoices"]
        return keys.contains(where: { hay.contains($0) })
    }

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
            colorHex: colorHex,
            use: looksLikeBills(title) ? .billsDue : .familyCalendar,
            useChosen: false
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

struct HubUnits: Codable, Equatable {
    var temperature: TemperatureUnit
    var wind: WindUnit
    var precipitation: PrecipUnit
    var distance: DistanceUnit
    var speed: SpeedUnit
    var weight: WeightUnit
    var volume: VolumeUnit
    var length: LengthUnit
    var time: TimeFormatUnit

    static let us = HubUnits(
        temperature: .fahrenheit,
        wind: .mph,
        precipitation: .inch,
        distance: .miles,
        speed: .mph,
        weight: .pounds,
        volume: .us,
        length: .inches,
        time: .twelve
    )

    static let metric = HubUnits(
        temperature: .celsius,
        wind: .kmh,
        precipitation: .mm,
        distance: .kilometers,
        speed: .kmh,
        weight: .kilograms,
        volume: .metric,
        length: .centimeters,
        time: .twentyFour
    )
}

enum TemperatureUnit: String, Codable, CaseIterable, Identifiable {
    case fahrenheit, celsius
    var id: String { rawValue }
    var label: String { self == .fahrenheit ? "°F" : "°C" }
    var name: String { self == .fahrenheit ? "Fahrenheit" : "Celsius" }
    var api: String { rawValue }
}

enum WindUnit: String, Codable, CaseIterable, Identifiable {
    case mph, kmh, ms, kn
    var id: String { rawValue }
    var label: String {
        switch self {
        case .mph: return "mph"
        case .kmh: return "km/h"
        case .ms: return "m/s"
        case .kn: return "knots"
        }
    }
    var name: String { label }
}

enum PrecipUnit: String, Codable, CaseIterable, Identifiable {
    case inch, mm
    var id: String { rawValue }
    var label: String { self == .inch ? "in" : "mm" }
    var name: String { self == .inch ? "Inches" : "Millimeters" }
    var api: String { rawValue }
}

enum DistanceUnit: String, Codable, CaseIterable, Identifiable {
    case miles, kilometers
    var id: String { rawValue }
    var label: String { self == .miles ? "mi" : "km" }
    var name: String { self == .miles ? "Miles" : "Kilometers" }
}

enum SpeedUnit: String, Codable, CaseIterable, Identifiable {
    case mph, kmh
    var id: String { rawValue }
    var label: String { self == .mph ? "mph" : "km/h" }
    var name: String { self == .mph ? "Miles per hour" : "Kilometers per hour" }
}

enum WeightUnit: String, Codable, CaseIterable, Identifiable {
    case pounds, kilograms
    var id: String { rawValue }
    var label: String { self == .pounds ? "lb" : "kg" }
    var name: String { self == .pounds ? "Pounds" : "Kilograms" }
}

enum VolumeUnit: String, Codable, CaseIterable, Identifiable {
    case us, metric
    var id: String { rawValue }
    var label: String { self == .us ? "cups" : "mL" }
    var name: String { self == .us ? "US cups / fl oz" : "Milliliters / liters" }
}

enum LengthUnit: String, Codable, CaseIterable, Identifiable {
    case inches, centimeters
    var id: String { rawValue }
    var label: String { self == .inches ? "in" : "cm" }
    var name: String { self == .inches ? "Inches / feet" : "Centimeters / meters" }
}

enum TimeFormatUnit: String, Codable, CaseIterable, Identifiable {
    case twelve, twentyFour
    var id: String { rawValue }
    var label: String { self == .twelve ? "12h" : "24h" }
    var name: String { self == .twelve ? "12-hour" : "24-hour" }
}

struct HubNotifyPrefs: Codable, Equatable {
    var morningBrief: Bool
    var eventPings: Bool
    var dinnerPing: Bool
    var chorePing: Bool
    var shoppingPing: Bool
    var billsPing: Bool

    enum CodingKeys: String, CodingKey {
        case morningBrief, eventPings, dinnerPing, chorePing, shoppingPing, billsPing
    }

    init(
        morningBrief: Bool,
        eventPings: Bool,
        dinnerPing: Bool,
        chorePing: Bool,
        shoppingPing: Bool,
        billsPing: Bool = false
    ) {
        self.morningBrief = morningBrief
        self.eventPings = eventPings
        self.dinnerPing = dinnerPing
        self.chorePing = chorePing
        self.shoppingPing = shoppingPing
        self.billsPing = billsPing
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        morningBrief = try c.decodeIfPresent(Bool.self, forKey: .morningBrief) ?? false
        eventPings = try c.decodeIfPresent(Bool.self, forKey: .eventPings) ?? false
        dinnerPing = try c.decodeIfPresent(Bool.self, forKey: .dinnerPing) ?? false
        chorePing = try c.decodeIfPresent(Bool.self, forKey: .chorePing) ?? false
        shoppingPing = try c.decodeIfPresent(Bool.self, forKey: .shoppingPing) ?? false
        billsPing = try c.decodeIfPresent(Bool.self, forKey: .billsPing) ?? false
    }

    static let off = HubNotifyPrefs(
        morningBrief: false,
        eventPings: false,
        dinnerPing: false,
        chorePing: false,
        shoppingPing: false,
        billsPing: false
    )

    var anyOn: Bool {
        morningBrief || eventPings || dinnerPing || chorePing || shoppingPing || billsPing
    }
}

struct HubCoachStep: Identifiable {
    let id: Int
    let title: String
    let detail: String
    let symbol: String
}

struct WeatherDay: Identifiable, Hashable {
    var dateISO: String
    var weekday: String
    var high: Int
    var low: Int
    var code: Int
    var precip: Int
    var uv: Int = 0
    var windMph: Int = 0
    var sunrise: Date? = nil
    var sunset: Date? = nil

    var id: String { dateISO }

    var symbolName: String { WeatherIcon.symbol(for: code, isDay: true) }
}

struct WeatherNow: Hashable {
    var temp: Int
    var feelsLike: Int
    var code: Int
    var isDay: Bool
    var humidity: Int = 0
    var windMph: Int = 0
    var uv: Int = 0
    var precip: Int = 0

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
