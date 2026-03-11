import SwiftUI

// MARK: - Domain
enum LeaveType: String, CaseIterable, Identifiable {
    case annual = "سنوية"
    case sick = "مرضية"
    case emergency = "طارئة"
    case training = "تدريب"
    case other = "أخرى"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .annual: return "sun.max.fill"
        case .sick: return "cross.case.fill"
        case .emergency: return "bolt.heart.fill"
        case .training: return "figure.run.circle.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }
    var tint: Color {
        switch self {
        case .annual: return .yellow
        case .sick: return .mint
        case .emergency: return .red
        case .training: return .indigo
        case .other: return .gray
        }
    }
}

enum LeaveStatus: String, CaseIterable, Identifiable {
    case pending = "قيد المراجعة"
    case approved = "مقبول"
    case rejected = "مرفوض"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .pending: return "hourglass"
        case .approved: return "checkmark.seal.fill"
        case .rejected: return "xmark.octagon.fill"
        }
    }
    var tint: Color {
        switch self {
        case .pending: return .orange
        case .approved: return .green
        case .rejected: return .red
        }
    }
}

struct LeaveRequest: Identifiable, Hashable {
    var id: String = UUID().uuidString
    var type: LeaveType
    var from: Date
    var to: Date
    var reason: String
    var status: LeaveStatus
}

struct LeaveRequestsView: View {
    let soldiers: [Soldier]
    let days: [Date]
    @Binding var daysOff: Set<DayOff>

    init(soldiers: [Soldier] = [],
         days: [Date] = [],
         daysOff: Binding<Set<DayOff>> = .constant([])) {
        self.soldiers = soldiers
        self.days = days
        self._daysOff = daysOff
    }

    @State private var leaveType: LeaveType = .annual
    @State private var from: Date = Date()
    @State private var to: Date = Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()
    @State private var reason: String = ""
    @State private var isSubmitting: Bool = false
    @State private var showSuccess: Bool = false
    @State private var showValidationAlert: Bool = false
    @State private var validationMessage: String = ""

    @State private var annualBalance: Int = 30

    @State private var history: [LeaveRequest] = [
        .init(type: .annual,   from: dateFromString("2025-05-01"), to: dateFromString("2025-05-03"), reason: "إجازة قصيرة",            status: .approved),
        .init(type: .sick,     from: dateFromString("2025-05-15"), to: dateFromString("2025-05-16"), reason: "نزلة برد",               status: .pending),
        .init(type: .training, from: dateFromString("2025-04-10"), to: dateFromString("2025-04-12"), reason: "دورة إسعافات أولية",     status: .rejected)
    ]

    @State private var statusFilter: LeaveStatus? = nil

    @Environment(\.dismiss) private var dismiss
    private let autoDismissAfterSubmit = true

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            gradientBackground

            ScrollView {
                VStack(spacing: 18) {
                    headerCard
                    balanceCard
                    requestComposer
                    historySection
                    Spacer(minLength: 16)
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
            }
        }
        .navigationTitle("طلبات الإجازة")
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.layoutDirection, .rightToLeft)
        .alert("تنبيه", isPresented: $showValidationAlert, actions: {
            Button("حسناً", role: .cancel) {}
        }, message: { Text(validationMessage) })
        .overlay(submitToast, alignment: .top)
    }
}

private extension LeaveRequestsView {
    var gradientBackground: some View {
        LinearGradient(
            gradient: Gradient(colors: [Color.black, Color.green.opacity(0.6)]),
            startPoint: .topLeading, endPoint: .bottomTrailing
        ).ignoresSafeArea()
    }

    var headerCard: some View {
        GlassCard(hPadding: 16, vPadding: 16) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(.ultraThinMaterial).frame(width: 56, height: 56)
                    Image(systemName: leaveType.icon)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(leaveType.tint)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("قدّم طلب إجازة")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("اختر النوع والتواريخ ثم أرسل للمراجعة")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                }
                Spacer()
            }
        }
    }

    var balanceCard: some View {
        GlassCard(hPadding: 16, vPadding: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("رصيد الإجازة السنوية")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.9))
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(annualBalance)")
                            .font(.system(size: 32, weight: .heavy, design: .rounded))
                            .foregroundStyle(.green)
                        Text("يوم")
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
                Spacer()
                VStack(spacing: 8) {
                    progressRing(value: usedAnnualPercentage)
                        .frame(width: 64, height: 64)
                    Text("استهلاك")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
    }

    var requestComposer: some View {
        GlassCard(hPadding: 14, vPadding: 14, corner: 22) {
            VStack(spacing: 14) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(LeaveType.allCases) { t in
                            SelectChip(title: t.rawValue, systemImage: t.icon, isSelected: leaveType == t, tint: t.tint) {
                                leaveType = t
                            }
                        }
                    }.padding(.vertical, 4)
                }

                GlassTile(title: "من", systemImage: "calendar") {
                    DatePicker("", selection: $from, displayedComponents: .date)
                        .labelsHidden()
                }
                GlassTile(title: "إلى", systemImage: "calendar.badge.clock") {
                    DatePicker("", selection: $to, in: from..., displayedComponents: .date)
                        .labelsHidden()
                }

                HStack {
                    Label("\(daysCount) يوم", systemImage: "clock").foregroundStyle(.white)
                    Spacer()
                    if leaveType == .annual {
                        Label("المتبقي بعد الطلب: \(max(0, annualBalance - daysCount)) يوم", systemImage: "scalemass.fill")
                            .foregroundStyle(.white.opacity(0.9))
                            .font(.caption)
                    }
                }
                .padding(12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.08)))

                VStack(alignment: .leading, spacing: 8) {
                    Label("السبب (اختياري)", systemImage: "text.bubble.fill")
                        .foregroundStyle(.white.opacity(0.9))
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $reason)
                            .frame(minHeight: 90)
                            .padding(8)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.08)))
                        if reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("مثال: ظرف عائلي طارئ…")
                                .foregroundStyle(.white.opacity(0.4))
                                .padding(.top, 14)
                                .padding(.leading, 14)
                        }
                    }
                }

                HStack(spacing: 10) {
                    Button(action: submit) {
                        HStack {
                            if isSubmitting { ProgressView().tint(.black) }
                            Text(isSubmitting ? "جاري الإرسال" : "إرسال الطلب")
                                .fontWeight(.bold)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SMHUI.PrimaryButton())
                    .disabled(isSubmitting)

                    Menu {
                        Button("إرفاق ملف (لاحقاً)", systemImage: "paperclip", action: {})
                        Button("مسح الحقول", systemImage: "eraser.fill", role: .destructive) { resetForm() }
                    } label: {
                        Label("خيارات", systemImage: "slider.horizontal.3")
                            .frame(width: 110, height: 48)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .foregroundStyle(.white)
                }
            }
        }
    }

    var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("طلباتي السابقة")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Menu {
                    Button("الكل", systemImage: "line.3.horizontal.decrease.circle") { statusFilter = nil }
                    Divider()
                    ForEach(LeaveStatus.allCases) { st in
                        Button(st.rawValue, systemImage: st.icon) { statusFilter = st }
                    }
                } label: {
                    Label(statusFilter?.rawValue ?? "تصفية الحالة", systemImage: "line.3.horizontal.decrease.circle")
                        .foregroundStyle(.white.opacity(0.9))
                }
            }

            ForEach(filteredHistory) { item in
                HistoryRow(item: item)
            }
        }
        .padding(.horizontal, 4)
    }

    var submitToast: some View {
        Group {
            if showSuccess {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill").font(.title2)
                    Text("تم إرسال الطلب للمراجعة")
                        .fontWeight(.semibold)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.12)))
                .foregroundStyle(.green)
                .padding(.top, 10)
                .transition(.move(edge: .top).combined(with: .opacity))
                .onAppear {
                    if autoDismissAfterSubmit {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}

private extension LeaveRequestsView {
    var daysCount: Int {
        let cal = Calendar.current
        let start = cal.startOfDay(for: from)
        let end = cal.startOfDay(for: to)
        let comps = cal.dateComponents([.day], from: start, to: end)
        return max(1, (comps.day ?? 0) + 1) // inclusive
    }

    var usedAnnualPercentage: Double {
        let used = max(0, 30 - annualBalance)
        let p = Double(used) / 30.0
        return min(max(p, 0), 1)
    }

    var filteredHistory: [LeaveRequest] {
        if let f = statusFilter { return history.filter { $0.status == f } }
        return history
    }

    func submit() {
        guard to >= from else { return showValidation(message: "تاريخ \"إلى\" يجب أن يكون بعد \"من\"") }
        if leaveType == .annual && daysCount > annualBalance {
            return showValidation(message: "عدد الأيام يتجاوز رصيدك السنوي")
        }
        withAnimation { isSubmitting = true }
        // Simulate network
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            let newItem = LeaveRequest(type: leaveType, from: from, to: to, reason: reason, status: .pending)
            history.insert(newItem, at: 0)
            if leaveType == .annual { annualBalance = max(annualBalance - daysCount, 0) }
            resetForm()
            withAnimation(.spring(response: 0.6, dampingFraction: 0.9)) {
                showSuccess = true
            }
            isSubmitting = false
        }
    }

    func resetForm() {
        leaveType = .annual
        from = Date()
        to = Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()
        reason = ""
    }

    func showValidation(message: String) {
        validationMessage = message
        showValidationAlert = true
    }
}

struct GlassCard<Content: View>: View {
    var hPadding: CGFloat = 12
    var vPadding: CGFloat = 12
    var corner: CGFloat = 20
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .padding(.vertical, vPadding)
            .padding(.horizontal, hPadding)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: corner, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: corner).stroke(.white.opacity(0.08)))
            .shadow(color: .black.opacity(0.25), radius: 18, x: 0, y: 10)
    }
}

struct GlassTile<Inner: View>: View {
    var title: String
    var systemImage: String
    @ViewBuilder var inner: Inner
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .foregroundStyle(.white.opacity(0.9))
            inner
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.08)))
    }
}

struct SelectChip: View {
    var title: String
    var systemImage: String
    var isSelected: Bool
    var tint: Color = .green
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                Text(title).fontWeight(.semibold)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(tint.opacity(isSelected ? 0.25 : 0.0))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? tint.opacity(0.6) : .white.opacity(0.08), lineWidth: 1)
            )
            .foregroundStyle(isSelected ? tint : .white)
        }
    }
}

struct HistoryRow: View {
    let item: LeaveRequest

    var body: some View {
        GlassCard(hPadding: 14, vPadding: 12, corner: 18) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(item.type.tint.opacity(0.18))
                        .frame(width: 48, height: 48)
                    Image(systemName: item.type.icon)
                        .foregroundStyle(item.type.tint)
                }
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(item.type.rawValue)
                            .font(.headline)
                            .foregroundStyle(.white)
                        Spacer()
                        StatusBadge(status: item.status)
                    }
                    HStack(spacing: 10) {
                        Label(dateRange(item.from, item.to), systemImage: "calendar")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.85))
                        Text("•")
                            .foregroundStyle(.white.opacity(0.5))
                        Label("\(daysBetween(item.from, item.to)) يوم", systemImage: "clock")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    if !item.reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(item.reason)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(.top, 4)
                    }
                }
            }
        }
    }
}

struct StatusBadge: View {
    let status: LeaveStatus
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: status.icon)
            Text(status.rawValue)
                .font(.caption)
                .fontWeight(.bold)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            Capsule().fill(
                LinearGradient(colors: [status.tint.opacity(0.25), .clear],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )
        )
        .overlay(Capsule().stroke(status.tint.opacity(0.6), lineWidth: 1))
        .foregroundStyle(status.tint)
    }
}

private extension LeaveRequestsView {
    func progressRing(value: Double) -> some View {
        ZStack {
            Circle().stroke(.white.opacity(0.1), lineWidth: 8)
            Circle()
                .trim(from: 0, to: value)
                .stroke(
                    AngularGradient(colors: [.green, .mint, .green], center: .center),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            Text("%\(Int(value * 100))")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.9))
        }
    }
}

enum SMHUI {
    struct PrimaryButton: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(.body.weight(.semibold))
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.white)
                        .opacity(configuration.isPressed ? 0.85 : 1.0)
                )
                .foregroundColor(.black)
                .shadow(color: .black.opacity(configuration.isPressed ? 0.1 : 0.25),
                        radius: 12, x: 0, y: 8)
                .scaleEffect(configuration.isPressed ? 0.98 : 1)
                .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
        }
    }
}

private func dateRange(_ from: Date, _ to: Date) -> String {
    let df = DateFormatter()
    df.calendar = Calendar(identifier: .gregorian)
    df.locale = Locale(identifier: "ar")
    df.dateFormat = "d MMM"
    let start = df.string(from: from)
    let end = df.string(from: to)
    return start == end ? start : "\(start) – \(end)"
}

private func daysBetween(_ from: Date, _ to: Date) -> Int {
    let cal = Calendar.current
    let s = cal.startOfDay(for: from)
    let e = cal.startOfDay(for: to)
    let d = cal.dateComponents([.day], from: s, to: e).day ?? 0
    return max(1, d + 1)
}

private func dateFromString(_ s: String) -> Date {
    let df = DateFormatter()
    df.dateFormat = "yyyy-MM-dd"
    df.calendar = Calendar(identifier: .gregorian)
    return df.date(from: s) ?? Date()
}

#Preview {
    NavigationStack {
        LeaveRequestsView(
            soldiers: [],
            days: [],
            daysOff: .constant([])
        )
        .preferredColorScheme(.dark)
    }
}
