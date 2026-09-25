import CloudKit
import XCTest
@testable import FamilyHub

@MainActor
final class RiskReviewTests: XCTestCase {
    override func setUp() {
        super.setUp()
        clearSavedAccount()
    }

    override func tearDown() {
        clearSavedAccount()
        super.tearDown()
    }

    private func clearSavedAccount() {
        UserDefaults.standard.removeObject(forKey: HubStore.accountKey)
        NSUbiquitousKeyValueStore.default.removeObject(forKey: HubStore.accountKey)
    }

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
        let restored = await store.restoreNewestBackup()
        XCTAssertNil(restored)
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
        _ = store.addQuickMember(name: "Cory", role: .parent, asOwner: true)
        store.markSetupComplete()
        try Data("{}".utf8).write(to: root.appendingPathComponent("hub-extra.json"))
        store.remote = ScriptedRemote()

        let erased = await store.eraseHousehold()
        XCTAssertNil(erased)

        let backups = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("hub-") && $0.pathExtension == "json" }
        XCTAssertEqual(backups, [])
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("device-role.json").path))
    }

    func testParticipantEraseSkipsForeignPublicCode() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let store = HubStore(rootURL: root)
        _ = store.addQuickMember(name: "Cory", role: .parent, asOwner: true)
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

    func testOwnerPermissionFailureKeepsLocalData() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let store = HubStore(rootURL: root)
        let person = store.addQuickMember(name: "Cory", role: .parent, asOwner: true)
        store.markSetupComplete()
        XCTAssertTrue(store.ownsPrivateZone)
        let remote = ScriptedRemote()
        remote.publicError = CKError(.permissionFailure)
        store.remote = remote

        let failure = await store.eraseHousehold()

        XCTAssertNotNil(failure)
        XCTAssertEqual(failure, store.errorMessage)
        XCTAssertEqual(store.members.map(\.id), [person.id])
        XCTAssertEqual(remote.privateDeletes, 1)
        XCTAssertEqual(remote.leaveCalls, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("hub.json").path))
    }

    func testDeviceRoleSurvivesRelaunch() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let store = HubStore(rootURL: root)
        _ = store.addQuickMember(name: "Cory", role: .parent, asOwner: true)
        store.ownsPrivateZone = false
        store.markSetupComplete()

        let reloaded = HubStore(rootURL: root)
        XCTAssertFalse(reloaded.ownsPrivateZone)
        XCTAssertFalse(reloaded.loadFailed)
    }

    func testFailedLaunchesDoNotEvictDecodableBackup() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        var snapshot = HubStore.emptySnapshot()
        snapshot.householdName = "Still here"
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let good = try encoder.encode(snapshot)
        let backup = root.appendingPathComponent("hub-2019-01-01T00-00-00Z.json")
        try good.write(to: backup)
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 10)], ofItemAtPath: backup.path)
        try Data("{not json".utf8).write(to: root.appendingPathComponent("hub.json"))

        for _ in 0..<7 {
            let launched = HubStore(rootURL: root)
            XCTAssertTrue(launched.loadFailed)
        }

        XCTAssertTrue(FileManager.default.fileExists(atPath: backup.path))
        let names = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil).map(\.lastPathComponent)
        XCTAssertEqual(names.filter { $0.hasPrefix("corrupt-hub-") }.count, 3)
        XCTAssertFalse(names.contains { $0.hasPrefix("hub-") && $0.hasPrefix("corrupt-hub-") == false && $0 != backup.lastPathComponent })
        let store = HubStore(rootURL: root)
        let restored = await store.restoreNewestBackup()
        XCTAssertNil(restored)
        XCTAssertEqual(store.householdName, "Still here")
    }

    func testOrdinarySavesLeaveDeviceRoleIntact() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let store = HubStore(rootURL: root)
        _ = store.addQuickMember(name: "Cory", role: .parent, asOwner: true)
        store.ownsPrivateZone = false
        for _ in 0..<10 {
            store.markSetupComplete()
        }
        let role = root.appendingPathComponent("device-role.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: role.path))
        let reloaded = HubStore(rootURL: root)
        XCTAssertFalse(reloaded.ownsPrivateZone)
    }

    func testMissingRoleFileDefaultsToOwner() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let store = HubStore(rootURL: root)
        XCTAssertTrue(store.ownsPrivateZone)
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("device-role.json").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("hub-role.json").path))
    }

    func testLegacyRoleFileIsMigrated() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data(#"{"ownsPrivateZone":false}"#.utf8).write(to: root.appendingPathComponent("hub-role.json"))
        var snapshot = HubStore.emptySnapshot()
        snapshot.householdName = "Joined"
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(snapshot).write(to: root.appendingPathComponent("hub.json"))

        let store = HubStore(rootURL: root)
        XCTAssertFalse(store.ownsPrivateZone)
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("device-role.json").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("hub-role.json").path))
    }

    func testOldSchemaLaunchKeepsParticipantRole() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let role = #"{"ownsPrivateZone":false}"#
        try Data(role.utf8).write(to: root.appendingPathComponent("device-role.json"))
        let old = """
        {"householdName":"Joined","members":[],"events":[],"reminders":[],"todos":[],"chores":[],"assignments":[],"ledger":[],"schemaVersion":0,"joinCode":"AB12CD","issuedJoinCodes":["AB12CD"]}
        """
        try Data(old.utf8).write(to: root.appendingPathComponent("hub.json"))

        let store = HubStore(rootURL: root)
        XCTAssertFalse(store.ownsPrivateZone)
        XCTAssertFalse(store.loadFailed)
        let saved = try String(contentsOf: root.appendingPathComponent("device-role.json"), encoding: .utf8)
        XCTAssertTrue(saved.contains("false"))
    }

    func testCorruptPruneKeepsThreeNewestNames() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data("{not json".utf8).write(to: root.appendingPathComponent("hub.json"))
        let sharedDate = Date(timeIntervalSince1970: 50)
        let seeded = [
            "corrupt-hub-2099-01-03T00-00-00.000Z.json",
            "corrupt-hub-2099-01-02T00-00-00.000Z.json",
            "corrupt-hub-2099-01-01T00-00-00.000Z.json",
            "corrupt-hub-2020-01-02T00-00-00.000Z.json",
            "corrupt-hub-2020-01-01T00-00-00.000Z.json"
        ]
        for name in seeded {
            let url = root.appendingPathComponent(name)
            try Data("{not json".utf8).write(to: url)
            try FileManager.default.setAttributes([.modificationDate: sharedDate], ofItemAtPath: url.path)
        }
        let oldest = root.appendingPathComponent("corrupt-hub-2020-01-01T00-00-00.000Z.json")
        try FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: oldest.path)

        let store = HubStore(rootURL: root)
        let names = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil).map(\.lastPathComponent)
        XCTAssertTrue(names.contains("corrupt-hub-2099-01-03T00-00-00.000Z.json"))
        XCTAssertTrue(names.contains("corrupt-hub-2099-01-02T00-00-00.000Z.json"))
        XCTAssertTrue(names.contains("corrupt-hub-2099-01-01T00-00-00.000Z.json"))
        XCTAssertFalse(names.contains("corrupt-hub-2020-01-02T00-00-00.000Z.json"))
        XCTAssertFalse(names.contains("corrupt-hub-2020-01-01T00-00-00.000Z.json"))
        let detail = store.loadFailureDetail ?? ""
        let named = names.first { detail.contains($0) && $0.hasPrefix("corrupt-hub-") }
        XCTAssertNotNil(named)
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
