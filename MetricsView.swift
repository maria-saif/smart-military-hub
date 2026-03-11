import SwiftUI

struct MetricsView: View {
    var result: ScheduleResult
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("التكليفات: \(result.assignments.count)")
            Text("أيام مغطاة: \(Set(result.assignments.map { Calendar.current.startOfDay(for: $0.date) }).count)")
        }
        .font(.subheadline)
    }
}

