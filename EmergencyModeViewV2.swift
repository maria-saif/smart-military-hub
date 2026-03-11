import SwiftUI

struct EmergencyModeViewV3: View {
    @State private var soldiers: [Soldier] = []
    @State private var days: [Date] = DemoData.nextDays(3)
    @State private var templates: [ShiftTemplate] = EmergencyDefaultsV2.templates12h
    @State private var daysOff: Set<DayOff> = []

    @State private var constraints = SchedulingConstraints(
        maxHoursPerWeek: 72,
        minRestHoursBetweenShifts: 6,
        avoidNightBias: false
    )

    @State private var staffingLevel: Double = 0.75
    @State private var durationDays: Int = 3
    @State private var use12h: Bool = true

    @State private var result: ScheduleResult?
    @State private var isGenerating = false
    @State private var pdfURL: URL?
    @State private var toast: EmergencyToast? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header

                SettingsCard {
                    SectionHeader("المعلمات السريعة")
                    ValueRow(title: "مستوى التغطية", value: "\(Int(staffingLevel*100))%")
                    LabeledSlider(value: $staffingLevel, range: 0.4...1.0, step: 0.05, minLabel: "40%", maxLabel: "100%")

                    Divider().overlay(.white.opacity(0.08))

                    ValueRow(title: "مدة الجداول", value: "\(durationDays) يوم")
                    StepSlider(current: $durationDays, range: 1...7, step: 1, minLabel: "1", maxLabel: "7")

                    Divider().overlay(.white.opacity(0.08))

                    HStack(spacing: 10) {
                        PillToggle(title: "قوالب 12 ساعة", isOn: $use12h)
                        Spacer()
                        Label(use12h ? "نهار / ليل" : "3 شفتات × 8س", systemImage: "clock.badge.exclamationmark")
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .onChange(of: use12h) { v in
                    templates = v ? EmergencyDefaultsV2.templates12h : EmergencyDefaultsV2.templates8h
                }

                VStack(spacing: 10) {
                    Button(action: generate) {
                        Label("توليد جدول مكثّف", systemImage: "bolt.fill")
                            .font(.headline.weight(.semibold))
                    }
                    .buttonStyle(FilledButtonV2(tint: .orange))
                    .disabled(isGenerating)

                    if let r = result {
                        HStack(spacing: 10) {
                            NavigationLink {
                                AssignmentsView(result: r, soldiers: soldiers, templates: templates)
                            } label: {
                                Label("عرض التعيينات", systemImage: "list.bullet.rectangle")
                            }
                            .buttonStyle(GlassButtonV2())

                            Button(action: exportPDF) {
                                Label("تصدير PDF", systemImage: "doc.richtext")
                            }
                            .buttonStyle(GlassButtonV2())
                        }
                    }
                }

                if let r = result, let k = emergencyKPI(for: r) {
                    KPIGrid(kpi: k)
                } else {
                    InfoCard(icon: "info.circle.fill",
                             text: "اضبط مستوى التغطية والمدة ثم اضغط «توليد جدول مكثّف».")
                }

                if let r = result {
                    AssignmentsSummaryCard(result: r, soldiers: soldiers, templates: templates)
                }

                Spacer(minLength: 24)
            }
            .padding(16)
        }
        .background(
            LinearGradient(colors: [Color(hex: 0x0E1116), Color(hex: 0x101826)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
        )
        .navigationTitle("وضع الطوارئ")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if soldiers.isEmpty { soldiers = DemoData.sampleSoldiers ?? [] }
            days = DemoData.nextDays(durationDays)
        }
        .onChange(of: durationDays) { days = DemoData.nextDays($0) }
        .overlay(alignment: .top) {
            if let toast {
                EmergencyToastView(toast: toast)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.86), value: toast)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "wave.3.right.circle.fill")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(LinearGradient(colors: [.orange, .yellow],
                                                startPoint: .top, endPoint: .bottom))
            Text("تشغيل جدول مكثّف مؤقّت")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
            Spacer()
        }
    }

    private func generate() {
        isGenerating = true
        toast = nil

        let neededCount = max(1, Int(Double(soldiers.count) * staffingLevel))
        let pool = Array(soldiers.prefix(neededCount))

        var emergConstraints = constraints
        emergConstraints.avoidNightBias = !use12h

        DispatchQueue.global(qos: .userInitiated).async {
            let engine = SchedulerEngine()
            let input = SchedulerEngine.Input(
                soldiers: pool,
                days: days,
                templatesPerDay: templates,
                daysOff: daysOff,
                constraints: emergConstraints
            )
            let out = engine.generate(input)
            DispatchQueue.main.async {
                self.result = out
                self.isGenerating = false
                self.toast = .success("تم توليد جدول الطوارئ بنجاح")
            }
        }
    }

    private func exportPDF() {
        guard let r = result else { return }
        let exporter = PDFExporter()
        if let url = exporter.makePDF(schedule: r, soldiers: soldiers, templates: templates) {
            self.pdfURL = url
            self.toast = .success("تم إنشاء ملف PDF")
        } else {
            self.toast = .error("تعذّر إنشاء PDF")
        }
    }

    private func emergencyKPI(for result: ScheduleResult) -> EmergencyKPIV2? {
        guard !result.assignments.isEmpty else { return nil }
        let cal = Calendar.current

        let totalSlots = days.count * templates.count
        let filled = result.assignments.count
        let coverage = Double(filled) / Double(max(1,totalSlots)) * 100.0

        var hoursMap: [UUID: Double] = [:]
        let byTplId = Dictionary(uniqueKeysWithValues: templates.map{ ($0.id, $0) })

        func date(_ day: Date, _ comps: DateComponents) -> Date {
            cal.date(bySettingHour: comps.hour ?? 0, minute: comps.minute ?? 0, second: 0,
                     of: cal.startOfDay(for: day))!
        }
        func dur(_ t: ShiftTemplate) -> Double {
            let s = date(Date(), t.start); let e = date(Date(), t.end)
            let m = cal.dateComponents([.minute], from: s, to: e).minute ?? 0
            return Double(max(0,m)) / 60.0
        }

        for a in result.assignments {
            if let t = byTplId[a.templateId] {
                hoursMap[a.soldierId, default: 0] += dur(t)
            }
        }
        let avgHours = hoursMap.isEmpty ? 0 : hoursMap.values.reduce(0,+) / Double(hoursMap.count)

        return EmergencyKPIV2(coverage: (coverage*10).rounded()/10,
                              avgHours: (avgHours*10).rounded()/10,
                              days: days.count,
                              templatesPerDay: templates.count)
    }
}


private struct SettingsCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .trailing, spacing: 12) {
            content
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(LinearGradient(colors: [.white.opacity(0.06), .white.opacity(0.03)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.12)))
    }
}

private struct SectionHeader: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        HStack {
            Spacer()
            Label(text, systemImage: "bolt.fill")
                .font(.caption.weight(.semibold))
                .padding(.horizontal,10).padding(.vertical,6)
                .background(
                    LinearGradient(colors: [.orange.opacity(0.25), .red.opacity(0.25)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: Capsule()
                )
                .overlay(Capsule().strokeBorder(.white.opacity(0.2)))
                .foregroundStyle(.white)
        }
    }
}

private struct ValueRow: View {
    let title: String
    let value: String
    var body: some View {
        HStack {
            Text(value)
                .font(.headline).monospacedDigit().foregroundStyle(.white)
            Spacer()
            Text(title)
                .font(.subheadline).foregroundStyle(.white.opacity(0.85))
        }
    }
}

private struct LabeledSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let minLabel: String
    let maxLabel: String

    var body: some View {
        VStack(spacing: 6) {
            Slider(value: $value, in: range, step: step).tint(.green)
            HStack {
                Text(minLabel).font(.caption2).foregroundStyle(.white.opacity(0.7))
                Spacer()
                Text(maxLabel).font(.caption2).foregroundStyle(.white.opacity(0.7))
            }
        }
    }
}

private struct StepSlider: View {
    @Binding var current: Int
    let range: ClosedRange<Int>
    let step: Int
    let minLabel: String
    let maxLabel: String

    var body: some View {
        VStack(spacing: 6) {
            Slider(
                value: Binding(
                    get: { Double(current) },
                    set: { current = Int($0.rounded()) }
                ),
                in: Double(range.lowerBound)...Double(range.upperBound),
                step: Double(step)
            ).tint(.blue)
            HStack {
                Text(minLabel).font(.caption2).foregroundStyle(.white.opacity(0.7))
                Spacer()
                Text(maxLabel).font(.caption2).foregroundStyle(.white.opacity(0.7))
            }
        }
    }
}

private struct PillToggle: View {
    let title: String
    @Binding var isOn: Bool
    var body: some View {
        Button { isOn.toggle() } label: {
            HStack(spacing: 6) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                Text(title)
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(.white.opacity(0.08), in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.16)))
            .foregroundStyle(.white)
        }
    }
}

private struct KPIGrid: View {
    let kpi: EmergencyKPIV2
    var body: some View {
        HStack(spacing: 12) {
            StatCardV2(title: "تغطية الشفتات",
                       value: "\(String(format: "%.0f", kpi.coverage))%",
                       system: "shield.checkerboard")
            StatCardV2(title: "متوسط ساعات الفرد",
                       value: "\(String(format: "%.1f س", kpi.avgHours))",
                       system: "clock")
            StatCardV2(title: "المدّة",
                       value: "\(kpi.days)ي / \(kpi.templatesPerDay)ش",
                       system: "calendar")
        }
    }
}

private struct InfoCard: View {
    let icon: String
    let text: String
    var body: some View {
        SettingsCard {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: icon).foregroundStyle(.white.opacity(0.9))
                Text(text).foregroundStyle(.white.opacity(0.92)).font(.callout)
                Spacer()
            }
        }
    }
}

private struct AssignmentsSummaryCard: View {
    let result: ScheduleResult
    let soldiers: [Soldier]
    let templates: [ShiftTemplate]

    var body: some View {
        let byDay = Dictionary(grouping: result.assignments,
                               by: { Calendar.current.startOfDay(for: $0.date) })
            .sorted { $0.key < $1.key }

        VStack(alignment: .trailing, spacing: 10) {
            HStack {
                Spacer()
                Label("موجز التعيينات", systemImage: "list.bullet.clipboard")
                    .font(.headline).foregroundStyle(.white)
            }
            ForEach(byDay, id: \.key) { (day, assigns) in
                SettingsCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(day.formatted(date: .abbreviated, time: .omitted))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        ForEach(assigns, id: \.id) { a in
                            let name = soldiers.first { $0.id == a.soldierId }?.name ?? "—"
                            let tpl  = templates.first { $0.id == a.templateId }?.name ?? "—"
                            HStack {
                                Text(name).foregroundStyle(.white)
                                Spacer()
                                Text(tpl).foregroundStyle(.white.opacity(0.8))
                            }
                            .font(.callout)
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
        }
    }
}

private struct StatCardV2: View {
    let title: String, value: String, system: String
    var body: some View {
        SettingsCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.caption).foregroundStyle(.white.opacity(0.7))
                    Text(value).font(.headline).foregroundStyle(.white)
                }
                Spacer()
                Image(systemName: system).foregroundStyle(.white.opacity(0.9))
            }
        }
    }
}

private struct GlassButtonV2: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .stroke(.white.opacity(configuration.isPressed ? 0.25 : 0.14)))
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

private struct FilledButtonV2: ButtonStyle {
    var tint: Color = .orange
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                LinearGradient(colors: [tint, tint.opacity(0.85)],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .shadow(color: tint.opacity(0.45), radius: 16, y: 10)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}


#if DEBUG
#Preview {
    NavigationStack {
        EmergencyModeViewV3()
            .environment(\.layoutDirection, .rightToLeft)
    }
    .preferredColorScheme(.dark)
}
#endif
