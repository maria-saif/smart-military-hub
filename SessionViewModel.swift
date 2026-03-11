import Foundation
import Combine
import FirebaseAuth

@MainActor
final class SessionViewModel: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var currentRole: AppRole? = nil
    @Published var currentUserUID: String? = nil
    @Published var currentUserName: String? = nil
    @Published var currentServiceId: String? = nil
    @Published var errorMsg: String? = nil

    static let shared = SessionViewModel()
    private var cancellables = Set<AnyCancellable>()

    init() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self else { return }

            Auth.auth().addStateDidChangeListener { _, user in
                Task { @MainActor in
                    self.isAuthenticated = (user != nil)
                    self.currentUserUID = user?.uid
                }
            }
        }
    }

    func signInAnonymously() async throws {
        do {
            let result = try await Auth.auth().signInAnonymously()
            await MainActor.run {
                self.isAuthenticated = true
                self.currentUserUID = result.user.uid
            }
        } catch {
            await MainActor.run {
                self.errorMsg = error.localizedDescription
            }
            throw error
        }
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
            isAuthenticated = false
            currentUserUID = nil
            currentRole = nil
            currentUserName = nil
            currentServiceId = nil
        } catch {
            print("Sign out error: \(error)")
        }
    }

    func setRole(_ role: AppRole) {
        currentRole = role
    }
}

extension SessionViewModel {
    static let preview: SessionViewModel = {
        let s = SessionViewModel()
        s.isAuthenticated = true
        s.currentRole = .commander
        s.currentUserName = "القائد أحمد"
        s.currentServiceId = "SMH-0001"
        s.currentUserUID = "preview-UID"
        return s
    }()
}
