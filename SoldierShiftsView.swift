import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct SoldierShiftsView: View {
    @State private var today: [ShiftItem] = []
    @State private var upcoming: [ShiftItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var listener: ListenerRegistration?
    @State private var now = Date()

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.black, Color.green.opacity(0.6)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            if isLoading {
                ProgressView("جارِ تحميل المناوبات...").tint(.green)
            } else if let err = errorMessage {
                Text("خطأ: \(err)").foregroundColor(.red).multilineTextAlignment(.center).padding()
            } else if today.isEmpty && upcoming.isEmpty {
                Text("لا توجد مناوَبات معتمدة حالياً.")
                    .foregroundColor(.white.opacity(0.75))
                    .padding()
            } else {
                List {
                    if !today.isEmpty {
                        Section(header: Text("مناوبة اليوم").foregroundColor(.green)) {
                            ForEach(today) { ShiftRow(item: $0, onCheckIn: checkIn, onCheckOut: checkOut) }
                        }
                    }
                    if !upcoming.isEmpty {
                        Section(header: Text("قادمة").foregroundColor(.green)) {
                            ForEach(upcoming) { ShiftRow(item: $0, onCheckIn: checkIn, onCheckOut: checkOut) }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("المناوبات")
        .environment(\.layoutDirection, .rightToLeft)
        .onAppear { attachListener() }
        .onDisappear { listener?.remove() }
        .refreshable { attachListener() }
    }

    private func attachListener() {
        listener?.remove()
        isLoading = true
        errorMessage = nil
        now = Date()

        guard let uid = Auth.auth().currentUser?.uid else {
            self.errorMessage = "المستخدم غير معروف."
            self.isLoading = false
            return
        }

        let ref = Firestore.firestore()
            .collection("soldiers").document(uid)
            .collection("shifts")

        listener = ref.addSnapshotListener { snap, err in
            if let err = err {
                self.errorMessage = err.localizedDescription
                self.isLoading = false
                return
            }
            guard let docs = snap?.documents else {
                self.today = []; self.upcoming = []; self.isLoading = false
                return
            }

            let items = docs.compactMap { ShiftItem.from(doc: $0) }
                .sorted { $0.startDate < $1.startDate }

            let cal = Calendar.current
            self.today = items.filter { cal.isDate($0.startDate, inSameDayAs: self.now) }
            self.upcoming = items.filter { $0.startDate > cal.startOfDay(for: self.now) && !cal.isDate($0.startDate, inSameDayAs: self.now) }
            self.isLoading = false
        }
    }

    private func checkIn(_ shift: ShiftItem) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let ref = Firestore.firestore()
            .collection("soldiers").document(uid)
            .collection("shifts").document(shift.id)
        ref.updateData([
            "checkIn": FieldValue.serverTimestamp(),
            "status": "in_progress"
        ])
    }

    private func checkOut(_ shift: ShiftItem) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let ref = Firestore.firestore()
            .collection("soldiers").document(uid)
            .collection("shifts").document(shift.id)
        ref.updateData([
            "checkOut": FieldValue.serverTimestamp(),
            "status": "done"
        ])
    }
}

struct ShiftItem: Identifiable, Equatable {
    let id: String
    let title: String
    let location: String
    let startDate: Date
    let endDate: Date
    let status: String
    let checkIn: Date?
    let checkOut: Date?

    static func from(doc: QueryDocumentSnapshot) -> ShiftItem? {
        let d = doc.data()
        guard
            let start = (d["start"] as? Timestamp)?.dateValue(),
            let end   = (d["end"] as? Timestamp)?.dateValue()
        else { return nil }

        return ShiftItem(
            id: doc.documentID,
            title: d["title"] as? String ?? "مناوبة",
            location: d["location"] as? String ?? "—",
            startDate: start,
            endDate: end,
            status: d["status"] as? String ?? "scheduled",
            checkIn: (d["checkIn"] as? Timestamp)?.dateValue(),
            checkOut: (d["checkOut"] as? Timestamp)?.dateValue()
        )
    }
}

struct ShiftRow: View {
    let item: ShiftItem
    var onCheckIn: (ShiftItem) -> Void
    var onCheckOut: (ShiftItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: iconName)
                    .foregroundColor(iconColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title).font(.headline)
                    Text(item.location).font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                Text(timeRange)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 8) {
                if item.status == "scheduled" {
                    Button("تسجيل حضور") { onCheckIn(item) }
                        .buttonStyle(.borderedProminent)
                } else if item.status == "in_progress" {
                    if let t = item.checkIn {
                        Label(t.formatted(date: .omitted, time: .shortened), systemImage: "checkmark.circle")
                            .font(.caption).foregroundColor(.green)
                    }
                    Button("تسجيل انصراف") { onCheckOut(item) }
                        .buttonStyle(.bordered)
                } else {
                    HStack(spacing: 8) {
                        if let cin = item.checkIn {
                            Label(cin.formatted(date: .omitted, time: .shortened), systemImage: "checkmark.circle")
                        }
                        if let cout = item.checkOut {
                            Label(cout.formatted(date: .omitted, time: .shortened), systemImage: "flag.checkered")
                        }
                    }
                    .font(.caption).foregroundColor(.secondary)
                }
                Spacer()
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }

    private var timeRange: String {
        "\(item.startDate.formatted(date: .omitted, time: .shortened))–\(item.endDate.formatted(date: .omitted, time: .shortened))"
    }
    private var iconName: String {
        switch item.status {
        case "scheduled": return "calendar.badge.clock"
        case "in_progress": return "clock.badge.checkmark"
        default: return "checkmark.seal"
        }
    }
    private var iconColor: Color {
        switch item.status {
        case "scheduled": return .yellow
        case "in_progress": return .blue
        default: return .green
        }
    }
}
