import XCTest
@testable import FamilyHub

final class ChoreEngineTests: XCTestCase {
    func testCompleteThenApproveCreditsReward() {
        let chore = Chore.make(title: "Dishes", rewardCents: 200, cadence: .daily)
        let kid = FamilyMember.make(name: "Alex", role: .child, colorHex: "3D5A80", symbol: "figure.run")
        var assignment = ChoreAssignment.make(choreID: chore.id, memberID: kid.id, dueOn: Date())

        assignment = ChoreEngine.complete(assignment)
        XCTAssertEqual(assignment.status, .done)
        XCTAssertNotNil(assignment.completedAt)

        let result = ChoreEngine.approve(assignment, chore: chore)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.0.status, .approved)
        XCTAssertEqual(result?.1.amountCents, 200)
        XCTAssertEqual(result?.1.memberID, kid.id)

        let nextBalance = ChoreEngine.applyLedger(balance: 0, entry: result!.1)
        XCTAssertEqual(nextBalance, 200)
    }

    func testCannotApproveUntilDone() {
        let chore = Chore.make(title: "Trash", rewardCents: 150, cadence: .weekly)
        let kid = FamilyMember.make(name: "Sam", role: .child, colorHex: "8C5A3C", symbol: "soccerball")
        let assignment = ChoreAssignment.make(choreID: chore.id, memberID: kid.id, dueOn: Date())
        XCTAssertNil(ChoreEngine.approve(assignment, chore: chore))
    }

    func testReopenOnlyFromDone() {
        let chore = Chore.make(title: "Room", rewardCents: 300, cadence: .weekly)
        let kid = FamilyMember.make(name: "Alex", role: .child, colorHex: "3D5A80", symbol: "figure.run")
        var assignment = ChoreAssignment.make(choreID: chore.id, memberID: kid.id, dueOn: Date())
        XCTAssertEqual(ChoreEngine.reopen(assignment).status, .pending)
        assignment = ChoreEngine.complete(assignment)
        XCTAssertEqual(ChoreEngine.reopen(assignment).status, .pending)
    }

    func testMarkPaidOnlyFromApproved() {
        let chore = Chore.make(title: "Lawn", rewardCents: 800, cadence: .weekly)
        let kid = FamilyMember.make(name: "Sam", role: .child, colorHex: "8C5A3C", symbol: "soccerball")
        var assignment = ChoreAssignment.make(choreID: chore.id, memberID: kid.id, dueOn: Date())
        XCTAssertEqual(ChoreEngine.markPaid(assignment).status, .pending)
        assignment = ChoreEngine.complete(assignment)
        let approved = ChoreEngine.approve(assignment, chore: chore)!.0
        XCTAssertEqual(ChoreEngine.markPaid(approved).status, .paid)
    }

    func testMoneyFormat() {
        XCTAssertEqual(Money.cents(200), " $2.00")
        XCTAssertEqual(Money.cents(-150), "- $1.50")
        XCTAssertEqual(Money.cents(0), " $0.00")
    }
}
