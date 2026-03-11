import Foundation

enum Role: String, Codable, CaseIterable, Identifiable {
    case commander = "قائد"
    case soldier   = "جندي"
    var id: String { rawValue }
}

struct SMHLocalUser: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var serviceId: String
    var name: String
    var role: Role
    var rank: String?
    var email: String?
    var phone: String?
    var unitMeta: String?
    var biometricEnabled: Bool
    var passwordHash: String
    var passwordSalt: String
    var createdAt: Date = Date()
    var lastLoginAt: Date? = nil
    var points: Int? = nil

    init(
        serviceId: String,
        name: String,
        role: Role,
        rank: String? = nil,
        email: String? = nil,
        phone: String? = nil,
        unitMeta: String? = nil,
        biometricEnabled: Bool = false,
        passwordHash: String,
        passwordSalt: String
    ) {
        self.serviceId = serviceId
        self.name = name
        self.role = role
        self.rank = rank
        self.email = email
        self.phone = phone
        self.unitMeta = unitMeta
        self.biometricEnabled = biometricEnabled
        self.passwordHash = passwordHash
        self.passwordSalt = passwordSalt
    }
}

typealias LocalUser = SMHLocalUser
