import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct SoldierTrainingView: View {
    private let enableLiveData: Bool
    @State private var trainings: [TrainingItem]
    @State private var isLoading: Bool
    @State private var errorMessage: String? = nil

    init(enableLiveData: Bool = true, previewItems: [TrainingItem] = []) {
        self.enableLiveData = enableLiveData
        _trainings = State(initialValue: previewItems)
        _isLoading  = State(initialValue: enableLiveData)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, Color.green.opacity(0.6)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            if isLoading {
                ProgressView("جارِ تحميل الدروس...")
                    .tint(.green)
            } else if let error = errorMessage {
                Text("⚠️ خطأ: \(error)")
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding()
            } else if trainings.isEmpty {
                VStack(spacing: 10) {
                    Text("لا توجد دروس متاحة حاليًا.")
                        .foregroundColor(.white.opacity(0.85))
                    if enableLiveData {
                        Button("إضافة درس تجريبي") {
                            Task { await seedSampleLesson() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
            } else {
                ScrollView {
                    VStack(spacing: 14) {
                        ForEach(trainings) { item in
                            TrainingCard(item: item)
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("التدريب الذكي")
        .environment(\.layoutDirection, .rightToLeft)
        .onAppear {
            if enableLiveData { startListening() }
        }
    }

    private var db: Firestore { Firestore.firestore() }
    private var authUID: String? { Auth.auth().currentUser?.uid }

    private func startListening() {
        guard let uid = authUID else {
            self.errorMessage = "لم يتم العثور على المستخدم."
            self.isLoading = false
            return
        }

        db.collection("soldiers").whereField("authUID", isEqualTo: uid).limit(to: 1)
            .addSnapshotListener { snap, err in
                if let err = err {
                    DispatchQueue.main.async {
                        self.errorMessage = "فشل جلب بيانات الجندي: \(err.localizedDescription)"
                        self.isLoading = false
                    }
                    return
                }

                let soldierDoc = snap?.documents.first
                let soldierId = soldierDoc?.documentID ?? uid
                listenToTrainings(for: soldierId)
            }
    }

    private func listenToTrainings(for soldierId: String) {
        self.isLoading = true
        self.errorMessage = nil

        var fromSub: [TrainingItem] = []
        var fromTop: [TrainingItem] = []

        db.collection("soldiers").document(soldierId).collection("trainings")
            .order(by: "date", descending: true)
            .addSnapshotListener { snap, err in
                if let err = err {
                    DispatchQueue.main.async {
                        self.errorMessage = "فشل جلب دروس الجندي: \(err.localizedDescription)"
                        self.isLoading = false
                    }
                    return
                }
                fromSub = (snap?.documents ?? []).compactMap { TrainingItem(document: $0) }
                mergeAndPublish()
            }

        db.collection("trainings")
            .whereField("assignedTo", arrayContains: soldierId)
            .order(by: "date", descending: true)
            .addSnapshotListener { snap, err in
                if let err = err {
                    print("Top-level trainings listener error: \(err.localizedDescription)")
                }
                fromTop = (snap?.documents ?? []).compactMap { TrainingItem(document: $0) }
                mergeAndPublish()
            }

        func mergeAndPublish() {
            let all = Dictionary(grouping: (fromSub + fromTop), by: { $0.id })
                .compactMap { $0.value.first }
                .sorted(by: { $0.date > $1.date })
            DispatchQueue.main.async {
                self.trainings = all
                self.isLoading = false
            }
        }
    }

    private func seedSampleLesson() async {
        guard let uid = authUID else { return }
        let soldierId = uid
        let ref = db.collection("soldiers").document(soldierId).collection("trainings").document()
        do {
            try await ref.setData([
                "title": "أساسيات الإسعاف القتالي",
                "description": "فيديو + اختبار قصير حول السيطرة على النزيف.",
                "progress": 0.25,
                "completed": false,
                "date": Timestamp(date: Date())
            ])
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "فشل إنشاء الدرس التجريبي: \(error.localizedDescription)"
            }
        }
    }
}

struct TrainingItem: Identifiable {
    var id: String
    var title: String
    var description: String
    var progress: Double
    var completed: Bool
    var date: Date
}

extension TrainingItem {
    init?(document: QueryDocumentSnapshot) {
        let data = document.data()
        self.id = document.documentID
        self.title = data["title"] as? String ?? "بدون عنوان"
        self.description = data["description"] as? String ?? ""
        self.progress = (data["progress"] as? Double) ?? 0.0
        self.completed = (data["completed"] as? Bool) ?? false
        self.date = (data["date"] as? Timestamp)?.dateValue() ?? Date()
    }
}

struct TrainingCard: View {
    let item: TrainingItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: item.completed ? "checkmark.circle.fill" : "book.fill")
                    .foregroundColor(item.completed ? .green : .blue)
                    .font(.system(size: 22))
                Text(item.title)
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Text(item.completed ? "مكتمل" : "قيد التنفيذ")
                    .font(.caption)
                    .foregroundColor(item.completed ? .green : .yellow)
            }

            if !item.description.isEmpty {
                Text(item.description)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.78))
                    .lineLimit(2)
            }

            ProgressView(value: min(max(item.progress, 0), 1))
                .progressViewStyle(.linear)
                .tint(item.completed ? .green : .blue)

            Text(item.date, style: .date)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.6))
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding()
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

#if DEBUG
struct SoldierTrainingView_Previews: PreviewProvider {
    static var sample: [TrainingItem] = [
        TrainingItem(id: "1", title: "أساسيات الإسعاف القتالي",
                     description: "السيطرة على النزيف – جولة تورنيكيت + تقييم سريع.",
                     progress: 0.25, completed: false, date: Date()),
        TrainingItem(id: "2", title: "تكتيكات التحرك الفردي",
                     description: "حركات low/high crawl + تمرين عملي.",
                     progress: 0.9, completed: false, date: Date().addingTimeInterval(-86400)),
        TrainingItem(id: "3", title: "السلامة مع السلاح",
                     description: "قواعد الأمان الأربعة + اختبار قصير.",
                     progress: 1.0, completed: true, date: Date().addingTimeInterval(-172800))
    ]

    static var previews: some View {
        Group {
            NavigationStack {
                SoldierTrainingView(enableLiveData: false, previewItems: sample)
            }
            .previewDisplayName("Light")

            NavigationStack {
                SoldierTrainingView(enableLiveData: false, previewItems: sample)
            }
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark")
        }
    }
}
#endif
