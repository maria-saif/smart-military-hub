import Foundation
import CryptoKit
import Security

final class DatabaseManager {

    static let shared = DatabaseManager()

    private var users: [String: LocalUser] = [:]
    private var otps: [String: (code: String, expiresAt: Date)] = [:]

    private init() {}

    func openIfNeeded() throws {
    }

    // Password Hashing
    func hashPassword(_ plain: String, saltBase64: String) -> String {
        let saltData = Data(base64Encoded: saltBase64) ?? Data()
        let data = Data(plain.utf8) + saltData
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }

    private func makeSalt() -> String {
        var bytes = [UInt8](repeating: 0, count: 16)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
    }

    // Users
    func saveUser(
        name: String,
        serviceId: String,
        role: Role,
        rank: String?,
        email: String?,
        phone: String?,
        unitMeta: String?,
        biometricEnabled: Bool,
        plainPassword: String
    ) throws {
        guard users[serviceId] == nil else {
            throw NSError(domain: "DB", code: 1, userInfo: [NSLocalizedDescriptionKey: "User exists"])
        }
        let salt = makeSalt()
        let hash = hashPassword(plainPassword, saltBase64: salt)

        let user = LocalUser(
            serviceId: serviceId,
            name: name,
            role: role,
            rank: rank,
            email: email,
            phone: phone,
            unitMeta: unitMeta,
            biometricEnabled: biometricEnabled,
            passwordHash: hash,
            passwordSalt: salt
        )
        users[serviceId] = user
    }

    func getUserByServiceId(_ serviceId: String) throws -> LocalUser? {
        users[serviceId]
    }

    func getAllUsers() throws -> [LocalUser] {
        Array(users.values).sorted { $0.name < $1.name }
    }


    func setOTP(for serviceId: String, code: String, ttlSeconds: Int) throws {
        let expiry = Date().addingTimeInterval(TimeInterval(ttlSeconds))
        otps[serviceId] = (code, expiry)
    }

    func consumeOTP(serviceId: String, code: String) throws -> Bool {
        guard let entry = otps[serviceId] else { return false }
        guard Date() <= entry.expiresAt else {
            otps.removeValue(forKey: serviceId)
            return false
        }
        let ok = (entry.code == code)
        if ok { otps.removeValue(forKey: serviceId) }
        return ok
    }
}
