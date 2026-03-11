import Foundation

public struct ScheduleResult: Identifiable, Hashable, Codable {
    public struct Assignment: Identifiable, Hashable, Codable {
        public var id: UUID = UUID()
        public var date: Date
        public var soldierId: UUID
        public var templateId: UUID

        public init(id: UUID = UUID(), date: Date, soldierId: UUID, templateId: UUID) {
            self.id = id
            self.date = date
            self.soldierId = soldierId
            self.templateId = templateId
        }
    }

    public var id: UUID = UUID()
    public var assignments: [Assignment] = []

    public init(id: UUID = UUID(), assignments: [Assignment] = []) {
        self.id = id
        self.assignments = assignments
    }
}
