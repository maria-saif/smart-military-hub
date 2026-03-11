import SwiftUI
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

struct SoldierShift: Identifiable, Hashable {
    var id: String
    var date: Date
    var start: String
    var end: String
    var location: String
    var status: String
    var note: String?

    var isToday: Bool { Calendar.current.isDateInToday(date) }
    var isPast: Bool { date < Calendar.current.startOfDay(for: Date()) }
    var isUpcoming: Bool { !isToday && !isPast }
    var timeRange: String { "\(start) — \(end)" }
}

struct SoldierShiftsScreen: View {
    private let injectedShifts: [SoldierShift]?
    init(injectedShifts: [SoldierShift]? = nil) {
        self.injectedShifts = injectedShifts
    }

    @State private var shifts: [SoldierShift] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    #if canImport(FirebaseFirestore)
    @State private var listener: ListenerRegistration?
    #endif

    private var todayShifts: [SoldierShift] { shifts.filter { $0.isToday } }
    private var upcomingShifts: [SoldierShift] { shifts.filter { $0.isUpcoming } }
    private var pastShifts: [SoldierShift] { shifts.filter { $0.isPast } }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.black, Color.green.opacity(0.5)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
                .overlay(
                    RadialGradient(colors: [.white.opacity(0.08), .clear],
                                   center: .top, startRadius: 10, endRadius: 450)
                )

            if isLoading {
                ProgressView("جارِ تحميل المناوبات...").tint(.green)
            } else if let err = errorMessage {
                errorState(err)
            } else if shifts.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 18) {
                        classyHeader
                            .padding(.horizontal)
                            .padding(.top, 8)

                        if !todayShifts.isEmpty {
                            ShiftsSectionView(title: "مناوبة اليوم") {
                                ForEach(todayShifts) { s in shiftRow(s) }
                            }
                        }
                        if !upcomingShifts.isEmpty {
                            ShiftsSectionView(title: "القادمة") {
                                ForEach(upcomingShifts) { s in shiftRow(s) }
                            }
                        }
                        if !pastShifts.isEmpty {
                            ShiftsSectionView(title: "المنتهية مؤخرًا") {
                                ForEach(pastShifts.prefix(7)) { s in shiftRow(s) }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
        }
        .navigationTitle("المناوبات")
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.layoutDirection, .rightToLeft)
        .onAppear { setup() }
        .onDisappear { detach() }
        #if DEBUG
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("إضافة عيّنات (Firestore)") { seedSampleShifts() }
                    Button("مسح العيّنات (Firestore)", role: .destructive) { clearShifts() }
                } label: {
                    Image(systemName: "wand.and.stars")
                }
            }
        }
        #endif
    }

    private var classyHeader: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 26, weight: .semibold))
                Text("مناوباتي")
                    .font(.title3.bold())
                Spacer()
                if !todayShifts.isEmpty {
                    chip(text: "اليوم \(todayShifts.count)", color: .green)
                }
            }
            .foregroundStyle(.white)

            HStack(spacing: 8) {
                if !upcomingShifts.isEmpty { chip(text: "القادمة \(upcomingShifts.count)", color: .blue) }
                if !pastShifts.isEmpty { chip(text: "المنتهية \(pastShifts.count)", color: .gray) }
                Spacer()
                Text(Date(), style: .date)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding()
        .background(
            .ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.25), radius: 18, x: 0, y: 10)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.system(size: 44))
                .foregroundStyle(.white.opacity(0.7))
            Text("لا توجد منـاوبات مسجّلة")
                .foregroundStyle(.white)
            Text("ستظهر هنا فورًا عند إضافتها من لوحة القائد.")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding()
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(.yellow)
            Text("خطأ: \(message)")
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
            #if DEBUG
            Text("تحقق من تسجيل الدخول وصلاحيات Firestore وأسماء الحقول.")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.7))
            #endif
        }
        .padding()
    }

    private func setup() {
        if let injectedShifts {
            self.shifts = injectedShifts.sorted(by: sortRule)
            self.isLoading = false
            self.errorMessage = nil
            return
        }
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        guard let uid = Auth.auth().currentUser?.uid else {
            self.errorMessage = "لم يتم العثور على المستخدم."
            self.isLoading = false
            return
        }
        isLoading = true
        listener = Firestore.firestore()
            .collection("soldiers").document(uid)
            .collection("shifts")
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                    return
                }
                let docs = snapshot?.documents ?? []
                var loaded: [SoldierShift] = []
                for d in docs {
                    let data = d.data()
                    let date: Date? = {
                        if let ts = data["date"] as? Timestamp { return ts.dateValue() }
                        if let iso = data["date"] as? String { return Self.isoDate(iso) }
                        return nil
                    }()
                    guard let date else { continue }
                    loaded.append(.init(
                        id: d.documentID,
                        date: date,
                        start: data["start"] as? String ?? "—",
                        end: data["end"] as? String ?? "—",
                        location: data["location"] as? String ?? "—",
                        status: data["status"] as? String ?? "scheduled",
                        note: data["note"] as? String
                    ))
                }
                withAnimation {
                    self.shifts = loaded.sorted(by: sortRule)
                    self.isLoading = false
                    self.errorMessage = nil
                }
            }
        #else
        self.errorMessage = "Firebase غير متاح في هذه البيئة."
        self.isLoading = false
        #endif
    }

    private func detach() {
        #if canImport(FirebaseFirestore)
        listener?.remove()
        #endif
    }

    // MARK: - UI helpers
    private func shiftRow(_ s: SoldierShift) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: statusIcon(s.status))
                .foregroundStyle(statusColor(s.status))
                .font(.title3)
                .frame(width: 28)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(dateString(s.date))
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    Text(s.timeRange)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.95))
                }

                HStack(spacing: 6) {
                    Image(systemName: "mappin.and.ellipse")
                    Text(s.location)
                }
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.85))

                HStack(spacing: 8) {
                    chip(text: statusText(s.status), color: statusColor(s.status))
                    if s.isToday { chip(text: "اليوم", color: .green) }
                    if let note = s.note, !note.isEmpty {
                        chip(text: "ملاحظة", color: .blue)
                            .help(note)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(
            Color.white.opacity(0.08),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(.white.opacity(0.1))
        )
    }

    private func chip(text: String, color: Color) -> some View {
        Text(text)
            .font(.footnote.weight(.medium))
            .foregroundStyle(.white)
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(color.opacity(0.85), in: Capsule())
    }

    private func dateString(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = .init(identifier: "ar")
        f.calendar = .init(identifier: .gregorian)
        f.dateFormat = "EEEE • d MMM yyyy"
        return f.string(from: date)
    }

    private func statusIcon(_ s: String) -> String {
        switch s.lowercased() {
        case "scheduled": return "clock"
        case "completed": return "checkmark.seal.fill"
        case "cancelled": return "xmark.circle.fill"
        default: return "clock"
        }
    }
    private func statusText(_ s: String) -> String {
        switch s.lowercased() {
        case "scheduled": return "مجدولة"
        case "completed": return "مكتملة"
        case "cancelled": return "ملغاة"
        default: return s
        }
    }
    private func statusColor(_ s: String) -> Color {
        switch s.lowercased() {
        case "scheduled": return .yellow
        case "completed": return .green
        case "cancelled": return .red
        default: return .gray
        }
    }

    private static func isoDate(_ str: String) -> Date? {
        let f = DateFormatter()
        f.calendar = .init(identifier: .gregorian)
        f.locale = .init(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: str)
    }

    private func sortRule(a: SoldierShift, b: SoldierShift) -> Bool {
        if a.date != b.date { return a.date < b.date }
        return a.start < b.start
    }

    #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
    private func seedSampleShifts() {
        guard let uid = Auth.auth().currentUser?.uid else {
            self.errorMessage = "سجل دخول أولاً لإضافة العيّنات."; return
        }
        let col = Firestore.firestore().collection("soldiers").document(uid).collection("shifts")
        let today = Date()
        let cal = Calendar.current

        let samples: [[String: Any]] = [
            [
                "date": Timestamp(date: today),
                "start": "08:00", "end": "14:00",
                "location": "البوابة الشمالية",
                "status": "scheduled",
                "note": "تبديل منتصف الوردية"
            ],
            [
                "date": Timestamp(date: cal.date(byAdding: .day, value: 1, to: today)!),
                "start": "14:00", "end": "22:00",
                "location": "المستودع A3",
                "status": "scheduled"
            ],
            [
                "date": Timestamp(date: cal.date(byAdding: .day, value: -1, to: today)!),
                "start": "06:00", "end": "12:00",
                "location": "الساحة الرئيسية",
                "status": "completed"
            ]
        ]

        Task {
            for s in samples {
                _ = try? await col.addDocument(data: s)
            }
        }
    }

    private func clearShifts() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let col = Firestore.firestore().collection("soldiers").document(uid).collection("shifts")
        col.getDocuments { snap, _ in
            snap?.documents.forEach { $0.reference.delete() }
        }
    }
    #endif
}

struct ShiftsSectionView<Content: View>: View {
    let title: String
    let content: Content
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title; self.content = content()
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.green)
                .padding(.horizontal, 4)
            VStack(spacing: 10) { content }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SoldierShiftsScreen_Previews: PreviewProvider {
    static var previews: some View {
        let mock: [SoldierShift] = [
            .init(id: "1", date: Date(),
                  start: "08:00", end: "14:00",
                  location: "البوابة الشمالية", status: "scheduled", note: "تبديل منتصف الوردية"),
            .init(id: "2", date: Calendar.current.date(byAdding: .day, value: 1, to: Date())!,
                  start: "14:00", end: "22:00",
                  location: "المستودع A3", status: "scheduled", note: nil),
            .init(id: "3", date: Calendar.current.date(byAdding: .day, value: -1, to: Date())!,
                  start: "06:00", end: "12:00",
                  location: "الساحة الرئيسية", status: "completed", note: "إنجاز ممتاز")
        ]

        NavigationStack {
            SoldierShiftsScreen(injectedShifts: mock)
        }
        .environment(\.layoutDirection, .rightToLeft)
        .preferredColorScheme(.dark)
    }
}
