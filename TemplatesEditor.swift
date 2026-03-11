import SwiftUI
import Combine

struct TemplatesDiskStore {
    static let fileName = "shift_templates.json"

    static var fileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent(fileName)
    }

    static func save(_ templates: [ShiftTemplate]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(templates)
        try data.write(to: fileURL, options: .atomic)
    }

    static func load() throws -> [ShiftTemplate] {
        let url = fileURL
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        return try decoder.decode([ShiftTemplate].self, from: data)
    }
}

extension Notification.Name {
    static let templatesSaved = Notification.Name("templatesSaved")
}

struct TemplatesEditor: View {
    @Binding var templates: [ShiftTemplate]
    @State private var showTimePickerFor: TimeEditTarget?
    @State private var haptic = UINotificationFeedbackGenerator()
    @State private var searchText = ""

    @State private var showSavedToast = false
    @State private var autosaveWorkItem: DispatchWorkItem?

    private var filtered: [ShiftTemplate] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return q.isEmpty ? templates : templates.filter { $0.name.localizedStandardContains(q) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [colorHex(0x0E1116), colorHex(0x1A2332)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                List {
                    if templates.isEmpty {
                        Section {
                            VStack(spacing: 12) {
                                Image(systemName: "clock.badge.plus")
                                    .font(.system(size: 44, weight: .semibold))
                                    .symbolRenderingMode(.hierarchical)
                                Text("لا توجد قوالب بعد").font(.headline)
                                Text("اضغطي “إضافة” لإنشاء قالب مناوبة.")
                                    .foregroundStyle(.secondary)
                                    .font(.subheadline)
                            }
                            .frame(maxWidth: .infinity, minHeight: 220)
                            .listRowBackground(Color.clear)
                        }
                    }

                    if !filtered.isEmpty {
                        Section("القوالب اليومية") {
                            ForEach($templates) { $tpl in
                                if filtered.contains(where: { $0.id == tpl.id }) {
                                    TemplateCardRow(
                                        tpl: $tpl,
                                        onEditStartTime: { showTimePickerFor = .init(kind: .start, binding: $tpl.start) },
                                        onEditEndTime:   { showTimePickerFor = .init(kind: .end,   binding: $tpl.end) },
                                        onDuplicate:     { duplicate(tpl) },
                                        onValidate:      { validate(&tpl) }
                                    )
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.clear)
                                }
                            }
                            .onDelete(perform: delete)
                            .onMove(perform: move)
                        }
                    }
                }
                .environment(\.layoutDirection, .rightToLeft)
                .scrollContentBackground(.hidden)
                .listStyle(.insetGrouped)
                .navigationTitle("القوالب")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) { EditButton() }
                    ToolbarItem(placement: .principal) {
                        Text("إدارة القوالب")
                            .font(.system(.title3, design: .rounded, weight: .bold))
                            .foregroundStyle(.white.opacity(0.95))
                    }
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button {
                            saveNow()
                        } label: {
                            Label("حفظ", systemImage: "tray.and.arrow.down.fill")
                        }
                        Button {
                            addTemplate()
                        } label: {
                            Label("إضافة", systemImage: "plus.circle.fill")
                        }.tint(.white)
                    }
                }
                .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "ابحث باسم القالب")

                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: addTemplate) {
                            Image(systemName: "plus")
                                .font(.system(size: 22, weight: .bold))
                                .padding(18)
                                .background(.ultraThinMaterial, in: Circle())
                                .overlay {
                                    Circle().stroke(LinearGradient(colors: [.white.opacity(0.4), .clear],
                                                                  startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                                }
                                .shadow(color: .black.opacity(0.25), radius: 16, x: 0, y: 8)
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 12)
                        .accessibilityLabel("إضافة قالب جديد")
                    }
                }

                VStack {
                    if showSavedToast {
                        Label("تم الحفظ", systemImage: "checkmark.circle.fill")
                            .padding(.horizontal, 14).padding(.vertical, 10)
                            .background(.ultraThinMaterial, in: Capsule())
                            .overlay { Capsule().stroke(.white.opacity(0.25), lineWidth: 1) }
                            .shadow(radius: 12)
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .padding(.top, 12)
                    }
                    Spacer()
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.9), value: showSavedToast)
                .allowsHitTesting(false)
            }
            .sheet(item: $showTimePickerFor) { target in
                TimePickerSheet(target: target)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
        .onAppear {
            haptic.prepare()
            loadFromDisk()
        }
        .onChange(of: templates) { _ in
            autosaveWorkItem?.cancel()
            let work = DispatchWorkItem { try? saveToDiskAndNotify() }
            autosaveWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7, execute: work)
        }
    }

    private func addTemplate() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            templates.append(
                ShiftTemplate(
                    name: "قالب جديد",
                    start: DateComponents(hour: 8, minute: 0),
                    end: DateComponents(hour: 16, minute: 0),
                    isNight: false
                )
            )
        }
        haptic.notificationOccurred(.success)
    }

    private func delete(at offsets: IndexSet) {
        withAnimation(.easeInOut) { templates.remove(atOffsets: offsets) }
        haptic.notificationOccurred(.warning)
    }

    private func move(from source: IndexSet, to destination: Int) {
        withAnimation(.easeInOut) { templates.move(fromOffsets: source, toOffset: destination) }
    }

    private func duplicate(_ tpl: ShiftTemplate) {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
            var copy = tpl
            copy.id = UUID()
            copy.name = tpl.name + " (نسخة)"
            templates.append(copy)
        }
        haptic.notificationOccurred(.success)
    }

    private func validate(_ tpl: inout ShiftTemplate) {
        let sh = tpl.start.hour ?? 0
        let eh = tpl.end.hour ?? 0
        if !tpl.isNight, eh < sh {
            tpl.end.hour = sh
        }
    }

    private func loadFromDisk() {
        do {
            let loaded = try TemplatesDiskStore.load()
            if !loaded.isEmpty {
                templates = loaded
            }
        } catch {
            print("Load templates error:", error)
        }
    }

    private func saveNow() {
        do {
            try saveToDiskAndNotify()
            haptic.notificationOccurred(.success)
            withAnimation { showSavedToast = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                withAnimation { showSavedToast = false }
            }
        } catch {
            haptic.notificationOccurred(.error)
            print("Save templates error:", error)
        }
    }

    @discardableResult
    private func saveToDiskAndNotify() throws -> URL {
        try TemplatesDiskStore.save(templates)
        let url = TemplatesDiskStore.fileURL
        NotificationCenter.default.post(name: .templatesSaved, object: nil, userInfo: ["url": url])
        return url
    }
}

struct TemplateCardRow: View {
    @Binding var tpl: ShiftTemplate
    var onEditStartTime: () -> Void
    var onEditEndTime: () -> Void
    var onDuplicate: () -> Void
    var onValidate: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.ultraThinMaterial)
                        .overlay {
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(
                                    LinearGradient(colors: [.white.opacity(0.35), .white.opacity(0.05)],
                                                   startPoint: .topLeading,
                                                   endPoint: .bottomTrailing),
                                    lineWidth: 1
                                )
                        }
                    Image(systemName: tpl.isNight ? "moon.stars.fill" : "sun.max.fill")
                        .symbolRenderingMode(.hierarchical)
                        .font(.system(size: 22, weight: .semibold))
                        .padding(10)
                }
                .frame(width: 48, height: 48)

                VStack(alignment: .trailing, spacing: 6) {
                    TextField("اسم القالب", text: $tpl.name)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .multilineTextAlignment(.trailing)

                    HStack(spacing: 8) {
                        TimeBadge(title: "بداية", time: format(dc: tpl.start), action: onEditStartTime)
                        Text("—").foregroundStyle(.secondary)
                        TimeBadge(title: "نهاية", time: format(dc: tpl.end), action: onEditEndTime)
                    }
                    .font(.callout)
                }

                Spacer(minLength: 0)
            }

            HStack {
                Toggle(isOn: $tpl.isNight) {
                    Label("ليلي", systemImage: "sparkles")
                }
                .onChange(of: tpl.isNight) { _, _ in onValidate() }

                Spacer()

                Menu {
                    Button(action: onDuplicate) {
                        Label("نسخ", systemImage: "doc.on.doc")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 8)
                }
            }
            .contentTransition(.opacity)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.25), radius: 24, x: 0, y: 14)
                .overlay {
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(LinearGradient(colors: [.white.opacity(0.35), .clear],
                                               startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                }
        )
        .animation(.spring(response: 0.4, dampingFraction: 0.9), value: tpl)
    }
}

struct TimeBadge: View {
    var title: String
    var time: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "clock")
                Text("\(title): \(time)")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(.thinMaterial)
                    .overlay { Capsule().stroke(.white.opacity(0.25), lineWidth: 1) }
            )
        }
        .buttonStyle(.plain)
    }
}

struct TimeEditTarget: Identifiable {
    enum Kind { case start, end }
    let id = UUID()
    let kind: Kind
    var binding: Binding<DateComponents>
}

struct TimePickerSheet: View {
    let target: TimeEditTarget
    @Environment(\.dismiss) private var dismiss

    @State private var hour: Int = 8
    @State private var minute: Int = 0

    private var title: String {
        switch target.kind {
        case .start: return "تعديل وقت البداية"
        case .end:   return "تعديل وقت النهاية"
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                HStack(spacing: 8) {
                    Text(format(dc: target.binding.wrappedValue))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .padding(.vertical, 4)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal)

                Divider().opacity(0.4)

                HStack {
                    Picker("الساعة", selection: $hour) {
                        ForEach(0..<24, id: \.self) { h in
                            Text(String(format: "%02d", h)).tag(h)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)

                    Text(":").font(.title2.weight(.semibold)).opacity(0.6)

                    Picker("الدقيقة", selection: $minute) {
                        ForEach(0..<60, id: \.self) { m in
                            Text(String(format: "%02d", m)).tag(m)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                }
                .labelsHidden()
                .frame(height: 210)

                Spacer()
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("إلغاء") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("تم") {
                        var dc = target.binding.wrappedValue
                        dc.hour = hour
                        dc.minute = minute
                        target.binding.wrappedValue = dc
                        dismiss()
                    }.bold()
                }
            }
            .onAppear {
                hour = target.binding.wrappedValue.hour ?? 0
                minute = target.binding.wrappedValue.minute ?? 0
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }
}

@inline(__always)
func format(dc: DateComponents) -> String {
    let h = dc.hour ?? 0
    let m = dc.minute ?? 0
    return String(format: "%02d:%02d", h, m)
}

@inline(__always)
func colorHex(_ hex: UInt, _ alpha: Double = 1) -> Color {
    Color(.sRGB,
          red:   Double((hex >> 16) & 0xFF) / 255.0,
          green: Double((hex >>  8) & 0xFF) / 255.0,
          blue:  Double((hex >>  0) & 0xFF) / 255.0,
          opacity: alpha)
}

struct TemplatesEditor_Previews: PreviewProvider {
    struct Host: View {
        @State var templates: [ShiftTemplate] = [
            .init(name: "صباحي", start: .init(hour: 06, minute: 00), end: .init(hour: 14, minute: 00), isNight: false),
            .init(name: "مسائي", start: .init(hour: 14, minute: 00), end: .init(hour: 22, minute: 00), isNight: false),
            .init(name: "ليلي",  start: .init(hour: 22, minute: 00), end: .init(hour: 06, minute: 00), isNight: true)
        ]
        var body: some View { TemplatesEditor(templates: $templates) }
    }
    static var previews: some View {
        Host().preferredColorScheme(.dark)
    }
}
