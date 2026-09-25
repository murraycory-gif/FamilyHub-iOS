import XCTest
@testable import FamilyHub

@MainActor
final class SnapshotReliabilityTests: XCTestCase {
    func testNotifyPrefsDropLegacyTwilioOnDecode() throws {
        let raw = """
        {"morningBrief":true,"eventPings":false,"dinnerPing":true,"chorePing":false,"shoppingPing":false,"billsPing":false,"channel":"text","who":"me","extraPhone":"3125550100","twilioSID":"AC123","twilioToken":"secret-token","twilioFrom":"+13125550199"}
        """.data(using: .utf8)!
        let prefs = try JSONDecoder().decode(HubNotifyPrefs.self, from: raw)
        XCTAssertEqual(prefs.extraPhone, "3125550100")
        XCTAssertTrue(prefs.morningBrief)
        XCTAssertEqual(prefs.channel, .device)
        let encoded = try JSONEncoder().encode(prefs)
        let text = String(data: encoded, encoding: .utf8) ?? ""
        XCTAssertFalse(text.contains("secret-token"))
        XCTAssertFalse(text.contains("twilioSID"))
        XCTAssertFalse(text.contains("twilioToken"))
        XCTAssertFalse(text.contains("twilioFrom"))
        XCTAssertTrue(HubNotifyPrefs.legacyTwilioPresent(in: raw))
    }

    func testWidgetTimelineAsksOnceAnHour() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let snap = WidgetBridge.Snapshot(
            household: "Murray",
            agendaTitle: "Soccer",
            agendaWhen: "4:30 PM",
            dinnerName: "Tacos",
            dinnerSide: "",
            leaveTitle: "Soccer",
            leaveAt: now.addingTimeInterval(20 * 60),
            eventStart: now.addingTimeInterval(40 * 60),
            updatedAt: now
        )
        let plan = WidgetBridge.timelinePlan(now: now, snap: snap)
        XCTAssertEqual(plan.dates.count, 3)
        XCTAssertEqual(plan.next.timeIntervalSince(now), 60 * 60, accuracy: 0.1)
    }

    func testPublicCloudPayloadDropsSecretsAndPII() {
        let kid = FamilyMember(
            id: UUID(),
            name: "Sam",
            role: .child,
            colorHex: "EA580C",
            symbol: "⚽️",
            allowanceBalanceCents: 800,
            birthday: Date(timeIntervalSince1970: 1_400_000_000),
            email: "sam@example.com",
            phone: "3125550101"
        )
        let parent = FamilyMember(
            id: UUID(),
            name: "Cory",
            role: .parent,
            colorHex: "163A5F",
            symbol: "😎",
            allowanceBalanceCents: 0,
            email: "cory@example.com",
            phone: "3125550100",
            diets: [.nutFree, .halal]
        )
        let prefs = HubNotifyPrefs(
            morningBrief: true,
            eventPings: false,
            dinnerPing: false,
            chorePing: false,
            shoppingPing: false,
            extraPhone: "3125550199"
        )
        let school = CalendarSource.make(brand: .subscribed, title: "School", icsURL: "https://school.example/secret.ics")
        var snapshot = HubStore.emptySnapshot()
        snapshot.householdName = "Murray"
        snapshot.members = [parent, kid]
        snapshot.joinCode = "AB12CD"
        snapshot.notifyPrefs = prefs
        snapshot.documents = [
            HubDocument.make(title: "Card", kind: .insurance, notes: "policy 123"),
            HubDocument.make(title: "Shot record", kind: .shots, notes: "MMR"),
            HubDocument.make(title: "Permission", kind: .school, notes: "field trip")
        ]
        snapshot.calendarSources = [school]
        snapshot.circlePlaces = [CirclePlace.make(name: "Home", kind: .home, lat: 41.8, lon: -87.6)]
        snapshot.placePings = [PlacePing(id: UUID(), placeID: UUID(), memberID: kid.id, arrived: true, at: Date())]
        let cloud = snapshot.forPublicDatabase()
        XCTAssertEqual(cloud.householdName, "Murray")
        XCTAssertEqual(cloud.joinCode, "AB12CD")
        XCTAssertEqual(cloud.members.map(\.name), ["Cory", "Sam"])
        XCTAssertEqual(cloud.members.map(\.role), [.parent, .child])
        XCTAssertEqual(cloud.members.map(\.phone), ["", ""])
        XCTAssertEqual(cloud.members.map(\.email), ["", ""])
        XCTAssertEqual(cloud.members.map(\.diets), [[], []])
        XCTAssertNil(cloud.members[1].birthday)
        XCTAssertEqual(cloud.members[1].allowanceBalanceCents, 0)
        XCTAssertEqual(cloud.notifyPrefs?.extraPhone, "")
        XCTAssertNil(cloud.issuedJoinCodes)
        XCTAssertEqual(cloud.documents?.map(\.kind), [.school])
        XCTAssertEqual(cloud.calendarSources?.first?.icsURL, nil)
        XCTAssertEqual(cloud.calendarSources?.first?.title, "School")
        XCTAssertEqual(cloud.circlePlaces?.first?.name, "Home")
        XCTAssertEqual(cloud.circlePlaces?.first?.latitude, 0)
        XCTAssertEqual(cloud.placePings?.isEmpty, true)
        let encoded = try? JSONEncoder().encode(cloud)
        let text = encoded.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        XCTAssertFalse(text.contains("sam@example.com"))
        XCTAssertFalse(text.contains("policy 123"))
        XCTAssertFalse(text.contains("secret.ics"))
    }

    func testEmptyHouseDoesNotIncludeDemoPeople() {
        let empty = HubStore.emptySnapshot()
        XCTAssertTrue(empty.members.isEmpty)
        XCTAssertEqual(empty.householdName, "")
        XCTAssertEqual(empty.recipes ?? [], [])
        XCTAssertEqual(empty.schemaVersion, HubSnapshot.currentSchema)
    }

    func testSnapshotDecodesWithoutNewFields() throws {
        let raw = """
        {"householdName":"Murray","members":[],"events":[],"reminders":[],"todos":[],"chores":[],"assignments":[],"ledger":[]}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(HubSnapshot.self, from: raw)
        XCTAssertEqual(decoded.householdName, "Murray")
        XCTAssertNil(decoded.schemaVersion)
        XCTAssertNil(decoded.issuedJoinCodes)
        XCTAssertNil(decoded.recipes)
    }

    @MainActor
    func testCorruptHubFileIsLeftAlone() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let original = Data("{not json".utf8)
        let url = root.appendingPathComponent("hub.json")
        try original.write(to: url)
        let store = HubStore(rootURL: root)
        let after = try Data(contentsOf: url)
        XCTAssertEqual(after, original)
        XCTAssertEqual(store.recipes, [])
        XCTAssertFalse(store.recipes.contains(where: { $0.name == "Tacos" }))
        XCTAssertNotNil(store.errorMessage)
        let copies = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("hub-") && $0.lastPathComponent.hasSuffix(".json") }
        XCTAssertEqual(copies.count, 1)
        XCTAssertEqual(try Data(contentsOf: copies[0]), original)
        store.setWhiteboardNote("should not overwrite")
        let still = try Data(contentsOf: url)
        XCTAssertEqual(still, original)
    }
}
