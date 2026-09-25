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

    static var container: CKContainer { CKContainer(identifier: containerID) }

    /// Unsigned test hosts trap inside CKContainer.init. Refuse before any database is touched.
    static func refuseCloudUnderTest() throws {
        let env = ProcessInfo.processInfo.environment
        if env["XCTestConfigurationFilePath"] != nil || env["XCTestBundlePath"] != nil {
            throw HouseholdCloudError.iCloud
        }
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
        guard HubJoinCode.isAcceptable(clean) else { return }
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
    case splash, corrupt, setup, home

    static func choose(splash: Bool, loadFailed: Bool, needsSetup: Bool) -> HubLaunchScreen {
        if splash { return .splash }
        if loadFailed { return .corrupt }
        if needsSetup { return .setup }
        return .home
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
