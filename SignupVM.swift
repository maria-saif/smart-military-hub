import Foundation
import FirebaseAuth
import FirebaseFirestore

enum UserRole: String { case leader, soldier }

@MainActor
final class SignupVM: ObservableObject {
    @Published var fullName = ""
    @Published var militaryId = ""
    @Published var rank = ""
    @Published var unit = ""
    @Published var phone = ""
    @Published var email = ""
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published var dob: Date = Calendar.current.date(byAdding: .year, value: -20, to: Date())!

    @Published var error: String?
    @Published var isDone = false
    @Published var isLoading = false

    private let db: Firestore?
    private static let isPreview: Bool = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"

    init() {
        if Self.isPreview {
            self.db = nil
        } else {
            self.db = Firestore.firestore()
        }
    }

    private func isValidEmail(_ s: String) -> Bool {
        let pattern = #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#
        return s.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }
    private func isValidPhone(_ s: String) -> Bool {
        let digits = s.filter(\.isNumber)
        return digits.count >= 8 && digits.count <= 15
    }
    private func isAdult(_ date: Date, minYears: Int = 18) -> Bool {
        let years = Calendar.current.dateComponents([.year], from: date, to: Date()).year ?? 0
        return years >= minYears
    }
    private func isStrongPassword(_ s: String) -> Bool {
        let hasMin = s.count >= 8
        let hasLetter = s.range(of: "[A-Za-z]", options: .regularExpression) != nil
        let hasDigit  = s.range(of: "[0-9]", options: .regularExpression) != nil
        return hasMin && hasLetter && hasDigit
    }
    private func validate() -> Bool {
        guard !fullName.isEmpty, !militaryId.isEmpty, !rank.isEmpty, !unit.isEmpty,
              !phone.isEmpty, !email.isEmpty else {
            error = "رجاءً عبّئ كل الحقول."
            return false
        }
        guard isValidEmail(email) else { error = "صيغة البريد الإلكتروني غير صحيحة."; return false }
        guard isValidPhone(phone) else { error = "رقم الهاتف غير صحيح."; return false }
        guard isAdult(dob, minYears: 18) else { error = "العمر يجب أن يكون 18 سنة أو أكثر."; return false }
        guard password == confirmPassword else { error = "كلمتا المرور غير متطابقتين."; return false }
        guard isStrongPassword(password) else {
            error = "كلمة المرور ضعيفة. استخدم 8+ أحرف مع أرقام وحروف."
            return false
        }
        return true
    }

    private func readableAuthError(_ err: Error) -> String {
        let ns = err as NSError
        guard ns.domain == AuthErrorDomain, let code = AuthErrorCode(rawValue: ns.code) else {
            return err.localizedDescription
        }
        switch code {
        case .emailAlreadyInUse:   return "هذا البريد الإلكتروني مستخدم مسبقًا."
        case .invalidEmail:        return "البريد الإلكتروني غير صالح."
        case .weakPassword:        return "كلمة المرور ضعيفة."
        case .networkError:        return "مشكلة في الشبكة. حاول لاحقًا."
        case .tooManyRequests:     return "محاولات كثيرة. جرّب لاحقًا."
        case .userDisabled:        return "تم تعطيل هذا الحساب."
        case .operationNotAllowed: return "التسجيل بهذا النوع غير مفعّل."
        default:                   return err.localizedDescription
        }
    }

    private func roleCollection(for role: UserRole) -> String {
        role == .leader ? "commanders" : "soldiers"
    }

    private func militaryIdExists(role: UserRole, militaryId: String) async throws -> Bool {
        guard let db else { return false }
        let col = db.collection(roleCollection(for: role))
        let snap = try await col.whereField("militaryId", isEqualTo: militaryId)
            .limit(to: 1).getDocuments()
        return !snap.documents.isEmpty
    }

    func signup(role: UserRole = .leader, sendEmailVerification: Bool = true) async {
        error = nil
        isDone = false
        guard validate() else { return }

        if Self.isPreview {
            isDone = true
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            if try await militaryIdExists(role: role, militaryId: militaryId) {
                self.error = "الرقم العسكري مستخدم مسبقًا."
                return
            }

            let res  = try await Auth.auth().createUser(withEmail: email, password: password)
            let uid  = res.user.uid

            let changeReq = res.user.createProfileChangeRequest()
            changeReq.displayName = fullName
            try await changeReq.commitChanges()

            if sendEmailVerification {
                try await res.user.sendEmailVerification()
            }

            let data: [String: Any] = [
                "uid": uid,
                "fullName": fullName,
                "militaryId": militaryId,
                "rank": rank,
                "unit": unit,
                "phone": phone,
                "email": email.lowercased(),
                "dob": Timestamp(date: dob),
                "role": role.rawValue,
                "createdAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp()
            ]

            try await db?.collection(roleCollection(for: role))
                .document(uid)
                .setData(data, merge: true)

            isDone = true
        } catch {
            self.error = readableAuthError(error)
        }
    }

    func signupSoldier() async { await signup(role: .soldier) }
    func signupCommander() async { await signup(role: .leader) }
}

extension SignupVM {
    static var preview: SignupVM {
        let vm = SignupVM()
        vm.fullName = "قائد تجريبي"
        vm.militaryId = "123456"
        vm.rank = "نقيب"
        vm.unit = "اللواء الأول"
        vm.phone = "90000000"
        vm.email = "commander@example.com"
        vm.dob = Calendar.current.date(from: DateComponents(year: 1990, month: 1, day: 1)) ?? Date()
        return vm
    }
}
