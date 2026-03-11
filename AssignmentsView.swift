import SwiftUI

struct AssignmentsView: View {
    let result: ScheduleResult
    let soldiers: [Soldier]
    let templates: [ShiftTemplate]

    private func soldierName(for soldierId: UUID) -> String {
        soldiers.first(where: { $0.id == soldierId })?.name ?? soldierId.uuidString
    }

    private func templateName(for templateId: UUID) -> String {
        templates.first(where: { $0.id == templateId })?.name ?? "غير محدد"
    }

    var body: some View {
        List {
            ForEach(result.assignments) { a in
                VStack(alignment: .leading, spacing: 6) {
                    Text(soldierName(for: a.soldierId))
                        .font(.headline)

                    Text(templateName(for: a.templateId))
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text(a.date, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("التعيينات")
    }
}
