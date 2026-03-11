import Foundation
import FirebaseFirestore

struct SoldierDTO: Codable, Identifiable {
    var id: String?

    var uid: String?
    var fullName: String
    var militaryId: String?
    var rank: String
    var unit: String?
    var phone: String?
    var skills: [String]?
    var role: String? = "soldier"
    var createdAt: Date?
    var updatedAt: Date?
}
