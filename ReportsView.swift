import SwiftUI
import PDFKit
import UniformTypeIdentifiers

struct ReportsKPI: Identifiable, Hashable {
    enum Period: String, CaseIterable, Identifiable {
        case weekly = "أسبوعي"
        case monthly = "شهري"
        var id: String { rawValue }
    }
    let id = UUID()
    var period: Period
    var start: Date
    var end: Date
    var rosterTimeSec: Int
    var nightBalanceImprovement: Int
    var conflicts: Int
    var readiness: Int
    var pdfURL: URL? = nil
}

struct ReportsScreen: View {
    @State private var period: ReportsKPI.Period = .weekly
    @State private var anchorDate = Date()
    @State private var isGenerating = false
    @State private var lastReportURL: URL?
    @State private var history: [ReportsKPI] = []
    @State private var exportURL: URL?
    @State private var showExporter = false
    @State private var appeared = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0x0B1016), Color(hex: 0x0F1B2B)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            RadialGradient(colors: [Color(hex: 0x3AD29F).opacity(0.14), .clear],
                           center: .topLeading, startRadius: 60, endRadius: 380)
            .blendMode(.plusLighter)
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header

                    controls
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .opacity(appeared ? 1 : 0)

                    metrics(previewMetrics())
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                        .opacity(appeared ? 1 : 0)

                    actions
                    historyList
                }
                .padding(20)
            }
        }
        .navigationTitle("التقارير الذكية")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if let url = lastReportURL {
                    ShareLink(item: url) { Image(systemName: "square.and.arrow.up") }
                    Button {
                        exportURL = url; showExporter = true
                    } label: { Image(systemName: "tray.and.arrow.down") }
                }
            }
        }
        .sheet(isPresented: $showExporter) {
            if let exportURL { DocumentExporter(url: exportURL) }
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.88)) { appeared = true }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(.ultraThinMaterial)
                    .frame(width: 58, height: 58)
                    .overlay(Circle().stroke(.white.opacity(0.1), lineWidth: 1))
                    .shadow(color: .black.opacity(0.35), radius: 10, y: 8)
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.title2).foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("التقارير الذكية")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("PDF • العدالة والجاهزية • أوفلاين")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
            }
            Spacer()
            Text("Prototype")
                .font(.caption).bold()
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(.white.opacity(0.08), in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.12), lineWidth: 1))
        }
    }

    private var controls: some View {
        VStack(spacing: 12) {
            Picker("المدة", selection: $period) {
                ForEach(ReportsKPI.Period.allCases) { p in Text(p.rawValue).tag(p) }
            }
            .pickerStyle(.segmented)

            Group {
                if period == .weekly {
                    DatePicker("بداية الأسبوع", selection: $anchorDate, displayedComponents: .date)
                } else {
                    DatePicker("الشهر", selection: $anchorDate, displayedComponents: .date)
                }
            }
            .tint(.white)
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.12), lineWidth: 1))
    }

    private func metrics(_ m: ReportsKPI) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("مؤشرات الفترة المحددة")
                .font(.headline).foregroundStyle(.white)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12)], spacing: 12) {
                MetricTile(title: "زمن إنشاء الجدول", value: "\(m.rosterTimeSec) ث",
                           icon: "timer", accent: Color(hex: 0x34D399))
                MetricTile(title: "تحسّن الليلي", value: "\(m.nightBalanceImprovement)%",
                           icon: "moon.stars.fill", accent: Color(hex: 0x60A5FA))
                MetricTile(title: "التعارضات", value: "\(m.conflicts)",
                           icon: "exclamationmark.triangle.fill", accent: Color(hex: 0xF59E0B))
                MetricTile(title: "الجاهزية", value: "\(m.readiness)%",
                           icon: "shield.checkerboard", accent: Color(hex: 0x10B981))
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack { Image(systemName: "bolt.heart.fill"); Text("مؤشر الجاهزية الإجمالي") }
                    .foregroundStyle(.secondary)

                ProgressView(value: Double(m.readiness), total: 100)
                    .progressViewStyle(.linear)
                    .tint(Color(hex: 0x3B82F6))
                    .scaleEffect(x: 1, y: 1.4)
                    .accessibilityLabel("جاهزية إجمالية")
                    .accessibilityValue("\(m.readiness) بالمئة")
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.12), lineWidth: 1))
        .shadow(color: .black.opacity(0.25), radius: 16, y: 10)
    }

    private var actions: some View {
        HStack(spacing: 12) {
            Button {
                Task { await generateReport() }
            } label: {
                HStack {
                    Image(systemName: isGenerating ? "gearshape.arrow.triangle.2.circlepath" : "doc.badge.gearshape")
                        .rotationEffect(.degrees(isGenerating ? 360 : 0))
                        .animation(isGenerating ? .linear(duration: 1.1).repeatForever(autoreverses: false) : .default, value: isGenerating)
                    Text(isGenerating ? "جاري التوليد..." : "توليد تقرير PDF").bold()
                }
                .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(hex: 0x3B82F6))
            .disabled(isGenerating)

            if let url = lastReportURL {
                ShareLink(item: url) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title3).frame(width: 48, height: 48)
                }
                .buttonStyle(.bordered)

                Button {
                    exportURL = url; showExporter = true
                } label: {
                    Image(systemName: "tray.and.arrow.down")
                        .font(.title3).frame(width: 48, height: 48)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.top, 6)
    }

    private var historyList: some View {
        Group {
            if !history.isEmpty {
                Divider().overlay(Color.white.opacity(0.15))
                    .padding(.top, 2)
                Text("التقارير السابقة")
                    .font(.headline).foregroundStyle(.white)
                VStack(spacing: 10) {
                    ForEach(history.reversed()) { r in
                        ReportRow(report: r)
                            .background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.06), lineWidth: 1))
                    }
                }
            }
        }
    }

    private func previewMetrics() -> ReportsKPI {
        let range = dateRange(for: period, anchor: anchorDate)
        let seed = Calendar.current.component(.day, from: anchorDate)
        return ReportsKPI(
            period: period,
            start: range.start,
            end: range.end,
            rosterTimeSec: 18 + (seed % 28),
            nightBalanceImprovement: 35 + (seed % 50),
            conflicts: (seed % 3 == 0) ? 0 : Int.random(in: 0...1),
            readiness: 68 + (seed % 28)
        )
    }

    private func dateRange(for p: ReportsKPI.Period, anchor: Date) -> (start: Date, end: Date) {
        let cal = Calendar.current
        switch p {
        case .weekly:
            let s = cal.dateInterval(of: .weekOfYear, for: anchor)?.start ?? anchor
            return (s, cal.date(byAdding: .day, value: 6, to: s) ?? anchor)
        case .monthly:
            let s = cal.dateInterval(of: .month, for: anchor)?.start ?? anchor
            let e = cal.date(byAdding: .month, value: 1, to: s).flatMap { cal.date(byAdding: .day, value: -1, to: $0) } ?? anchor
            return (s, e)
        }
    }

    private func generateReport() async {
        guard !isGenerating else { return }
        isGenerating = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        defer { isGenerating = false }

        var r = previewMetrics()
        if let url = makeReportPDF(for: r) {
            r.pdfURL = url
            lastReportURL = url
            withAnimation(.spring(response: 0.6, dampingFraction: 0.9)) { history.append(r) }
        }
    }

    private func makeReportPDF(for report: ReportsKPI) -> URL? {
        let page = CGSize(width: 595, height: 842)
        let view = ReportPDFView(report: report)
            .frame(width: page.width, height: page.height)
            .background(Color.white)

        let renderer = ImageRenderer(content: view)
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let url = docs.appendingPathComponent("report-\(UUID().uuidString).pdf")
        let pdf = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: page))
        do {
            try pdf.writePDF(to: url) { ctx in
                ctx.beginPage()
                if let img = renderer.uiImage { img.draw(in: CGRect(origin: .zero, size: page)) }
            }
            return url
        } catch {
            print("PDF error:", error)
            return nil
        }
    }
}

fileprivate struct MetricTile: View {
    let title: String, value: String, icon: String, accent: Color
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(accent.opacity(0.18))
                    .frame(width: 46, height: 46)
                Image(systemName: icon).foregroundStyle(accent).font(.headline)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Text(value).font(.headline).foregroundStyle(.white)
            }
            Spacer()
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.08), lineWidth: 1))
        .shadow(color: .black.opacity(0.25), radius: 12, y: 8)
    }
}

fileprivate struct ReportRow: View {
    let report: ReportsKPI
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.richtext.fill")
                .foregroundStyle(.blue.opacity(0.9))
                .imageScale(.large)
            VStack(alignment: .leading, spacing: 4) {
                Text("\(report.period.rawValue) • \(report.start.formatted(date: .abbreviated, time: .omitted)) → \(report.end.formatted(date: .abbreviated, time: .omitted))")
                    .foregroundStyle(.white)
                    .font(.headline)
                Text("زمن الجدول: \(report.rosterTimeSec)ث • التعارضات: \(report.conflicts) • الجاهزية: \(report.readiness)%")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            }
            Spacer()
            if let url = report.pdfURL {
                ShareLink(item: url) { Image(systemName: "square.and.arrow.up") }
                    .buttonStyle(.bordered)
            }
        }
        .padding(12)
    }
}

fileprivate struct ReportPDFView: View {
    let report: ReportsKPI
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            LinearGradient(colors: [Color(hex: 0x0EA5E9), Color(hex: 0x22C55E)],
                           startPoint: .leading, endPoint: .trailing)
                .frame(height: 8).clipShape(Capsule())
                .padding(.bottom, 6)

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Smart Military Hub").font(.title2).bold()
                    Text("تقرير \(report.period.rawValue)").font(.headline).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(Date().formatted(date: .abbreviated, time: .shortened))
                        .font(.footnote).foregroundStyle(.secondary)
                    Text("Offline • Signed").font(.footnote)
                }
            }

            Divider()

            Group {
                Text("نطاق التقرير").font(.headline)
                Text("\(report.start.formatted(date: .long, time: .omitted)) → \(report.end.formatted(date: .long, time: .omitted))")
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("المؤشرات الرئيسية (KPIs)").font(.headline)
                kpi("زمن إنشاء الجدول", "\(report.rosterTimeSec) ثانية")
                kpi("تحسّن توازن النوبات الليلية", "\(report.nightBalanceImprovement)%")
                kpi("عدد التعارضات", "\(report.conflicts)")
                kpi("نسبة الجاهزية", "\(report.readiness)%")
            }

            Spacer()

            HStack {
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4,3]))
                    .frame(width: 64, height: 64)
                    .overlay(Image(systemName: "qrcode").opacity(0.7))
                Text("ختم داخلي: توليد أوفلاين على الجهاز • QR لاحقًا")
                    .font(.footnote).foregroundStyle(.secondary)
                Spacer()
                Text("© Smart Military Hub").font(.footnote)
            }
        }
        .padding(28)
        .background(Color.white)
        .foregroundColor(.black)
    }

    private func kpi(_ t: String, _ v: String) -> some View {
        HStack { Text(t); Spacer(); Text(v).bold() }
            .padding(.vertical, 6)
            .overlay(Rectangle().frame(height: 0.6).foregroundColor(.gray.opacity(0.25)), alignment: .bottom)
    }
}

fileprivate struct DocumentExporter: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let c = UIDocumentPickerViewController(forExporting: [url])
        c.allowsMultipleSelection = false
        return c
    }
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
}

#if DEBUG
#Preview {
    NavigationStack { ReportsScreen() }
        .preferredColorScheme(.dark)
        .previewDisplayName("التقارير الذكية – معاينة")
}
#endif
