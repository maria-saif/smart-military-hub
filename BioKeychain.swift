import Foundation
import LocalAuthentication
import Security

enum BioKeychain {
    static let service = "com.smh.credentials"

    // MARK: - Store securely
    static func setProtected(_ value: String, forKey key: String) throws {
        #if targetEnvironment(simulator)
        print("⚠️ Skipping biometric save in simulator.")
        return
        #endif

        let access = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            [.biometryCurrentSet, .userPresence],
            nil
        )!

        let del: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(del as CFDictionary)

        let ctx = LAContext()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: Data(value.utf8),
            kSecAttrAccessControl as String: access,
            kSecUseAuthenticationContext as String: ctx
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
    }

    // MARK: - Retrieve securely
    static func getProtected(_ key: String, prompt: String) throws -> String {
        #if targetEnvironment(simulator)
        print("⚠️ Skipping biometric read in simulator.")
        return "simulator_placeholder"
        #endif

        let ctx = LAContext()
        ctx.localizedReason = prompt

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecUseOperationPrompt as String: prompt,
            kSecUseAuthenticationContext as String: ctx
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let str = String(data: data, encoding: .utf8) else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
        return str
    }

    // MARK: - Delete
    static func delete(_ key: String) {
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(q as CFDictionary)
    }
}
