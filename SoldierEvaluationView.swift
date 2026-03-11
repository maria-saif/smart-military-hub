import SwiftUI
import UIKit


struct EvalSoldier: Identifiable, Hashable {
    let id = UUID()
    let fullName: String
    let rank: String
    let unit: String
}

struct SoldierEvaluationView: View {
    let soldiers: [EvalSoldier] = [
        .init(fullName: "سالم البوسعيدي", rank: "رقيب",       unit: "الكتيبة 1"),
        .init(fullName: "يزن العوفي",    rank: "وكيل رقيب",  unit: "السرية ب"),
        .init(fullName: "مازن الهنائي",  rank: "عريف",       unit: "السرية أ"),
        .init(fullName: "جابر المعولي",  rank: "رقيب",       unit: "الكتيبة 1"),
        .init(fullName: "حمد السيابي",   rank: "جندي",       unit: "الكتيبة 3"),
        .init(fullName: "خالد المقبالي",  rank: "عريف",       unit: "السرية أ")
    ]
    
    @State private var selectedSoldier: EvalSoldier? = nil
    @State private var evalDate: Date = .now
    @State private var hours: Int = 2
    
    @State private var fitness: Double = 70
    @State private var marksmanship: Double = 75
    @State private var discipline: Double = 80
    @State private var teamwork: Double = 78
    @State private var knowledge: Double = 72
    
    @State private var notes: String = ""
    @State private var showSaved: Bool = false
    
    @State private var shareURL: URL? = nil
    @State private var isSharePresented = false
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0x0E1116), Color(hex: 0x111827), Color(hex: 0x0B1220)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(alignment: .trailing, spacing: 16) {
                    Text("تقييم الجنود")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    
                    CardBackground {
                        VStack(alignment: .trailing, spacing: 10) {
                            Text("معلومات الجندي")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            
                            Menu {
                                ForEach(soldiers) { s in
                                    Button(s.fullName) { selectedSoldier = s }
                                }
                            } label: {
                                rowButton(icon: "person.crop.circle.fill",
                                          text: selectedSoldier?.fullName ?? "اختر الجندي")
                            }
                            
                            if let s = selectedSoldier {
                                HStack(spacing: 8) {
                                    InfoPill(text: s.rank, systemImage: "chevron.up")
                                    InfoPill(text: s.unit, systemImage: "building.2.fill")
                                }
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                        }
                    }
                    
                    CardBackground {
                        VStack(alignment: .trailing, spacing: 12) {
                            Text("الزمان والساعات")
                                .font(.headline).foregroundStyle(.white)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            
                            DatePicker("تاريخ التقييم", selection: $evalDate, displayedComponents: .date)
                                .labelsHidden()
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .colorScheme(.dark)
                            
                            HStack {
                                Stepper(value: $hours, in: 0...40) { EmptyView() }
                                Text("\(hours) ساعة").font(.body.monospacedDigit())
                                Image(systemName: "clock.fill")
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }
                    
                    CardBackground {
                        VStack(alignment: .trailing, spacing: 14) {
                            Text("محاور التقييم")
                                .font(.headline).foregroundStyle(.white)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            
                            sliderRow(title: "اللياقة", value: $fitness, symbol: "figure.run")
                            sliderRow(title: "الرماية", value: $marksmanship, symbol: "scope")
                            sliderRow(title: "الانضباط", value: $discipline, symbol: "checkmark.seal")
                            sliderRow(title: "العمل الجماعي", value: $teamwork, symbol: "person.3.sequence")
                            sliderRow(title: "المعرفة", value: $knowledge, symbol: "book.closed.fill")
                        }
                    }
                    
                    CardBackground {
                        VStack(alignment: .trailing, spacing: 10) {
                            Text("نتيجة التقييم")
                                .font(.headline).foregroundStyle(.white)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            
                            HStack {
                                DonutProgress(progress: overallScore / 100.0)
                                    .frame(width: 80, height: 80)
                                Spacer()
                                VStack(alignment: .trailing, spacing: 6) {
                                    Text("المجموع: \(Int(overallScore)) / 100")
                                        .font(.title3.weight(.bold))
                                        .monospacedDigit()
                                        .foregroundStyle(.white)
                                    
                                    Label(statusText, systemImage: statusIcon)
                                        .foregroundStyle(statusColor)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(statusColor.opacity(0.15), in: Capsule())
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    
                    CardBackground {
                        VStack(alignment: .trailing, spacing: 8) {
                            Text("ملاحظات المدرب")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            
                            TextEditor(text: $notes)
                                .frame(minHeight: 120)
                                .padding(8)
                                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                                .foregroundStyle(.white)
                                .scrollContentBackground(.hidden)
                                .colorScheme(.dark)
                        }
                    }
                    
                    HStack(spacing: 12) {
                        Button { resetForm() } label: {
                            HStack { Image(systemName: "arrow.uturn.backward"); Text("إعادة ضبط") }
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        
                        Button { showSaved = true } label: {
                            HStack { Image(systemName: "tray.and.arrowDown.fill"); Text("حفظ التقييم") }
                        }
                        .buttonStyle(PrimaryButtonStyle(color: .green))
                        .disabled(selectedSoldier == nil)
                        .opacity(selectedSoldier == nil ? 0.6 : 1)
                    }
                    .padding(.top, 4)
                    
                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)
                .environment(\.layoutDirection, .rightToLeft)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { exportMenu }
        }
        .alert("تم الحفظ", isPresented: $showSaved) {
            Button("تم") { }
        } message: {
            Text("تم حفظ تقييم \(selectedSoldier?.fullName ?? "الجندي") بتاريخ \(formatted(evalDate)).")
        }
        .sheet(isPresented: $isSharePresented) {
            if let url = shareURL {
                ActivityShareView(activityItems: [url])
                    .presentationDetents([.medium, .large])
            } else {
                Text("لا يوجد ملف للمشاركة").padding()
            }
        }
    }
    
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
            Image(systemName: "ellipsis.circle")
                .font(.title3)
                .foregroundStyle(.white)
        }
    }
    
    private var overallScore: Double {
        (fitness + marksmanship + discipline + teamwork + knowledge) / 5.0
    }
    private var statusText: String {
        switch overallScore {
        case 85...100: return "ممتاز"
        case 70..<85:  return "جيد"
        default:       return "يحتاج متابعة"
        }
    }
    private var statusColor: Color {
        switch overallScore {
        case 85...100: return .green
        case 70..<85:  return .blue
        default:       return .orange
        }
    }
    private var statusIcon: String {
        switch overallScore {
        case 85...100: return "checkmark.seal.fill"
        case 70..<85:  return "hand.thumbsup.fill"
        default:       return "exclamationmark.triangle.fill"
        }
    }
    
    private func rowButton(icon: String, text: String) -> some View {
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
    
    private func sliderRow(title: String, value: Binding<Double>, symbol: String) -> some View {
        VStack(alignment: .trailing, spacing: 6) {
            HStack {
                Text("\(Int(value.wrappedValue))")
                    .monospacedDigit()
                    .font(.callout.bold())
                    .foregroundStyle(.white.opacity(0.9))
                Spacer()
                Label(title, systemImage: symbol)
                    .foregroundStyle(.white)
            }
            Slider(value: value, in: 0...100, step: 1)
                .tint(LinearGradient(colors: [.green, .blue], startPoint: .leading, endPoint: .trailing))
        }
    }
    
    private func resetForm() {
        selectedSoldier = nil
        evalDate = .now
        hours = 2
        fitness = 70; marksmanship = 75; discipline = 80; teamwork = 78; knowledge = 72
        notes = ""
    }
    
    private func formatted(_ date: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "ar")
        df.dateStyle = .medium
        return df.string(from: date)
    }
}

extension SoldierEvaluationView {
    private func makePDF() -> URL? {
        let pageSize = CGSize(width: 595, height: 842)
        
        let printable = SoldierEvaluationPDFView(
            soldier: selectedSoldier,
            evalDate: evalDate,
            hours: hours,
            fitness: Int(fitness),
            marksmanship: Int(marksmanship),
            discipline: Int(discipline),
            teamwork: Int(teamwork),
            knowledge: Int(knowledge),
            total: Int(overallScore),
            statusText: statusText,
            statusColor: statusColor,
            notes: notes
        )
        .frame(width: pageSize.width, alignment: .topTrailing)
        .environment(\.layoutDirection, .rightToLeft)
        
        let renderer = ImageRenderer(content: printable)
        let format = UIGraphicsPDFRendererFormat()
        let bounds = CGRect(origin: .zero, size: pageSize)
        let pdf = UIGraphicsPDFRenderer(bounds: bounds, format: format)
        
        let tmp = FileManager.default.temporaryDirectory
        let url = tmp.appendingPathComponent("soldier-evaluation-\(UUID().uuidString).pdf")
        
        do {
            try pdf.writePDF(to: url) { ctx in
                ctx.beginPage()
                if let img = renderer.uiImage {
                    img.draw(in: bounds)
                } else {
                    let host = UIHostingController(rootView: printable)
                    host.view.bounds = bounds
                    let container = UIView(frame: bounds)
                    container.addSubview(host.view)
                    host.view.backgroundColor = .clear
                    container.drawHierarchy(in: bounds, afterScreenUpdates: true)
                }
            }
            return url
        } catch {
            print("PDF error:", error.localizedDescription)
            return nil
        }
    }
}

struct SoldierEvaluationPDFView: View {
    let soldier: EvalSoldier?
    let evalDate: Date
    let hours: Int
    let fitness: Int
    let marksmanship: Int
    let discipline: Int
    let teamwork: Int
    let knowledge: Int
    let total: Int
    let statusText: String
    let statusColor: Color
    let notes: String
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 14) {
            HStack {
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("نموذج تقييم جندي").font(.title2.bold())
                    Text(Date.now.formatted(date: .abbreviated, time: .shortened))
                        .font(.footnote).foregroundColor(.secondary)
                }
            }
            
            GroupBox {
                VStack(alignment: .trailing, spacing: 6) {
                    HStack {
                        textPair(title: "الاسم", value: soldier?.fullName ?? "—")
                        textPair(title: "الرتبة", value: soldier?.rank ?? "—")
                        textPair(title: "الوحدة", value: soldier?.unit ?? "—")
                    }
                    HStack {
                        textPair(title: "تاريخ التقييم", value: formatted(evalDate))
                        textPair(title: "ساعات التدريب", value: "\(hours) ساعة")
                        Spacer()
                    }
                }
            } label: {
                Text("بيانات أساسية").font(.headline)
            }
            
            GroupBox {
                VStack(spacing: 8) {
                    row(title: "اللياقة", value: fitness)
                    row(title: "الرماية", value: marksmanship)
                    row(title: "الانضباط", value: discipline)
                    row(title: "العمل الجماعي", value: teamwork)
                    row(title: "المعرفة", value: knowledge)
                }
            } label: {
                Text("محاور التقييم (0–100)").font(.headline)
            }
            
            GroupBox {
                HStack {
                    textPair(title: "المجموع", value: "\(total) / 100")
                    Spacer()
                    Text(statusText)
                        .font(.headline)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(statusColor.opacity(0.15), in: Capsule())
                        .foregroundStyle(statusColor)
                }
            } label: {
                Text("النتيجة العامة").font(.headline)
            }
            
            GroupBox {
                Text(notes.isEmpty ? "—" : notes)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .minimumScaleFactor(0.8)
            } label: {
                Text("ملاحظات المدرب").font(.headline)
            }
            
            Spacer(minLength: 0)
            
            HStack {
                Text("تم التوليد بواسطة Smart Military Hub")
                    .font(.footnote).foregroundColor(.secondary)
                Spacer()
                Text("صفحة 1 / 1").font(.footnote).foregroundColor(.secondary)
            }
        }
        .padding(24)
        .background(.white)
    }
    
    private func row(title: String, value: Int) -> some View {
        HStack {
            ProgressView(value: Double(value)/100)
                .tint(.blue)
                .frame(maxWidth: 240)
            Spacer()
            Text("\(value)").monospacedDigit()
            Text(title).font(.body)
        }
        .padding(.vertical, 4)
    }
    
    private func textPair(title: String, value: String) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(title).font(.caption).foregroundColor(.secondary)
            Text(value).font(.headline)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
    
    private func formatted(_ date: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "ar")
        df.dateStyle = .medium
        return df.string(from: date)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var color: Color = .blue
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(color.opacity(configuration.isPressed ? 0.85 : 1.0),
                        in: RoundedRectangle(cornerRadius: 14))
            .foregroundStyle(.white)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.08), lineWidth: 1))
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(.white.opacity(configuration.isPressed ? 0.10 : 0.08),
                        in: RoundedRectangle(cornerRadius: 14))
            .foregroundStyle(.white)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.08), lineWidth: 1))
    }
}

struct ActivityShareView: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) { }
}

struct SoldierEvaluationView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            SoldierEvaluationView()
                .environment(\.layoutDirection, .rightToLeft)
        }
        .preferredColorScheme(.dark)
    }
}
