import SwiftUI
import Charts
import UIKit


struct SoldierResult: Identifiable {
    let id = UUID()
    let fullName: String
    let rank: String
    let unit: String
    let score: Int
    let hours: Int
    let status: Status
    let lastUpdate: Date
    
    enum Status: String, CaseIterable, Identifiable {
        case excellent = "ممتاز"
        case good = "جيد"
        case needsAttention = "يحتاج متابعة"
        var id: String { rawValue }
        var color: Color {
            switch self {
            case .excellent: return .green
            case .good: return .blue
            case .needsAttention: return .orange
            }
        }
        var icon: String {
            switch self {
            case .excellent: return "checkmark.seal.fill"
            case .good: return "hand.thumbsup.fill"
            case .needsAttention: return "exclamationmark.triangle.fill"
            }
        }
    }
}

struct TrainingResultsView: View {
    @State private var query: String = ""
    @State private var period: Period = .monthly
    @State private var selectedUnit: String? = nil
    @State private var selectedRank: String? = nil
    @State private var selectedStatus: SoldierResult.Status? = nil
    @State private var sortBy: Sort = .scoreDesc
    @State private var soldiers: [SoldierResult] = SampleData.soldiers
    
    @State private var shareURL: URL? = nil
    @State private var isSharePresented = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0x0E1116), Color(hex: 0x111827), Color(hex: 0x0B1220)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .trailing, spacing: 16) {
                    
                    VStack(alignment: .trailing, spacing: 6) {
                        Text("نتائج التدريب")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white)
                        Text(period.subtitle)
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.7))
                        Picker("الفترة", selection: $period) {
                            ForEach(Period.allCases) { p in Text(p.title).tag(p) }
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    VStack(spacing: 12) {
                        MetricCard(
                            title: "نسبة الإنجاز",
                            valueView: AnyView(DonutProgress(progress: overallCompletion)),
                            footer: Text("%\(Int(overallCompletion*100)) من الأهداف مكتملة")
                        )
                        .frame(maxWidth: .infinity).frame(height: 120)
                        
                        MetricCard(
                            title: "ساعات التدريب",
                            valueView: AnyView(
                                Text("\(totalHours)")
                                    .font(.system(size: 34, weight: .heavy))
                                    .monospacedDigit()
                                    .foregroundStyle(.white)
                            ),
                            footer: Text("إجمالي ساعات الفترة الحالية")
                        )
                        .frame(maxWidth: .infinity).frame(height: 110)
                        
                        MetricCard(
                            title: "متوسط التقييم",
                            valueView: AnyView(
                                HStack(spacing: 6) {
                                    Image(systemName: "star.fill").foregroundStyle(.yellow)
                                    Text(String(format: "%.1f", averageScore/20))
                                        .font(.system(size: 30, weight: .bold))
                                        .monospacedDigit()
                                }.foregroundStyle(.white)
                            ),
                            footer: Text("من 5 نجوم")
                        )
                        .frame(maxWidth: .infinity).frame(height: 110)
                        
                        MetricCard(
                            title: "عدد الجنود",
                            valueView: AnyView(
                                Text("\(soldiers.count)")
                                    .font(.system(size: 34, weight: .heavy))
                                    .monospacedDigit()
                                    .foregroundStyle(.white)
                            ),
                            footer: Text("المسجلون في هذه الفترة")
                        )
                        .frame(maxWidth: .infinity).frame(height: 110)
                    }
                    
                    performanceSection
                    
                    filters
                    
                    HStack {
                        Menu {
                            Picker("الترتيب", selection: $sortBy) {
                                ForEach(Sort.allCases) { s in
                                    Label(s.title, systemImage: s.icon).tag(s)
                                }
                            }
                        } label: {
                            Label(sortBy.title, systemImage: "arrow.up.arrow.down")
                                .font(.subheadline)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(.white.opacity(0.08), in: Capsule())
                        }
                        Spacer()
                        Text("\(filtered.count) نتيجة")
                            .foregroundStyle(.white.opacity(0.6))
                            .font(.caption)
                    }
                    
                    VStack(alignment: .trailing, spacing: 10) {
                        ForEach(Array(filteredAndSorted.enumerated()), id: \.element.id) { idx, s in
                            HStack(alignment: .top, spacing: 10) {
                                Text("\(idx + 1)")
                                    .font(.callout.bold())
                                    .padding(8)
                                    .background(.white.opacity(0.08), in: Circle())
                                    .foregroundStyle(.white)
                                SoldierRow(soldier: s)
                            }
                        }
                    }
                    
                    Spacer(minLength: 28)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)
                .environment(\.layoutDirection, .rightToLeft)
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { exportMenu }
            ToolbarItem(placement: .topBarLeading) { addButton }
        }
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: Text("ابحث باسم الجندي، الرتبة، الوحدة"))
        .sheet(isPresented: $isSharePresented) {
            if let url = shareURL {
                ActivityView(activityItems: [url])
                    .presentationDetents([.medium, .large])
            } else {
                Text("لا يوجد ملف للمشاركة").padding()
            }
        }
    }
}

extension TrainingResultsView {
    private var perfData: [SampleData.PerfPoint] { SampleData.performance(period: period) }
    private var perfMaxY: Double { Double((perfData.map { $0.hours }.max() ?? 1) + 2) }
    
    @ViewBuilder private var performanceSection: some View {
        VStack(alignment: .trailing, spacing: 10) {
            HStack {
                Spacer()
                Label("اتجاه الأداء", systemImage: "chart.bar.doc.horizontal.fill")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            
            CardBackground {
                if #available(iOS 16.0, *) {
                    Chart(perfData) { item in
                        BarMark(
                            x: .value("الفترة", item.label),
                            y: .value("الساعات", item.hours)
                        )
                        .foregroundStyle(.blue)
                        .cornerRadius(5)
                        .annotation(position: .top) {
                            Text("\(item.hours)")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.9))
                        }
                    }
                    .chartYScale(domain: 0...perfMaxY)
                    .chartXAxis {
                        AxisMarks { _ in
                            AxisGridLine().foregroundStyle(Color.white.opacity(0.15))
                            AxisTick().foregroundStyle(Color.white.opacity(0.30))
                            AxisValueLabel().foregroundStyle(Color.white.opacity(0.90))
                        }
                    }
                    .chartYAxis {
                        AxisMarks { _ in
                            AxisGridLine().foregroundStyle(Color.white.opacity(0.15))
                            AxisTick().foregroundStyle(Color.white.opacity(0.30))
                            AxisValueLabel().foregroundStyle(Color.white.opacity(0.90))
                        }
                    }
                    .chartPlotStyle { plot in
                        plot.background(.clear)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 6)
                    }
                    .frame(height: 300)
                    .clipped()
                } else {
                    Text("المخططات غير مدعومة في هذا الإصدار")
                        .frame(height: 220)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .padding(.bottom, 8)
        }
    }
}

extension TrainingResultsView {
    private var filters: some View {
        VStack(alignment: .trailing, spacing: 10) {
            HStack { Spacer(); Text("ترشيحات سريعة").font(.headline).foregroundStyle(.white) }
            
            Menu {
                Button("كل الوحدات") { selectedUnit = nil }
                ForEach(SampleData.units, id: \.self) { unit in
                    Button(unit) { selectedUnit = unit }
                }
            } label: {
                filterRow(icon: "building.2.fill", text: selectedUnit ?? "كل الوحدات")
            }
            
            Menu {
                Button("كل الرتب") { selectedRank = nil }
                ForEach(SampleData.ranks, id: \.self) { r in
                    Button(r) { selectedRank = r }
                }
            } label: {
                filterRow(icon: "chevron.up.chevron.down", text: selectedRank ?? "كل الرتب")
            }
            
            Menu {
                Button("كل الحالات") { selectedStatus = nil }
                ForEach(SoldierResult.Status.allCases) { st in
                    Button(st.rawValue) { selectedStatus = st }
                }
            } label: {
                filterRow(icon: "line.3.horizontal.decrease.circle.fill", text: selectedStatus?.rawValue ?? "كل الحالات")
            }
        }
    }
    
    private func filterRow(icon: String, text: String) -> some View {
        HStack {
            Image(systemName: icon)
            Text(text)
            Spacer()
            Image(systemName: "chevron.down")
        }
        .padding()
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        .foregroundStyle(.white)
    }
}

extension TrainingResultsView {
    private var exportMenu: some View {
        Menu {
            Button {
                if let url = makePDF() {
                    shareURL = url
                    isSharePresented = true
                }
            } label: { Label("تصدير PDF", systemImage: "doc.richtext") }

            Button {
                if let existing = shareURL ?? makePDF() {
                    shareURL = existing
                    isSharePresented = true
                }
            } label: { Label("مشاركة", systemImage: "square.and.arrow.up") }
        } label: {
            Image(systemName: "ellipsis.circle").font(.title3).foregroundStyle(.white)
        }
    }
    private var addButton: some View {
        Button { } label: {
            Label("تقييم جديد", systemImage: "plus.circle.fill").font(.headline)
        }.tint(.green)
    }
}

extension TrainingResultsView {
    private var filtered: [SoldierResult] {
        soldiers.filter { s in
            (selectedUnit == nil || s.unit == selectedUnit!) &&
            (selectedRank == nil || s.rank == selectedRank!) &&
            (selectedStatus == nil || s.status == selectedStatus!) &&
            (query.isEmpty || s.fullName.contains(query) || s.rank.contains(query) || s.unit.contains(query))
        }
    }
    private var filteredAndSorted: [SoldierResult] {
        let arr = filtered
        switch sortBy {
        case .scoreDesc: return arr.sorted { ($0.score, $0.lastUpdate) > ($1.score, $1.lastUpdate) }
        case .scoreAsc:  return arr.sorted { ($0.score, $0.lastUpdate) < ($1.score, $1.lastUpdate) }
        case .hoursDesc: return arr.sorted { ($0.hours, $0.lastUpdate) > ($1.hours, $1.lastUpdate) }
        case .hoursAsc:  return arr.sorted { ($0.hours, $0.lastUpdate) < ($1.hours, $1.lastUpdate) }
        case .recent:    return arr.sorted { $0.lastUpdate > $1.lastUpdate }
        }
    }
    private var overallCompletion: Double {
        guard !soldiers.isEmpty else { return 0 }
        return Double(soldiers.map(\.score).reduce(0, +)) / Double(soldiers.count*100)
    }
    private var totalHours: Int { soldiers.map(\.hours).reduce(0, +) }
    private var averageScore: Double {
        guard !soldiers.isEmpty else { return 0 }
        return Double(soldiers.map(\.score).reduce(0, +)) / Double(soldiers.count)
    }
}

enum Period: String, CaseIterable, Identifiable {
    case weekly, monthly, quarterly
    var id: String { rawValue }
    var title: String {
        switch self {
        case .weekly: return "أسبوعي"
        case .monthly: return "شهري"
        case .quarterly: return "ربع سنوي"
        }
    }
    var subtitle: String {
        let now = Date()
        switch self {
        case .weekly:
            let w = Calendar.current.component(.weekOfYear, from: now)
            let df = DateFormatter(); df.locale = Locale(identifier: "ar"); df.dateStyle = .medium
            return "الأسبوع \(w) - \(df.string(from: now))"
        case .monthly:
            let comps = Calendar.current.dateComponents([.year,.month], from: now)
            let df = DateFormatter(); df.locale = Locale(identifier: "ar")
            let monthName = df.monthSymbols[(comps.month ?? 1) - 1]
            return "\(monthName) \(comps.year ?? 0)"
        case .quarterly:
            let q = ((Calendar.current.component(.month, from: now)-1)/3)+1
            return "الربع \(q)"
        }
    }
}

enum Sort: String, CaseIterable, Identifiable {
    case scoreDesc, scoreAsc, hoursDesc, hoursAsc, recent
    var id: String { rawValue }
    var title: String {
        switch self {
        case .scoreDesc: return "الأعلى تقييمًا"
        case .scoreAsc:  return "الأقل تقييمًا"
        case .hoursDesc: return "أكثر ساعات"
        case .hoursAsc:  return "أقل ساعات"
        case .recent:    return "الأحدث تحديثًا"
        }
    }
    var icon: String {
        switch self {
        case .scoreDesc: return "star.fill"
        case .scoreAsc:  return "star"
        case .hoursDesc: return "clock.fill"
        case .hoursAsc:  return "clock"
        case .recent:    return "arrow.clockwise"
        }
    }
}

struct SoldierRow: View {
    let soldier: SoldierResult
    var body: some View {
        CardBackground {
            HStack(alignment: .top, spacing: 10) {
                avatar
                VStack(alignment: .trailing, spacing: 8) {
                    HStack {
                        Spacer()
                        Label(soldier.status.rawValue, systemImage: soldier.status.icon)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(soldier.status.color.opacity(0.18), in: Capsule())
                            .foregroundStyle(soldier.status.color)
                            .lineLimit(1)
                    }
                    Text(soldier.fullName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    HStack(spacing: 6) {
                        InfoPill(text: soldier.rank, systemImage: "chevron.up")
                        InfoPill(text: soldier.unit, systemImage: "building.2")
                        InfoPill(text: "\(soldier.hours) س", systemImage: "clock")
                    }
                    .lineLimit(1)
                    ProgressView(value: Double(soldier.score)/100) {
                        Text("نسبة الإنجاز").font(.caption2).foregroundStyle(.white.opacity(0.7))
                    } currentValueLabel: {
                        Text("\(soldier.score)%").font(.caption).monospacedDigit()
                    }
                    .tint(LinearGradient(colors: [.green, .blue], startPoint: .leading, endPoint: .trailing))
                    .foregroundStyle(.white.opacity(0.7))
                }
            }
            .frame(maxWidth: .infinity)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(soldier.fullName)، إنجاز \(soldier.score) بالمئة، ساعات \(soldier.hours)"))
    }
    private var avatar: some View {
        ZStack {
            Circle().fill(
                LinearGradient(colors: [Color(hex: 0x0EA5E9), Color(hex: 0x10B981)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            Text(initials(of: soldier.fullName))
                .font(.subheadline).bold()
                .foregroundStyle(.white)
        }
        .frame(width: 40, height: 40)
        .shadow(color: .black.opacity(0.25), radius: 5, x: 0, y: 3)
    }
    private func initials(of name: String) -> String {
        let comps = name.split(separator: " ")
        let first = comps.first?.first.map(String.init) ?? "ج"
        let last  = comps.dropFirst().first?.first.map(String.init) ?? "ن"
        return first + last
    }
}

struct CardBackground<Content: View>: View {
    private let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        ZStack {
            shape
                .fill(LinearGradient(colors: [Color.white.opacity(0.045), Color.white.opacity(0.02)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            shape
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            VStack { content }
                .padding(12)
        }
        .clipShape(shape)
        .contentShape(shape)
    }
}

struct MetricCard: View {
    let title: String
    let valueView: AnyView
    let footer: Text
    var body: some View {
        CardBackground {
            VStack(alignment: .trailing, spacing: 8) {
                Text(title).font(.subheadline).foregroundStyle(.white.opacity(0.8))
                valueView
                footer.font(.caption).foregroundStyle(.white.opacity(0.7))
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(maxWidth: .infinity)
    }
}

struct DonutProgress: View {
    let progress: Double
    var body: some View {
        ZStack {
            Circle().trim(from: 0, to: 1)
                .stroke(Color.white.opacity(0.1), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Circle().trim(from: 0, to: progress)
                .stroke(AngularGradient(colors: [.green, .blue, .cyan], center: .center),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: .cyan.opacity(0.4), radius: 6)
            Text("%\(Int(progress*100))")
                .font(.system(size: 28, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(.white)
        }
        .frame(height: 70)
    }
}

struct InfoPill: View {
    let text: String
    let systemImage: String
    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.caption2)
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.white.opacity(0.06), in: Capsule())
            .foregroundStyle(.white.opacity(0.9))
    }
}

extension Color {
    init(hex: Int, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF)/255.0
        let g = Double((hex >> 8) & 0xFF)/255.0
        let b = Double(hex & 0xFF)/255.0
        self = Color(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

enum SampleData {
    static let units = ["الكتيبة 1", "الكتيبة 3", "السرية أ", "السرية ب"]
    static let ranks = ["جندي", "عريف", "وكيل رقيب", "رقيب"]
    static let soldiers: [SoldierResult] = [
        .init(fullName: "سالم البوسعيدي", rank: "رقيب", unit: "الكتيبة 1", score: 94, hours: 26, status: .excellent, lastUpdate: .now.addingTimeInterval(-3600*3)),
        .init(fullName: "مازن الهنائي", rank: "عريف", unit: "السرية أ", score: 81, hours: 19, status: .good, lastUpdate: .now.addingTimeInterval(-3600*6)),
        .init(fullName: "حمد السيابي", rank: "جندي", unit: "الكتيبة 3", score: 62, hours: 14, status: .needsAttention, lastUpdate: .now.addingTimeInterval(-3600*30)),
        .init(fullName: "يزن العوفي", rank: "وكيل رقيب", unit: "السرية ب", score: 88, hours: 22, status: .good, lastUpdate: .now.addingTimeInterval(-3600*50)),
        .init(fullName: "جابر المعولي", rank: "رقيب", unit: "الكتيبة 1", score: 72, hours: 17, status: .good, lastUpdate: .now.addingTimeInterval(-3600*70)),
        .init(fullName: "خالد المقبالي", rank: "عريف", unit: "السرية أ", score: 55, hours: 10, status: .needsAttention, lastUpdate: .now.addingTimeInterval(-3600*100))
    ]
    struct PerfPoint: Identifiable { let id = UUID(); let label: String; let hours: Int }
    static func performance(period: Period) -> [PerfPoint] {
        switch period {
        case .weekly:
            return ["س", "أ", "ث", "أر", "خ", "ج", "س"].enumerated()
                .map { .init(label: $0.element, hours: [3,4,2,5,6,1,0][$0.offset]) }
        case .monthly:
            return (1...8).map { .init(label: "أسبوع \($0)", hours: [12,16,9,14,18,10,7,15][$0-1]) }
        case .quarterly:
            return ["ش1", "ش2", "ش3"].enumerated()
                .map { .init(label: $0.element, hours: [40,52,47][$0.offset]) }
        }
    }
}

extension TrainingResultsView {
    private func makePDF() -> URL? {
        let pageSize = CGSize(width: 595, height: 842)

        let printable = TrainingResultsPDFView(
            soldiers: filteredAndSorted,
            period: period,
            totalHours: totalHours,
            overallCompletion: overallCompletion,
            averageScore: averageScore,
            perfData: SampleData.performance(period: period)
        )
        .frame(width: pageSize.width, alignment: .topTrailing)
        .environment(\.layoutDirection, .rightToLeft)

        let renderer = ImageRenderer(content: printable)
        let format = UIGraphicsPDFRendererFormat()
        let bounds = CGRect(origin: .zero, size: pageSize)
        let pdf = UIGraphicsPDFRenderer(bounds: bounds, format: format)

        let temp = FileManager.default.temporaryDirectory
        let url = temp.appendingPathComponent("training-results-\(UUID().uuidString).pdf")

        do {
            try pdf.writePDF(to: url) { ctx in
                ctx.beginPage()
                if let img = renderer.uiImage {
                    img.draw(in: bounds)
                } else {
                    let hosting = UIHostingController(rootView: printable)
                    hosting.view.bounds = bounds
                    let root = UIView(frame: bounds)
                    root.addSubview(hosting.view)
                    hosting.view.backgroundColor = .clear
                    root.drawHierarchy(in: bounds, afterScreenUpdates: true)
                }
            }
            return url
        } catch {
            print("PDF error:", error.localizedDescription)
            return nil
        }
    }
}

struct TrainingResultsPDFView: View {
    let soldiers: [SoldierResult]
    let period: Period
    let totalHours: Int
    let overallCompletion: Double
    let averageScore: Double
    let perfData: [SampleData.PerfPoint]

    var body: some View {
        VStack(alignment: .trailing, spacing: 12) {
            VStack(alignment: .trailing, spacing: 4) {
                Text("تقرير نتائج التدريب")
                    .font(.title2.bold())
                Text(period.subtitle)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 12) {
                pdfMetric(title: "نسبة الإنجاز", value: "\(Int(overallCompletion*100))%")
                pdfMetric(title: "ساعات التدريب", value: "\(totalHours) س")
                pdfMetric(title: "متوسط التقييم", value: String(format: "%.1f / 5", averageScore/20))
                pdfMetric(title: "عدد الجنود", value: "\(soldiers.count)")
            }

            Divider()

            VStack(alignment: .trailing, spacing: 6) {
                Text("قائمة الجنود").font(.headline)
                TableLike(headers: ["الاسم", "الرتبة", "الوحدة", "الساعات", "الإنجاز"]) {
                    ForEach(soldiers) { s in
                        TableRow(cells: [
                            s.fullName,
                            s.rank,
                            s.unit,
                            "\(s.hours)",
                            "\(s.score)%"
                        ])
                    }
                }
                .font(.caption)
            }

            Spacer(minLength: 0)

            HStack {
                Text("تم التوليد بواسطة Smart Military Hub")
                    .font(.footnote).foregroundColor(.secondary)
                Spacer()
                Text(Date.now.formatted(date: .abbreviated, time: .shortened))
                    .font(.footnote).foregroundColor(.secondary)
            }
        }
        .padding(24)
        .background(.white)
    }

    private func pdfMetric(title: String, value: String) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(title).font(.caption).foregroundColor(.secondary)
            Text(value).font(.headline).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(12)
        .background(Color(white: 0.96))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct TableLike<Rows: View>: View {
    let headers: [String]
    @ViewBuilder var rows: () -> Rows

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                ForEach(headers, id: \.self) { h in
                    Text(h).font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .padding(8)
            .background(Color(white: 0.93))

            Divider()

            VStack(spacing: 0) {
                rows()
            }
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(white: 0.85), lineWidth: 1)
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

struct TableRow: View {
    let cells: [String]
    var body: some View {
        HStack(alignment: .top) {
            ForEach(cells.indices, id: \.self) { i in
                Text(cells[i])
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(8)
        .background(Color.white)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(white: 0.9)),
            alignment: .bottom
        )
    }
}

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) { }
}

struct TrainingResultsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            TrainingResultsView()
                .environment(\.locale, Locale(identifier: "ar"))
                .environment(\.layoutDirection, .rightToLeft)
        }
    }
}
