import Foundation
import Security

enum HubKeychain {
    private static let service = "com.corymurray.FamilyHub.twilio"

    /// Drops any sender secrets left from the removed text path.
    static func deleteTwilio() {
        for account in ["sid", "token", "from"] {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account,
            ]
            SecItemDelete(query as CFDictionary)
        }
    }
}
