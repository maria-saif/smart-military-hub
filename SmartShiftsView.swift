import SwiftUI

private let rosterReadinessNotification = Notification.Name("rosterReadinessUpdated")

struct SmartShiftsView: View {
    @State private var soldiers: [Soldier] = []
    @State private var days: [Date] = DemoData.nextWeek()
    @State private var templates: [ShiftTemplate] = DemoData.defaultTemplates
    @State private var daysOff: Set<DayOff> = []
    @State private var constraints = SchedulingConstraints(
        maxHoursPerWeek: 48,
        minRestHoursBetweenShifts: 8,
        avoidNightBias: true
    )

    @State private var result: ScheduleResult?
    @State private var isGenerating = false
    @State private var pdfURL: URL?

    private let grid = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [Color(hex: 0x0E1116), Color(hex: 0x1A2332)]),
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                RadialGradient(
                    gradient: Gradient(colors: [Color(hex: 0x22C55E).opacity(0.18), .clear]),
                    center: .topTrailing, startRadius: 16, endRadius: 520
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 18) {

                        FancyHeader(title: "المناوبات الذكية",
                                    subtitle: "تخطيط مرن • تحكم كامل")

                        LazyVGrid(columns: grid, spacing: 14) {

                            ZstackCard(icon: "slider.horizontal.3",
                                       title: "الأوامر / القيود",
                                       subtitle: "سياسات وقيود التوزيع",
                                       tint: Color(hex: 0x10B981)) {
                                PoliciesConstraintsView(constraints: $constraints)
                            }

                            ZstackCard(icon: "calendar.badge.clock",
                                       title: "القوالب اليومية",
                                       subtitle: "تعريف الشفتات",
                                       tint: Color(hex: 0x6366F1)) {
                                DailyTemplatesView(templates: $templates)
                            }

                            ZstackCard(icon: "person.3.fill",
                                       title: "الجنود",
                                       subtitle: "إدارة الأفراد",
                                       tint: Color(hex: 0x34D399)) {
                                SoldiersEditor(soldiers: $soldiers)
                            }

                            ZstackCard(icon: "beach.umbrella.fill",
                                       title: "الإجازات",
                                       subtitle: "طلبات وأيام الراحة",
                                       tint: Color(hex: 0x06B6D4)) {
                                LeaveRequestsView(soldiers: soldiers,
                                                  days: days,
                                                  daysOff: $daysOff)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 4)

                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 10) {
                                Image(systemName: "chart.bar.fill")
                                    .font(.title2.bold())
                                    .foregroundColor(.white)
                                Text("ملخص الجدولة")
                                    .font(.title3.weight(.semibold))
                                    .foregroundColor(.white)
                            }
                            if let r = result,
                               let m = computeRosterMetrics(result: r,
                                                            soldiers: soldiers,
                                                            templates: templates,
                                                            constraints: constraints,
                                                            days: days) {
                                RosterSummaryView(metrics: m)
                                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                                    .foregroundStyle(.white)
                            } else {
                                Text("لم يتم توليد جدول بعد. اضغط «توليد الجدول» بالأسفل.")
                                    .font(.callout.weight(.medium))
                                    .foregroundColor(.white.opacity(0.92))
                            }
                        }
                        .padding(16)
                        .background(
                            LinearGradient(colors: [Color(hex: 0x10B981),
                                                    Color(hex: 0x059669)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .overlay(RoundedRectangle(cornerRadius: 18)
                            .strokeBorder(.white.opacity(0.12), lineWidth: 1))
                        .cornerRadius(18)
                        .shadow(color: .black.opacity(0.35), radius: 20, y: 12)
                        .padding(.horizontal, 16)

                        DateRangePills(days: $days)
                            .padding(10)
                            .background(Color.white.opacity(0.08),
                                        in: RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(.white.opacity(0.15)))
                            .padding(.horizontal, 16)

                        VStack(spacing: 12) {
                            Button {
                                generate()
                                Haptics.soft()
                            } label: {
                                HStack(spacing: 10) {
                                    if isGenerating { ProgressView().tint(.white) }
                                    Text(isGenerating ? "جارٍ التوليد..." : "توليد الجدول")
                                        .font(.headline.weight(.semibold))
                                        .foregroundColor(.white)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                            }
                            .buttonStyle(NeonProminent(tint: Color(hex: 0x2563EB)))
                            .disabled(isGenerating)

                            if let r = result {
                                HStack(spacing: 10) {
                                    NavigationLink {
                                        AssignmentsView(result: r,
                                                        soldiers: soldiers,
                                                        templates: templates)
                                    } label: {
                                        Label("عرض الجدول",
                                              systemImage: "list.bullet.rectangle")
                                            .font(.subheadline.weight(.semibold))
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 14)
                                    }
                                    .buttonStyle(GlassBordered())

                                    Button {
                                        exportPDF()
                                        Haptics.light()
                                    } label: {
                                        Label("تصدير PDF", systemImage: "doc.richtext")
                                            .font(.subheadline.weight(.semibold))
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 14)
                                    }
                                    .buttonStyle(GlassBordered())
                                }
                            }

                            if let url = pdfURL {
                                ShareLink(item: url,
                                          preview: SharePreview("جدول المناوبات",
                                                                image: Image(systemName: "doc.richtext")))
                                .tint(.white)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            HStack(spacing: 6) {
                                Image(systemName: "shield.lefthalf.filled")
                                    .foregroundStyle(Color(hex: 0x22C55E))
                                Text("S.M.H")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.primary)
                            }
                            .padding(.horizontal, 10)
                        )
                        .frame(height: 28)
                }
            }
            .environment(\.layoutDirection, .rightToLeft)
            .onAppear {
                if soldiers.isEmpty { soldiers = DemoData.sampleSoldiers ?? [] }
            }
        }
    }

    private func generate() {
        isGenerating = true
        DispatchQueue.global(qos: .userInitiated).async {
            let engine = SchedulerEngine()
            let input = SchedulerEngine.Input(
                soldiers: soldiers,
                days: days,
                templatesPerDay: templates,
                daysOff: daysOff,
                constraints: constraints
            )
            let out = engine.generate(input)
            DispatchQueue.main.async {
                self.result = out
                self.isGenerating = false

                if let m = computeRosterMetrics(result: out,
                                                soldiers: self.soldiers,
                                                templates: self.templates,
                                                constraints: self.constraints,
                                                days: self.days) {
                    NotificationCenter.default.post(
                        name: rosterReadinessNotification,
                        object: nil,
                        userInfo: [
                            "readiness": m.readinessScore,
                            "restPct": m.restPct,
                            "hoursPct": m.hoursPct,
                            "nightStd": m.nightStd,
                            "conflicts": m.conflicts
                        ]
                    )
                }
            }
        }
    }

    private func exportPDF() {
        guard let r = result else { return }
        let exporter = PDFExporter()
        if let url = exporter.makePDF(schedule: r,
                                      soldiers: soldiers,
                                      templates: templates) {
            self.pdfURL = url
        }
    }

    private func computeRosterMetrics(
        result: ScheduleResult,
        soldiers: [Soldier],
        templates: [ShiftTemplate],
        constraints: SchedulingConstraints,
        days: [Date]
    ) -> (nightStd: Double, restPct: Double, hoursPct: Double,
          conflicts: Int, readinessScore: Double)? {

        guard !result.assignments.isEmpty, !soldiers.isEmpty else { return nil }

        let cal = Calendar.current
        let activeIds = Set(soldiers.map(\.id))
        let tplById = Dictionary(uniqueKeysWithValues: templates.map { ($0.id, $0) })

        let startDay = cal.startOfDay(for: days.first ?? Date())
        let endDay = cal.date(byAdding: .day, value: 1,
                              to: cal.startOfDay(for: days.last ?? Date()))!
        let assigns = result.assignments.filter { a in
            activeIds.contains(a.soldierId) && a.date >= startDay && a.date < endDay
        }

        let nightCounts: [UUID: Int] = Dictionary(
            grouping: assigns.filter { tplById[$0.templateId]?.isNight == true },
            by: \.soldierId
        ).mapValues { $0.count }

        let vec = soldiers.map { Double(nightCounts[$0.id] ?? 0) }
        let mean = vec.reduce(0,+) / Double(max(1, vec.count))
        let variance = vec.map { pow($0 - mean, 2) }.reduce(0,+) / Double(max(1, vec.count))
        let nightStd = sqrt(variance)

        func date(_ day: Date, _ comps: DateComponents) -> Date {
            cal.date(bySettingHour: comps.hour ?? 0,
                     minute: comps.minute ?? 0,
                     second: 0,
                     of: cal.startOfDay(for: day))!
        }
        func hours(for t: ShiftTemplate) -> Double {
            let s = date(Date(), t.start)
            let e = date(Date(), t.end)
            let minutes = cal.dateComponents([.minute], from: s, to: e).minute ?? 0
            return max(0, Double(minutes)) / 60.0
        }

        var okRest = 0, edges = 0
        let grouped = Dictionary(grouping: assigns, by: \.soldierId)
        for (_, arr) in grouped {
            let sorted = arr.sorted { l, r in
                guard let lt = tplById[l.templateId],
                      let rt = tplById[r.templateId] else { return l.date < r.date }
                return date(l.date, lt.start) < date(r.date, rt.start)
            }
            for i in 1..<sorted.count {
                edges += 1
                guard let prev = tplById[sorted[i-1].templateId],
                      let cur  = tplById[sorted[i].templateId] else { continue }
                let prevEnd  = date(sorted[i-1].date, prev.end)
                let curStart = date(sorted[i].date, cur.start)
                if let hrs = cal.dateComponents([.hour], from: prevEnd, to: curStart).hour,
                   Double(hrs) >= Double(constraints.minRestHoursBetweenShifts) {
                    okRest += 1
                }
            }
        }
        let restPct = edges == 0 ? 100.0 : (Double(okRest) / Double(edges)) * 100.0

        var hoursPer: [UUID: Double] = [:]
        for a in assigns {
            if let t = tplById[a.templateId] {
                hoursPer[a.soldierId, default: 0] += hours(for: t)
            }
        }
        let withinMax = soldiers.filter {
            (hoursPer[$0.id] ?? 0) <= Double(constraints.maxHoursPerWeek)
        }.count
        let hoursPct = Double(withinMax) / Double(soldiers.count) * 100.0

        let conflicts = 0

        let fairnessScore = max(0, 100 - min(100, (nightStd/2.0) * 100))
        let conflictsScore = (conflicts == 0) ? 100.0 : 0.0
        let readiness = fairnessScore*0.4 + restPct*0.3 + hoursPct*0.2 + conflictsScore*0.1
        let readinessClamped = max(0, min(100, readiness))

        return (nightStd,
                restPct.rounded(),
                hoursPct.rounded(),
                conflicts,
                readinessClamped.rounded())
    }
}

private struct ZstackCard<Destination: View>: View {
    let icon: String, title: String, subtitle: String, tint: Color
    let destination: Destination
    init(icon: String, title: String, subtitle: String, tint: Color,
         @ViewBuilder destination: () -> Destination) {
        self.icon = icon; self.title = title; self.subtitle = subtitle
        self.tint = tint; self.destination = destination()
    }
    var body: some View {
        ZStack { DashboardCard(title: title, subtitle: subtitle, systemIcon: icon) { destination } }
            .glassCard().iconAccent(tint)
    }
}

private struct FancyHeader: View {
    let title: String; let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.45), radius: 10, y: 8)
            Text(subtitle).font(.callout.weight(.medium))
                .foregroundStyle(.white.opacity(0.75))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16).padding(.top, 8)
    }
}

private struct DashboardCard<Destination: View>: View {
    let title: String, subtitle: String, systemIcon: String
    let destination: Destination
    init(title: String, subtitle: String, systemIcon: String,
         @ViewBuilder destination: () -> Destination) {
        self.title = title; self.subtitle = subtitle; self.systemIcon = systemIcon
        self.destination = destination()
    }
    var body: some View {
        NavigationLink(destination: destination) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: systemIcon).font(.title2).foregroundColor(.white)
                Text(title).font(.headline.weight(.semibold)).foregroundColor(.white)
                Text(subtitle).font(.subheadline).foregroundColor(.white.opacity(0.75))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private extension View {
    func glassCard() -> some View {
        self.padding(14)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.28)))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.16), lineWidth: 1))
            .shadow(color: .black.opacity(0.35), radius: 16, y: 10)
    }
    func iconAccent(_ color: Color) -> some View {
        self.tint(color).symbolRenderingMode(.monochrome)
    }
}

private struct NeonProminent: ButtonStyle {
    var tint: Color = Color(hex: 0x2563EB)
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .background(LinearGradient(colors: [tint, tint.opacity(0.9)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing))
            .cornerRadius(16)
            .shadow(color: tint.opacity(0.5), radius: 20, y: 10)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

private struct GlassBordered: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.foregroundColor(.white)
            .background(Color.white.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14)
                .stroke(.white.opacity(configuration.isPressed ? 0.22 : 0.14), lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

enum Haptics {
    static func soft() { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
    static func light() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
}
