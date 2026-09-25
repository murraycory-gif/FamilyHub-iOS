import CloudKit
import Foundation
import SwiftUI

enum HouseholdCloudError: LocalizedError {
    case missingHouse
    case iCloud

    var errorDescription: String? {
        switch self {
        case .missingHouse: return "No family share is on this iCloud account yet. The owner shares HUB from Settings → Invite."
        case .iCloud: return "Sign this device into iCloud, then try again."
        }
    }
}

enum HouseholdCloud {
    static let containerID = "iCloud.com.corymurray.FamilyHub"
    static let recordType = "HubHousehold"
    static let zoneName = "FamilyHub"
    static let recordName = "household"

    static var container: CKContainer { CKContainer(identifier: containerID) }

    private static var privateDB: CKDatabase { container.privateCloudDatabase }
    private static var sharedDB: CKDatabase { container.sharedCloudDatabase }
    private static var publicDB: CKDatabase { container.publicCloudDatabase }

    private static var ownerZoneID: CKRecordZone.ID {
        CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)
    }

    /// Saves the household in the owner's private custom zone. Not the public database.
    static func publish(data: Data) async throws {
        _ = try await savePrivate(data: data, shareTitle: nil)
    }

    /// Saves the private record and returns the CKShare the owner sends with UICloudSharingController.
    static func makeShare(data: Data, title: String) async throws -> CKShare {
        try await savePrivate(data: data, shareTitle: title)
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
    static func fetchShared() async throws -> Data {
        let ownID = CKRecord.ID(recordName: recordName, zoneID: ownerZoneID)
        if let record = try? await privateDB.record(for: ownID), let data = record["payload"] as? Data, !data.isEmpty {
            return data
        }
        let zones = try await sharedDB.allRecordZones()
        for zone in zones where zone.zoneID.zoneName == zoneName {
            let id = CKRecord.ID(recordName: recordName, zoneID: zone.zoneID)
            if let record = try? await sharedDB.record(for: id), let data = record["payload"] as? Data, !data.isEmpty {
                return data
            }
        }
        throw HouseholdCloudError.missingHouse
    }

    /// Public database is only for retiring the old hub-<code> records.
    static func delete(code: String) async throws {
        let clean = code.replacingOccurrences(of: " ", with: "").uppercased()
        guard clean.count == 6 else { return }
        let id = CKRecord.ID(recordName: "hub-\(clean)")
        do {
            try await publicDB.deleteRecord(withID: id)
        } catch let error as CKError where error.code == .unknownItem {
            return
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
