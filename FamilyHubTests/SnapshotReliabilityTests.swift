import XCTest
@testable import FamilyHub

final class SnapshotReliabilityTests: XCTestCase {
    func testNotifyPrefsStripTwilioBeforeDisk() {
        let prefs = HubNotifyPrefs(
            morningBrief: true,
            eventPings: false,
            dinnerPing: true,
            chorePing: false,
            shoppingPing: false,
            billsPing: false,
            extraPhone: "3125550100",
            twilioSID: "AC123",
            twilioToken: "secret-token",
            twilioFrom: "+13125550199"
        )
        let stripped = prefs.strippingSecrets()
        XCTAssertEqual(stripped.twilioSID, "")
        XCTAssertEqual(stripped.twilioToken, "")
        XCTAssertEqual(stripped.twilioFrom, "")
        XCTAssertEqual(stripped.extraPhone, "3125550100")
        XCTAssertTrue(stripped.morningBrief)
        XCTAssertFalse(stripped.textReady)
        XCTAssertTrue(prefs.textReady)
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
            phone: "3125550100"
        )
        let prefs = HubNotifyPrefs(
            morningBrief: true,
            eventPings: false,
            dinnerPing: false,
            chorePing: false,
            shoppingPing: false,
            extraPhone: "3125550199",
            twilioSID: "ACexample",
            twilioToken: "auth-token",
            twilioFrom: "+13125550100"
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
        XCTAssertNil(cloud.members[1].birthday)
        XCTAssertEqual(cloud.members[1].allowanceBalanceCents, 0)
        XCTAssertEqual(cloud.notifyPrefs?.twilioToken, "")
        XCTAssertEqual(cloud.notifyPrefs?.twilioSID, "")
        XCTAssertEqual(cloud.notifyPrefs?.extraPhone, "")
        XCTAssertEqual(cloud.documents?.map(\.kind), [.school])
        XCTAssertEqual(cloud.calendarSources?.first?.icsURL, nil)
        XCTAssertEqual(cloud.calendarSources?.first?.title, "School")
        XCTAssertEqual(cloud.circlePlaces?.first?.name, "Home")
        XCTAssertEqual(cloud.circlePlaces?.first?.latitude, 0)
        XCTAssertEqual(cloud.placePings?.isEmpty, true)
        let encoded = try? JSONEncoder().encode(cloud)
        let text = encoded.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        XCTAssertFalse(text.contains("auth-token"))
        XCTAssertFalse(text.contains("sam@example.com"))
        XCTAssertFalse(text.contains("policy 123"))
        XCTAssertFalse(text.contains("secret.ics"))
    }

    func testEmptyHouseDoesNotIncludeDemoPeople() {
        let empty = HubStore.emptySnapshot()
        XCTAssertTrue(empty.members.isEmpty)
        XCTAssertEqual(empty.householdName, "")
        XCTAssertFalse(empty.recipes?.isEmpty ?? true)
    }
}
