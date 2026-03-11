import SwiftUI

enum SMHTasksKit {


    enum Status: String, Codable, CaseIterable, Identifiable {
        case open, done, blocked
        var id: String { rawValue }
        var title: String {
            switch self {
            case .open: return "مفتوحة"
            case .done: return "منتهية"
            case .blocked: return "معلّقة"
            }
        }
        var symbol: String {
            switch self {
            case .open: return "circle.dashed"
            case .done: return "checkmark.circle.fill"
            case .blocked: return "exclamationmark.triangle.fill"
            }
        }
        var tint: Color {
            switch self {
            case .open: return .blue
            case .done: return .green
            case .blocked: return .orange
            }
        }
    }

    struct Todo: Identifiable, Codable, Equatable {
        var id: String = UUID().uuidString
        var title: String
        var notes: String?
        var dueAt: Date?
        var status: Status = .open
        var createdAt: Date = Date()
        var updatedAt: Date = Date()
    }

    protocol Service {
        func loadTodos() async throws -> [Todo]
        func addTodo(_ todo: Todo) async throws
        func updateTodo(_ todo: Todo) async throws
        func deleteTodo(id: String) async throws
    }

    final class MockService: Service {
        private var storage: [Todo] = [
            Todo(title: "تفقد نقاط التفتيش", notes: "النقطة 3 و 5", dueAt: Date().addingTimeInterval(60*60)),
            Todo(title: "استلام معدات", notes: "مخزن أ-2", dueAt: Date().addingTimeInterval(60*60*5)),
            Todo(title: "تقرير مناوبة", notes: "مختصر — حتى صفحتين", dueAt: Calendar.current.date(byAdding: .day, value: 1, to: Date()))
        ]
        func loadTodos() async throws -> [Todo] { storage }
        func addTodo(_ todo: Todo) async throws { storage.insert(todo, at: 0) }
        func updateTodo(_ todo: Todo) async throws {
            if let i = storage.firstIndex(where: { $0.id == todo.id }) { storage[i] = todo }
        }
        func deleteTodo(id: String) async throws { storage.removeAll { $0.id == id } }
    }


    @MainActor
    final class VM: ObservableObject {
        @Published var all: [Todo] = []
        @Published var query: String = ""
        @Published var filter: Status? = .open
        @Published var loading = false
        @Published var errorMessage: String?

        private let service: Service
        init(service: Service = MockService()) { self.service = service }

        var visible: [Todo] {
            var items = all
            if let f = filter { items = items.filter { $0.status == f } }
            if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                items = items.filter {
                    $0.title.localizedCaseInsensitiveContains(query) ||
                    ($0.notes ?? "").localizedCaseInsensitiveContains(query)
                }
            }
            return items.sorted {
                let a = $0.dueAt ?? .distantFuture
                let b = $1.dueAt ?? .distantFuture
                return a < b
            }
        }

        func load() async {
            loading = true; defer { loading = false }
            do { all = try await service.loadTodos() }
            catch { errorMessage = "تعذّر تحميل المهام: \(error.localizedDescription)" }
        }

        func add(title: String, notes: String?, dueAt: Date?, status: Status) async {
            var t = Todo(title: title, notes: notes, dueAt: dueAt, status: status)
            t.createdAt = Date(); t.updatedAt = Date()
            do {
                try await service.addTodo(t)
                all.insert(t, at: 0)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } catch {
                errorMessage = "تعذّر إضافة المهمة."
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }

        func update(_ todo: Todo) async {
            do {
                try await service.updateTodo(todo)
                if let i = all.firstIndex(where: { $0.id == todo.id }) { all[i] = todo }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } catch {
                errorMessage = "تعذّر تحديث المهمة."
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }

        func delete(id: String) async {
            do {
                try await service.deleteTodo(id: id)
                all.removeAll { $0.id == id }
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } catch {
                errorMessage = "تعذّر حذف المهمة."
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
    }

    static func hex(_ value: UInt, alpha: Double = 1.0) -> Color {
        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0
        return Color(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }

    static func timeRemaining(until date: Date) -> String {
        let now = Date()
        if date <= now { return "انتهى الموعد" }
        let comps = Calendar.current.dateComponents([.day, .hour, .minute], from: now, to: date)
        let d = comps.day ?? 0, h = comps.hour ?? 0, m = comps.minute ?? 0
        if d > 0 { return "بعد \(d)ي \(h)س" }
        if h > 0 { return "بعد \(h)س \(m)د" }
        return "بعد \(m)د"
    }


    struct ProView: View {
        @StateObject private var vm = VM()
        @State private var showAdd = false
        @State private var editTodo: Todo? = nil

        var body: some View {
            ZStack {
                LinearGradient(colors: [Color.black, SMHTasksKit.hex(0x0C1F14)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()

                VStack(spacing: 14) {
                    header
                    SearchBar(text: $vm.query, placeholder: "ابحث في المهام")
                    StatusChips(filter: $vm.filter,
                                counts: (
                                    open: vm.all.filter{$0.status == .open}.count,
                                    done: vm.all.filter{$0.status == .done}.count,
                                    blocked: vm.all.filter{$0.status == .blocked}.count
                                ))
                    ToggleRow(isOn: Binding(get: { vm.filter == .open },
                                            set: { vm.filter = $0 ? .open : nil }))

                    contentList
                }
                .padding(.top, 14)
                .task { await vm.load() }
                .alert("خطأ", isPresented: Binding(get: { vm.errorMessage != nil },
                                                   set: { _ in vm.errorMessage = nil })) {
                    Button("حسناً", role: .cancel) { vm.errorMessage = nil }
                } message: { Text(vm.errorMessage ?? "") }
                .environment(\.layoutDirection, .rightToLeft)

                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        FloatingAddButton { showAdd = true }
                            .padding(.trailing, 18)
                            .padding(.bottom, 22)
                    }
                }
            }
            .sheet(isPresented: $showAdd) {
                EditTodoSheet { title, notes, due, status in
                    Task { await vm.add(title: title, notes: notes, dueAt: due, status: status) }
                }
                .presentationDetents([.height(420), .medium])
                .presentationDragIndicator(.visible)
            }
            .sheet(item: $editTodo) { t in
                EditTodoSheet(todo: t) { title, notes, due, status in
                    var nt = t
                    nt.title = title
                    nt.notes = notes
                    nt.dueAt = due
                    nt.status = status
                    Task { await vm.update(nt) }
                }
                .presentationDetents([.height(420), .medium])
            }
            .navigationBarHidden(true)
        }

        @ViewBuilder
        private var contentList: some View {
            if vm.loading {
                Spacer(); ProgressView().controlSize(.large); Spacer()
            } else if vm.visible.isEmpty {
                Spacer(minLength: 8)
                EmptyStateView(
                    title: "لا توجد مهام",
                    subtitle: vm.query.isEmpty ? "أضف أول مهمة لك الآن" : "جرّب كلمات أخرى في البحث"
                )
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(vm.visible) { todo in
                            TaskCard(todo: todo)
                                .contextMenu {
                                    Button {
                                        var t = todo
                                        t.status = (todo.status == .done) ? .open : .done
                                        Task { await vm.update(t) }
                                    } label: {
                                        Label(todo.status == .done ? "إعادة فتح" : "وضع كمنتهية",
                                              systemImage: todo.status == .done ? "arrow.uturn.left.circle" : "checkmark.circle")
                                    }
                                    Divider()
                                    Button(role: .destructive) {
                                        Task { await vm.delete(id: todo.id) }
                                    } label: { Label("حذف", systemImage: "trash") }
                                }
                                .onTapGesture { editTodo = todo }
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    Button {
                                        var t = todo
                                        t.status = (todo.status == .done) ? .open : .done
                                        Task { await vm.update(t) }
                                    } label: {
                                        Label(todo.status == .done ? "إعادة" : "إنهاء",
                                              systemImage: todo.status == .done ? "arrow.uturn.left.circle" : "checkmark.circle")
                                    }.tint(.green)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        Task { await vm.delete(id: todo.id) }
                                    } label: { Label("حذف", systemImage: "trash") }
                                }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 96)
                }
            }
        }

        private var header: some View {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("المهام اليومية")
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Text("تابع تقدمك ونفّذ مهامك بسهولة")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                }
                Spacer()
                HStack(spacing: 10) {
                    CircleButton(system: "line.3.horizontal.decrease.circle")
                    CircleButton(system: "bell.badge")
                }
            }
            .padding(.horizontal, 16)
        }
    }

   
    struct SearchBar: View {
        @Binding var text: String
        var placeholder: String = "ابحث"
        var body: some View {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").opacity(0.8)
                TextField(placeholder, text: $text)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            .font(.subheadline)
            .padding(12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
            .padding(.horizontal, 16)
        }
    }

    struct StatusChips: View {
        @Binding var filter: Status?
        let counts: (open: Int, done: Int, blocked: Int)
        var body: some View {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    chip("مفتوحة", counts.open, "circle.dashed", .blue, .open)
                    chip("منتهية", counts.done, "checkmark.circle.fill", .green, .done)
                    chip("معلّقة", counts.blocked, "exclamationmark.triangle.fill", .orange, .blocked)
                }.padding(.horizontal, 16)
            }
        }
        private func chip(_ title: String, _ count: Int, _ symbol: String, _ tint: Color, _ type: Status) -> some View {
            Button {
                filter = (filter == type) ? nil : type
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: symbol)
                    Text(title)
                    Text("\(count)")
                        .font(.footnote).bold()
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(tint.opacity(0.15), in: Capsule())
                }
                .font(.caption)
                .foregroundStyle(filter == type ? .white : tint)
                .padding(.horizontal, 12).padding(.vertical, 9)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(
                    Capsule().strokeBorder(
                        LinearGradient(colors: [tint.opacity(filter == type ? 0.8 : 0.3), .clear],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 1
                    )
                )
            }.buttonStyle(.plain)
        }
    }

    struct ToggleRow: View {
        @Binding var isOn: Bool
        var body: some View {
            HStack {
                Toggle("إظهار المفتوحة فقط", isOn: $isOn).labelsHidden()
                Spacer()
                Text("إظهار المفتوحة فقط")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
    }

    struct TaskCard: View {
        let todo: Todo
        var body: some View {
            HStack(alignment: .top, spacing: 12) {
                StatusRing(status: todo.status)
                VStack(alignment: .leading, spacing: 6) {
                    Text(todo.title).font(.headline).foregroundStyle(.white)
                    HStack(spacing: 10) {
                        if let n = todo.notes, !n.isEmpty {
                            Label(n, systemImage: "note.text")
                                .font(.caption).foregroundStyle(.white.opacity(0.7)).lineLimit(1)
                        }
                        if let d = todo.dueAt {
                            Label("\(d.formatted(date: .abbreviated, time: .shortened))",
                                  systemImage: "calendar.badge.clock")
                                .font(.caption).foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    if let d = todo.dueAt {
                        HStack(spacing: 6) {
                            Image(systemName: "hourglass"); Text(SMHTasksKit.timeRemaining(until: d))
                        }
                        .font(.caption2).foregroundStyle(.white.opacity(0.7))
                    }
                }
                Spacer()
                switch todo.status {
                case .open: Pill(text: "مفتوحة", tint: .blue)
                case .done: Pill(text: "منتهية", tint: .green)
                case .blocked: Pill(text: "معلّقة", tint: .orange)
                }
            }
            .padding(14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(LinearGradient(colors: [Color.white.opacity(0.08), .clear],
                                           startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
            )
        }

        private struct Pill: View {
            let text: String; let tint: Color
            var body: some View {
                Text(text)
                    .font(.caption2).bold()
                    .foregroundStyle(tint)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(tint.opacity(0.15), in: Capsule())
            }
        }
    }

    struct StatusRing: View {
        let status: Status
        var body: some View {
            ZStack {
                Circle().stroke(.white.opacity(0.15), lineWidth: 3).frame(width: 28, height: 28)
                Circle()
                    .trim(from: 0, to: status == .done ? 1 : (status == .blocked ? 0.33 : 0.66))
                    .stroke(style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .foregroundStyle(status.tint)
                    .rotationEffect(.degrees(-90))
                    .frame(width: 28, height: 28)
                Image(systemName: status.symbol)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(status.tint)
            }
        }
    }

    struct FloatingAddButton: View {
        var action: () -> Void
        var body: some View {
            Button(action: action) {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(
                        LinearGradient(colors: [SMHTasksKit.hex(0x00C853), SMHTasksKit.hex(0x00E676)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: Circle()
                    )
                    .shadow(color: .green.opacity(0.45), radius: 18, x: 0, y: 10)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("إضافة مهمة")
        }
    }

    struct CircleButton: View {
        let system: String
        var action: () -> Void = {}
        var body: some View {
            Button(action: action) {
                Image(systemName: system)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    struct EmptyStateView: View {
        let title: String
        let subtitle: String
        var body: some View {
            VStack(spacing: 10) {
                Image(systemName: "tray")
                    .font(.system(size: 44, weight: .regular))
                    .foregroundStyle(.white.opacity(0.5))
                Text(title).font(.headline).foregroundStyle(.white)
                Text(subtitle).font(.subheadline).foregroundStyle(.white.opacity(0.7))
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))
            .padding(.horizontal, 16)
        }
    }

    struct EditTodoSheet: View {
        var todo: Todo?
        var onSave: (_ title: String, _ notes: String?, _ dueAt: Date?, _ status: Status) -> Void

        @Environment(\.dismiss) private var dismiss
        @State private var title: String = ""
        @State private var notes: String = ""
        @State private var dueAt: Date = Date().addingTimeInterval(3600)
        @State private var hasDue: Bool = true
        @State private var status: Status = .open

        init(todo: Todo? = nil,
             onSave: @escaping (_ title: String, _ notes: String?, _ dueAt: Date?, _ status: Status) -> Void) {
            self.todo = todo
            self.onSave = onSave
            _title = State(initialValue: todo?.title ?? "")
            _notes = State(initialValue: todo?.notes ?? "")
            _hasDue = State(initialValue: todo?.dueAt != nil)
            _dueAt = State(initialValue: todo?.dueAt ?? Date().addingTimeInterval(3600))
            _status = State(initialValue: todo?.status ?? .open)
        }

        var body: some View {
            NavigationStack {
                Form {
                    Section("التفاصيل") {
                        TextField("عنوان المهمة", text: $title)
                        TextField("ملاحظات (اختياري)", text: $notes, axis: .vertical)
                            .lineLimit(2...4)
                    }
                    Section {
                        Toggle("تحديد موعد", isOn: $hasDue)
                        if hasDue {
                            DatePicker("الموعد", selection: $dueAt, displayedComponents: [.date, .hourAndMinute])
                        }
                    }
                    Section("الحالة") {
                        Picker("الحالة", selection: $status) {
                            ForEach(Status.allCases) { st in
                                Label(st.title, systemImage: st.symbol).tag(st)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
                .navigationTitle(todo == nil ? "مهمة جديدة" : "تعديل المهمة")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("إلغاء") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("حفظ") {
                            guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                            onSave(title, notes.isEmpty ? nil : notes, hasDue ? dueAt : nil, status)
                            dismiss()
                        }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .environment(\.layoutDirection, .rightToLeft)
        }
    }
}
