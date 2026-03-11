import Foundation

enum DemoData {
    static func nextWeek() -> [Date] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }

    static var defaultTemplates: [ShiftTemplate] = [
        ShiftTemplate(name: "صباحي"),
        ShiftTemplate(name: "مسائي"),
        ShiftTemplate(name: "ليلي")
    ]

    static var sampleSoldiers: [Soldier]? = [
        Soldier(name: "أحمد السالمي", rank: "رقيب", unit: "الكتيبة 1"),
        Soldier(name: "سعيد العوفي", rank: "عريف", unit: "الكتيبة 2"),
        Soldier(name: "مازن الرواحي", rank: "جندي", unit: "الكتيبة 3")
    ]
}
