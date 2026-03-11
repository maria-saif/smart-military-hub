import Foundation
import Security

enum Keychain {

    static func set(_ value: String, forKey key: String) throws {
        let data = Data(value.utf8)
        _ = try? delete(key)

        let query: [String: Any] = [
            kSecClass as String:                  kSecClassGenericPassword,
            kSecAttrAccount as String:            key,
            kSecAttrService as String:            "com.smh.credentials",
            kSecAttrAccessible as String:         kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String:              data
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NSError(
                domain: NSOSStatusErrorDomain,
                code: Int(status),
                userInfo: [NSLocalizedDescriptionKey: "Keychain set failed (\(status))"]
            )
        }
    }

    static func get(_ key: String) throws -> String {
        let query: [String: Any] = [
            kSecClass as String:                  kSecClassGenericPassword,
            kSecAttrAccount as String:            key,
            kSecAttrService as String:            "com.smh.credentials",
            kSecMatchLimit as String:             kSecMatchLimitOne,
            kSecReturnData as String:             true
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let str = String(data: data, encoding: .utf8) else {
            throw NSError(
                domain: NSOSStatusErrorDomain,
                code: Int(status),
                userInfo: [NSLocalizedDescriptionKey: "Keychain get failed (\(status))"]
            )
        }
        return str
    }

    @discardableResult
    static func delete(_ key: String) throws -> Bool {
        let query: [String: Any] = [
            kSecClass as String:                  kSecClassGenericPassword,
            kSecAttrAccount as String:            key,
            kSecAttrService as String:            "com.smh.credentials"
        ]
        let status = SecItemDelete(query as CFDictionary)
        if status == errSecSuccess || status == errSecItemNotFound { return true }
        throw NSError(
            domain: NSOSStatusErrorDomain,
            code: Int(status),
            userInfo: [NSLocalizedDescriptionKey: "Keychain delete failed (\(status))"]
        )
    }

    static func exists(_ key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String:                  kSecClassGenericPassword,
            kSecAttrAccount as String:            key,
            kSecAttrService as String:            "com.smh.credentials",
            kSecMatchLimit as String:             kSecMatchLimitOne,
            kSecReturnData as String:             false
        ]
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }
}
