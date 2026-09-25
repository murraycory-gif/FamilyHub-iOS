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

    func testEmptyHouseDoesNotIncludeDemoPeople() {
        let empty = HubStore.emptySnapshot()
        XCTAssertTrue(empty.members.isEmpty)
        XCTAssertEqual(empty.householdName, "")
        XCTAssertFalse(empty.recipes?.isEmpty ?? true)
    }
}
