import Foundation

struct ShiftTemplate: Identifiable, Hashable, Codable {
    var id: UUID
    var name: String
    var start: DateComponents
    var end: DateComponents
    var minSoldiers: Int
    var isNight: Bool

    init(id: UUID = UUID(),
         name: String,
         start: DateComponents = DateComponents(hour: 8, minute: 0),
         end: DateComponents = DateComponents(hour: 16, minute: 0),
         minSoldiers: Int = 2,
         isNight: Bool = false) {
        self.id = id
        self.name = name
        self.start = start
        self.end = end
        self.minSoldiers = minSoldiers
        self.isNight = isNight
    }
}
