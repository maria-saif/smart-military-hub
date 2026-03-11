import SwiftUI

struct ActiveSoldiersDebugView: View {
    @State private var query: String = ""
    @State private var demo: [SoldierRow] = [
        .init(id: "1", fullName: "سالم البوسعيدي", rank: "رقيب",   unit: "الكتيبة 1", militaryId: "A12345", lastLoginAt: Date().addingTimeInterval(-3600)),
        .init(id: "2", fullName: "يزن العوفي",    rank: "عريف",   unit: "السرية أ",   militaryId: "B98765", lastLoginAt: Date().addingTimeInterval(-7200)),
        .init(id: "3", fullName: "مازن الهنائي",  rank: "وكيل",   unit: "السرية ب",   militaryId: "C54321", lastLoginAt: Date().addingTimeInterval(-86000))
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black.opacity(0.95), Color(red: 0.08, green: 0.12, blue: 0.18)],
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

                let list = filtered(demo, by: query)
                if list.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 48, weight: .semibold))
                            .opacity(0.7)
                        Text("لا توجد نتائج")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("هذه شاشة تجريبية للتأكد من التنقّل.")
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(.top, 40)
                } else {
                    List(list) { s in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(s.fullName).font(.headline)
                            HStack(spacing: 8) {
                                if let r = s.rank, !r.isEmpty { Text(r) }
                                if let u = s.unit, !u.isEmpty { Text("• \(u)") }
                                if let m = s.militaryId, !m.isEmpty { Text("• \(m)") }
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
        .environment(\.layoutDirection, .rightToLeft)
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
}
