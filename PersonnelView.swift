import SwiftUI

struct SoldierUI: Identifiable {
    let id: String
    var name: String
    var rank: String
    var skills: [String]
}

struct PersonnelView: View {
    @State private var soldiers: [SoldierUI] = [
        .init(id: "s1", name: "جندي 1", rank: "R1", skills: ["Medic"]),
        .init(id: "s2", name: "جندي 2", rank: "R2", skills: ["Driver"]),
        .init(id: "s3", name: "جندي 3", rank: "R1", skills: ["Tech"]),
    ]
    
    var body: some View {
        List {
            ForEach(soldiers) { s in
                VStack(alignment: .leading) {
                    HStack {
                        Text(s.name).font(.headline)
                        Spacer()
                        Text(s.rank).foregroundStyle(.secondary)
                    }
                    if !s.skills.isEmpty {
                        Text("مهارات: \(s.skills.joined(separator: ", "))")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete { idx in soldiers.remove(atOffsets: idx) }
        }
        .navigationTitle("الجنود")
        .toolbar { EditButton() }
    }
}
