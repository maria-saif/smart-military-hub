import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct ChatMessage: Identifiable, Equatable {
    enum Sender { case user, bot }
    let id = UUID()
    let sender: Sender
    let text: String
    let time: Date = .now
}

struct QuickAction: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let command: String
}

@MainActor
final class SoldierChatBotViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var input: String = ""
    @Published var isTyping = false
    @Published var unreadAlerts: Int = 0
    @Published var todayShift: (date: Date, start: String, end: String, loc: String)?
    
    private var alertsListener: ListenerRegistration?
    private var shiftsListener: ListenerRegistration?
    
    func start() {
        messages = [
            .init(sender: .bot, text: "مرحبًا! أنا المساعد الميداني لـ Smart Military Hub.\nاسألني عن مناوبتك اليوم أو قل: «التنبيهات».")
        ]
        attachLiteData()
    }
    func stop() {
        alertsListener?.remove()
        shiftsListener?.remove()
    }
    
    func send() {
        let content = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        messages.append(.init(sender: .user, text: content))
        input = ""
        respond(to: content)
    }
    
    private func respond(to text: String) {
        isTyping = true
        Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            let reply = await handleIntent(text)
            messages.append(.init(sender: .bot, text: reply))
            isTyping = false
        }
    }
    
    private func normalize(_ s: String) -> String {
        s.folding(options: .diacriticInsensitive, locale: Locale(identifier: "ar"))
         .replacingOccurrences(of: "ة", with: "ه")
         .replacingOccurrences(of: "ى", with: "ي")
         .lowercased()
    }
    private func containsAny(_ text: String, _ keys: [String]) -> Bool {
        let t = normalize(text)
        return keys.contains { t.contains(normalize($0)) }
    }
    private func formatDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = .init(identifier: "ar")
        f.calendar = .init(identifier: .gregorian)
        f.dateFormat = "EEEE d MMM"
        return f.string(from: d)
    }
    private func intentHelp() -> String {
        """
        تقدر تقول:
        • جدولي اليوم / مناوبتي
        • التنبيهات / كم عندي تنبيه؟
        • ملفي / بياناتي
        • تدريب اليوم / تدريباتي
        • دعم فني / مشكلة
        """
    }
    private func replyForShift() -> String {
        if let s = todayShift {
            return "مناوبة **\(formatDate(s.date))**:\n\(s.start) — \(s.end)\nالموقع: \(s.loc)"
        } else {
            return "لا توجد مناوبة مسجّلة لليوم."
        }
    }
    private func replyForAlerts() -> String { "عندك \(unreadAlerts) تنبيه غير مقروء." }
    
    private func handleIntent(_ raw: String) async -> String {
        if containsAny(raw, ["ساعدني","help","اوامر","ماذا استطيع"]) { return intentHelp() }
        if containsAny(raw, ["التنبيه","التنبيهات","الاشعارات","alerts"]) { return replyForAlerts() }
        if containsAny(raw, ["مناوبتي","جدولي اليوم","شفت اليوم","shift","schedule"]) { return replyForShift() }
        if containsAny(raw, ["ملفي","بياناتي","بروفايلي","profile"]) {
            return "افتح صفحة **لوحة الجندي** لعرض بياناتك."
        }
        if containsAny(raw, ["تدريب","training"]) {
            return "راجع قسم **التدريب الذكي** لمتابعة الدروس والاختبارات."
        }
        if containsAny(raw, ["دعم","support","مشكله","بلاغ"]) {
            return "لرفع بلاغ اختر **الدعم الفني** من القائمة."
        }
        return "فهمت طلبك: «\(raw)».\n\(intentHelp())"
    }
    
    private func attachLiteData() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        
        alertsListener = db.collection("soldiers").document(uid)
            .collection("alerts")
            .whereField("isRead", isEqualTo: false)
            .addSnapshotListener { [weak self] snap, _ in
                self?.unreadAlerts = snap?.documents.count ?? 0
            }
        
        shiftsListener = db.collection("soldiers").document(uid)
            .collection("shifts")
            .addSnapshotListener { [weak self] snap, _ in
                guard let self else { return }
                let items = (snap?.documents ?? []).compactMap { doc -> (Date,String,String,String)? in
                    let d = doc.data()
                    guard let ts = d["date"] as? Timestamp else { return nil }
                    let date = ts.dateValue()
                    let start = d["start"] as? String ?? "—"
                    let end = d["end"] as? String ?? "—"
                    let loc = d["location"] as? String ?? "—"
                    return (date,start,end,loc)
                }
                if let today = items.first(where: { Calendar.current.isDateInToday($0.0) }) {
                    self.todayShift = (today.0, today.1, today.2, today.3)
                } else {
                    self.todayShift = nil
                }
            }
    }
}

struct SoldierChatBotView: View {
    @StateObject private var vm = SoldierChatBotViewModel()
    @FocusState private var isFocused: Bool
    
    private let actions: [QuickAction] = [
        .init(title: "مناوبتي اليوم", icon: "clock.badge", command: "جدولي اليوم"),
        .init(title: "التنبيهات",     icon: "bell.badge.fill", command: "التنبيهات"),
        .init(title: "ملفي",           icon: "person.text.rectangle", command: "ملفي"),
        .init(title: "تدريباتي",      icon: "figure.strengthtraining.traditional", command: "تدريب")
    ]
    
    var body: some View {
        ZStack {
            AngularGradient(
                gradient: .init(colors: [Color.black, Color(hexRGB: 0x0F1F14), Color.green.opacity(0.35)]),
                center: .center, angle: .degrees(135)
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                header
                
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(vm.messages) { msg in
                                bubble(msg)
                                    .id(msg.id)
                                    .transition(.move(edge: msg.sender == .user ? .trailing : .leading).combined(with: .opacity))
                            }
                            if vm.isTyping { typingIndicator }
                            suggestions.padding(.top, 6)
                        }
                        .padding(.horizontal, 14)
                        .padding(.top, 10)
                        .padding(.bottom, 8)
                    }
                    .onChange(of: vm.messages.count) { _ in
                        withAnimation(.easeOut) { proxy.scrollTo(vm.messages.last?.id, anchor: .bottom) }
                    }
                }
                
                inputBar
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { vm.start() }
        .onDisappear { vm.stop() }
    }
    
    private var header: some View {
        HStack(alignment: .center) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.green)
                .padding(8)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text("المساعد الميداني")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                Text("جاهز للخدمة · \(Date.now.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
            Spacer()
            if vm.unreadAlerts > 0 {
                Text("\(vm.unreadAlerts)")
                    .font(.caption2.bold())
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(.red, in: Capsule())
                    .foregroundStyle(.white)
                    .accessibilityLabel("تنبيهات غير مقروءة \(vm.unreadAlerts)")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
    
    @ViewBuilder
    private func bubble(_ m: ChatMessage) -> some View {
        HStack {
            if m.sender == .bot { avatar }
            VStack(alignment: .leading, spacing: 6) {
                Text(m.text)
                    .font(.body)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                Text(m.time, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        m.sender == .user
                        ? AnyShapeStyle(LinearGradient(
                            colors: [Color(hexRGB: 0x1B3A2F, alpha: 0.85), Color.green.opacity(0.35)],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                        : AnyShapeStyle(Color.white.opacity(0.08))
                    )
            )
            .overlay(alignment: .topLeading) {
                if m.sender == .bot {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.08))
                }
            }
            if m.sender == .user { avatarUser }
        }
        .frame(maxWidth: .infinity, alignment: m.sender == .user ? .trailing : .leading)
        .padding(m.sender == .user ? .leading : .trailing, 60)
    }
    
    private var avatar: some View {
        Image(systemName: "face.smiling.inverse")
            .font(.title3)
            .foregroundStyle(.green)
            .padding(8)
    }
    private var avatarUser: some View {
        Image(systemName: "person.circle.fill")
            .font(.title3)
            .foregroundStyle(.green)
            .padding(8)
    }
    
    private var typingIndicator: some View {
        HStack(spacing: 6) {
            Circle().frame(width: 6, height: 6)
            Circle().frame(width: 6, height: 6)
            Circle().frame(width: 6, height: 6)
        }
        .foregroundStyle(.white.opacity(0.7))
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Color.white.opacity(0.08), in: Capsule())
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 60)
        .transition(.opacity)
    }
    
    private var suggestions: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(actions) { a in
                    Button {
                        vm.input = a.command
                        vm.send()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: a.icon)
                            Text(a.title)
                        }
                        .font(.footnote.weight(.medium))
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                    }
                }
            }
            .padding(.horizontal, 6)
        }
    }
    
    private var inputBar: some View {
        HStack(spacing: 10) {
            Button { /* لاحقًا: مايك */ } label: {
                Image(systemName: "mic.fill")
                    .padding(10)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            
            TextField("اكتب رسالتك…", text: $vm.input, axis: .vertical)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .focused($isFocused)
                .padding(12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .foregroundStyle(.white)
                .lineLimit(1...4)
            
            Button {
                vm.send()
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            } label: {
                Image(systemName: "paperplane.fill")
                    .rotationEffect(.degrees(180)) // RTL
                    .padding(10)
                    .background(
                        LinearGradient(
                            colors: [Color.green.opacity(0.9), Color(hexRGB: 0x1B3A2F)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        in: Circle()
                    )
                    .foregroundStyle(.black)
            }
            .disabled(vm.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Rectangle()
                .fill(.thinMaterial)
                .overlay(Divider().background(Color.white.opacity(0.08)), alignment: .top)
        )
    }
}

extension Color {
    init(hexRGB: UInt, alpha: Double = 1.0) {
        self.init(.sRGB,
                  red:   Double((hexRGB >> 16) & 0xff) / 255.0,
                  green: Double((hexRGB >> 8)  & 0xff) / 255.0,
                  blue:  Double( hexRGB        & 0xff) / 255.0,
                  opacity: alpha)
    }
}

#Preview {
    NavigationStack { SoldierChatBotView() }
}
