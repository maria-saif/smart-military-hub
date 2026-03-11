import Foundation
import Combine
import FirebaseFirestore
import FirebaseAuth

final class ActiveSoldiersService: ObservableObject {

    @Published var soldiers: [Soldier] = []

    private var listener: ListenerRegistration?
    private let db = Firestore.firestore()

    init() {
        if let uid = Auth.auth().currentUser?.uid {
            startListening(forLeader: uid)
        }
    }

    deinit { stopListening() }

    func startListening(forLeader leaderUID: String) {
        stopListening()
        listener = db.collection("soldiers")
            .document(leaderUID)
            .collection("soldiers")
            .order(by: "fullName", descending: false)
            .addSnapshotListener { [weak self] snap, err in
                guard let self = self else { return }
                if let err = err { print("Soldiers listen error:", err); return }
                self.soldiers = (snap?.documents ?? []).map { d in
                    let x = d.data()
                    return Soldier(
                        id: UUID(uuidString: x["uuid"] as? String ?? UUID().uuidString) ?? UUID(),
                        name: x["fullName"] as? String ?? "—",
                        rank: x["rank"] as? String ?? "",
                        unit: x["unit"] as? String ?? ""
                    )
                }
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }
}
