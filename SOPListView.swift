import SwiftUI

struct SOPItem: Identifiable, Hashable {
    let id = UUID()
    var title: String
    var category: String
    var stepsCount: Int
    var estimatedMinutes: Int
}

struct SOPListView: View {
    @State private var items: [SOPItem] = [
        .init(title: "نزيف خارجي (إسعافات أولية)", category: "إسعاف",  stepsCount: 6, estimatedMinutes: 4),
        .init(title: "تعطّل مركبة في الدورية",       category: "مركبات", stepsCount: 7, estimatedMinutes: 6),
        .init(title: "تفتيش معدات قبل التحرك",       category: "انضباط", stepsCount: 8, estimatedMinutes: 5)
    ]
    @State private var query = ""

    private var filtered: [SOPItem] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return items }
        return items.filter { $0.title.lowercased().contains(q) || $0.category.lowercased().contains(q) }
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x0E1116), Color(hex: 0x1A2332)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()

            VStack(spacing: 12) {
                HStack {
                    TextField("ابحث عن إجراء…", text: $query)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .padding(12)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.12), lineWidth: 1))
                }
                .padding(.horizontal)

                List(filtered) { s in
                    NavigationLink {
                        SOPDetailView(item: s)
                    } label: {
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.white.opacity(0.06))
                                .frame(width: 42, height: 42)
                                .overlay(
                                    Image(systemName: icon(for: s.category))
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundStyle(
                                            LinearGradient(colors: [Color(hex: 0x3AD29F), Color(hex: 0x7AA5FF)],
                                                           startPoint: .top, endPoint: .bottom)
                                        )
                                )

                            VStack(alignment: .leading, spacing: 4) {
                                Text(s.title).foregroundStyle(.white)
                                Text("\(s.category) • \(s.stepsCount) خطوات • ~\(s.estimatedMinutes) د")
                                    .font(.caption).foregroundStyle(.white.opacity(0.7))
                            }

                            Spacer()
                            Image(systemName: "chevron.left")
                                .foregroundStyle(.white.opacity(0.35))
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(Color.clear)
                }
                .listStyle(.plain)
            }
            .padding(.top, 8)
        }
        .navigationTitle("إجراءات سريعة (SOP)")
        .environment(\.layoutDirection, .rightToLeft)
    }

    private func icon(for category: String) -> String {
        switch category {
        case "إسعاف":  return "cross.vial.fill"
        case "مركبات": return "car.fill"
        case "انضباط": return "checkmark.seal.fill"
        default:       return "doc.text.fill"
        }
    }
}
