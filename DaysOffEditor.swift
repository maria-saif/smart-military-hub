import SwiftUI

struct DaysOffEditor: View {
    var soldiers: [Soldier]
    var days: [Date]
    @Binding var daysOff: Set<DayOff>

    @State private var query: String = ""
    @State private var showSaveAlert = false

    private let grid = [GridItem(.adaptive(minimum: 86), spacing: 10)]

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.07, green: 0.09, blue: 0.18),
                        Color(red: 0.14, green: 0.18, blue: 0.28),
                        Color(red: 0.05, green: 0.06, blue: 0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                List {
                    ForEach(filteredSoldiers) { s in
                        Section {
                            ForEach(monthGroups.sorted(by: { $0.key < $1.key }), id: \.key) { monthStart, monthDays in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text(monthTitle(monthStart))
                                            .font(.headline)
                                            .foregroundStyle(.white.opacity(0.7))
                                        Spacer()
                                        Menu {
                                            Button("تحديد كل أيام هذا الشهر", systemImage: "checkmark.circle") {
                                                setAll(true, for: s, in: monthDays)
                                            }
                                            Button("إلغاء التحديد للشهر", systemImage: "xmark.circle") {
                                                setAll(false, for: s, in: monthDays)
                                            }
                                        } label: {
                                            Label("إجراءات", systemImage: "slider.horizontal.3")
                                                .foregroundColor(.white.opacity(0.8))
                                        }
                                    }

                                    LazyVGrid(columns: grid, spacing: 10) {
                                        ForEach(monthDays, id: \.self) { d in
                                            let key = DayOff(soldierId: s.id, date: d)
                                            Toggle(isOn: binding(for: key)) {
                                                DayChipContent(date: d)
                                            }
                                            .toggleStyle(CheckmarkCardToggleStyle())
                                        }
                                    }
                                    .padding(.top, 4)
                                }
                                .listRowBackground(Color.clear)
                            }
                        } header: {
                            SoldierHeader(
                                soldier: s,
                                selectedCount: selectedCount(for: s),
                                totalCount: days.count
                            )
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .listStyle(.insetGrouped)
            }
            .navigationTitle("إدارة الإجازات")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        withAnimation {
                            showSaveAlert = true
                        }
                    } label: {
                        Label("حفظ", systemImage: "tray.and.arrow.down.fill")
                            .labelStyle(.titleAndIcon)
                    }
                    .tint(.green)
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "ابحث باسم الجندي")
            .alert("تم الحفظ بنجاح ✅", isPresented: $showSaveAlert) {
                Button("موافق", role: .cancel) { }
            }
        }
    }


    private var filteredSoldiers: [Soldier] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return soldiers }
        return soldiers.filter { $0.name.localizedStandardContains(q) }
    }

    private var monthGroups: [Date: [Date]] {
        let cal = Calendar.current
        let normalized = days.map { cal.startOfDay(for: $0) }
        return Dictionary(grouping: normalized) { date in
            cal.date(from: cal.dateComponents([.year, .month], from: date))!
        }
    }

    private func monthTitle(_ monthStart: Date) -> String {
        monthStart.formatted(.dateTime.year(.defaultDigits).month(.wide))
    }

    private func binding(for key: DayOff) -> Binding<Bool> {
        Binding(
            get: { daysOff.contains(key) },
            set: { newValue in
                if newValue { daysOff.insert(key) } else { daysOff.remove(key) }
            }
        )
    }

    private func selectedCount(for soldier: Soldier) -> Int {
        daysOff.filter { $0.soldierId == soldier.id }.count
    }

    private func setAll(_ value: Bool, for soldier: Soldier, in dates: [Date]) {
        var updated = daysOff
        for d in dates {
            let key = DayOff(soldierId: soldier.id, date: d)
            if value { updated.insert(key) } else { updated.remove(key) }
        }
        daysOff = updated
    }

    private func accessibilityFor(date: Date, soldier: Soldier) -> String {
        let d = date.formatted(.dateTime.day().month(.wide).year())
        return "إجازة \(soldier.name) في \(d)"
    }
}

private struct SoldierHeader: View {
    var soldier: Soldier
    var selectedCount: Int
    var totalCount: Int

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(LinearGradient(
                    colors: [Color.cyan.opacity(0.9), Color.blue.opacity(0.7)],
                    startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .frame(width: 40, height: 40)
                .overlay(
                    Text(initials(from: soldier.name))
                        .font(.headline.bold())
                        .foregroundColor(.white)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(soldier.name)
                    .font(.headline)
                    .foregroundColor(.white)
                HStack(spacing: 6) {
                    if !soldier.rank.isBlank {
                        Text(soldier.rank)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    if !soldier.unit.isBlank {
                        Text("• \(soldier.unit)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }

            Spacer()

            HStack(spacing: 6) {
                Image(systemName: "calendar.badge.checkmark")
                    .foregroundColor(.green)
                Text("\(selectedCount)/\(totalCount)")
                    .font(.subheadline)
                    .foregroundColor(.green)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
        }
        .padding(.vertical, 6)
    }

    private func initials(from name: String) -> String {
        let parts = name.split(separator: " ").prefix(2)
        return parts.map { String($0.prefix(1)) }.joined()
    }
}

private extension String {
    var isBlank: Bool {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

private struct DayChipContent: View {
    let date: Date
    var body: some View {
        VStack(spacing: 6) {
            Text(date.formatted(.dateTime.day()))
                .font(.title3.bold())
                .foregroundColor(.white)
            Text(date.formatted(.dateTime.month(.abbreviated)))
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, minHeight: 70)
        .contentShape(Rectangle())
    }
}

private struct CheckmarkCardToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                configuration.isOn.toggle()
            }
        } label: {
            configuration.label
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(configuration.isOn ?
                              LinearGradient(colors: [Color.green.opacity(0.3), Color.green.opacity(0.1)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing)
                              : LinearGradient(colors: [Color.white.opacity(0.08), Color.white.opacity(0.02)],
                                               startPoint: .topLeading, endPoint: .bottomTrailing))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(configuration.isOn ? Color.green.opacity(0.8) : Color.white.opacity(0.2),
                                lineWidth: 1.3)
                )
                .overlay(alignment: .topLeading) {
                    if configuration.isOn {
                        Image(systemName: "checkmark.seal.fill")
                            .imageScale(.small)
                            .foregroundColor(.green)
                            .padding(6)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .shadow(color: configuration.isOn ? Color.green.opacity(0.3) : Color.black.opacity(0.2),
                        radius: 10, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }
}
