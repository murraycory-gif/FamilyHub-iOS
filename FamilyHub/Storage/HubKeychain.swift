import Foundation
import Security

enum HubKeychain {
    private static let service = "com.corymurray.FamilyHub.twilio"

    struct Twilio: Equatable {
        var sid: String
        var token: String
        var from: String

        var isEmpty: Bool { sid.isEmpty && token.isEmpty && from.isEmpty }
    }

    static func loadTwilio() -> Twilio {
        Twilio(sid: read("sid") ?? "", token: read("token") ?? "", from: read("from") ?? "")
    }

    static func saveTwilio(_ value: Twilio) {
        write("sid", value.sid)
        write("token", value.token)
        write("from", value.from)
    }

    private static let placesService = "com.corymurray.FamilyHub.places"

    static func loadPlacesPhotoKey() -> String {
        read("google", service: placesService) ?? ""
    }

    static func savePlacesPhotoKey(_ value: String) {
        write("google", value.trimmingCharacters(in: .whitespacesAndNewlines), service: placesService)
    }

    private static func read(_ account: String, service: String = HubKeychain.service) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data
        else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func write(_ account: String, _ value: String, service: String = HubKeychain.service) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
        guard !value.isEmpty else { return }
        var add = query
        add[kSecValueData as String] = Data(value.utf8)
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(add as CFDictionary, nil)
    }
}
