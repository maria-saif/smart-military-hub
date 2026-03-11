import FirebaseAuth
import FirebaseFirestore

final class SoldiersRepository {
    private var listener: ListenerRegistration?

    func startListening() {
        #if DEBUG
        if IS_PREVIEW { return }
        #endif

        guard let uid = Auth.auth().currentUser?.uid else { return }

        let db = Firestore.firestore()
        listener = db.collection("soldiers")
            .whereField("leaderUID", isEqualTo: uid)
            .addSnapshotListener { snapshot, error in
                if let error = error { print("Firestore error:", error); return }
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }
}
