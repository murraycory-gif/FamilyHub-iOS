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
    @Published private(set) var weatherFollowsMe: Bool
    @Published private(set) var units: HubUnits
    @Published private(set) var hubWidgets: [HubWidget]
    @Published private(set) var calendarSources: [CalendarSource]
    @Published private(set) var recipes: [Recipe]
    @Published private(set) var dinners: [DinnerPlan]
    @Published private(set) var shoppingItems: [ShoppingItem]
    @Published private(set) var flights: [TrackedFlight]
    @Published private(set) var packages: [TrackedPackage]
    @Published private(set) var ownerID: UUID?
    @Published private(set) var joinCode: String
    @Published private(set) var signedInMemberID: UUID?
    @Published private(set) var notifyPrefs: HubNotifyPrefs
    @Published var errorMessage: String?
    @Published private(set) var familyPhotoData: Data?
    @Published private(set) var memberPhotos: [UUID: Data] = [:]

    private let fileManager: FileManager
    private let snapshotURL: URL
    private var familyPhotoURL: URL { snapshotURL.deletingLastPathComponent().appendingPathComponent("family-photo.jpg") }
    private var memberPhotoFolder: URL { snapshotURL.deletingLastPathComponent().appendingPathComponent("member-photos", isDirectory: true) }

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
        weatherFollowsMe = true
        units = .us
        hubWidgets = HubWidget.defaultSet
        calendarSources = []
        recipes = []
        dinners = []
        shoppingItems = []
        flights = []
        packages = []
        ownerID = nil
        joinCode = Self.makeJoinCode()
        signedInMemberID = nil
        notifyPrefs = .off
        familyPhotoData = nil
        loadOrSeed()
        familyPhotoData = try? Data(contentsOf: familyPhotoURL)
        loadMemberPhotos()
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
        if let name = plan.placeName, !name.isEmpty { return name }
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

    func setDinner(on day: Date, recipeID: UUID?, note: String = "", servings: Int = 4, cookMethod: CookMethod? = nil) {
        upsertDinner(
            on: day,
            recipeID: recipeID,
            note: note,
            placeName: nil,
            placeAddress: nil,
            placePhone: nil,
            placeURL: nil,
            placeKind: nil,
            servings: servings,
            cookMethod: cookMethod?.rawValue
        )
    }

    func setDinnerPlace(
        on day: Date,
        name: String,
        address: String,
        phone: String,
        url: String,
        kind: String,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) {
        upsertDinner(
            on: day,
            recipeID: nil,
            note: PlaceMode(rawValue: kind)?.title ?? "Eating out",
            placeName: name,
            placeAddress: address,
            placePhone: phone,
            placeURL: url,
            placeKind: kind,
            placeLatitude: latitude,
            placeLongitude: longitude
        )
    }

    private func upsertDinner(
        on day: Date,
        recipeID: UUID?,
        note: String,
        placeName: String?,
        placeAddress: String?,
        placePhone: String?,
        placeURL: String?,
        placeKind: String?,
        placeLatitude: Double? = nil,
        placeLongitude: Double? = nil,
        servings: Int = 4,
        cookMethod: String? = nil
    ) {
        let start = Calendar.current.startOfDay(for: day)
        let people = max(1, min(20, servings))
        if let idx = dinners.firstIndex(where: {
            guard let range = CalendarMath.dayRange(start) else { return false }
            return CalendarMath.occurs($0.day, in: range)
        }) {
            removeDinnerShopping(on: start)
            dinners[idx].recipeID = recipeID
            dinners[idx].note = note
            dinners[idx].placeName = placeName
            dinners[idx].placeAddress = placeAddress
            dinners[idx].placePhone = placePhone
            dinners[idx].placeURL = placeURL
            dinners[idx].placeKind = placeKind
            dinners[idx].placeLatitude = placeLatitude
            dinners[idx].placeLongitude = placeLongitude
            dinners[idx].sideRecipeID = nil
            dinners[idx].servings = people
            dinners[idx].cookMethod = cookMethod
            dinners[idx].sideCookMethod = nil
        } else {
            dinners.append(.make(
                day: start,
                recipeID: recipeID,
                note: note,
                placeName: placeName,
                placeAddress: placeAddress,
                placePhone: placePhone,
                placeURL: placeURL,
                placeKind: placeKind,
                placeLatitude: placeLatitude,
                placeLongitude: placeLongitude,
                servings: people,
                cookMethod: cookMethod
            ))
        }
        persist()
    }

    func setDinnerSide(on day: Date, recipeID: UUID?, cookMethod: CookMethod? = nil) {
        let start = Calendar.current.startOfDay(for: day)
        guard let idx = dinners.firstIndex(where: { Calendar.current.isDate($0.day, inSameDayAs: start) }) else { return }
        if let old = dinners[idx].sideRecipeID {
            removeDinnerShopping(on: start, recipeID: old)
        }
        dinners[idx].sideRecipeID = recipeID
        dinners[idx].sideCookMethod = cookMethod?.rawValue
        persist()
    }

    func dinnerSide(on day: Date) -> Recipe? {
        dinner(on: day).flatMap(\.sideRecipeID).flatMap(recipe(id:))
    }

    func dinnerCookMethod(on day: Date, side: Bool = false) -> CookMethod? {
        guard let plan = dinner(on: day) else { return nil }
        let raw = side ? plan.sideCookMethod : plan.cookMethod
        return raw.flatMap(CookMethod.init(rawValue:))
    }

    func setDinnerCookMethod(on day: Date, method: CookMethod, side: Bool = false) {
        let start = Calendar.current.startOfDay(for: day)
        guard let idx = dinners.firstIndex(where: { Calendar.current.isDate($0.day, inSameDayAs: start) }) else { return }
        if side {
            dinners[idx].sideCookMethod = method.rawValue
        } else {
            dinners[idx].cookMethod = method.rawValue
        }
        persist()
    }

    func clearDinner(on day: Date) {
        let start = Calendar.current.startOfDay(for: day)
        removeDinnerShopping(on: start)
        dinners.removeAll { Calendar.current.isDate($0.day, inSameDayAs: start) }
        persist()
    }

    func removeDinnerShopping(on day: Date, recipeID: UUID? = nil) {
        let start = Calendar.current.startOfDay(for: day)
        let plan = dinner(on: start)
        let recipeIDs: Set<UUID> = {
            if let recipeID { return [recipeID] }
            return Set([plan?.recipeID, plan?.sideRecipeID].compactMap { $0 })
        }()
        var names = Set<String>()
        let servings = plan?.servings ?? 4
        for id in recipeIDs {
            guard let recipe = recipe(id: id) else { continue }
            for line in recipe.ingredients {
                names.insert(Self.shopKey(line))
            }
            for line in IngredientScale.lines(recipe.ingredients, servings: servings) {
                names.insert(Self.shopKey(line))
            }
        }
        shoppingItems.removeAll { item in
            if let rid = item.sourceRecipeID, recipeIDs.contains(rid) { return true }
            if let source = item.sourceDay, Calendar.current.isDate(source, inSameDayAs: start) { return true }
            if item.sourceDay == nil, names.contains(Self.shopKey(item.name)) { return true }
            return false
        }
    }

    private static func shopKey(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
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
            .sorted {
                let a = $0.dueOn.timeIntervalSince1970
                let b = $1.dueOn.timeIntervalSince1970
                return (a.isFinite ? a : 0) < (b.isFinite ? b : 0)
            }
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
        HubPhoto.forget("family")
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
        } else if member.role == .child {
            let insertAt = members.lastIndex(where: { $0.role == .parent || $0.role == .child }).map { $0 + 1 } ?? members.count
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
        guard members.count > 1 else { return }
        members.removeAll { $0.id == id }
        setMemberPhoto(id, data: nil)
        if ownerID == id {
            ownerID = members.first(where: { $0.role == .parent })?.id ?? members.first?.id
        }
        if signedInMemberID == id {
            signedInMemberID = ownerID
        }
        persist()
    }

    func photo(for member: FamilyMember) -> Data? {
        memberPhotos[member.id]
    }

    func setMemberPhoto(_ id: UUID, data: Data?) {
        HubPhoto.forget(id.uuidString)
        if let data, let image = UIImage(data: data) {
            let resized = image.preparingThumbnail(of: CGSize(width: 600, height: 600)) ?? image
            memberPhotos[id] = resized.jpegData(compressionQuality: 0.82)
        } else {
            memberPhotos[id] = nil
        }
        let url = memberPhotoFolder.appendingPathComponent("\(id.uuidString).jpg")
        if let payload = memberPhotos[id] {
            try? fileManager.createDirectory(at: memberPhotoFolder, withIntermediateDirectories: true)
            try? payload.write(to: url, options: [.atomic])
        } else {
            try? fileManager.removeItem(at: url)
        }
    }

    private func loadMemberPhotos() {
        guard let files = try? fileManager.contentsOfDirectory(at: memberPhotoFolder, includingPropertiesForKeys: nil) else { return }
        var loaded: [UUID: Data] = [:]
        for file in files where file.pathExtension.lowercased() == "jpg" {
            if let id = UUID(uuidString: file.deletingPathExtension().lastPathComponent),
               let data = try? Data(contentsOf: file) {
                loaded[id] = data
            }
        }
        memberPhotos = loaded
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

    func setWeatherPlace(_ place: WeatherPlace, followMe: Bool? = nil) {
        weatherPlace = place
        if let followMe { weatherFollowsMe = followMe }
        persist()
    }

    func setWeatherFollowsMe(_ on: Bool) {
        weatherFollowsMe = on
        persist()
    }

    func setUnits(_ units: HubUnits) {
        self.units = units
        persist()
    }

    func setNotifyPrefs(_ prefs: HubNotifyPrefs) {
        notifyPrefs = prefs
        persist()
        HubPinger.shared.refresh(self)
    }

    func setSignedIn(_ id: UUID?) {
        signedInMemberID = id
        persist()
    }

    func setOwner(_ id: UUID) {
        ownerID = id
        if signedInMemberID == nil { signedInMemberID = id }
        persist()
    }

    func refreshJoinCode() {
        joinCode = Self.makeJoinCode()
        persist()
    }

    var isOwnerDevice: Bool {
        signedInMemberID == nil || signedInMemberID == ownerID
    }

    func signedInMember() -> FamilyMember? {
        signedInMemberID.flatMap { member(id: $0) } ?? members.first
    }

    static func makeJoinCode() -> String {
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<6).compactMap { _ in alphabet.randomElement() })
    }

    func addQuickMember(name: String, role: MemberRole, asOwner: Bool = false) -> FamilyMember {
        let colors = ["1D4ED8", "DB2777", "16A34A", "D97706", "7C3AED", "0F766E", "C2410C"]
        let color = colors[members.count % colors.count]
        let person = FamilyMember.make(name: name, role: role, colorHex: color, symbol: role.defaultEmoji)
        addMember(person)
        if asOwner || ownerID == nil {
            ownerID = person.id
            signedInMemberID = person.id
            persist()
        }
        return person
    }

    func addHubWidget(_ kind: HubWidgetKind) {
        guard HubWidgetKind.choosable.contains(kind) else { return }
        guard !hubWidgets.contains(where: { $0.kind == kind }) else { return }
        hubWidgets.append(.make(kind))
        persist()
    }

    func setHubWidgets(_ kinds: [HubWidgetKind]) {
        hubWidgets = kinds.filter { HubWidgetKind.choosable.contains($0) }.map(HubWidget.make)
        if hubWidgets.isEmpty { hubWidgets = HubWidget.defaultSet }
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
        HubWidgetKind.choosable.filter { kind in
            !hubWidgets.contains(where: { $0.kind == kind })
        }
    }

    func addFlight(_ flight: TrackedFlight) {
        flights.append(flight)
        persist()
    }

    func removeFlight(_ id: UUID) {
        flights.removeAll { $0.id == id }
        persist()
    }

    func addPackage(_ package: TrackedPackage) {
        packages.insert(package, at: 0)
        persist()
    }

    func updatePackage(_ package: TrackedPackage) {
        if let index = packages.firstIndex(where: { $0.id == package.id }) {
            packages[index] = package
            persist()
        }
    }

    func removePackage(_ id: UUID) {
        packages.removeAll { $0.id == id }
        persist()
    }

    // MARK: Calendar sources

    func upsertCalendarSources(_ discovered: [DiscoveredCalendar]) {
        reconcileCalendarSources(discovered)
    }

    func reconcileCalendarSources(_ discovered: [DiscoveredCalendar]) {
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
            if let idx = calendarSources.firstIndex(where: { $0.eventKitID == item.eventKitID }),
               !calendarSources[idx].useChosen,
               CalendarSource.looksLikeBills(calendarSources[idx].title) {
                calendarSources[idx].use = .billsDue
            }
        }
        let liveIDs = Set(discovered.map(\.eventKitID))
        let stale = calendarSources.filter { source in
            guard let eventKitID = source.eventKitID else { return false }
            return !liveIDs.contains(eventKitID)
        }
        for source in stale {
            events.removeAll { $0.sourceID == source.id }
            reminders.removeAll { $0.sourceID == source.id }
            calendarSources.removeAll { $0.id == source.id }
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
            reminders.removeAll { $0.sourceID == id }
        }
        persist()
    }

    func setBillsCalendar(_ id: UUID?) {
        for i in calendarSources.indices {
            let sourceID = calendarSources[i].id
            if sourceID == id {
                calendarSources[i].use = .billsDue
                calendarSources[i].useChosen = true
                calendarSources[i].isEnabled = true
                events.removeAll { $0.sourceID == sourceID }
            } else if calendarSources[i].use == .billsDue {
                calendarSources[i].use = .familyCalendar
                calendarSources[i].useChosen = true
                reminders.removeAll { $0.sourceID == sourceID }
            }
        }
        persist()
    }

    func setSourceUse(_ id: UUID, use: CalendarHubUse) {
        guard let idx = calendarSources.firstIndex(where: { $0.id == id }) else { return }
        calendarSources[idx].use = use
        calendarSources[idx].useChosen = true
        if use == .billsDue {
            events.removeAll { $0.sourceID == id }
        } else {
            reminders.removeAll { $0.sourceID == id }
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
        reminders.removeAll { $0.sourceID == id }
        persist()
    }

    func replaceImportedReminders(sourceID: UUID, with incoming: [ReminderItem]) {
        let keptComplete = Set(reminders.filter { $0.sourceID == sourceID && $0.isCompleted }.compactMap(\.externalID))
        reminders.removeAll { $0.sourceID == sourceID }
        var next = incoming
        for i in next.indices {
            if let ext = next[i].externalID, keptComplete.contains(ext) {
                next[i].isCompleted = true
            }
        }
        reminders.append(contentsOf: next)
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

    // MARK: Shopping

    func addShoppingItem(_ name: String, fromDinner day: Date? = nil, recipeID: UUID? = nil) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        shoppingItems.insert(.make(name: trimmed, sourceDay: day.map { Calendar.current.startOfDay(for: $0) }, sourceRecipeID: recipeID), at: 0)
        persist()
    }

    func toggleShoppingItem(_ id: UUID) {
        guard let idx = shoppingItems.firstIndex(where: { $0.id == id }) else { return }
        shoppingItems[idx].isChecked.toggle()
        persist()
    }

    func deleteShoppingItem(_ id: UUID) {
        shoppingItems.removeAll { $0.id == id }
        persist()
    }

    func clearCheckedShopping() {
        shoppingItems.removeAll { $0.isChecked }
        persist()
    }

    func clearAllShopping() {
        shoppingItems.removeAll()
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
        weatherFollowsMe = snapshot.weatherFollowsMe ?? true
        units = snapshot.units ?? .us
        let widgets = snapshot.hubWidgets ?? []
        hubWidgets = HubWidget.migrated(widgets)
        calendarSources = snapshot.calendarSources ?? []
        recipes = snapshot.recipes ?? SampleFamily.starterRecipes
        dinners = snapshot.dinners ?? []
        shoppingItems = snapshot.shoppingItems ?? []
        flights = snapshot.flights ?? []
        packages = snapshot.packages ?? []
        ownerID = snapshot.ownerID ?? snapshot.members.first(where: { $0.role == .parent })?.id
        joinCode = (snapshot.joinCode?.isEmpty == false) ? (snapshot.joinCode ?? Self.makeJoinCode()) : Self.makeJoinCode()
        signedInMemberID = snapshot.signedInMemberID ?? ownerID
        notifyPrefs = snapshot.notifyPrefs ?? .off
        if snapshot.joinCode == nil {
            persist()
        }
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
            weatherFollowsMe: weatherFollowsMe,
            hubWidgets: hubWidgets,
            flights: flights,
            packages: packages,
            calendarSources: calendarSources,
            recipes: recipes,
            dinners: dinners,
            shoppingItems: shoppingItems,
            units: units,
            ownerID: ownerID,
            joinCode: joinCode,
            signedInMemberID: signedInMemberID,
            notifyPrefs: notifyPrefs
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
