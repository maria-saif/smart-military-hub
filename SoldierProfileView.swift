import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct SoldierProfile {
    var fullName: String
    var militaryId: String
    var rank: String
    var unit: String
    var phone: String
    var email: String
    var readiness: String
}

struct SoldierProfileView: View {
    @State private var profile: SoldierProfile?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var listener: ListenerRegistration?

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.black, Color.green.opacity(0.5)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            if isLoading {
                ProgressView("جارِ تحميل بياناتك...").tint(.green)
            } else if let p = profile {
                ScrollView {
                    VStack(spacing: 16) {
                        // Header مختصر
                        VStack(spacing: 8) {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(.green)
                            Text(p.fullName).font(.title3.bold()).foregroundColor(.white)
                            Text("Smart Military Hub").font(.subheadline).foregroundColor(.white.opacity(0.7))
                            Text("جاهزية: \(p.readiness)")
                                .font(.footnote).foregroundColor(.white)
                                .padding(.vertical, 6).padding(.horizontal, 12)
                                .background(Color.green.opacity(0.85), in: Capsule())
                        }

                        SectionView(title: "البيانات الأساسية") {
                            row(icon: "number.square", title: "الرقم العسكري", value: p.militaryId)
                            row(icon: "star", title: "الرتبة", value: p.rank)
                            row(icon: "shield.lefthalf.filled", title: "الوحدة", value: p.unit)
                        }

                        SectionView(title: "التواصل") {
                            row(icon: "phone.fill", title: "الهاتف", value: p.phone)
                            row(icon: "envelope.fill", title: "البريد", value: p.email)
                        }
                    }
                    .padding()
                }
            } else if let err = errorMessage {
                Text("خطأ: \(err)").foregroundColor(.red).multilineTextAlignment(.center).padding()
            }
        }
        .navigationTitle("لوحة الجندي")
        .environment(\.layoutDirection, .rightToLeft)
        .onAppear { attachListener() }
        .onDisappear { listener?.remove() }
    }

    private func attachListener() {
        guard let uid = Auth.auth().currentUser?.uid else {
            self.errorMessage = "لم يتم العثور على المستخدم."
            self.isLoading = false
            return
        }
        isLoading = true
        let docRef = Firestore.firestore().collection("soldiers").document(uid)
        listener = docRef.addSnapshotListener { snapshot, error in
            if let error = error {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
                return
            }
            guard let data = snapshot?.data() else {
                self.errorMessage = "لا توجد بيانات."
                self.isLoading = false
                return
            }
            let p = SoldierProfile(
                fullName: data["fullName"] as? String ?? "—",
                militaryId: data["militaryId"] as? String ?? "—",
                rank: data["rank"] as? String ?? "—",
                unit: data["unit"] as? String ?? "—",
                phone: data["phone"] as? String ?? "—",
                email: data["email"] as? String ?? "—",
                readiness: data["readiness"] as? String ?? "جاهز" // افتراضي
            )
            withAnimation { self.profile = p; self.isLoading = false }
        }
    }

    private func row(icon: String, title: String, value: String) -> some View {
        HStack {
            Image(systemName: icon).foregroundStyle(.green)
            VStack(alignment: .leading) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Text(value).font(.body.weight(.medium)).foregroundStyle(.white)
            }
            Spacer()
        }
        .padding()
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct SectionView<Content: View>: View {
    let title: String
    let content: Content
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title; self.content = content()
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline).foregroundStyle(.green).padding(.horizontal, 4)
            VStack(spacing: 8) { content }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
