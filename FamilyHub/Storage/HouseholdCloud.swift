import CloudKit
import Foundation

enum HouseholdCloudError: LocalizedError {
    case badCode
    case missingHouse
    case iCloud

    var errorDescription: String? {
        switch self {
        case .badCode: return "Ask the owner for the 6-character HUB code."
        case .missingHouse: return "No HUB is published for that code yet. On the owner’s iPad open Settings → Invite and wait a few seconds."
        case .iCloud: return "Sign this device into iCloud, then try the code again."
        }
    }
}

enum HouseholdCloud {
    static let containerID = "iCloud.com.corymurray.FamilyHub"
    static let recordType = "HubHousehold"

    private static var database: CKDatabase {
        CKContainer(identifier: containerID).publicCloudDatabase
    }

    private static func recordID(for code: String) -> CKRecord.ID {
        CKRecord.ID(recordName: "hub-\(code.uppercased())")
    }

    static func publish(code: String, data: Data) async throws {
        let clean = code.replacingOccurrences(of: " ", with: "").uppercased()
        guard clean.count == 6 else { throw HouseholdCloudError.badCode }
        let id = recordID(for: clean)
        let record: CKRecord
        if let existing = try? await database.record(for: id) {
            record = existing
        } else {
            record = CKRecord(recordType: recordType, recordID: id)
        }
        record["payload"] = data as CKRecordValue
        record["updatedAt"] = Date() as CKRecordValue
        _ = try await database.save(record)
    }

    static func fetch(code: String) async throws -> Data {
        let clean = code.replacingOccurrences(of: " ", with: "").uppercased()
        guard clean.count == 6 else { throw HouseholdCloudError.badCode }
        do {
            let record = try await database.record(for: recordID(for: clean))
            if let data = record["payload"] as? Data { return data }
            throw HouseholdCloudError.missingHouse
        } catch let error as HouseholdCloudError {
            throw error
        } catch let error as CKError where error.code == .unknownItem {
            throw HouseholdCloudError.missingHouse
        } catch {
            throw HouseholdCloudError.iCloud
        }
    }
}
