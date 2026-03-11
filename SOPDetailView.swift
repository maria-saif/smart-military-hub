import SwiftUI
import UIKit

struct SOPStep: Identifiable, Hashable {
    let id = UUID()
    var text: String
    var isDone: Bool = false
}

struct SOPDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var session: SessionViewModel

    let item: SOPItem

    @State private var steps: [SOPStep] = []
    @State private var startedAt: Date? = nil
    @State private var elapsedSeconds: Int = 0
    @State private var running = false

    @State private var showShare = false
    @State private var exportedURL: URL?

    private var progress: Double {
        guard !steps.isEmpty else { return 0 }
        return Double(steps.filter(\.isDone).count) / Double(steps.count)
    }
    private var executorName: String { session.currentUserName ?? "—" }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerCard

                VStack(alignment: .leading, spacing: 10) {
                    ForEach($steps) { $s in
                        HStack(alignment: .top, spacing: 10) {
                            Button {
                                s.isDone.toggle()
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } label: {
                                Image(systemName: s.isDone ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundStyle(s.isDone ? Color.green : .white.opacity(0.7))
                            }
                            .buttonStyle(.plain)

                            Text(s.text)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(12)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.10), lineWidth: 1))
                    }
                }

                HStack(spacing: 12) {
                    Button {
                        toggleTimer()
                    } label: {
                        Label(running ? "إيقاف" : "بدء", systemImage: running ? "pause.fill" : "play.fill")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(running ? Color.red.opacity(0.2) : Color.green.opacity(0.2),
                                        in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(running ? .red : .green)

                    Button {
                        finishAndExport()
                    } label: {
                        Label("إنهاء وتصدير PDF", systemImage: "doc.richtext")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                    .disabled(steps.contains(where: { !$0.isDone }))
                    .opacity(steps.contains(where: { !$0.isDone }) ? 0.6 : 1)
                }

                Spacer(minLength: 12)
            }
            .padding(16)
        }
        .navigationTitle(item.title)
        .navigationBarTitleDisplayMode(.inline)
        .background(
            LinearGradient(colors: [Color(hex: 0x0E1116), Color(hex: 0x1A2332)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
        )
        .environment(\.layoutDirection, .rightToLeft)
        .sheet(isPresented: $showShare, onDismiss: { exportedURL = nil }) {
            if let url = exportedURL {
                SMHShareSheet(activityItems: [url])
            }
        }
        .onAppear {
            if steps.isEmpty { steps = defaultSteps(for: item) }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon(for: item.category))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(LinearGradient(colors: [Color(hex: 0x3AD29F), Color(hex: 0x7AA5FF)],
                                                   startPoint: .top, endPoint: .bottom))
                Text(item.category).foregroundStyle(.white.opacity(0.8))
                Spacer()
                Text(timeString(elapsedSeconds))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(running ? .green : .white.opacity(0.8))
            }

            ProgressView(value: progress) {
                Text("التقدّم: \(Int(progress*100))%").foregroundStyle(.white)
            }
            .progressViewStyle(.linear)
            .tint(Color(hex: 0x3AD29F))

            Text("المنفّذ: \(executorName)")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.12), lineWidth: 1))
    }

    private func toggleTimer() {
        if running {
            running = false
        } else {
            if startedAt == nil { startedAt = Date() }
            running = true
            startTicking()
        }
    }

    private func startTicking() {
        Task {
            while running {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await MainActor.run { elapsedSeconds += 1 }
            }
        }
    }

    private func finishAndExport() {
        running = false
        let endedAt = Date()
        let url = exportPDF(
            title: item.title,
            category: item.category,
            steps: steps,
            executor: executorName,
            startedAt: startedAt,
            endedAt: endedAt,
            duration: elapsedSeconds
        )
        exportedURL = url
        showShare = (url != nil)
    }

    private func timeString(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    private func icon(for category: String) -> String {
        switch category {
        case "إسعاف":  return "cross.vial.fill"
        case "مركبات": return "car.fill"
        case "انضباط": return "checkmark.seal.fill"
        default:       return "doc.text.fill"
        }
    }

    private func defaultSteps(for item: SOPItem) -> [SOPStep] {
        switch item.title {
        case _ where item.title.contains("نزيف"):
            return [
                .init(text: "تأمين المكان وفحص السلامة"),
                .init(text: "ارتداء قفازات إن أمكن"),
                .init(text: "ضغط مباشر على موضع النزيف"),
                .init(text: "رفع الطرف المصاب إن أمكن"),
                .init(text: "تثبيت الضماد والتحقق من استمرار النزيف"),
                .init(text: "تسجيل الوقت وإشعار القائد")
            ]
        case _ where item.title.contains("تعطّل مركبة"):
            return [
                .init(text: "إيقاف المركبة في مكان آمن وتشغيل مثلث التحذير"),
                .init(text: "تقييم العطل بسرعة (حرارة/إطارات/زيت)"),
                .init(text: "إبلاغ مركز القيادة بالموقع والحالة"),
                .init(text: "تأمين الأفراد حول المركبة"),
                .init(text: "محاولة إصلاح بسيط إن أمكن وفق SOP"),
                .init(text: "تجهيز نقل/سحب إذا لزم"),
                .init(text: "تسجيل بلاغ بعد المعالجة")
            ]
        default:
            return [
                .init(text: "قراءة تعليمات الإجراء"),
                .init(text: "تجهيز المعدات المطلوبة"),
                .init(text: "تنفيذ الخطوات حسب الترتيب"),
                .init(text: "مراجعة النتيجة وتوثيقها")
            ]
        }
    }

    private func exportPDF(title: String,
                           category: String,
                           steps: [SOPStep],
                           executor: String,
                           startedAt: Date?,
                           endedAt: Date,
                           duration: Int) -> URL? {

        let report = SOPReportView(title: title,
                                   category: category,
                                   steps: steps,
                                   executor: executor,
                                   startedAt: startedAt,
                                   endedAt: endedAt,
                                   duration: duration)
            .environment(\.layoutDirection, .rightToLeft)

        let renderer = ImageRenderer(content: report)
        renderer.scale = UIScreen.main.scale
        guard let img = renderer.uiImage else { return nil }

        let pageRect = CGRect(x: 0, y: 0, width: max(img.size.width, 612), height: max(img.size.height, 792))
        let pdfRenderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("SOP_\(UUID().uuidString.prefix(6)).pdf")

        do {
            try pdfRenderer.writePDF(to: url) { ctx in
                ctx.beginPage()
                img.draw(in: CGRect(origin: .zero, size: pageRect.size))
            }
            return url
        } catch {
            print("PDF export error:", error)
            return nil
        }
    }
}


private struct SOPReportView: View {
    let title: String
    let category: String
    let steps: [SOPStep]
    let executor: String
    let startedAt: Date?
    let endedAt: Date
    let duration: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("تقرير تنفيذ إجراء (SOP)").font(.title2).bold()
                    Text(title).font(.headline)
                    Text("الفئة: \(category)").font(.subheadline)
                }
                Spacer()
                Image(systemName: "checklist").font(.largeTitle)
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("المنفّذ: \(executor)")
                Text("البدء: \(startedAt.map { DateFormatter.localizedString(from: $0, dateStyle: .short, timeStyle: .short) } ?? "—")")
                Text("الانتهاء: \(DateFormatter.localizedString(from: endedAt, dateStyle: .short, timeStyle: .short))")
                Text("المدة: \(duration/60) دقيقة \(duration%60) ثانية")
            }
            .font(.subheadline)

            Divider()

            Text("الخطوات المنفّذة:").bold()
            ForEach(steps) { s in
                HStack(alignment: .top) {
                    Image(systemName: s.isDone ? "checkmark.square.fill" : "square")
                    Text(s.text)
                }
            }

            Spacer(minLength: 12)
            Text("توليد تلقائي من Smart Military Hub")
                .font(.footnote).foregroundColor(.secondary)
        }
        .padding(24)
        .frame(width: 612)
        .background(Color.white)
    }
}

struct SMHShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
