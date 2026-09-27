import XCTest
@testable import FamilyHub

final class ChoreReviewTests: XCTestCase {
    func testChildSeesOnlyTheirBoardAndParentCanFocusAKid() {
        let kid = UUID()
        let other = UUID()
        XCTAssertEqual(ChoreDesk.mode(role: .child, memberID: kid, focusedKidID: other), .kid(kid))
        XCTAssertEqual(ChoreDesk.mode(role: .parent, memberID: UUID(), focusedKidID: nil), .parent)
        XCTAssertEqual(ChoreDesk.mode(role: .parent, memberID: UUID(), focusedKidID: kid), .kid(kid))
        XCTAssertEqual(ChoreDesk.mode(role: .grandma, memberID: UUID(), focusedKidID: nil), .parent)
    }

    func testSendBackReturnsTheChoreWithoutACredit() {
        let chore = Chore.make(title: "Dishes", rewardCents: 200, cadence: .daily)
        let kid = FamilyMember.make(name: "Alex", role: .child, colorHex: "3D5A80", symbol: "figure.run")
        var assignment = ChoreAssignment.make(choreID: chore.id, memberID: kid.id, dueOn: Date())
        assignment = ChoreEngine.complete(assignment)
        assignment = ChoreEngine.sendBack(assignment, reason: "  Try the corners please, and the cups too, this reason is intentionally much longer than eighty characters. ")
        XCTAssertEqual(assignment.status, .pending)
        XCTAssertNil(assignment.completedAt)
        XCTAssertEqual(assignment.returnReason?.count, 80)
        XCTAssertTrue(assignment.returnReason?.hasPrefix("Try the corners") == true)
        XCTAssertNil(ChoreEngine.approve(assignment, chore: chore))
        assignment = ChoreEngine.sendBack(assignment, reason: "again")
        XCTAssertEqual(assignment.status, .pending)
    }

    func testEmptySendBackClearsTheReasonAndUndoWindowCloses() {
        let chore = Chore.make(title: "Room", rewardCents: 100, cadence: .daily)
        let kid = UUID()
        var assignment = ChoreAssignment.make(choreID: chore.id, memberID: kid, dueOn: Date())
        let doneAt = Date(timeIntervalSince1970: 1_700_000_000)
        assignment = ChoreEngine.complete(assignment, at: doneAt)
        XCTAssertTrue(ChoreReview.offersUndo(status: assignment.status, completedAt: assignment.completedAt, now: doneAt.addingTimeInterval(5)))
        XCTAssertFalse(ChoreReview.offersUndo(status: assignment.status, completedAt: assignment.completedAt, now: doneAt.addingTimeInterval(5.01)))
        XCTAssertFalse(ChoreReview.offersUndo(status: .pending, completedAt: doneAt, now: doneAt))
        assignment = ChoreEngine.sendBack(assignment, reason: "   ")
        XCTAssertNil(assignment.returnReason)
        XCTAssertEqual(assignment.status, .pending)
    }

    func testApproveCreditsAllowanceAndKeepsTheStreak() {
        let chore = Chore.make(title: "Dishes", rewardCents: 200, cadence: .daily, icon: "fork.knife")
        let kid = FamilyMember.make(name: "Alex", role: .child, colorHex: "3D5A80", symbol: "figure.run")
        var assignment = ChoreAssignment.make(choreID: chore.id, memberID: kid.id, dueOn: Date())
        assignment = ChoreEngine.complete(assignment)
        let streak = CircleXP.streak(memberID: kid.id, assignments: [assignment])
        XCTAssertGreaterThanOrEqual(streak, 1)
        let approved = ChoreEngine.approve(assignment, chore: chore)!
        XCTAssertEqual(approved.0.status, .approved)
        XCTAssertEqual(approved.1.amountCents, 200)
        XCTAssertEqual(approved.0.kidLabel, "Great job!")
        XCTAssertGreaterThan(CircleXP.points(for: approved.0, chore: chore), 0)
        XCTAssertGreaterThanOrEqual(CircleXP.streak(memberID: kid.id, assignments: [approved.0]), 1)
        XCTAssertEqual(ChoreDesk.waiting([assignment]).count, 1)
        XCTAssertEqual(ChoreDesk.waiting([approved.0]).count, 0)
    }

    func testParentNoticeNamesTheKidAndTheChore() {
        let kid = FamilyMember.make(name: "Alex", role: .child, colorHex: "3D5A80", symbol: "figure.run")
        let chore = Chore.make(title: "Dishes", rewardCents: 50, cadence: .once)
        var waiting = ChoreAssignment.make(choreID: chore.id, memberID: kid.id, dueOn: Date())
        waiting = ChoreEngine.complete(waiting)
        let pending = ChoreAssignment.make(choreID: chore.id, memberID: kid.id, dueOn: Date())
        let drafts = ChoreReview.incomingDone(
            before: [pending],
            after: [waiting],
            members: [kid],
            chores: [chore],
            viewerIsChild: false
        )
        XCTAssertEqual(drafts.count, 1)
        XCTAssertEqual(drafts[0].title, "Alex finished Dishes")
        XCTAssertEqual(drafts[0].assignmentID, waiting.id)
        XCTAssertEqual(drafts[0].identifier, ChoreReview.identifier(for: waiting.id))
        XCTAssertEqual(ChoreReview.categoryID, "hub.chore.review")
        XCTAssertEqual(ChoreReview.approveAction, "hub.chore.approve")
        XCTAssertEqual(ChoreReview.sendBackAction, "hub.chore.notYet")
        let childView = ChoreReview.incomingDone(
            before: [pending],
            after: [waiting],
            members: [kid],
            chores: [chore],
            viewerIsChild: true
        )
        XCTAssertTrue(childView.isEmpty)
        let again = ChoreReview.incomingDone(
            before: [waiting],
            after: [waiting],
            members: [kid],
            chores: [chore],
            viewerIsChild: false
        )
        XCTAssertTrue(again.isEmpty)
    }

    func testOlderChoreSnapshotsStillDecode() throws {
        let id = UUID()
        let choreJSON = """
        {"id":"\(id.uuidString)","title":"Dishes","details":"","rewardCents":100,"cadence":"weekly"}
        """
        let chore = try JSONDecoder().decode(Chore.self, from: Data(choreJSON.utf8))
        XCTAssertEqual(chore.icon, "sparkles")
        XCTAssertEqual(chore.title, "Dishes")

        let made = ChoreAssignment.make(choreID: id, memberID: UUID(), dueOn: Date())
        let data = try JSONEncoder().encode(made)
        let text = String(decoding: data, as: UTF8.self)
        XCTAssertFalse(text.contains("returnReason"))
        let decoded = try JSONDecoder().decode(ChoreAssignment.self, from: data)
        XCTAssertNil(decoded.returnReason)
        XCTAssertEqual(decoded.status, .pending)
    }

    func testKidCardsKeepTodaysPraiseAndDropOldPaidChores() {
        let kid = UUID()
        let chore = UUID()
        var fresh = ChoreAssignment.make(choreID: chore, memberID: kid, dueOn: Date())
        fresh = ChoreEngine.complete(fresh)
        fresh = ChoreEngine.approve(fresh, chore: Chore.make(title: "Dishes", rewardCents: 10, cadence: .once))!.0
        fresh = ChoreEngine.markPaid(fresh)
        var old = fresh
        old.id = UUID()
        old.approvedAt = Date().addingTimeInterval(-90_000)
        let shown = ChoreDesk.kidCards([fresh, old], now: Date())
        XCTAssertEqual(shown.map(\.id), [fresh.id])
        XCTAssertEqual(ChoreDesk.doneButtonMinHeight, 60)
        XCTAssertTrue(ChoreDesk.symbolIcon("trash.fill"))
        XCTAssertFalse(ChoreDesk.symbolIcon("🧹"))
    }

    func testCloudSubscriptionIDsStayDistinct() {
        XCTAssertNotEqual(HouseholdCloud.privateChangeSubscriptionID, HouseholdCloud.sharedChangeSubscriptionID)
        XCTAssertFalse(HouseholdCloud.privateChangeSubscriptionID.isEmpty)
        XCTAssertFalse(HouseholdCloud.sharedChangeSubscriptionID.isEmpty)
    }
}
