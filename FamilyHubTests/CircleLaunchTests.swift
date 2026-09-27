import XCTest
@testable import FamilyHub

final class CircleLaunchTests: XCTestCase {
    func testACircleAlreadyOnThisDeviceSkipsCreate() {
        XCTAssertTrue(CircleLaunch.hasLocalCircle(setupCompleted: true, memberCount: 0))
        XCTAssertTrue(CircleLaunch.hasLocalCircle(setupCompleted: false, memberCount: 4))
        XCTAssertFalse(CircleLaunch.hasLocalCircle(setupCompleted: false, memberCount: 0))
        XCTAssertEqual(
            HubLaunchScreen.restored(splash: false, loadFailed: false, hasLocalCircle: true, phase: .pending),
            .home
        )
        XCTAssertEqual(
            HubLaunchScreen.restored(splash: false, loadFailed: false, hasLocalCircle: true, phase: .empty),
            .home
        )
    }

    func testACircleFoundInICloudSkipsCreateAndJoin() {
        let phase = CircleLaunch.phase(hasLocal: false, account: .available, remote: .found)
        XCTAssertEqual(phase, .found)
        XCTAssertEqual(
            HubLaunchScreen.restored(splash: false, loadFailed: false, hasLocalCircle: false, phase: phase),
            .home
        )
    }

    func testCreateIsOfferedOnlyAfterICloudSaysThereIsNoCircle() {
        XCTAssertEqual(CircleLaunch.phase(hasLocal: false, account: .available, remote: nil), .pending)
        XCTAssertEqual(
            HubLaunchScreen.restored(splash: false, loadFailed: false, hasLocalCircle: false, phase: .pending),
            .finding
        )
        XCTAssertEqual(CircleLaunch.phase(hasLocal: false, account: .available, remote: .missing), .empty)
        XCTAssertEqual(
            HubLaunchScreen.restored(splash: false, loadFailed: false, hasLocalCircle: false, phase: .empty),
            .setup
        )
    }

    func testNoICloudIsAClearStopInsteadOfCreate() {
        XCTAssertEqual(CircleLaunch.phase(hasLocal: false, account: .noAccount, remote: nil), .noICloud)
        XCTAssertEqual(CircleLaunch.phase(hasLocal: false, account: .restricted, remote: .missing), .noICloud)
        XCTAssertEqual(
            HubLaunchScreen.restored(splash: false, loadFailed: false, hasLocalCircle: false, phase: .noICloud),
            .noICloud
        )
    }

    func testAQuietICloudKeepsLooking() {
        XCTAssertEqual(CircleLaunch.phase(hasLocal: false, account: .temporarilyUnavailable, remote: nil), .failed)
        XCTAssertEqual(CircleLaunch.phase(hasLocal: false, account: .couldNotDetermine, remote: nil), .failed)
        XCTAssertEqual(CircleLaunch.phase(hasLocal: false, account: .available, remote: .failed), .failed)
        XCTAssertEqual(
            HubLaunchScreen.restored(splash: false, loadFailed: false, hasLocalCircle: false, phase: .failed),
            .finding
        )
    }

    func testAnEmptyCloudRecordIsNotACircle() {
        XCTAssertFalse(CircleLaunch.snapshotHasCircle(setupCompleted: false, memberCount: 0))
        XCTAssertFalse(CircleLaunch.snapshotHasCircle(setupCompleted: nil, memberCount: 0))
        XCTAssertTrue(CircleLaunch.snapshotHasCircle(setupCompleted: true, memberCount: 0))
        XCTAssertTrue(CircleLaunch.snapshotHasCircle(setupCompleted: nil, memberCount: 2))
    }

    func testSplashAndABadFileStillWin() {
        XCTAssertEqual(
            HubLaunchScreen.restored(splash: true, loadFailed: true, hasLocalCircle: false, phase: .empty),
            .splash
        )
        XCTAssertEqual(
            HubLaunchScreen.restored(splash: false, loadFailed: true, hasLocalCircle: true, phase: .found),
            .corrupt
        )
        XCTAssertEqual(HubLaunchScreen.choose(splash: false, loadFailed: false, needsSetup: false), .home)
        XCTAssertEqual(HubLaunchScreen.choose(splash: false, loadFailed: true, needsSetup: true), .corrupt)
    }

    func testLaunchAsksICloudBeforeOnboarding() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let store = try String(contentsOf: root.appendingPathComponent("FamilyHub/Storage/HubStore.swift"), encoding: .utf8)
        let rootView = try String(contentsOf: root.appendingPathComponent("FamilyHub/RootView.swift"), encoding: .utf8)
        XCTAssertTrue(store.contains("func discoverExistingCircle()"))
        XCTAssertTrue(store.contains("HouseholdCloud.fetchShared()"))
        XCTAssertTrue(store.contains("HouseholdCloud.currentAccount()"))
        XCTAssertFalse(store.contains("HubJoinCode.isAcceptable(saved)"))
        XCTAssertTrue(rootView.contains("Finding your family..."))
        XCTAssertTrue(rootView.contains("Sign in to iCloud"))
        XCTAssertTrue(rootView.contains("HubLaunchScreen.restored"))
    }
}
