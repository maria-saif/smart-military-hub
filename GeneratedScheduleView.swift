import SwiftUI

struct GeneratedScheduleView: View {
    let result: ScheduleResult
    let soldiers: [Soldier]
    let templates: [ShiftTemplate]
    let days: [Date]

    private let grid = [GridItem(.flexible()), GridItem(.flexible())]
    private let cal = Calendar.current

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color(hex: 0x0E1116), Color(hex: 0x1A2332)]),
                startPoint: .topLeading, endPoint: .bottomTrailing
            ).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    header

                    LazyVGrid(columns: grid, spacing: 16) {
                        ForEach(days, id: \.self) { day in
                            dayCard(for: day)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
                .padding(.vertical, 16)
            }
        }
        .navigationTitle("الجدول المُولد")
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.layoutDirection, .rightToLeft)
    }

    private var header: some View {
        VStack(alignment: .trailing, spacing: 6) {
            Text("الجدول المُولد").font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.45), radius: 10, y: 6)
            Text("عرض جميع الشفتات لكل يوم").font(.callout.weight(.medium))
                .foregroundStyle(.white.opacity(0.75))
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.horizontal, 16)
    }

    private func dayCard(for day: Date) -> some View {
        VStack(alignment: .trailing, spacing: 10) {
            Text(day.formatted(.dateTime.day().month(.abbreviated)))
                .font(.headline.weight(.semibold))
                .foregroundColor(.white)

            Divider().background(.white.opacity(0.2))

            let dayAssignments = assignments(for: day)

            ForEach(dayAssignments, id: \.id) { assign in
                HStack {
                    if let soldier = soldiers.first(where: { $0.id == assign.soldierId }),
                       let template = templates.first(where: { $0.id == assign.templateId }) {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(soldier.name).font(.subheadline.weight(.bold)).foregroundColor(.white)
                            Text("\(soldier.rank) • \(soldier.unit)").font(.caption).foregroundColor(.white.opacity(0.7))
                            Text("\(template.name) • \(formattedTime(template: template))")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.6))
                        }
                        Spacer()
                        Image(systemName: template.isNight ? "moon.fill" : "sun.max.fill")
                            .foregroundColor(template.isNight ? .yellow : .orange)
                    }
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.08)))
            }

            if dayAssignments.isEmpty {
                Text("لا توجد شفتات لهذا اليوم")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
                    .padding(8)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 18)
            .fill(Color.black.opacity(0.28))
            .shadow(color: .black.opacity(0.35), radius: 12, y: 6))
    }

    private func assignments(for day: Date) -> [ScheduleResult.Assignment] {
        result.assignments.filter { cal.isDate($0.date, inSameDayAs: day) }
    }

    private func formattedTime(template: ShiftTemplate) -> String {
        let df = DateFormatter()
        df.dateFormat = "HH:mm"
        let start = cal.date(bySettingHour: template.start.hour ?? 0,
                             minute: template.start.minute ?? 0,
                             second: 0,
                             of: Date()) ?? Date()
        let end = cal.date(bySettingHour: template.end.hour ?? 0,
                           minute: template.end.minute ?? 0,
                           second: 0,
                           of: Date()) ?? Date()
        return "\(df.string(from: start)) - \(df.string(from: end))"
    }
}

#Preview {
    let soldiers = [
        Soldier(id: UUID(), name: "أحمد", rank: "جندي", unit: "الفوج 1"),
        Soldier(id: UUID(), name: "سلمان", rank: "عريف", unit: "الفوج 2"),
        Soldier(id: UUID(), name: "فاطمة", rank: "رقيب", unit: "الفوج 1")
    ]

    let templates = [
        ShiftTemplate(id: UUID(), name: "صباحي", start: DateComponents(hour: 8), end: DateComponents(hour: 14), isNight: false),
        ShiftTemplate(id: UUID(), name: "مسائي", start: DateComponents(hour: 14), end: DateComponents(hour: 20), isNight: false),
        ShiftTemplate(id: UUID(), name: "ليلي", start: DateComponents(hour: 20), end: DateComponents(hour: 4), isNight: true)
    ]

    let today = Date()
    let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
    let days = [today, tomorrow]

    let assignments = [
        ScheduleResult.Assignment(id: UUID(), date: today, soldierId: soldiers[0].id, templateId: templates[0].id),
        ScheduleResult.Assignment(id: UUID(), date: today, soldierId: soldiers[1].id, templateId: templates[1].id),
        ScheduleResult.Assignment(id: UUID(), date: today, soldierId: soldiers[2].id, templateId: templates[2].id),
        ScheduleResult.Assignment(id: UUID(), date: tomorrow, soldierId: soldiers[0].id, templateId: templates[1].id)
    ]

    let result = ScheduleResult(assignments: assignments)

    GeneratedScheduleView(result: result, soldiers: soldiers, templates: templates, days: days)
}
