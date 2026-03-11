import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import FirebaseCore

struct ActiveSoldiersView: View {
    let leaderUID: String

    @State private var items: [SoldierRow] = []
    @State private var query: String = ""
    @State private var listener: ListenerRegistration?

    private var isPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    private var col: CollectionReference {
        Firestore.firestore()
            .collection("soldiers")
            .document(leaderUID)
            .collection("soldiers")
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0x0E1116), Color(hex: 0x1A2332)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 12) {
                HStack {
                    TextField("ابحث بالاسم / الرقم العسكري", text: $query)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .padding(12)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.12), lineWidth: 1))
                }
                .padding(.horizontal)

                let data = filtered(items, by: query)

                if data.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 48, weight: .semibold))
                            .opacity(0.7)
                        Text("لا توجد بيانات لعرضها الآن")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text(isPreview ? "هذه بيانات معاينة — أضِف جنودًا من Firebase لتظهر هنا."
                                       : "تحقق من اتصالك أو من صلاحيات القراءة في Firestore")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 40)
                } else {
                    List(data) { s in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(s.fullName).font(.headline)
                            HStack(spacing: 8) {
                                if let r = s.rank, !r.isEmpty { Text(r) }
                                if let u = s.unit, !u.isEmpty { Text("• \(u)") }
                            }
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                            if let t = s.lastLoginAt {
                                Text("آخر دخول: \(relative(t))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                }
            }
        }
        .navigationTitle("الجنود النشطون")
        .environment(\.layoutDirection, .rightToLeft)
        .onAppear {
            if isPreview {
                self.items = Self.mockItems
                return
            }

            guard FirebaseApp.app() != nil else {
                print("FirebaseApp غير مهيأ"); return
            }
            if Auth.auth().currentUser == nil {
                Auth.auth().signInAnonymously { _, err in
                    if let err = err { print("Auth error:", err) }
                }
            }

            listener = col
                .order(by: "fullName", descending: false)
                .addSnapshotListener { snap, err in
                    if let err = err { print("ActiveSoldiers list error:", err); return }
                    self.items = (snap?.documents ?? []).map { d in
                        let x = d.data()
                        return SoldierRow(
                            id: d.documentID,
                            fullName: (x["fullName"] as? String)
                                      ?? (x["name"] as? String)
                                      ?? "—",
                            rank: x["rank"] as? String,
                            unit: x["unit"] as? String,
                            militaryId: x["militaryId"] as? String,
                            lastLoginAt: (x["lastLoginAt"] as? Timestamp)?.dateValue()
                        )
                    }
                    if self.items.isEmpty {
                        print("No soldiers under /soldiers/\(leaderUID)/soldiers")
                    }
                }
        }
        .onDisappear {
            listener?.remove()
            listener = nil
        }
    }

    // MARK: Helpers
    private func filtered(_ all: [SoldierRow], by query: String) -> [SoldierRow] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return all }
        return all.filter { s in
            s.fullName.lowercased().contains(q)
            || (s.militaryId ?? "").lowercased().contains(q)
            || (s.rank ?? "").lowercased().contains(q)
            || (s.unit ?? "").lowercased().contains(q)
        }
    }

    private func relative(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "ar")
        f.unitsStyle = .full
        return f.localizedString(for: date, relativeTo: Date())
    }

    struct SoldierRow: Identifiable {
        let id: String
        let fullName: String
        let rank: String?
        let unit: String?
        let militaryId: String?
        let lastLoginAt: Date?
    }

    // MARK: Mock (للمعاينة فقط)
    private static let mockItems: [SoldierRow] = [
        SoldierRow(id: "1", fullName: "سالم بن ناصر", rank: "رقيب", unit: "الفصيل 1", militaryId: "A1234", lastLoginAt: Date().addingTimeInterval(-3600)),
        SoldierRow(id: "2", fullName: "مازن السعدي", rank: "عريف", unit: "الفصيل 2", militaryId: "B4521", lastLoginAt: Date().addingTimeInterval(-7200)),
        SoldierRow(id: "3", fullName: "عامر الهنائي", rank: "جندي", unit: "الفصيل 1", militaryId: "C9981", lastLoginAt: Date().addingTimeInterval(-18000)),
    ]
}

#if DEBUG
#Preview {
    NavigationStack {
        ActiveSoldiersView(leaderUID: "preview-leader-uid")
    }
    .preferredColorScheme(.dark)
}
#endif
