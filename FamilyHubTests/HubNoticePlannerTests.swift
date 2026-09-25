import XCTest
@testable import FamilyHub

final class HubNoticePlannerTests: XCTestCase {
    func testSoonestNoticesWinTheCap() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let slots = (0..<80).map { index in
            HubNoticeSlot(identifier: "hub.event.\(index)", fireAt: now.addingTimeInterval(TimeInterval(index * 60)))
        }
        let kept = HubNoticePlanner.prioritize(slots)
        XCTAssertEqual(kept.count, 64)
        XCTAssertEqual(kept.first?.identifier, "hub.event.0")
        XCTAssertEqual(kept.last?.identifier, "hub.event.63")
        XCTAssertFalse(kept.contains { $0.identifier == "hub.event.79" })
    }

    func testRescheduleRemovesStaleHubIDsOnly() {
        let pending = ["hub.morning", "hub.event.old", "hub.now.immediate", "other.app"]
        let remove = HubNoticePlanner.identifiersToRemove(pending: pending, keeping: ["hub.morning"])
        XCTAssertEqual(remove, ["hub.event.old"])
    }

    func testNextDailyRollsToTomorrowAfterTheHour() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 9, day: 25, hour: 8, minute: 30))!
        let next = HubNoticePlanner.nextDaily(hour: 7, minute: 0, now: now, calendar: calendar)
        let parts = calendar.dateComponents([.day, .hour], from: next)
        XCTAssertEqual(parts.day, 26)
        XCTAssertEqual(parts.hour, 7)
    }
}
