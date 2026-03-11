import SwiftUI

struct DailyTemplatesView: View {
    @Binding var templates: [ShiftTemplate]
    @State private var showAdd = false

    var body: some View {
        List {
            Section("القوالب اليومية") {
                ForEach(templates) { t in
                    templateRow(t)
                }
                .onDelete { offsets in
                    templates.remove(atOffsets: offsets)
                }
            }
        }
        .navigationTitle("القوالب اليومية")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                EditButton()
                Button(action: {
                    templates.append(
                        ShiftTemplate(
                            id: UUID(),
                            name: "جديد",
                            start: DateComponents(hour: 8, minute: 0),
                            end:   DateComponents(hour: 16, minute: 0),
                            minSoldiers: 2,
                            isNight: false
                        )
                    )
                }) {
                    Image(systemName: "plus")
                }
            }
        }
    }

    @ViewBuilder
    private func templateRow(_ t: ShiftTemplate) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(t.name).font(.headline)
                Spacer()
                Text(timeText(t.start))
                Text("→")
                Text(timeText(t.end)).foregroundStyle(.secondary)
            }
            Text("الحد الأدنى للجنود: \(t.minSoldiers)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func timeText(_ dc: DateComponents) -> String {
        let h = dc.hour ?? 0
        let m = dc.minute ?? 0
        return String(format: "%d:%02d", h, m)
    }
}

#Preview {
    DailyTemplatesView(templates: .constant([
        ShiftTemplate(
            id: UUID(),
            name: "صباحي",
            start: DateComponents(hour: 6, minute: 0),
            end: DateComponents(hour: 14, minute: 0),
            minSoldiers: 3,
            isNight: false
        ),
        ShiftTemplate(
            id: UUID(),
            name: "مسائي",
            start: DateComponents(hour: 14, minute: 0),
            end: DateComponents(hour: 22, minute: 0),
            minSoldiers: 3,
            isNight: false
        )
    ]))
}
