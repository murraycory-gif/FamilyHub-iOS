import Foundation
import UIKit

@MainActor
final class HubStore: ObservableObject {
    @Published private(set) var householdName: String
    @Published private(set) var members: [FamilyMember]
    @Published private(set) var events: [CalendarEvent]
    @Published private(set) var reminders: [ReminderItem]
    @Published private(set) var todos: [TodoItem]
    @Published private(set) var chores: [Chore]
    @Published private(set) var assignments: [ChoreAssignment]
    @Published private(set) var ledger: [LedgerEntry]
    @Published private(set) var weatherPlace: WeatherPlace?
    @Published private(set) var hubWidgets: [HubWidget]
    @Published private(set) var calendarSources: [CalendarSource]
    @Published private(set) var recipes: [Recipe]
    @Published private(set) var dinners: [DinnerPlan]
    @Published var errorMessage: String?
    @Published private(set) var familyPhotoData: Data?

    private let fileManager: FileManager
    private let snapshotURL: URL
    private var familyPhotoURL: URL { snapshotURL.deletingLastPathComponent().appendingPathComponent("family-photo.jpg") }

    init(rootURL: URL? = nil) {
        fileManager = .default
        let root = rootURL ?? Self.defaultRoot()
        if !fileManager.fileExists(atPath: root.path) {
            try? fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        }
        snapshotURL = root.appendingPathComponent("hub.json")
        householdName = "Murray"
        members = []
        events = []
        reminders = []
        todos = []
        chores = []
        assignments = []
        ledger = []
        weatherPlace = WeatherPlace.chicago
        hubWidgets = HubWidget.defaultSet
        calendarSources = []
        recipes = []
        dinners = []
        familyPhotoData = nil
        loadOrSeed()
        familyPhotoData = try? Data(contentsOf: familyPhotoURL)
    }

    private static func defaultRoot() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("FamilyHub", isDirectory: true)
    }

    // MARK: Lookups

    func recipe(id: UUID) -> Recipe? {
        recipes.first { $0.id == id }
    }

    func dinner(on day: Date) -> DinnerPlan? {
        let start = Calendar.current.startOfDay(for: day)
        return dinners.first { Calendar.current.isDate($0.day, inSameDayAs: start) }
    }

    func dinnerTitle(on day: Date) -> String? {
        guard let plan = dinner(on: day) else { return nil }
        if let recipeID = plan.recipeID, let recipe = recipe(id: recipeID) {
            return recipe.name
        }
        if !plan.note.isEmpty { return plan.note }
        return nil
    }

    func addRecipe(_ recipe: Recipe) {
        recipes.insert(recipe, at: 0)
        persist()
    }

    func setDinner(on day: Date, recipeID: UUID?, note: String = "") {
        let start = Calendar.current.startOfDay(for: day)
        if let idx = dinners.firstIndex(where: { Calendar.current.isDate($0.day, inSameDayAs: start) }) {
            dinners[idx].recipeID = recipeID
            dinners[idx].note = note
        } else {
            dinners.append(.make(day: start, recipeID: recipeID, note: note))
        }
        persist()
    }

    func clearDinner(on day: Date) {
        let start = Calendar.current.startOfDay(for: day)
        dinners.removeAll { Calendar.current.isDate($0.day, inSameDayAs: start) }
        persist()
    }

    func member(id: UUID) -> FamilyMember? {
        members.first { $0.id == id }
    }

    func chore(id: UUID) -> Chore? {
        chores.first { $0.id == id }
    }

    func parents() -> [FamilyMember] {
        members.filter { $0.role == .parent }
    }

    func kids() -> [FamilyMember] {
        members.filter { $0.role == .child }
    }

    func events(on day: Date, filter: DayFilter) -> [CalendarEvent] {
        CalendarMath.events(events, on: day, filter: filter)
    }

    func openAssignments(for memberID: UUID? = nil) -> [ChoreAssignment] {
        assignments
            .filter { $0.status == .pending || $0.status == .done }
            .filter { memberID == nil || $0.memberID == memberID }
            .sorted { $0.dueOn < $1.dueOn }
    }

    func openReminders(for memberID: UUID) -> [ReminderItem] {
        reminders.filter { !$0.isCompleted && $0.memberID == memberID }
    }

    func openTodos(for memberID: UUID) -> [TodoItem] {
        todos.filter { !$0.isCompleted && $0.memberID == memberID }
    }

    func todayEvents(for memberID: UUID) -> [CalendarEvent] {
        events(on: Date(), filter: .member(memberID))
    }

    func upcomingItems(limit: Int = 12) -> [UpcomingItem] {
        let now = Date()
        var items: [UpcomingItem] = []
        for event in events where event.startAt >= now.addingTimeInterval(-60 * 30) {
            items.append(.event(event))
        }
        for reminder in reminders where !reminder.isCompleted {
            items.append(.reminder(reminder))
        }
        for todo in todos where !todo.isCompleted {
            items.append(.todo(todo))
        }
        for assignment in assignments where assignment.status == .pending || assignment.status == .done {
            items.append(.chore(assignment))
        }
        return Array(items.sorted { $0.sortDate < $1.sortDate }.prefix(limit))
    }

    // MARK: Members

    func setHouseholdName(_ name: String) {
        householdName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        persist()
    }

    func setFamilyPhoto(_ data: Data?) {
        if let data, let image = UIImage(data: data) {
            let resized = image.preparingThumbnail(of: CGSize(width: 600, height: 600)) ?? image
            familyPhotoData = resized.jpegData(compressionQuality: 0.82)
        } else {
            familyPhotoData = nil
        }
        if let familyPhotoData {
            try? familyPhotoData.write(to: familyPhotoURL, options: [.atomic])
        } else {
            try? fileManager.removeItem(at: familyPhotoURL)
        }
    }

    func addMember(_ member: FamilyMember) {
        if member.role == .parent {
            let insertAt = members.lastIndex(where: { $0.role == .parent }).map { $0 + 1 } ?? 0
            members.insert(member, at: insertAt)
        } else {
            members.append(member)
        }
        persist()
    }

    func updateMember(_ member: FamilyMember) {
        guard let idx = members.firstIndex(where: { $0.id == member.id }) else { return }
        members[idx] = member
        persist()
    }

    func deleteMember(_ id: UUID) {
        members.removeAll { $0.id == id }
        persist()
    }

    /// In-memory only — persist after the finger lifts so the hub does not hitch.
    func moveMemberLive(from: Int, to: Int) {
        guard from != to,
              members.indices.contains(from),
              to >= 0, to <= members.count
        else { return }
        members.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
    }

    func moveMemberLive(id: UUID, before targetID: UUID) {
        guard let from = members.firstIndex(where: { $0.id == id }),
              let to = members.firstIndex(where: { $0.id == targetID }),
              from != to
        else { return }
        moveMemberLive(from: from, to: to)
    }

    func moveMember(id: UUID, before targetID: UUID) {
        moveMemberLive(id: id, before: targetID)
        persist()
    }

    func moveMembers(from offsets: IndexSet, to offset: Int) {
        members.move(fromOffsets: offsets, toOffset: offset)
        persist()
    }

    func persistMembers() {
        persist()
    }

    func setWeatherPlace(_ place: WeatherPlace) {
        weatherPlace = place
        persist()
    }

    func addHubWidget(_ kind: HubWidgetKind) {
        guard !hubWidgets.contains(where: { $0.kind == kind }) else { return }
        hubWidgets.append(.make(kind))
        persist()
    }

    func removeHubWidget(_ id: UUID) {
        hubWidgets.removeAll { $0.id == id }
        persist()
    }

    func moveHubWidget(id: UUID, by delta: Int) {
        guard let from = hubWidgets.firstIndex(where: { $0.id == id }) else { return }
        let to = from + delta
        guard hubWidgets.indices.contains(to) else { return }
        hubWidgets.swapAt(from, to)
        persist()
    }

    func unusedHubWidgets() -> [HubWidgetKind] {
        HubWidgetKind.allCases.filter { kind in
            !hubWidgets.contains(where: { $0.kind == kind })
        }
    }

    // MARK: Calendar sources

    func upsertCalendarSources(_ discovered: [DiscoveredCalendar]) {
        for item in discovered {
            if let idx = calendarSources.firstIndex(where: { $0.eventKitID == item.eventKitID }) {
                calendarSources[idx].title = item.title
                calendarSources[idx].account = item.account
                calendarSources[idx].brand = item.brand
                calendarSources[idx].colorHex = item.colorHex
            } else {
                calendarSources.append(
                    .make(
                        brand: item.brand,
                        title: item.title,
                        account: item.account,
                        eventKitID: item.eventKitID,
                        colorHex: item.colorHex
                    )
                )
            }
        }
        persist()
    }

    func addICSSource(title: String, url: String, brand: CalendarBrand = .ics) {
        var source = CalendarSource.make(brand: brand, title: title.isEmpty ? "Calendar link" : title, icsURL: url)
        source.isEnabled = true
        calendarSources.append(source)
        persist()
    }

    func setSourceEnabled(_ id: UUID, enabled: Bool) {
        guard let idx = calendarSources.firstIndex(where: { $0.id == id }) else { return }
        calendarSources[idx].isEnabled = enabled
        if !enabled {
            events.removeAll { $0.sourceID == id }
        }
        persist()
    }

    func setSourceMember(_ id: UUID, memberID: UUID?) {
        guard let idx = calendarSources.firstIndex(where: { $0.id == id }) else { return }
        calendarSources[idx].memberID = memberID
        for i in events.indices where events[i].sourceID == id {
            events[i].memberID = memberID
        }
        persist()
    }

    func removeCalendarSource(_ id: UUID) {
        calendarSources.removeAll { $0.id == id }
        events.removeAll { $0.sourceID == id }
        persist()
    }

    func replaceImportedEvents(sourceID: UUID, with incoming: [CalendarEvent]) {
        events.removeAll { $0.sourceID == sourceID }
        events.append(contentsOf: incoming)
        events.sort { $0.startAt < $1.startAt }
        persist()
    }

    func markSourceSynced(_ id: UUID) {
        guard let idx = calendarSources.firstIndex(where: { $0.id == id }) else { return }
        calendarSources[idx].lastSyncedAt = Date()
        persist()
    }

    func source(id: UUID) -> CalendarSource? {
        calendarSources.first { $0.id == id }
    }

    // MARK: Events

    func addEvent(_ event: CalendarEvent) {
        events.append(event)
        events.sort { $0.startAt < $1.startAt }
        persist()
    }

    func updateEvent(_ event: CalendarEvent) {
        guard let idx = events.firstIndex(where: { $0.id == event.id }) else { return }
        events[idx] = event
        events.sort { $0.startAt < $1.startAt }
        persist()
    }

    func deleteEvent(_ id: UUID) {
        events.removeAll { $0.id == id }
        persist()
    }

    // MARK: Reminders

    func addReminder(_ item: ReminderItem) {
        reminders.insert(item, at: 0)
        persist()
    }

    func toggleReminder(_ id: UUID) {
        guard let idx = reminders.firstIndex(where: { $0.id == id }) else { return }
        reminders[idx].isCompleted.toggle()
        persist()
    }

    func deleteReminder(_ id: UUID) {
        reminders.removeAll { $0.id == id }
        persist()
    }

    // MARK: To-dos

    func addTodo(_ item: TodoItem) {
        todos.insert(item, at: 0)
        persist()
    }

    func toggleTodo(_ id: UUID) {
        guard let idx = todos.firstIndex(where: { $0.id == id }) else { return }
        todos[idx].isCompleted.toggle()
        persist()
    }

    func deleteTodo(_ id: UUID) {
        todos.removeAll { $0.id == id }
        persist()
    }

    // MARK: Chores

    func addChore(_ chore: Chore) {
        chores.insert(chore, at: 0)
        persist()
    }

    func updateChore(_ chore: Chore) {
        guard let idx = chores.firstIndex(where: { $0.id == chore.id }) else { return }
        chores[idx] = chore
        persist()
    }

    func deleteChore(_ id: UUID) {
        chores.removeAll { $0.id == id }
        assignments.removeAll { $0.choreID == id }
        persist()
    }

    func assign(choreID: UUID, to memberID: UUID, dueOn: Date) {
        assignments.append(.make(choreID: choreID, memberID: memberID, dueOn: dueOn))
        persist()
    }

    func completeAssignment(_ id: UUID) {
        guard let idx = assignments.firstIndex(where: { $0.id == id }) else { return }
        assignments[idx] = ChoreEngine.complete(assignments[idx])
        persist()
    }

    func reopenAssignment(_ id: UUID) {
        guard let idx = assignments.firstIndex(where: { $0.id == id }) else { return }
        assignments[idx] = ChoreEngine.reopen(assignments[idx])
        persist()
    }

    @discardableResult
    func approveAssignment(_ id: UUID) -> Bool {
        guard let idx = assignments.firstIndex(where: { $0.id == id }),
              let chore = chore(id: assignments[idx].choreID),
              let result = ChoreEngine.approve(assignments[idx], chore: chore)
        else { return false }
        assignments[idx] = result.0
        ledger.insert(result.1, at: 0)
        if let memberIdx = members.firstIndex(where: { $0.id == result.1.memberID }) {
            members[memberIdx].allowanceBalanceCents = ChoreEngine.applyLedger(
                balance: members[memberIdx].allowanceBalanceCents,
                entry: result.1
            )
        }
        persist()
        return true
    }

    func markAssignmentPaid(_ id: UUID) {
        guard let idx = assignments.firstIndex(where: { $0.id == id }) else { return }
        assignments[idx] = ChoreEngine.markPaid(assignments[idx])
        persist()
    }

    func addManualAllowance(memberID: UUID, amountCents: Int, reason: String) {
        let entry = LedgerEntry.make(memberID: memberID, amountCents: amountCents, reason: reason)
        ledger.insert(entry, at: 0)
        if let idx = members.firstIndex(where: { $0.id == memberID }) {
            members[idx].allowanceBalanceCents = ChoreEngine.applyLedger(
                balance: members[idx].allowanceBalanceCents,
                entry: entry
            )
        }
        persist()
    }

    // MARK: Persistence

    private func loadOrSeed() {
        guard fileManager.fileExists(atPath: snapshotURL.path) else {
            apply(SampleFamily.snapshot())
            persist()
            return
        }
        do {
            let data = try Data(contentsOf: snapshotURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let decoded = try decoder.decode(HubSnapshot.self, from: data)
            apply(decoded)
        } catch {
            errorMessage = "Could not load FamilyHub data: \(error.localizedDescription)"
            apply(SampleFamily.snapshot())
        }
    }

    private func apply(_ snapshot: HubSnapshot) {
        householdName = snapshot.householdName
        members = snapshot.members
        events = snapshot.events.sorted { $0.startAt < $1.startAt }
        reminders = snapshot.reminders
        todos = snapshot.todos
        chores = snapshot.chores
        assignments = snapshot.assignments
        ledger = snapshot.ledger.sorted { $0.createdAt > $1.createdAt }
        weatherPlace = snapshot.weatherPlace ?? WeatherPlace.chicago
        let widgets = snapshot.hubWidgets ?? []
        hubWidgets = widgets.isEmpty ? HubWidget.defaultSet : widgets
        calendarSources = snapshot.calendarSources ?? []
        recipes = snapshot.recipes ?? SampleFamily.starterRecipes
        dinners = snapshot.dinners ?? []
    }

    private func persist() {
        let snapshot = HubSnapshot(
            householdName: householdName,
            members: members,
            events: events,
            reminders: reminders,
            todos: todos,
            chores: chores,
            assignments: assignments,
            ledger: ledger,
            weatherPlace: weatherPlace,
            hubWidgets: hubWidgets,
            calendarSources: calendarSources,
            recipes: recipes,
            dinners: dinners
        )
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(snapshot)
            try data.write(to: snapshotURL, options: [.atomic])
        } catch {
            errorMessage = "Could not save: \(error.localizedDescription)"
        }
    }
}

enum UpcomingKind {
    case event, reminder, todo, chore
}

struct UpcomingItem: Identifiable {
    let id: UUID
    let kind: UpcomingKind
    let title: String
    let subtitle: String
    let sortDate: Date
    let memberID: UUID?

    static func event(_ event: CalendarEvent) -> UpcomingItem {
        UpcomingItem(
            id: event.id,
            kind: .event,
            title: event.title,
            subtitle: event.location.isEmpty ? "Calendar" : event.location,
            sortDate: event.startAt,
            memberID: event.memberID
        )
    }

    static func reminder(_ item: ReminderItem) -> UpcomingItem {
        UpcomingItem(
            id: item.id,
            kind: .reminder,
            title: item.title,
            subtitle: "Reminder",
            sortDate: item.dueAt ?? Date.distantFuture,
            memberID: item.memberID
        )
    }

    static func todo(_ item: TodoItem) -> UpcomingItem {
        UpcomingItem(
            id: item.id,
            kind: .todo,
            title: item.title,
            subtitle: "To-do",
            sortDate: item.dueAt ?? Date.distantFuture,
            memberID: item.memberID
        )
    }

    static func chore(_ assignment: ChoreAssignment) -> UpcomingItem {
        UpcomingItem(
            id: assignment.id,
            kind: .chore,
            title: "Chore due",
            subtitle: assignment.status.label,
            sortDate: assignment.dueOn,
            memberID: assignment.memberID
        )
    }
}

enum SampleFamily {
    static let starterRecipes: [Recipe] = [
        .make(name: "Tacos", kind: .recipe, notes: "Beef, shells, toppings"),
        .make(name: "Spaghetti", kind: .recipe, notes: "Marinara and garlic bread"),
        .make(name: "Grilled chicken", kind: .cooked),
        .make(name: "Leftovers", kind: .cooked),
        .make(name: "Pizza night", kind: .recipe),
    ]

    static func snapshot(now: Date = Date(), calendar: Calendar = .current) -> HubSnapshot {
        let cory = FamilyMember.make(name: "Cory", role: .parent, colorHex: "163A5F", symbol: "😎")
        let alex = FamilyMember.make(name: "Alex", role: .child, colorHex: "2563EB", symbol: "🏃")
        let sam = FamilyMember.make(name: "Sam", role: .child, colorHex: "EA580C", symbol: "⚽️")

        func day(_ offset: Int, hour: Int, minute: Int = 0) -> Date {
            let start = calendar.startOfDay(for: now)
            let shifted = calendar.date(byAdding: .day, value: offset, to: start) ?? start
            return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: shifted) ?? shifted
        }

        let dishes = Chore.make(title: "Dishes", details: "Load and wipe the counters.", rewardCents: 200, cadence: .daily)
        let trash = Chore.make(title: "Take out trash", details: "Kitchen + bathrooms.", rewardCents: 150, cadence: .weekly)
        let room = Chore.make(title: "Clean bedroom", details: "Floor, bed, desk.", rewardCents: 300, cadence: .weekly)
        let lawn = Chore.make(title: "Mow the lawn", details: "Front and back.", rewardCents: 800, cadence: .weekly)

        let a1 = ChoreAssignment.make(choreID: dishes.id, memberID: alex.id, dueOn: now)
        let a2 = ChoreAssignment.make(choreID: trash.id, memberID: sam.id, dueOn: now)
        let a3 = ChoreAssignment.make(choreID: room.id, memberID: alex.id, dueOn: calendar.date(byAdding: .day, value: 2, to: now) ?? now)
        let a4 = ChoreAssignment.make(choreID: lawn.id, memberID: sam.id, dueOn: calendar.date(byAdding: .day, value: 3, to: now) ?? now)

        return HubSnapshot(
            householdName: "Murray",
            members: [cory, alex, sam],
            events: [
                .make(title: "Soccer practice", startAt: day(0, hour: 16, minute: 30), endAt: day(0, hour: 18), location: "Lincoln Park field", memberID: sam.id),
                .make(title: "Family dinner", startAt: day(0, hour: 18, minute: 30), location: "Home"),
                .make(title: "Dentist", startAt: day(1, hour: 10), location: "Oak Street Dental", memberID: alex.id),
                .make(title: "Piano", startAt: day(2, hour: 15, minute: 30), location: "Studio B", memberID: alex.id),
                .make(title: "Game night", startAt: day(5, hour: 19), location: "Home"),
            ],
            reminders: [
                .make(title: "Permission slip for field trip", dueAt: day(1, hour: 8), memberID: alex.id),
                .make(title: "Trash night", dueAt: day(0, hour: 19), memberID: sam.id),
                .make(title: "Pay soccer fees", dueAt: day(4, hour: 12), memberID: cory.id),
            ],
            todos: [
                .make(title: "Grocery run", notes: "Milk, berries, sandwich bread", dueAt: day(0, hour: 17), memberID: cory.id),
                .make(title: "Schedule oil change", dueAt: day(3, hour: 9), memberID: cory.id),
                .make(title: "Pack gym bag", dueAt: day(0, hour: 15), memberID: sam.id),
            ],
            chores: [dishes, trash, room, lawn],
            assignments: [a1, a2, a3, a4],
            ledger: [],
            weatherPlace: .chicago,
            hubWidgets: HubWidget.defaultSet,
            recipes: starterRecipes,
            dinners: [
                .make(day: now, recipeID: starterRecipes.first(where: { $0.name == "Tacos" })?.id),
            ]
        )
    }
}
