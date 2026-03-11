import SwiftUI
import PDFKit
import UIKit

enum TrainingTask: String, CaseIterable, Identifiable {
    case firstAid = "الإسعافات الأولية"
    case shooting = "الرماية"
    case fitness = "اللياقة البدنية"
    case tactics = "تكتيكات ميدانية"
    var id: String { rawValue }
}

struct TrainingSession: Identifiable, Hashable {
    var id = UUID()
    var soldier: Soldier
    var task: TrainingTask
    var start: Date
    var end: Date
}

final class ScheduleVM: ObservableObject {
    @Published var selectedDate = Date()
    @Published var allSoldiers: [Soldier] = [
        .init(id: .init(), name: "أحمد الشحي", rank: "رقيب", unit: "الكتيبة 1"),
        .init(id: .init(), name: "سالم البوسعيدي", rank: "عريف", unit: "الكتيبة 2"),
        .init(id: .init(), name: "حمود اليعربي", rank: "جندي", unit: "الكتيبة 1"),
        .init(id: .init(), name: "ناصر الرواحي", rank: "جندي أول", unit: "الكتيبة 3"),
        .init(id: .init(), name: "مازن الحارثي", rank: "عريف", unit: "الكتيبة 2")
    ]
    @Published var query = ""
    @Published var selectedSoldiers = Set<UUID>()
    @Published var selectedTask: TrainingTask = .firstAid
    @Published var startTime = Date()
    @Published var sessionMinutes: Int = 45
    @Published var sessions: [TrainingSession] = []
    @Published var isGenerating = false
    @Published var exportedFileURL: URL?
    
    var filteredSoldiers: [Soldier] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return allSoldiers }
        return allSoldiers.filter { $0.name.contains(query) || $0.unit.contains(query) || $0.rank.contains(query) }
    }
    
    func toggleSelect(_ soldier: Soldier) {
        if selectedSoldiers.contains(soldier.id) { selectedSoldiers.remove(soldier.id) }
        else { selectedSoldiers.insert(soldier.id) }
    }
    
    func generateSchedule() {
        isGenerating = true
        defer { isGenerating = false }
        
        let chosen = allSoldiers.filter { selectedSoldiers.contains($0.id) }
        guard !chosen.isEmpty else { return }
        
        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.hour, .minute], from: startTime)
        let day = calendar.startOfDay(for: selectedDate)
        guard let baseStart = calendar.date(bySettingHour: startComponents.hour ?? 9,
                                            minute: startComponents.minute ?? 0,
                                            second: 0, of: day) else { return }
        
        var cursor = baseStart
        var result: [TrainingSession] = []
        for s in chosen {
            let end = calendar.date(byAdding: .minute, value: sessionMinutes, to: cursor) ?? cursor.addingTimeInterval(Double(sessionMinutes) * 60)
            result.append(.init(soldier: s, task: selectedTask, start: cursor, end: end))
            cursor = end
        }
        sessions = result.sorted { $0.start < $1.start }
    }
    
    func removeSession(_ session: TrainingSession) {
        sessions.removeAll { $0.id == session.id }
    }
    
    @MainActor
    func exportPDF() {
        let url = makeSchedulePDF(sessions: sessions, date: selectedDate, task: selectedTask)
        exportedFileURL = url
    }
    
    @MainActor
    private func makeSchedulePDF(sessions: [TrainingSession], date: Date, task: TrainingTask) -> URL? {
        guard !sessions.isEmpty else { return nil }
        
        let pageSize = CGSize(width: 595, height: 842)
        let view = SchedulePDFView(date: date, task: task, sessions: sessions)
            .frame(width: pageSize.width, height: pageSize.height)
            .padding()
        
        let renderer = ImageRenderer(content: view)
        let temp = FileManager.default.temporaryDirectory
        let url = temp.appendingPathComponent("schedule-\(UUID().uuidString).pdf")
        
        let format = UIGraphicsPDFRendererFormat()
        let bounds = CGRect(origin: .zero, size: pageSize)
        let pdf = UIGraphicsPDFRenderer(bounds: bounds, format: format)
        
        do {
            try pdf.writePDF(to: url) { ctx in
                ctx.beginPage()
                if let img = renderer.uiImage {
                    img.draw(in: bounds)
                } else {
                    let hosting = UIHostingController(rootView: view)
                    hosting.view.bounds = bounds
                    hosting.view.backgroundColor = .clear
                    hosting.view.layer.render(in: ctx.cgContext)
                }
            }
            return url
        } catch {
            print("PDF error:", error)
            return nil
        }
    }
}

struct FancyGroupBoxStyle: GroupBoxStyle {
    var label: Label<Text, Image>
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                label
                    .font(.headline.bold())
                    .foregroundColor(.white)
                    .shadow(radius: 2)
                Spacer()
            }
            .padding(14)
            .background(LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing))
            .cornerRadius(18)
            
            configuration.content
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(22)
                .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 6)
        }
    }
}

struct SessionRow: View {
    let session: TrainingSession
    var onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "clock.fill")
                .foregroundStyle(LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing))
                .font(.title2)
                .padding(16)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 4)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(session.soldier.name).font(.headline.weight(.semibold))
                Text(session.task.rawValue).font(.subheadline).foregroundColor(.gray)
                Text("\(formatTime(session.start)) - \(formatTime(session.end))")
                    .font(.footnote.monospacedDigit())
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash.fill")
                    .foregroundColor(.red)
                    .padding(10)
                    .background(Color.red.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(16)
        .background(LinearGradient(colors: [Color(.systemBackground), Color(.secondarySystemBackground)], startPoint: .top, endPoint: .bottom))
        .cornerRadius(28)
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 6)
    }
    
    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f.string(from: date)
    }
}

struct SchedulePDFView: View {
    var date: Date
    var task: TrainingTask
    var sessions: [TrainingSession]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing)
                .mask(Text("تقرير جدول التدريب").font(.title.bold()))
                .frame(height: 32)
            
            Text("التاريخ: \(format(date))  •  المهمة: \(task.rawValue)")
                .foregroundColor(.secondary)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("الاسم").bold().frame(maxWidth: .infinity, alignment: .leading)
                    Text("الرتبة/الوحدة").bold().frame(maxWidth: .infinity, alignment: .leading)
                    Text("الوقت").bold().frame(width: 160, alignment: .leading)
                }
                
                ForEach(sessions) { s in
                    HStack {
                        Text(s.soldier.name).frame(maxWidth: .infinity, alignment: .leading)
                        Text("\(s.soldier.rank) • \(s.soldier.unit)").foregroundColor(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                        Text("\(fmt(s.start)) - \(fmt(s.end))").monospacedDigit().frame(width: 160, alignment: .leading)
                    }
                    Divider()
                }
            }
            
            Spacer()
            Text("تم الإنشاء بواسطة نظام إدارة التدريب")
                .font(.footnote)
                .foregroundColor(.secondary)
                .shadow(radius: 1)
        }
        .padding(28)
    }
    
    private func fmt(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f.string(from: d)
    }
    private func format(_ d: Date) -> String {
        let f = DateFormatter(); f.dateStyle = .medium; return f.string(from: d)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

struct ScheduleManagementView: View {
    @StateObject private var vm = ScheduleVM()
    @State private var showPDFShare = false
    @State private var showNoSessionsAlert = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    GroupBox {
                        DatePicker("اختر تاريخ التدريب", selection: $vm.selectedDate, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .padding(6)
                    }
                    .groupBoxStyle(FancyGroupBoxStyle(label: Label("التاريخ", systemImage: "calendar")))
                    
                    GroupBox {
                        Picker("المهمة", selection: $vm.selectedTask) {
                            ForEach(TrainingTask.allCases) { task in Text(task.rawValue).tag(task) }
                        }
                        .pickerStyle(.menu)
                        
                        DatePicker("وقت البدء", selection: $vm.startTime, displayedComponents: .hourAndMinute)
                        
                        HStack {
                            Text("مدة الجلسة (دقيقة)")
                            Spacer()
                            Stepper(value: $vm.sessionMinutes, in: 15...180, step: 5) {
                                Text("\(vm.sessionMinutes)").monospacedDigit()
                            }
                        }
                    }
                    .groupBoxStyle(FancyGroupBoxStyle(label: Label("إعدادات الجلسة", systemImage: "clock.fill")))
                    
                    GroupBox {
                        TextField("ابحث بالاسم/الوحدة/الرتبة", text: $vm.query)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(14)
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
                        
                        LazyVStack(spacing: 16) {
                            ForEach(vm.filteredSoldiers) { s in
                                Button { vm.toggleSelect(s) } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(s.name).font(.headline.weight(.semibold))
                                            Text("\(s.rank) • \(s.unit)").foregroundColor(.secondary).font(.subheadline)
                                        }
                                        Spacer()
                                        Image(systemName: vm.selectedSoldiers.contains(s.id) ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(vm.selectedSoldiers.contains(s.id) ? .green : .gray)
                                            .font(.title2)
                                    }
                                    .padding(14)
                                    .background(Color(.systemBackground))
                                    .cornerRadius(22)
                                    .shadow(color: Color.black.opacity(0.1), radius: 6, x: 0, y: 4)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.top, 10)
                    }
                    .groupBoxStyle(FancyGroupBoxStyle(label: Label("الجنود", systemImage: "person.3.fill")))
                    
                    HStack(spacing: 16) {
                        Button {
                            vm.generateSchedule()
                            if vm.sessions.isEmpty { showNoSessionsAlert = true }
                        } label: {
                            Label(vm.isGenerating ? "جارٍ التوليد..." : "توليد الجدول", systemImage: "wand.and.stars")
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                        .disabled(vm.isGenerating || vm.selectedSoldiers.isEmpty)
                        
                        Button {
                            if vm.sessions.isEmpty { showNoSessionsAlert = true }
                            else {
                                vm.exportPDF()
                                if vm.exportedFileURL != nil { showPDFShare = true }
                            }
                        } label: {
                            Label("تصدير PDF", systemImage: "doc.richtext.fill")
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.purple)
                    }
                    
                    GroupBox {
                        if vm.sessions.isEmpty {
                            Text("لا توجد جلسات بعد. اختر الجنود واضبط الوقت ثم اضغط توليد الجدول.")
                                .foregroundColor(.secondary)
                                .padding(8)
                        } else {
                            VStack(spacing: 12) {
                                ForEach(vm.sessions) { s in
                                    SessionRow(session: s) { vm.removeSession(s) }
                                }
                            }
                        }
                    }
                    .groupBoxStyle(FancyGroupBoxStyle(label: Label("جلسات التدريب", systemImage: "list.bullet.rectangle")))
                }
                .padding()
            }
            .navigationTitle("إدارة الجدول")
            .sheet(isPresented: $showPDFShare) {
                if let url = vm.exportedFileURL {
                    ShareSheet(activityItems: [url])
                        .ignoresSafeArea()
                }
            }
            .alert("لا توجد جلسات", isPresented: $showNoSessionsAlert) {
                Button("حسناً", role: .cancel) {}
            } message: {
                Text("ولِّد الجدول أولاً قبل التصدير.")
            }
        }
    }
}

struct ScheduleManagementView_Previews: PreviewProvider {
    static var previews: some View {
        ScheduleManagementView()
    }
}
