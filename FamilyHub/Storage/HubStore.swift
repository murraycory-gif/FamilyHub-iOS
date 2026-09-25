import CloudKit
import CoreLocation
import Foundation
import os
import UIKit
import WidgetKit

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
    @Published private(set) var issuedJoinCodes: [String]
    @Published private(set) var signedInMemberID: UUID?
    @Published private(set) var notifyPrefs: HubNotifyPrefs
    @Published private(set) var whiteboardNote: String
    @Published private(set) var hubWidgetLimit: Int
    @Published private(set) var setupCompleted: Bool
    @Published private(set) var appearance: HubAppearance
    @Published var errorMessage: String?
    @Published private(set) var familyPhotoData: Data?
    @Published private(set) var memberPhotos: [UUID: Data] = [:]
    @Published private(set) var eventComments: [EventComment] = []
    @Published private(set) var circlePlaces: [CirclePlace] = []
    @Published private(set) var placePings: [PlacePing] = []
    @Published private(set) var documents: [HubDocument] = []
    @Published private(set) var custodyHouses: [CustodyHouse] = []
    @Published private(set) var quietHours: [QuietHours] = []
    @Published private(set) var recapPhotos: [RecapPhoto] = []
    @Published private(set) var choreProofs: [ChoreProof] = []

    private let fileManager: FileManager
    private let snapshotURL: URL
    /// A failed decode must not be overwritten by a later save, and must not look like an empty house.
    @Published private(set) var loadFailed = false
    @Published private(set) var loadFailureDetail: String?
    var remote: any HouseholdRemote = HouseholdCloudClient()
    /// False after this device joins someone else's share. Erase then only leaves that share.
    /// Restored from device-role.json so a relaunch does not treat a participant as the owner.
    var ownsPrivateZone = true
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
        issuedJoinCodes = []
        signedInMemberID = nil
        notifyPrefs = .off
        whiteboardNote = ""
        hubWidgetLimit = 4
        setupCompleted = false
        appearance = .system
        familyPhotoData = nil
        loadDeviceRole()
        loadOrSeed()
        roleLoaded = true
        let photoURL = familyPhotoURL
        let folder = memberPhotoFolder
        HubAccess.store = self
        Task { await loadPhotos(photoURL: photoURL, folder: folder) }
        Task { await restoreAccountIfNeeded() }
        LaunchTiming.mark("store ready")
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

    private func dinnerIndex(on day: Date) -> Int? {
        guard let range = CalendarMath.dayRange(day) else { return nil }
        return dinners.firstIndex { CalendarMath.occurs($0.day, in: range) }
    }

    func dinner(on day: Date) -> DinnerPlan? {
        guard let idx = dinnerIndex(on: day) else { return nil }
        return dinners[idx]
    }

    func billsDue(on day: Date) -> [ReminderItem] {
        guard let range = CalendarMath.dayRange(day) else { return [] }
        return reminders.filter {
            $0.isBills && !$0.isCompleted && ($0.dueAt.map { CalendarMath.occurs($0, in: range) } ?? false)
        }
        .sorted { ($0.dueAt ?? .distantFuture) < ($1.dueAt ?? .distantFuture) }
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
        guard let idx = dinnerIndex(on: start) else { return }
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
        guard let idx = dinnerIndex(on: start) else { return }
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
        if let idx = dinnerIndex(on: start) {
            dinners.remove(at: idx)
        }
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
            if let source = item.sourceDay, let range = CalendarMath.dayRange(start), CalendarMath.occurs(source, in: range) { return true }
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

    private func loadPhotos(photoURL: URL, folder: URL) async {
        let started = CFAbsoluteTimeGetCurrent()
        let loaded: (Data?, [UUID: Data]) = await Task.detached(priority: .userInitiated) {
            let family = try? Data(contentsOf: photoURL)
            var photos: [UUID: Data] = [:]
            let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
            for file in files where file.pathExtension.lowercased() == "jpg" {
                if let id = UUID(uuidString: file.deletingPathExtension().lastPathComponent),
                   let data = try? Data(contentsOf: file) {
                    photos[id] = data
                }
            }
            return (family, photos)
        }.value
        familyPhotoData = loaded.0
        memberPhotos = loaded.1
        let ms = Int((CFAbsoluteTimeGetCurrent() - started) * 1000)
        Logger(subsystem: "com.corymurray.FamilyHub", category: "launch").info("photos \(ms, privacy: .public) ms")
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
        var next = prefs
        next.channel = .device
        notifyPrefs = next
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
        let now = Date().timeIntervalSince1970
        var times = (UserDefaults.standard.array(forKey: Self.issueTimesKey) as? [Double] ?? [])
            .filter { now - $0 < 3600 }
        if times.count >= HubJoinCode.maxIssuesPerHour {
            errorMessage = "Too many new codes this hour. Try again later."
            return
        }
        times.append(now)
        UserDefaults.standard.set(times, forKey: Self.issueTimesKey)
        let previous = joinCode
        rememberIssued(previous)
        joinCode = HubJoinCode.make()
        rememberIssued(joinCode)
        persist()
        let retired = previous
        Task { @MainActor in
            let failed = await self.deletePublicCodes([retired])
            if !failed.isEmpty {
                self.errorMessage = "Could not delete the old shared record \(retired). It is still on iCloud."
            }
        }
    }

    func knownShareCodes() -> [String] {
        var codes = issuedJoinCodes
        rememberIssued(joinCode)
        if !codes.contains(joinCode) { codes.append(joinCode) }
        return codes
    }

    /// Owner-triggered only. Deletes every hub-&lt;code&gt; this device has issued, including the current one.
    func removeOldSharedRecords() async -> String {
        let failed = await deletePublicCodes(knownShareCodes(), attempts: 3)
        if failed.isEmpty {
            let count = knownShareCodes().count
            return "Removed \(count) shared record\(count == 1 ? "" : "s"). Publish again if family should rejoin."
        }
        let message = "Could not delete old shared records (\(failed.joined(separator: ", "))). They are still on iCloud."
        errorMessage = message
        return message
    }

    /// Retries transient iCloud errors. Returns the codes that still failed. Never treats a failure as success.
    func deletePublicCodes(_ codes: [String], attempts: Int = 3) async -> [String] {
        var failed: [String] = []
        for code in codes {
            let clean = code.replacingOccurrences(of: " ", with: "").uppercased()
            guard HubJoinCode.isAcceptable(clean) else { continue }
            var removed = false
            for attempt in 0..<max(1, attempts) {
                do {
                    try await remote.deletePublicCode(clean)
                    removed = true
                    break
                } catch {
                    if HouseholdCloud.isForeignPublicRecord(error, participant: !ownsPrivateZone) {
                        removed = true
                        break
                    }
                    let retry = HouseholdCloud.isTransient(error) && attempt < attempts - 1
                    if !retry { break }
                    try? await Task.sleep(for: .milliseconds(50 * (attempt + 1)))
                }
            }
            if !removed { failed.append(clean) }
        }
        return failed
    }

    private func rememberIssued(_ code: String) {
        let clean = HubJoinCode.normalized(code)
        guard HubJoinCode.isAcceptable(clean) else { return }
        if !issuedJoinCodes.contains(clean) { issuedJoinCodes.append(clean) }
    }

    var isOwnerDevice: Bool {
        signedInMemberID == nil || signedInMemberID == ownerID
    }

    func signedInMember() -> FamilyMember? {
        signedInMemberID.flatMap { member(id: $0) } ?? members.first
    }

    static func makeJoinCode() -> String {
        HubJoinCode.make()
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
        guard hubWidgets.count < 4 else { return }
        hubWidgets.append(.make(kind))
        persist()
    }

    func setHubWidget(at index: Int, kind: HubWidgetKind) {
        guard HubWidgetKind.choosable.contains(kind) else { return }
        var kinds = hubWidgets.map(\.kind)
        if kinds.isEmpty { kinds = HubWidget.defaultSet.map(\.kind) }
        while kinds.count <= index && kinds.count < 4 {
            if let extra = unused(in: kinds).first {
                kinds.append(extra)
            } else {
                break
            }
        }
        guard kinds.indices.contains(index) else { return }
        if let other = kinds.firstIndex(of: kind), other != index {
            kinds.swapAt(index, other)
        } else {
            kinds[index] = kind
        }
        setHubWidgets(kinds)
    }

    func addWidgetUnderRight() {
        hubWidgetLimit = 4
        var kinds = hubWidgets.map(\.kind)
        if kinds.isEmpty { kinds = HubWidget.defaultSet.map(\.kind) }
        while kinds.count < 3 {
            if let extra = unused(in: kinds).first { kinds.append(extra) } else { break }
        }
        if kinds.count < 4, let extra = unused(in: kinds).first {
            kinds.append(extra)
        }
        setHubWidgets(kinds)
    }

    func makeRightWidgetBigger() {
        hubWidgetLimit = 3
        var kinds = hubWidgets.map(\.kind)
        if kinds.count > 3 {
            kinds = Array(kinds.prefix(3))
            setHubWidgets(kinds)
        } else {
            persist()
        }
    }

    private func unused(in kinds: [HubWidgetKind]) -> [HubWidgetKind] {
        HubWidgetKind.choosable.filter { kinds.contains($0) == false }
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

    func setWhiteboardNote(_ text: String) {
        whiteboardNote = String(text.prefix(400))
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
        guard !discovered.isEmpty else { return }
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
        let stored = ICSLink.normalize(url)
        var source = CalendarSource.make(brand: brand, title: title.isEmpty ? "Calendar link" : title, icsURL: stored)
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

    func addEventComment(eventID: UUID, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return }
        eventComments.insert(.make(eventID: eventID, memberID: signedInMemberID, text: trimmed), at: 0)
        persist()
    }

    func comments(for eventID: UUID) -> [EventComment] {
        eventComments.filter { $0.eventID == eventID }.sorted { $0.createdAt < $1.createdAt }
    }

    func addCirclePlace(_ place: CirclePlace) {
        circlePlaces.append(place)
        persist()
    }

    func recordPlacePing(placeID: UUID, memberID: UUID, arrived: Bool) {
        placePings.insert(PlacePing(id: UUID(), placeID: placeID, memberID: memberID, arrived: arrived, at: Date()), at: 0)
        persist()
    }

    func addDocument(_ doc: HubDocument) {
        documents.insert(doc, at: 0)
        persist()
    }

    func deleteDocument(_ id: UUID) {
        documents.removeAll { $0.id == id }
        persist()
    }

    func setCustodyHouses(_ houses: [CustodyHouse]) {
        custodyHouses = houses
        persist()
    }

    func house(on day: Date, kidID: UUID? = nil) -> CustodyHouse? {
        let weekday = Calendar.current.component(.weekday, from: day)
        return custodyHouses.first { house in
            house.weekdays.contains(weekday) && (kidID == nil || house.kidIDs.contains(kidID!))
        }
    }

    func setQuietHours(_ rows: [QuietHours]) {
        quietHours = rows
        persist()
    }

    func isQuiet(memberID: UUID, at date: Date = Date()) -> Bool {
        guard let row = quietHours.first(where: { $0.memberID == memberID && $0.enabled }) else { return false }
        let hour = Calendar.current.component(.hour, from: date)
        let minute = Calendar.current.component(.minute, from: date)
        let mins = hour * 60 + minute
        if row.startMinute <= row.endMinute {
            return mins >= row.startMinute && mins < row.endMinute
        }
        return mins >= row.startMinute || mins < row.endMinute
    }

    func addRecap(_ photo: RecapPhoto) {
        recapPhotos.insert(photo, at: 0)
        persist()
    }

    func addChoreProof(assignmentID: UUID, note: String) {
        choreProofs.insert(ChoreProof(id: UUID(), assignmentID: assignmentID, note: note, createdAt: Date()), at: 0)
        persist()
    }

    func addQuickEvent(from text: String, memberID: UUID? = nil) -> CalendarEvent? {
        guard let draft = QuickAdd.parse(text) else { return nil }
        let event = CalendarEvent.make(
            title: draft.title,
            startAt: draft.startAt,
            endAt: draft.allDay ? nil : draft.startAt.addingTimeInterval(3600),
            allDay: draft.allDay,
            location: draft.location,
            memberID: memberID
        )
        addEvent(event)
        return event
    }

    func markBillPaid(_ id: UUID) {
        guard let idx = reminders.firstIndex(where: { $0.id == id }) else { return }
        reminders[idx].isCompleted = true
        persist()
    }

    func addSchoolCalendar(title: String, url: String) {
        addICSSource(title: title.isEmpty ? "School" : title, url: url, brand: .subscribed)
    }

    // MARK: Persistence

    private func loadOrSeed() {
        guard fileManager.fileExists(atPath: snapshotURL.path) else {
            apply(Self.emptySnapshot())
            return
        }
        let started = CFAbsoluteTimeGetCurrent()
        do {
            let data = try Data(contentsOf: snapshotURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let decoded = try decoder.decode(HubSnapshot.self, from: data)
            apply(decoded)
            let ms = Int((CFAbsoluteTimeGetCurrent() - started) * 1000)
            Logger(subsystem: "com.corymurray.FamilyHub", category: "launch").info("hub.json \(data.count, privacy: .public) bytes \(ms, privacy: .public) ms")
        } catch {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let stamp = formatter.string(from: Date()).replacingOccurrences(of: ":", with: "-")
            var backup = snapshotURL.deletingLastPathComponent().appendingPathComponent("corrupt-hub-\(stamp).json")
            if fileManager.fileExists(atPath: backup.path) {
                backup = snapshotURL.deletingLastPathComponent().appendingPathComponent("corrupt-hub-\(stamp)-\(UUID().uuidString).json")
            }
            try? fileManager.copyItem(at: snapshotURL, to: backup)
            try? fileManager.setAttributes([.modificationDate: Date()], ofItemAtPath: backup.path)
            HubFilePrivacy.excludeFromBackup(backup)
            pruneCorruptCopies(keeping: 3, protecting: backup.lastPathComponent)
            loadFailed = true
            loadFailureDetail = "Saved data could not be read. A copy is \(backup.lastPathComponent). The original file was left alone."
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
        recipes = snapshot.recipes ?? []
        dinners = snapshot.dinners ?? []
        shoppingItems = snapshot.shoppingItems ?? []
        flights = snapshot.flights ?? []
        packages = snapshot.packages ?? []
        ownerID = snapshot.ownerID ?? snapshot.members.first(where: { $0.role == .parent })?.id
        if let existing = snapshot.joinCode, HubJoinCode.isAcceptable(existing) {
            joinCode = HubJoinCode.normalized(existing)
        } else if snapshot.joinCode?.isEmpty == false {
            joinCode = snapshot.joinCode ?? HubJoinCode.make()
        } else {
            joinCode = HubJoinCode.make()
        }
        issuedJoinCodes = snapshot.issuedJoinCodes ?? []
        rememberIssued(joinCode)
        signedInMemberID = snapshot.signedInMemberID ?? ownerID
        notifyPrefs = snapshot.notifyPrefs ?? .off
        HubKeychain.deleteTwilio()
        whiteboardNote = snapshot.whiteboardNote ?? ""
        hubWidgetLimit = min(4, max(3, snapshot.hubWidgetLimit ?? 4))
        setupCompleted = snapshot.setupCompleted ?? !snapshot.members.isEmpty
        appearance = snapshot.appearance ?? .system
        eventComments = snapshot.eventComments ?? []
        circlePlaces = snapshot.circlePlaces ?? []
        placePings = snapshot.placePings ?? []
        documents = snapshot.documents ?? []
        custodyHouses = snapshot.custodyHouses ?? []
        quietHours = snapshot.quietHours ?? []
        recapPhotos = snapshot.recapPhotos ?? []
        choreProofs = snapshot.choreProofs ?? []
        let missingCode = snapshot.joinCode == nil
        let missingHistory = !(snapshot.issuedJoinCodes ?? []).contains(joinCode)
        let oldSchema = snapshot.schemaVersion != HubSnapshot.currentSchema
        if missingCode || missingHistory || oldSchema {
            persistNow()
        }
        rememberAccount()
    }

    private func writeSnapshot() {
        guard !loadFailed else { return }
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
            notifyPrefs: notifyPrefs.strippingSecrets(),
            whiteboardNote: whiteboardNote,
            hubWidgetLimit: hubWidgetLimit,
            setupCompleted: setupCompleted,
            appearance: appearance,
            eventComments: eventComments,
            circlePlaces: circlePlaces,
            placePings: placePings,
            documents: documents,
            custodyHouses: custodyHouses,
            quietHours: quietHours,
            recapPhotos: recapPhotos,
            choreProofs: choreProofs,
            schemaVersion: HubSnapshot.currentSchema,
            issuedJoinCodes: issuedJoinCodes
        )
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(snapshot)
            try data.write(to: snapshotURL, options: [.atomic])
            HubFilePrivacy.protectUntilFirstUnlock(snapshotURL)
            writeTimestampedBackup(data)
            rememberAccount()
            scheduleCloudPublish(data)
            publishWidgets()
        } catch {
            errorMessage = "Could not save: \(error.localizedDescription)"
        }
    }

    private var persistTask: Task<Void, Never>?

    private func persist() {
        persistTask?.cancel()
        persistTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            writeSnapshot()
        }
    }

    private func persistNow() {
        persistTask?.cancel()
        writeSnapshot()
        if roleLoaded && writingRole { saveDeviceRole() }
    }

    private func publishWidgets() {
        let day = Date()
        let next = events.filter { $0.startAt > Date() }.sorted { $0.startAt < $1.startAt }.first
        writeWidgetSnapshot(day: day, next: next, travelMinutes: LeaveByETA.fallbackMinutes)
        guard let next, let lat = next.latitude, let lon = next.longitude, let home = weatherPlace else { return }
        let eventID = next.id
        let title = next.title
        let start = next.startAt
        let origin = CLLocationCoordinate2D(latitude: home.latitude, longitude: home.longitude)
        let destination = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        Task { @MainActor in
            let minutes = await LeaveByETA.driveMinutes(from: origin, to: destination) ?? LeaveByETA.fallbackMinutes
            guard events.contains(where: { $0.id == eventID && $0.startAt == start }) else { return }
            writeWidgetSnapshot(day: Date(), next: events.first { $0.id == eventID }, travelMinutes: minutes)
            #if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
            LeaveByLive.publish(title: title, eventID: eventID.uuidString, startAt: start, travelMinutes: minutes)
            #endif
        }
    }

    private func writeWidgetSnapshot(day: Date, next: CalendarEvent?, travelMinutes: Int) {
        let minutes = max(1, travelMinutes)
        WidgetBridge.write(WidgetBridge.Snapshot(
            household: householdName.isEmpty ? "HUB Circle" : householdName,
            agendaTitle: next?.title ?? "Nothing on the calendar",
            agendaWhen: next.map { $0.allDay ? "All day" : Date.hubClock($0.startAt) } ?? "Today",
            dinnerName: dinnerTitle(on: day) ?? "Nothing planned",
            dinnerSide: dinnerSide(on: day)?.name ?? "",
            leaveTitle: next?.title ?? "",
            leaveAt: next.map { $0.startAt.addingTimeInterval(TimeInterval(-minutes * 60)) },
            eventStart: next?.startAt,
            updatedAt: Date()
        ))
        WidgetCenter.shared.reloadAllTimelines()
        #if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
        if let next {
            LeaveByLive.publish(title: next.title, eventID: next.id.uuidString, startAt: next.startAt, travelMinutes: minutes)
        }
        #endif
    }

    private var cloudPublishTask: Task<Void, Never>?

    private func scheduleCloudPublish(_ data: Data) {
        guard !Self.runningUnitTests else { return }
        guard signedInMemberID != nil, signedInMemberID == ownerID else { return }
        cloudPublishTask?.cancel()
        cloudPublishTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled else { return }
            do {
                try await HouseholdCloud.publish(data: data)
                if let note = await self?.retirePublicRecordsOnce() {
                    await MainActor.run { self?.errorMessage = note }
                }
            } catch {
                await MainActor.run { self?.errorMessage = error.localizedDescription }
            }
        }
    }

    private static let publicCleanupKey = "familyhub.publicHubCleanup.v1"

    /// After the private-zone save succeeds, delete old public hub-<code> records one time.
    @discardableResult
    func retirePublicRecordsOnce() async -> String? {
        guard !UserDefaults.standard.bool(forKey: Self.publicCleanupKey) else { return nil }
        let failed = await deletePublicCodes(knownShareCodes(), attempts: 3)
        if !failed.isEmpty {
            let message = "Could not delete old shared records (\(failed.joined(separator: ", "))). They are still on iCloud."
            errorMessage = message
            return message
        }
        UserDefaults.standard.set(true, forKey: Self.publicCleanupKey)
        return nil
    }

    func currentHouseholdData() -> Data? {
        guard let raw = try? Data(contentsOf: snapshotURL) else { return nil }
        return raw
    }

    func publishHouseholdNow() async -> String? {
        guard let data = currentHouseholdData() else { return "Nothing to share yet." }
        do {
            try await HouseholdCloud.publish(data: data)
            return await retirePublicRecordsOnce()
        } catch {
            return error.localizedDescription
        }
    }

    func prepareHouseholdShare() async throws -> CKShare {
        guard let data = currentHouseholdData() else { throw HouseholdCloudError.missingHouse }
        let title = householdName.isEmpty ? "HUB Circle" : householdName
        let share = try await HouseholdCloud.makeShare(data: data, title: title)
        ownsPrivateZone = true
        saveDeviceRole()
        if let note = await retirePublicRecordsOnce() {
            errorMessage = note
        }
        return share
    }

    func joinSharedHousehold() async throws {
        guard !Self.runningUnitTests, remote is HouseholdCloudClient else {
            throw HouseholdCloudError.missingHouse
        }
        let fetched = try await HouseholdCloud.fetchShared()
        let data = fetched.data
        ownsPrivateZone = fetched.ownedHere
        saveDeviceRole()
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let snapshot = try decoder.decode(HubSnapshot.self, from: data)
        apply(snapshot)
        signedInMemberID = nil
        persistNow()
    }

    func markSetupComplete() {
        setupCompleted = true
        persistNow()
    }

    func setAppearance(_ value: HubAppearance) {
        appearance = value
        persist()
    }

    private func rememberAccount() {
        guard setupCompleted || !members.isEmpty else { return }
        UserDefaults.standard.set(joinCode, forKey: Self.accountKey)
        NSUbiquitousKeyValueStore.default.set(joinCode, forKey: Self.accountKey)
        NSUbiquitousKeyValueStore.default.synchronize()
    }

    static let accountKey = "familyhub.account.join"
    static let issueTimesKey = "familyhub.join.issueTimes"
    #if DEBUG
    static var runningUnitTests: Bool {
        let env = ProcessInfo.processInfo.environment
        return env["XCTestConfigurationFilePath"] != nil || env["XCTestBundlePath"] != nil
    }
    #else
    static var runningUnitTests: Bool { false }
    #endif

    func restoreAccountIfNeeded() async {
        guard !Self.runningUnitTests else { return }
        guard !loadFailed else { return }
        if setupCompleted || !members.isEmpty {
            rememberAccount()
            return
        }
        let saved = NSUbiquitousKeyValueStore.default.string(forKey: Self.accountKey)
            ?? UserDefaults.standard.string(forKey: Self.accountKey)
        guard let saved, HubJoinCode.isAcceptable(saved) else { return }
        do {
            try await joinSharedHousehold()
            setupCompleted = true
            persist()
        } catch {
            // Stay on setup if the cloud house is not published yet.
        }
    }

    /// Owner deletes the private-zone record and CKShare. A participant only leaves the share.
    /// Local data stays if iCloud does not confirm.
    func eraseHousehold() async -> String? {
        do {
            if ownsPrivateZone {
                try await remote.deletePrivateHouseholdAndShare()
            } else {
                try await remote.leaveShare()
            }
        } catch {
            let message = "Could not erase the iCloud copy. This HUB is still on this device. \(error.localizedDescription)"
            errorMessage = message
            return message
        }
        let failed = await deletePublicCodes(knownShareCodes(), attempts: 3)
        if !failed.isEmpty {
            let message = "Could not delete old shared records (\(failed.joined(separator: ", "))). This HUB is still on this device."
            errorMessage = message
            return message
        }
        clearLocalHouse()
        return nil
    }

    func restoreNewestBackup() async -> String? {
        let folder = snapshotURL.deletingLastPathComponent()
        let data = await Task.detached(priority: .userInitiated) {
            Self.newestDecodableBackup(in: folder)
        }.value
        guard let data else {
            return "No readable backup was found. The original file is still untouched."
        }
        do {
            try data.write(to: snapshotURL, options: [.atomic])
        } catch {
            return "Could not restore the backup. \(error.localizedDescription)"
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let snapshot = try? decoder.decode(HubSnapshot.self, from: data) else {
            return "No readable backup was found. The original file is still untouched."
        }
        loadFailed = false
        loadFailureDetail = nil
        apply(snapshot)
        return nil
    }

    nonisolated static func newestDecodableBackup(in folder: URL) -> Data? {
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey]))?
            .filter { $0.lastPathComponent.hasPrefix("hub-") && $0.pathExtension == "json" } ?? []
        let ordered = files.sorted { lhs, rhs in
            let left = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let right = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return left > right
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        for file in ordered {
            guard let data = try? Data(contentsOf: file),
                  (try? decoder.decode(HubSnapshot.self, from: data)) != nil
            else { continue }
            return data
        }
        return nil
    }

    private var writingBackup = true
    private var writingRole = true
    /// Stays false through the launch `persistNow()`, so that save cannot invent an owner role file.
    private var roleLoaded = false

    private func writeTimestampedBackup(_ data: Data) {
        guard writingBackup else { return }
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let folder = snapshotURL.deletingLastPathComponent()
        let backup = folder.appendingPathComponent("hub-\(stamp).json")
        try? data.write(to: backup, options: [.atomic])
        HubFilePrivacy.excludeFromBackup(backup)
        pruneBackups(keeping: 5)
    }

    private var roleURL: URL { snapshotURL.deletingLastPathComponent().appendingPathComponent("device-role.json") }
    private var legacyRoleURL: URL { snapshotURL.deletingLastPathComponent().appendingPathComponent("hub-role.json") }

    private struct DeviceRole: Codable {
        var ownsPrivateZone: Bool
    }

    private func loadDeviceRole() {
        if !fileManager.fileExists(atPath: roleURL.path), fileManager.fileExists(atPath: legacyRoleURL.path) {
            try? fileManager.moveItem(at: legacyRoleURL, to: roleURL)
        }
        guard let data = try? Data(contentsOf: roleURL),
              let role = try? JSONDecoder().decode(DeviceRole.self, from: data) else { return }
        ownsPrivateZone = role.ownsPrivateZone
    }

    private func saveDeviceRole() {
        guard let data = try? JSONEncoder().encode(DeviceRole(ownsPrivateZone: ownsPrivateZone)) else { return }
        try? data.write(to: roleURL, options: [.atomic])
        // Kept in backup, unlike hub-*.json copies: a restore must not turn a participant into the owner.
        // Protected until first unlock, same as hub.json, so launch can read it.
        HubFilePrivacy.protectUntilFirstUnlock(roleURL)
    }

    private func backupFiles(in folder: URL) -> [URL] {
        (try? fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey]))?
            .filter { $0.lastPathComponent.hasPrefix("hub-") && $0.pathExtension == "json" } ?? []
    }

    /// Cap is the 5 newest `hub-*.json` backups plus the newest one that still decodes, when that file is older (at most 6).
    /// Corrupt copies use the `corrupt-hub-` prefix and are not part of this set.
    /// Does nothing while hub.json itself is corrupt, so failed launches cannot evict a good copy.
    private func pruneBackups(keeping limit: Int) {
        guard !loadFailed else { return }
        let folder = snapshotURL.deletingLastPathComponent()
        let ordered = backupFiles(in: folder).sorted { lhs, rhs in
            let left = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let right = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return left > right
        }
        var keep = Set(ordered.prefix(limit).map(\.path))
        if let protected = Self.newestDecodableBackupURL(in: folder) {
            keep.insert(protected.path)
        }
        for file in ordered where !keep.contains(file.path) {
            try? fileManager.removeItem(at: file)
        }
    }

    nonisolated static func newestDecodableBackupURL(in folder: URL) -> URL? {
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey]))?
            .filter { $0.lastPathComponent.hasPrefix("hub-") && $0.pathExtension == "json" } ?? []
        let ordered = files.sorted { lhs, rhs in
            let left = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let right = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return left > right
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        for file in ordered {
            guard let data = try? Data(contentsOf: file),
                  (try? decoder.decode(HubSnapshot.self, from: data)) != nil
            else { continue }
            return file
        }
        return nil
    }

    /// Failed launches keep the 3 newest corrupt copies, ordered by the timestamp in the filename.
    /// `protecting` is the copy named on the restore screen and is never deleted.
    private func pruneCorruptCopies(keeping limit: Int, protecting protectedName: String? = nil) {
        let folder = snapshotURL.deletingLastPathComponent()
        let ordered = (try? fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil))?
            .filter { $0.lastPathComponent.hasPrefix("corrupt-hub-") && $0.pathExtension == "json" } ?? []
        let sorted = ordered.sorted { Self.corruptStamp($0.lastPathComponent) > Self.corruptStamp($1.lastPathComponent) }
        var keep = Set(sorted.prefix(limit).map(\.lastPathComponent))
        if let protectedName { keep.insert(protectedName) }
        for file in ordered where !keep.contains(file.lastPathComponent) {
            try? fileManager.removeItem(at: file)
        }
    }

    nonisolated static func corruptStamp(_ name: String) -> String {
        var body = name
        let prefix = "corrupt-hub-"
        if body.hasPrefix(prefix) { body.removeFirst(prefix.count) }
        if body.hasSuffix(".json") { body.removeLast(".json".count) }
        return body
    }

    private func deleteAllBackups() {
        let folder = snapshotURL.deletingLastPathComponent()
        for file in backupFiles(in: folder) {
            try? fileManager.removeItem(at: file)
        }
        pruneCorruptCopies(keeping: 0)
    }

    private func clearLocalHouse() {
        writingBackup = false
        writingRole = false
        defer {
            writingBackup = true
            writingRole = true
        }
        deleteAllBackups()
        ownsPrivateZone = true
        try? fileManager.removeItem(at: roleURL)
        try? fileManager.removeItem(at: legacyRoleURL)
        UserDefaults.standard.removeObject(forKey: Self.accountKey)
        NSUbiquitousKeyValueStore.default.removeObject(forKey: Self.accountKey)
        NSUbiquitousKeyValueStore.default.synchronize()
        try? fileManager.removeItem(at: snapshotURL)
        try? fileManager.removeItem(at: familyPhotoURL)
        try? fileManager.removeItem(at: memberPhotoFolder)
        loadFailed = false
        loadFailureDetail = nil
        apply(Self.emptySnapshot())
        setupCompleted = false
        issuedJoinCodes = []
        familyPhotoData = nil
        memberPhotos = [:]
        persistNow()
    }

    static func emptySnapshot() -> HubSnapshot {
        HubSnapshot(
            householdName: "",
            members: [],
            events: [],
            reminders: [],
            todos: [],
            chores: [],
            assignments: [],
            ledger: [],
            weatherPlace: .chicago,
            weatherFollowsMe: true,
            hubWidgets: HubWidget.defaultSet,
            recipes: [],
            schemaVersion: HubSnapshot.currentSchema
        )
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

