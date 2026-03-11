import Foundation

final class SchedulerEngine {
    struct Input {
        var soldiers: [Soldier]
        var days: [Date]
        var templatesPerDay: [ShiftTemplate]
        var daysOff: Set<DayOff>
        var constraints: SchedulingConstraints
    }

    func generate(_ input: Input) -> ScheduleResult {
        var result = ScheduleResult(assignments: [])

        guard
            let first = input.soldiers.first,
            let firstTpl = input.templatesPerDay.first
        else { return result }

        let cal = Calendar.current

        for d in input.days {
            let isOff = input.daysOff.contains { off in
                off.soldierId == first.id && cal.isDate(off.date, inSameDayAs: d)
            }

            if !isOff {
                result.assignments.append(
                    ScheduleResult.Assignment(
                        date: d,
                        soldierId: first.id,
                        templateId: firstTpl.id
                    )
                )
            }
        }

        return result
    }
}
