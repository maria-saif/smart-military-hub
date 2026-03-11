import SwiftUI


struct SoldiersEditor: View {
    @Binding var soldiers: [Soldier]

    var onSave: (([Soldier]) -> Void)? = nil

    @State private var query: String = ""
    @State private var showSaved = false

    private let ranks = ["جندي", "عريف", "وكيل عريف", "رقيب", "وكيل رقيب", "رقيب أول", "ملازم", "ملازم أول", "نقيب"]
    private let units = ["المشاة", "المدفعية", "المدرعات", "الهندسة", "الإشارة", "الإمداد", "الطبية", "التدريب"]

    private var canSave: Bool {
        !soldiers.isEmpty &&
        soldiers.allSatisfy { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty &&
                              !$0.rank.trimmingCharacters(in: .whitespaces).isEmpty &&
                              !$0.unit.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    private var filteredIndices: [Int] {
        let t = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return Array(soldiers.indices) }
        let q = t.folding(options: .diacriticInsensitive, locale: .current)
        return soldiers.indices.filter { i in
            let s = soldiers[i]
            let hay = "\(s.name) \(s.rank) \(s.unit)"
                .folding(options: .diacriticInsensitive, locale: .current)
            return hay.localizedCaseInsensitiveContains(q)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.055, green: 0.067, blue: 0.086),
                        Color(red: 0.102, green: 0.137, blue: 0.196)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                List {
                    if soldiers.isEmpty {
                        Section {
                            VStack(spacing: 10) {
                                Image(systemName: "person.3.sequence.fill")
                                    .font(.system(size: 42, weight: .medium))
                                Text("لا يوجد جنود بعد").font(.headline)
                                Text("اضغط «إضافة» لإنشاء جندي جديد.")
                                    .foregroundStyle(.secondary)
                                    .font(.subheadline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 28)
                        }
                    }

                    Section("القائمة") {
                        ForEach(filteredIndices, id: \.self) { i in
                            SoldierCardRowSMH(
                                soldier: $soldiers[i],
                                ranks: ranks,
                                units: units
                            )
                            .listRowInsets(EdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14))
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    soldiers.remove(at: i)
                                } label: {
                                    Label("حذف", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                Button {
                                    let s = soldiers[i]
                                    soldiers.insert(
                                        Soldier(id: UUID(), name: s.name + " (نسخة)", rank: s.rank, unit: s.unit),
                                        at: min(i + 1, soldiers.count)
                                    )
                                } label: {
                                    Label("تكرار", systemImage: "plus.rectangle.on.rectangle")
                                }
                            }
                        }
                        .onMove { from, to in
                            soldiers.move(fromOffsets: from, toOffset: to)
                        }
                        .onDelete { offsets in
                            soldiers.remove(atOffsets: offsets)
                        }
                    }

                    Section {
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                soldiers.append(Soldier(id: UUID(), name: "جندي جديد", rank: "", unit: ""))
                            }
                        } label: {
                            Label("إضافة جندي", systemImage: "plus.circle.fill")
                                .font(.headline)
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("الجنود")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { EditButton() }

                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                soldiers.append(Soldier(id: UUID(), name: "جندي جديد", rank: "", unit: ""))
                            }
                        } label: {
                            Image(systemName: "plus").font(.headline)
                        }
                        .accessibilityLabel("إضافة")

                        Button {
                            onSave?(soldiers)
                            showSaved = true
                        } label: {
                            Text("حفظ")
                                .font(.headline)
                        }
                        .disabled(!canSave)
                        .opacity(canSave ? 1 : 0.5)
                        .keyboardShortcut(.return, modifiers: [.command])
                        .accessibilityHint("لن يتفعّل حتى تُكمل الاسم والرتبة والوحدة")
                    }
                }
            }
            .searchable(text: $query,
                        placement: .navigationBarDrawer(displayMode: .automatic),
                        prompt: "ابحث بالاسم/الرتبة/الوحدة")
            .alert("تم الحفظ", isPresented: $showSaved) {
                Button("حسناً", role: .cancel) { }
            } message: {
                Text("تم حفظ قائمة الجنود بنجاح.")
            }
        }
    }
}

private struct SoldierCardRowSMH: View {
    @Binding var soldier: Soldier
    let ranks: [String]
    let units: [String]
    @FocusState private var isNameFocused: Bool

    private var isValid: Bool {
        !soldier.name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !soldier.rank.trimmingCharacters(in: .whitespaces).isEmpty &&
        !soldier.unit.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 46, height: 46)
                    .overlay(Image(systemName: "person.fill")
                        .font(.system(size: 20, weight: .semibold)))
                    .shadow(radius: 2, y: 1)

                VStack(alignment: .leading, spacing: 6) {
                    TextField("الاسم", text: $soldier.name)
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(true)
                        .font(.system(size: 18, weight: .semibold))
                        .focused($isNameFocused)

                    HStack(spacing: 8) {
                        Menu {
                            Picker("اختر الرتبة", selection: $soldier.rank) {
                                Text("غير محدد").tag("")
                                ForEach(ranks, id: \.self) { Text($0).tag($0) }
                            }
                        } label: {
                            BadgeSMH(text: soldier.rank.isEmpty ? "الرتبة" : soldier.rank,
                                     systemImage: "shield.lefthalf.fill")
                        }

                        Menu {
                            Picker("اختر الوحدة", selection: $soldier.unit) {
                                Text("غير محدد").tag("")
                                ForEach(units, id: \.self) { Text($0).tag($0) }
                            }
                        } label: {
                            BadgeSMH(text: soldier.unit.isEmpty ? "الوحدة" : soldier.unit,
                                     systemImage: "building.2.fill")
                        }
                    }
                }

                Spacer(minLength: 0)
            }

            Divider().opacity(0.25)

            HStack(spacing: 10) {
                Label(soldier.rank.isEmpty ? "—" : soldier.rank, systemImage: "chevron.up.chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("•").foregroundStyle(.secondary)
                Label(soldier.unit.isEmpty ? "—" : soldier.unit, systemImage: "map")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.thinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(isValid ? .white.opacity(0.06) : Color.red.opacity(0.35), lineWidth: 1)
                )
        )
        .contentShape(Rectangle())
        .onTapGesture { isNameFocused = true }
        .animation(
            .easeInOut(duration: 0.18),
            value: soldier.name + "|" + soldier.rank + "|" + soldier.unit
        )
        .overlay(alignment: .topTrailing) {
            if !isValid {
                Text("أكمل الحقول")
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.red.opacity(0.15)))
                    .overlay(Capsule().stroke(Color.red.opacity(0.4)))
                    .foregroundColor(.red)
                    .padding(8)
            }
        }
    }
}

private struct BadgeSMH: View {
    let text: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
            Text(text)
        }
        .font(.caption)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(.ultraThinMaterial))
        .overlay(Capsule().strokeBorder(.white.opacity(0.1)))
    }
}

#if DEBUG
struct SoldiersEditor_Previews: PreviewProvider {
    static var previews: some View {
        SoldiersEditor(soldiers: .constant([]))
            .environment(\.layoutDirection, .rightToLeft)
    }
}
#endif
