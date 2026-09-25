import XCTest
@testable import FamilyHub

@MainActor
final class RiskReviewTests: XCTestCase {
    func testEraseDeletesPrivateShareBeforeClearingLocalData() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let store = HubStore(rootURL: root)
        let person = store.addQuickMember(name: "Cory", role: .parent, asOwner: true)
        store.markSetupComplete()
        let before = try Data(contentsOf: root.appendingPathComponent("hub.json"))
        let remote = ScriptedRemote()
        remote.privateError = HouseholdCloudError.iCloud
        store.remote = remote

        let failure = await store.eraseHousehold()

        XCTAssertEqual(remote.privateDeletes, 1)
        XCTAssertEqual(failure, store.errorMessage)
        XCTAssertNotNil(failure)
        XCTAssertEqual(store.members.map(\.id), [person.id])
        XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent("hub.json")), before)

        remote.privateError = nil
        let success = await store.eraseHousehold()
        XCTAssertNil(success)
        XCTAssertEqual(remote.privateDeletes, 2)
        XCTAssertTrue(store.members.isEmpty)
    }

    func testCorruptFileShowsRestoreAndRestoreWorks() async throws {
        XCTAssertEqual(HubLaunchScreen.choose(splash: false, loadFailed: true, needsSetup: true), .corrupt)
        XCTAssertEqual(HubLaunchScreen.choose(splash: true, loadFailed: true, needsSetup: true), .splash)
        XCTAssertEqual(HubLaunchScreen.choose(splash: false, loadFailed: false, needsSetup: false), .home)

        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        var snapshot = HubStore.emptySnapshot()
        snapshot.householdName = "Restored"
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let good = try encoder.encode(snapshot)
        let backup = root.appendingPathComponent("hub-2020-01-01T00-00-00Z.json")
        try good.write(to: backup)
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 1_000)], ofItemAtPath: backup.path)
        try Data("{not json".utf8).write(to: root.appendingPathComponent("hub.json"))

        let store = HubStore(rootURL: root)
        XCTAssertTrue(store.loadFailed)
        XCTAssertNotEqual(store.householdName, "Restored")
        XCTAssertNil(await store.restoreNewestBackup())
        XCTAssertFalse(store.loadFailed)
        XCTAssertEqual(store.householdName, "Restored")
    }

    func testPublicCleanupReportsErrorsAndRetriesTransientFailures() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let store = HubStore(rootURL: root)
        let remote = ScriptedRemote()
        remote.publicError = HouseholdCloudError.iCloud
        store.remote = remote

        let message = await store.removeOldSharedRecords()
        XCTAssertTrue(message.contains("Could not delete"))
        XCTAssertFalse(message.hasPrefix("Removed"))
        XCTAssertEqual(store.errorMessage, message)

        remote.publicError = nil
        remote.transientFailuresRemaining = 2
        let failed = await store.deletePublicCodes(["AB12CD"], attempts: 3)
        XCTAssertEqual(failed, [])
        XCTAssertEqual(remote.publicDeletes.filter { $0 == "AB12CD" }.count, 3)
    }

    func testBackupPruneKeepsFiveNewest() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let store = HubStore(rootURL: root)
        for index in 0..<8 {
            let file = root.appendingPathComponent(String(format: "hub-2000-01-%02dT00-00-00Z.json", index + 1))
            try Data("{}".utf8).write(to: file)
            try FileManager.default.setAttributes(
                [.modificationDate: Date(timeIntervalSince1970: TimeInterval(index + 1))],
                ofItemAtPath: file.path
            )
        }
        store.markSetupComplete()
        let backups = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("hub-") && $0.pathExtension == "json" }
        XCTAssertEqual(backups.count, 5)
        XCTAssertFalse(backups.contains { $0.lastPathComponent.contains("2000-01-01") })
    }

    func testEraseSuccessRemovesEveryBackup() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let store = HubStore(rootURL: root)
        store.addQuickMember(name: "Cory", role: .parent, asOwner: true)
        store.markSetupComplete()
        try Data("{}".utf8).write(to: root.appendingPathComponent("hub-extra.json"))
        store.remote = ScriptedRemote()

        XCTAssertNil(await store.eraseHousehold())

        let backups = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("hub-") && $0.pathExtension == "json" }
        XCTAssertEqual(backups, [])
    }

    func testParticipantEraseSkipsForeignPublicCode() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let store = HubStore(rootURL: root)
        store.addQuickMember(name: "Cory", role: .parent, asOwner: true)
        store.markSetupComplete()
        store.ownsPrivateZone = false
        let remote = ScriptedRemote()
        remote.publicError = CKError(.permissionFailure)
        store.remote = remote

        let result = await store.eraseHousehold()

        XCTAssertNil(result)
        XCTAssertEqual(remote.privateDeletes, 0)
        XCTAssertEqual(remote.leaveCalls, 1)
        XCTAssertTrue(store.members.isEmpty)
    }
}

private final class ScriptedRemote: HouseholdRemote {
    var privateDeletes = 0
    var leaveCalls = 0
    var publicDeletes: [String] = []
    var privateError: Error?
    var publicError: Error?
    var transientFailuresRemaining = 0

    func deletePrivateHouseholdAndShare() async throws {
        privateDeletes += 1
        if let privateError { throw privateError }
    }

    func leaveShare() async throws {
        leaveCalls += 1
    }

    func deletePublicCode(_ code: String) async throws {
        publicDeletes.append(code)
        if transientFailuresRemaining > 0 {
            transientFailuresRemaining -= 1
            throw HouseholdCloudError.transient
        }
        if let publicError { throw publicError }
    }
}
