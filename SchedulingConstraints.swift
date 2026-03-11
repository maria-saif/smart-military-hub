import Foundation

struct SchedulingConstraints: Hashable, Codable {
    var maxHoursPerWeek: Int
    var minRestHoursBetweenShifts: Int
    var avoidNightBias: Bool
}
