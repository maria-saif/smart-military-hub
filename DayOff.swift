import Foundation

struct DayOff: Identifiable, Hashable, Codable {
    var id: UUID = UUID()
    var soldierId: UUID
    var date: Date
}
