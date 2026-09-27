import CloudKit
import Foundation
import SwiftUI

enum HouseholdCloudError: LocalizedError, Equatable {
    case missingHouse
    case iCloud
    case transient

    var errorDescription: String? {
        switch self {
        case .missingHouse: return "No family share is on this iCloud account yet. The owner shares HUB from Settings → Invite."
        case .iCloud: return "Sign this device into iCloud, then try again."
        case .transient: return "iCloud did not respond. Try again."
        }
    }
}

protocol HouseholdRemote: AnyObject {
    func deletePrivateHouseholdAndShare() async throws
    func leaveShare() async throws
    func deletePublicCode(_ code: String) async throws
}

enum HouseholdCloud {
    static let containerID = "iCloud.com.corymurray.FamilyHub"
    static let recordType = "HubHousehold"
    static let zoneName = "FamilyHub"
    static let recordName = "household"
    /// Silent database subscription on the owner's private zone.
    static let privateChangeSubscriptionID = "hub.private.changes"
    /// Silent database subscription for participants reading the shared zone.
    static let sharedChangeSubscriptionID = "hub.shared.changes"

    static var container: CKContainer { CKContainer(identifier: containerID) }

    /// Debug and Xcode installs use the CloudKit Development environment.
    /// TestFlight and the App Store use Production. Records do not cross between them.
    static func currentAccount() async throws -> CircleLaunch.Account {
        try refuseCloudUnderTest()
        let status: CKAccountStatus
        do {
            status = try await container.accountStatus()
        } catch {
            if isNoAccount(error) { return .noAccount }
            throw error
        }
        switch status {
        case .available: return .available
        case .noAccount: return .noAccount
        case .restricted: return .restricted
        case .couldNotDetermine: return .couldNotDetermine
        case .temporarilyUnavailable: return .temporarilyUnavailable
        @unknown default: return .couldNotDetermine
        }
    }

    static func isNoAccount(_ error: Error) -> Bool {
        if let cloud = error as? HouseholdCloudError, cloud == .iCloud { return true }
        guard let ck = error as? CKError else { return false }
        return ck.code == .notAuthenticated
    }

    /// Unsigned test hosts trap inside CKContainer.init. Refuse before any database is touched.
    static func refuseCloudUnderTest() throws {
        #if DEBUG
        let env = ProcessInfo.processInfo.environment
        if env["XCTestConfigurationFilePath"] != nil || env["XCTestBundlePath"] != nil {
            throw HouseholdCloudError.iCloud
        }
        #endif
    }

    private static var privateDB: CKDatabase { container.privateCloudDatabase }
    private static var sharedDB: CKDatabase { container.sharedCloudDatabase }
    private static var publicDB: CKDatabase { container.publicCloudDatabase }

    private static var ownerZoneID: CKRecordZone.ID {
        CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)
    }

    /// Saves the household in the owner's private custom zone. Not the public database.
    static func publish(data: Data) async throws {
        try refuseCloudUnderTest()
        _ = try await savePrivate(data: data, shareTitle: nil)
    }

    /// Saves the private record and returns the CKShare the owner sends with UICloudSharingController.
    static func makeShare(data: Data, title: String) async throws -> CKShare {
        try refuseCloudUnderTest()
        return try await savePrivate(data: data, shareTitle: title)
    }

    @discardableResult
    private static func savePrivate(data: Data, shareTitle: String?) async throws -> CKShare {
        _ = try await privateDB.save(CKRecordZone(zoneID: ownerZoneID))
        let id = CKRecord.ID(recordName: recordName, zoneID: ownerZoneID)
        let record = (try? await privateDB.record(for: id)) ?? CKRecord(recordType: recordType, recordID: id)
        record["payload"] = data as CKRecordValue
        record["updatedAt"] = Date() as CKRecordValue
        if let ref = record.share,
           let existing = try? await privateDB.record(for: ref.recordID) as? CKShare {
            _ = try await privateDB.save(record)
            return existing
        }
        let share = CKShare(rootRecord: record)
        share[CKShare.SystemFieldKey.title] = (shareTitle ?? "HUB Circle") as CKRecordValue
        share.publicPermission = .none
        let (saved, _) = try await privateDB.modifyRecords(saving: [record, share], deleting: [], savePolicy: .changedKeys)
        if let result = saved[share.recordID], let stored = try result.get() as? CKShare {
            return stored
        }
        return share
    }

    /// Writes the household into the shared zone. Participants use this so a kid's "done" reaches the owner's devices.
    static func publishShared(data: Data) async throws {
        try refuseCloudUnderTest()
        let zones = try await sharedDB.allRecordZones()
        guard let zone = zones.first(where: { $0.zoneID.zoneName == zoneName }) else {
            throw HouseholdCloudError.missingHouse
        }
        let id = CKRecord.ID(recordName: recordName, zoneID: zone.zoneID)
        guard let record = try? await sharedDB.record(for: id) else {
            throw HouseholdCloudError.missingHouse
        }
        record["payload"] = data as CKRecordValue
        record["updatedAt"] = Date() as CKRecordValue
        _ = try await sharedDB.save(record)
    }

    /// CKDatabaseSubscription wakes other devices when the household record changes.
    /// Delivery needs the Push Notifications capability and the CloudKit container in the Apple Developer portal.
    /// Without those, saves fail quietly and the app falls back to a local notification the next time it syncs.
    static func ensureDatabaseSubscription(shared: Bool) async {
        do {
            try refuseCloudUnderTest()
        } catch {
            return
        }
        let database = shared ? sharedDB : privateDB
        let subscriptionID = shared ? sharedChangeSubscriptionID : privateChangeSubscriptionID
        let subscription = CKDatabaseSubscription(subscriptionID: subscriptionID)
        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true
        subscription.notificationInfo = info
        do {
            _ = try await database.save(subscription)
        } catch {
            // Missing aps-environment, or the container is not allowed to subscribe yet.
        }
    }

    /// Owner's private copy, then a zone shared with this iCloud user.
    /// `ownedHere` is false when the payload came from someone else's shared zone.
    static func fetchShared() async throws -> (data: Data, ownedHere: Bool) {
        try refuseCloudUnderTest()
        let ownID = CKRecord.ID(recordName: recordName, zoneID: ownerZoneID)
        if let record = try? await privateDB.record(for: ownID), let data = record["payload"] as? Data, !data.isEmpty {
            return (data, true)
        }
        let zones = try await sharedDB.allRecordZones()
        for zone in zones where zone.zoneID.zoneName == zoneName {
            let id = CKRecord.ID(recordName: recordName, zoneID: zone.zoneID)
            if let record = try? await sharedDB.record(for: id), let data = record["payload"] as? Data, !data.isEmpty {
                return (data, false)
            }
        }
        throw HouseholdCloudError.missingHouse
    }

    /// Participant leaves the share. Does not delete the owner's zone or share record.
    static func leaveShare() async throws {
        try refuseCloudUnderTest()
        let zones = try await sharedDB.allRecordZones()
        for zone in zones where zone.zoneID.zoneName == zoneName {
            let id = CKRecord.ID(recordName: recordName, zoneID: zone.zoneID)
            guard let record = try? await sharedDB.record(for: id), let shareID = record.share?.recordID else { continue }
            try await deleteIgnoringMissing(sharedDB, shareID)
        }
    }

    /// Deletes the private-zone household record and its CKShare. Missing records count as already gone.
    static func deletePrivateHouseholdAndShare() async throws {
        try refuseCloudUnderTest()
        let householdID = CKRecord.ID(recordName: recordName, zoneID: ownerZoneID)
        do {
            let record = try await privateDB.record(for: householdID)
            if let shareID = record.share?.recordID {
                try await deleteIgnoringMissing(privateDB, shareID)
            }
            try await deleteIgnoringMissing(privateDB, householdID)
        } catch let error as CKError where error.code == .unknownItem || error.code == .zoneNotFound {
            return
        }
    }

    private static func deleteIgnoringMissing(_ database: CKDatabase, _ id: CKRecord.ID) async throws {
        do {
            try await database.deleteRecord(withID: id)
        } catch let error as CKError where error.code == .unknownItem || error.code == .zoneNotFound {
            return
        }
    }

    static func isTransient(_ error: Error) -> Bool {
        if let cloud = error as? HouseholdCloudError, cloud == .transient { return true }
        guard let ck = error as? CKError else { return false }
        switch ck.code {
        case .networkUnavailable, .networkFailure, .serviceUnavailable, .requestRateLimited, .zoneBusy, .serverResponseLost:
            return true
        default:
            return false
        }
    }

    /// A public hub-<code> record created by another iCloud user is not ours to delete.
    /// An owner's permissionFailure is a real failure, not a skip.
    static func isForeignPublicRecord(_ error: Error, participant: Bool) -> Bool {
        guard participant, let ck = error as? CKError else { return false }
        return ck.code == .permissionFailure
    }

    /// Public database is only for retiring the old hub-<code> records.
    static func delete(code: String) async throws {
        try refuseCloudUnderTest()
        let clean = code.replacingOccurrences(of: " ", with: "").uppercased()
        guard HubJoinCode.isDeletable(clean) else { return }
        let id = CKRecord.ID(recordName: "hub-\(clean)")
        do {
            try await publicDB.deleteRecord(withID: id)
        } catch let error as CKError where error.code == .unknownItem {
            return
        }
    }
}

final class HouseholdCloudClient: HouseholdRemote {
    func deletePrivateHouseholdAndShare() async throws {
        try await HouseholdCloud.deletePrivateHouseholdAndShare()
    }

    func leaveShare() async throws {
        try await HouseholdCloud.leaveShare()
    }

    func deletePublicCode(_ code: String) async throws {
        try await HouseholdCloud.delete(code: code)
    }
}

enum HubLaunchScreen: Equatable {
    case splash, finding, noICloud, corrupt, setup, home

    static func choose(splash: Bool, loadFailed: Bool, needsSetup: Bool) -> HubLaunchScreen {
        if splash { return .splash }
        if loadFailed { return .corrupt }
        if needsSetup { return .setup }
        return .home
    }

    /// Launch after the local file is read. A Circle already on this iCloud account skips Create and Join.
    static func restored(splash: Bool, loadFailed: Bool, hasLocalCircle: Bool, phase: CircleLaunch.Phase) -> HubLaunchScreen {
        if splash { return .splash }
        if loadFailed { return .corrupt }
        if hasLocalCircle { return .home }
        switch phase {
        case .pending, .failed: return .finding
        case .found: return .home
        case .empty: return .setup
        case .noICloud: return .noICloud
        }
    }
}

/// Decides whether this Apple ID already has a Circle before onboarding is offered.
enum CircleLaunch {
    enum Account: Equatable {
        case available, noAccount, restricted, couldNotDetermine, temporarilyUnavailable
    }

    enum Remote: Equatable {
        case found, missing, failed
    }

    enum Phase: Equatable {
        case pending, found, empty, noICloud, failed
    }

    static func hasLocalCircle(setupCompleted: Bool, memberCount: Int) -> Bool {
        setupCompleted || memberCount > 0
    }

    static func snapshotHasCircle(setupCompleted: Bool?, memberCount: Int) -> Bool {
        if setupCompleted == true { return true }
        return memberCount > 0
    }

    static func phase(hasLocal: Bool, account: Account, remote: Remote?) -> Phase {
        if hasLocal { return .found }
        switch account {
        case .noAccount, .restricted:
            return .noICloud
        case .couldNotDetermine, .temporarilyUnavailable:
            return .failed
        case .available:
            switch remote {
            case .none: return .pending
            case .found: return .found
            case .missing: return .empty
            case .failed: return .failed
            }
        }
    }
}

struct HouseholdShareItem: Identifiable {
    let id = UUID()
    let share: CKShare
}

struct HouseholdShareSheet: UIViewControllerRepresentable {
    let share: CKShare

    func makeUIViewController(context: Context) -> UICloudSharingController {
        let controller = UICloudSharingController(share: share, container: HouseholdCloud.container)
        controller.availablePermissions = [.allowReadWrite, .allowPrivate]
        return controller
    }

    func updateUIViewController(_ controller: UICloudSharingController, context: Context) {}
}
