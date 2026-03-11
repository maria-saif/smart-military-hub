import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct SoldierAlert: Identifiable, Hashable {
    var id: String
    var title: String
    var message: String
    var type: String
    var date: Date
    var isRead: Bool
    
    var icon: String {
        switch type.lowercased() {
        case "system":   return "gear.circle.fill"
        case "training": return "book.fill"
        case "shift":    return "calendar.badge.clock"
        case "warning":  return "exclamationmark.triangle.fill"
        default:         return "bell.fill"
        }
    }
    
    var tint: Color {
        switch type.lowercased() {
        case "system":   return Color(red: 1.0, green: 0.84, blue: 0.0)
        case "training": return Color(red: 0.0, green: 0.60, blue: 0.90)
        case "shift":    return Color(red: 0.40, green: 0.90, blue: 0.50)
        case "warning":  return Color(red: 1.0, green: 0.55, blue: 0.0)
        default:         return .gray
        }
    }
    
    static var mocks: [SoldierAlert] = [
        .init(id: "1", title: "تحديث النظام", message: "تم تحديث النظام إلى الإصدار 1.2", type: "system",   date: Date().addingTimeInterval(-3600),  isRead: false),
        .init(id: "2", title: "حصة تدريب",   message: "موعد تدريب الرماية غدًا 07:30",       type: "training", date: Date().addingTimeInterval(-7200),  isRead: false),
        .init(id: "3", title: "مناوبة",      message: "مناوبة البوابة الشرقية الساعة 18:00", type: "shift",    date: Date().addingTimeInterval(-86000), isRead: true),
        .init(id: "4", title: "تنبيه أمني",  message: "رجاء التأكد من بطاقات الدخول",        type: "warning",  date: Date().addingTimeInterval(-200000),isRead: true),
    ]
}

enum AlertFilter: String, CaseIterable, Identifiable {
    case all = "الكل"
    case unread = "غير المقروء"
    case system = "النظام"
    case training = "التدريب"
    case shift = "المناوبات"
    case warning = "تحذيرات"
    var id: String { rawValue }
}


struct SoldierAlertsView: View {
    let useMock: Bool
    init(useMock: Bool = false) { self.useMock = useMock }
    
    @State private var alerts: [SoldierAlert] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var searchText = ""
    @State private var filter: AlertFilter = .all
    @State private var listener: ListenerRegistration?
    
    private var filteredAlerts: [SoldierAlert] {
        var list = alerts
        switch filter {
        case .all: break
        case .unread:  list = list.filter { !$0.isRead }
        case .system:  list = list.filter { $0.type.lowercased() == "system" }
        case .training:list = list.filter { $0.type.lowercased() == "training" }
        case .shift:   list = list.filter { $0.type.lowercased() == "shift" }
        case .warning: list = list.filter { $0.type.lowercased() == "warning" }
        }
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !q.isEmpty {
            list = list.filter { $0.title.lowercased().contains(q) || $0.message.lowercased().contains(q) }
        }
        return list
    }
    
    var body: some View {
        ZStack {
            backgroundGradient.ignoresSafeArea()
            content.safeAreaPadding(.horizontal)
        }
        .navigationTitle("التنبيهات")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { markAllRead() } label: {
                    Label("تعيين الكل كمقروء", systemImage: "checkmark.seal")
                }
                .disabled(alerts.allSatisfy { $0.isRead })
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    if useMock { alerts = SoldierAlert.mocks.shuffled() } else { seedSampleAlerts() }
                } label: { Image(systemName: "bell.badge") }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .onAppear { setup() }
        .onDisappear { listener?.remove() }
    }
    
    private var content: some View {
        VStack(spacing: 16) {
            header
            filtersBar
            searchField
            
            if isLoading {
                ProgressView("جارِ التحميل…").tint(.yellow)
                Spacer()
            } else if let err = errorMessage {
                errorState(err)
            } else if filteredAlerts.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(filteredAlerts) { alert in
                        alertRow(alert)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                    .onDelete(perform: delete)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .refreshable { refresh() }
            }
        }
        .padding(.vertical)
    }
    
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [Color(red: 0.04, green: 0.06, blue: 0.04),
                     Color(red: 0.00, green: 0.30, blue: 0.16)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }
    
    private var header: some View {
        VStack(spacing: 6) {
            Image(systemName: "bell.fill").font(.system(size: 48)).foregroundStyle(.yellow)
            Text("Smart Military Hub")
                .foregroundStyle(Color(white: 0.92))
                .font(.subheadline)
        }
    }
    
    private var filtersBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(AlertFilter.allCases) { f in
                    FilterChip(
                        title: f.rawValue,
                        isActive: filter == f,
                        tap: { withAnimation(.easeInOut) { filter = f } }
                    )
                }
            }
            .padding(.horizontal, 2)
        }
    }
    
    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
            TextField("ابحث في العناوين أو الرسائل…", text: $searchText)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
            if !searchText.isEmpty {
                Button { searchText = "" } label: { Image(systemName: "xmark.circle.fill") }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.1), lineWidth: 1))
        .foregroundStyle(Color(white: 0.92))
    }
    
    private func errorState(_ msg: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").font(.largeTitle)
            Text("خطأ أثناء الجلب").font(.headline)
            Text(msg).font(.footnote).multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.8))
        }
        .foregroundStyle(.orange)
        .padding(.top, 40)
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bell.slash.fill").font(.system(size: 52))
                .foregroundStyle(.white.opacity(0.7))
            Text("لا توجد تنبيهات حالياً")
                .foregroundStyle(Color(white: 0.92))
                .font(.headline)
            Text("ستظهر التنبيهات هنا عند إرسالها من القائد أو النظام.")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(.top, 30)
    }
    
    private func alertRow(_ alert: SoldierAlert) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle().fill(alert.tint.opacity(0.25)).frame(width: 40, height: 40)
                Image(systemName: alert.icon).foregroundStyle(alert.tint)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(alert.title).font(.headline).foregroundStyle(Color(white: 0.95))
                    if !alert.isRead { Circle().fill(Color.yellow).frame(width: 8, height: 8) }
                    Spacer()
                    Text(shortDate(alert.date)).font(.footnote).foregroundStyle(.white.opacity(0.75))
                }
                Text(alert.message).font(.subheadline).foregroundStyle(.white.opacity(0.88)).lineLimit(3)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(alert.tint.opacity(alert.isRead ? 0.45 : 0.80),
                                lineWidth: alert.isRead ? 0.8 : 1.8)
                        .shadow(color: alert.tint.opacity(0.28), radius: 3, x: 0, y: 1)
                )
        )
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if alert.isRead {
                Button("غير مقروء") { setRead(alert, false) }.tint(.indigo)
            } else {
                Button("مقروء") { setRead(alert, true) }.tint(.green)
            }
            Button(role: .destructive) { delete(id: alert.id) } label: { Label("حذف", systemImage: "trash") }
        }
        .contentShape(Rectangle())
        .onTapGesture { if !alert.isRead { setRead(alert, true) } }
    }
    
    private func shortDate(_ date: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "ar"); f.dateFormat = "d MMM"
        return f.string(from: date)
    }
    
    private func setup() {
        if useMock { alerts = SoldierAlert.mocks; isLoading = false; return }
        attachListener()
    }
    
    private func refresh() {
        if useMock { alerts = SoldierAlert.mocks.shuffled() }
        else { listener?.remove(); attachListener() }
    }
    
    private func attachListener() {
        guard let uid = Auth.auth().currentUser?.uid else {
            self.errorMessage = "المستخدم غير مسجّل."; self.isLoading = false; return
        }
        isLoading = true
        listener = Firestore.firestore()
            .collection("soldiers").document(uid)
            .collection("alerts")
            .order(by: "date", descending: true)
            .addSnapshotListener { snap, err in
                if let err = err {
                    self.errorMessage = err.localizedDescription; self.isLoading = false; return
                }
                let items: [SoldierAlert] = (snap?.documents ?? []).compactMap { d in
                    let data = d.data(); let ts = data["date"] as? Timestamp
                    return SoldierAlert(
                        id: d.documentID,
                        title: data["title"] as? String ?? "تنبيه",
                        message: data["message"] as? String ?? "—",
                        type: data["type"] as? String ?? "system",
                        date: ts?.dateValue() ?? Date(),
                        isRead: data["isRead"] as? Bool ?? false
                    )
                }
                withAnimation(.easeInOut) {
                    self.alerts = items; self.isLoading = false; self.errorMessage = nil
                }
            }
    }
    
    private func setRead(_ alert: SoldierAlert, _ read: Bool) {
        if useMock {
            if let idx = alerts.firstIndex(of: alert) { alerts[idx].isRead = read }
            return
        }
        guard let uid = Auth.auth().currentUser?.uid else { return }
        Firestore.firestore()
            .collection("soldiers").document(uid)
            .collection("alerts").document(alert.id)
            .updateData(["isRead": read])
    }
    
    private func delete(at offsets: IndexSet) {
        for i in offsets { delete(id: filteredAlerts[i].id) }
    }
    
    private func delete(id: String) {
        if useMock { alerts.removeAll { $0.id == id }; return }
        guard let uid = Auth.auth().currentUser?.uid else { return }
        Firestore.firestore()
            .collection("soldiers").document(uid)
            .collection("alerts").document(id)
            .delete()
    }
    
    private func markAllRead() {
        if useMock {
            alerts = alerts.map { var a = $0; a.isRead = true; return a }; return
        }
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let ref = Firestore.firestore()
            .collection("soldiers").document(uid)
            .collection("alerts")
        ref.getDocuments { snapshot, error in
            if let error = error { self.errorMessage = error.localizedDescription; return }
            let docs = snapshot?.documents ?? []; if docs.isEmpty { return }
            let batch = Firestore.firestore().batch()
            for doc in docs { batch.updateData(["isRead": true], forDocument: doc.reference) }
            batch.commit { err in
                if let err = err { self.errorMessage = err.localizedDescription }
                else { withAnimation { self.alerts = self.alerts.map { var a = $0; a.isRead = true; return a } } }
            }
        }
    }
    
    private func seedSampleAlerts() {
        guard !useMock, let uid = Auth.auth().currentUser?.uid else { return }
        let ref = Firestore.firestore()
            .collection("soldiers").document(uid)
            .collection("alerts")
        let now = Date()
        let samples: [[String: Any]] = [
            ["title":"تحديث النظام","message":"تم تحديث النظام إلى 1.2","type":"system","date": Timestamp(date: now.addingTimeInterval(-1000)),"isRead": false],
            ["title":"تدريب لياقة","message":"تمرين صباحي 06:00 في الساحة","type":"training","date": Timestamp(date: now.addingTimeInterval(-3600)),"isRead": false],
            ["title":"مناوبة البوابة","message":"اليوم 20:00 - 22:00","type":"shift","date": Timestamp(date: now.addingTimeInterval(-7200)),"isRead": true],
            ["title":"تنبيه أمني","message":"تفقد العتاد قبل المغادرة","type":"warning","date": Timestamp(date: now.addingTimeInterval(-150000)),"isRead": true],
        ]
        for s in samples { _ = ref.addDocument(data: s) }
    }
}

private struct FilterChip: View {
    let title: String
    let isActive: Bool
    let tap: () -> Void

    var body: some View {
        Button(action: tap) {
            Text(title)
                .font(.callout.weight(.semibold))
                .foregroundStyle(isActive ? Color.black.opacity(0.85) : Color(white: 0.92))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(chipShapeStyle(active: isActive), in: RoundedRectangle(cornerRadius: 18))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(.white.opacity(0.18), lineWidth: 1)
                )
        }
    }

    private func chipShapeStyle(active: Bool) -> AnyShapeStyle {
        if active {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [.yellow.opacity(0.75), .orange.opacity(0.5)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        } else {
            return AnyShapeStyle(Color.white.opacity(0.08))
        }
    }
}

struct SoldierAlertsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            SoldierAlertsView(useMock: true)
        }
        .preferredColorScheme(.dark)
    }
}
