import Foundation

struct Soldier: Identifiable, Hashable, Codable {
    var id: UUID
    var name: String
    var rank: String
    var unit: String

    init(id: UUID = UUID(), name: String, rank: String, unit: String) {
        self.id = id
        self.name = name
        self.rank = rank
        self.unit = unit
    }
}

