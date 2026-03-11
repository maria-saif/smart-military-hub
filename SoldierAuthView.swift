import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import LocalAuthentication

struct SoldierAuthView: View {
    @EnvironmentObject var session: SessionViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showRegister = false
    @State private var serviceId = ""
    @State private var password = ""
    @State private var errorMsg: String?
    @State private var isLoading = false
    @State private var goDashboard = false

    @State private var canUseBiometrics = false
    @State private var hasStoredCreds = false
    @State private var askEnableBiometrics = false
    @State private var pendingSoldierName: String? = nil

    private let kBioEnabled = "soldier_bio_enabled"

    private var biometryIcon: String {
        let ctx = LAContext()
        _ = ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch ctx.biometryType {
        case .faceID:  return "faceid"
        case .touchID: return "touchid"
        default:       return "faceid"
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [.black, .green.opacity(0.6)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()

                VStack(spacing: 18) {
                    Spacer(minLength: 24)

                    Image("AppLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 84, height: 84)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .shadow(radius: 8)

                    Text("دخول الجندي")
                        .font(.title3.bold())
                        .foregroundStyle(.white)

                    VStack(spacing: 12) {
                        TextField("الرقم العسكري / الهوية", text: $serviceId)
                            .keyboardType(.numberPad)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .textContentType(.username)

                        SecureField("كلمة المرور", text: $password)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .textContentType(.password)
                    }
                    .padding()
                    .foregroundStyle(.white)
                    .tint(.white)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.08)))
                    .padding(.horizontal)

                    if let e = errorMsg {
                        Text(e)
                            .font(.footnote)
                            .foregroundStyle(.red.opacity(0.95))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    Button {
                        Task { await loginSoldier() }
                    } label: {
                        ZStack {
                            if isLoading { ProgressView().tint(.black) }
                            else { Text("دخول").font(.headline) }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.white)
                        .foregroundStyle(.black)
                        .clipShape(Capsule())
                        .shadow(radius: 6)
                    }
                    .padding(.horizontal, 24)
                    .disabled(isLoading)

                    if canUseBiometrics && !hasStoredCreds {
                        Button {
                            askEnableBiometrics = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: biometryIcon)
                                Text("تفعيل الدخول بالبصمة").font(.subheadline.bold())
                            }
                            .frame(maxWidth: .infinity)
                            .padding(10)
                            .background(.ultraThinMaterial)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(.white.opacity(0.2)))
                        }
                        .padding(.horizontal, 24)
                    }

                    if canUseBiometrics && hasStoredCreds {
                        Button {
                            Task { await biometricLogin() }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: biometryIcon)
                                Text("دخول بالبصمة").font(.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.ultraThinMaterial)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(.white.opacity(0.15)))
                        }
                        .padding(.horizontal, 24)
                        .disabled(isLoading)
                    }

                    Button {
                        showRegister = true
                    } label: {
                        Text("لا يوجد لدي حساب؟ إنشاء حساب جندي")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.95))
                            .padding(.top, 4)
                    }

                    Spacer()

                    Text("© 2025 Smart Military Hub – جميع الحقوق محفوظة")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.bottom, 10)
                }

                NavigationLink("", destination: SoldierDashboardView().environmentObject(session), isActive: $goDashboard).hidden()
            }
            .sheet(isPresented: $showRegister) {
                SoldierSignupView().environmentObject(session)
            }
            .onAppear {
                refreshBiometryState()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                refreshBiometryState()
            }
            .alert("تفعيل الدخول بالبصمة؟", isPresented: $askEnableBiometrics) {
                Button("لاحقًا", role: .cancel) {
                    Task { await MainActor.run { proceedToDashboard(name: pendingSoldierName ?? "الجندي") } }
                }
                Button("تفعيل") {
                    Task {
                        await enableBiometricsNow()
                        await MainActor.run { proceedToDashboard(name: pendingSoldierName ?? "الجندي") }
                    }
                }
            } message: {
                let bioName = biometryIcon == "faceid" ? "Face ID" : "Touch ID"
                Text("سيمكنك الدخول بسرعة باستخدام \(bioName) لهذا الحساب فقط.")
            }
        }
    }

    private func refreshBiometryState() {
        let ctx = LAContext()
        canUseBiometrics = ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        hasStoredCreds = UserDefaults.standard.bool(forKey: kBioEnabled)
        print("🔎 Soldier canUseBiometrics=\(canUseBiometrics), hasStoredCreds=\(hasStoredCreds)")
    }

    private func loginSoldier() async {
        errorMsg = nil
        guard !serviceId.isEmpty, !password.isEmpty else {
            errorMsg = "أدخل الرقم العسكري وكلمة المرور."
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let snap = try await Firestore.firestore()
                .collection("soldiers")
                .whereField("militaryId", isEqualTo: serviceId)
                .limit(to: 1)
                .getDocuments()

            guard let doc = snap.documents.first,
                  let email = doc.get("email") as? String else {
                errorMsg = "لا يوجد جندي بهذا الرقم."
                return
            }

            let soldierName =
                (doc.get("fullName") as? String) ??
                (doc.get("name") as? String) ??
                "الجندي"

            try await Auth.auth().signIn(withEmail: email, password: password)

            if canUseBiometrics && !UserDefaults.standard.bool(forKey: kBioEnabled) {
                pendingSoldierName = soldierName
                askEnableBiometrics = true
            } else {
                await MainActor.run { proceedToDashboard(name: soldierName) }
            }

            print("✅ تم تسجيل الدخول للجندي: \(email)")
        } catch {
            let ns = error as NSError
            if ns.domain == AuthErrorDomain,
               let code = AuthErrorCode(rawValue: ns.code) {
                switch code {
                case .wrongPassword: errorMsg = "كلمة المرور غير صحيحة."
                case .userDisabled:  errorMsg = "تم تعطيل هذا الحساب."
                case .userNotFound:  errorMsg = "الحساب غير موجود."
                default:             errorMsg = "تعذّر تسجيل الدخول. (\(code.rawValue))"
                }
            } else {
                errorMsg = error.localizedDescription
            }
        }
    }

    private func enableBiometricsNow() async {
        do {
            let snap = try await Firestore.firestore()
                .collection("soldiers")
                .whereField("militaryId", isEqualTo: serviceId)
                .limit(to: 1)
                .getDocuments()
            guard let doc = snap.documents.first,
                  let email = doc.get("email") as? String else { return }

            try BioKeychain.setProtected(email, forKey: "sold_email")
            try BioKeychain.setProtected(password, forKey: "sold_pass")
            UserDefaults.standard.set(true, forKey: kBioEnabled)
            hasStoredCreds = true
            print("✅ تم تفعيل الدخول بالبصمة للجندي: \(email)")
        } catch {
            print("⚠️ تعذر تفعيل الدخول بالبصمة: \(error.localizedDescription)")
        }
    }

    private func biometricLogin() async {
        errorMsg = nil
        guard canUseBiometrics, hasStoredCreds else {
            errorMsg = "الدخول بالبصمة غير مفعّل."
            return
        }

        do {
            let prompt = "تأكيد هويتك للدخول كجندي"
            let email = try BioKeychain.getProtected("sold_email", prompt: prompt)
            let pass  = try BioKeychain.getProtected("sold_pass", prompt: prompt)

            isLoading = true
            defer { isLoading = false }

            try await Auth.auth().signIn(withEmail: email, password: pass)

            if (session.currentUserName ?? "").isEmpty || (session.currentServiceId ?? "").isEmpty {
                let snap = try await Firestore.firestore()
                    .collection("soldiers")
                    .whereField("email", isEqualTo: email)
                    .limit(to: 1)
                    .getDocuments()
                if let doc = snap.documents.first {
                    await MainActor.run {
                        session.currentUserName =
                            (doc.get("fullName") as? String) ??
                            (doc.get("name") as? String) ?? "الجندي"
                        session.currentServiceId = (doc.get("militaryId") as? String) ?? ""
                    }
                }
            }

            await MainActor.run {
                session.currentRole = .soldier
                session.isAuthenticated = true
                if (session.currentUserName ?? "").isEmpty { session.currentUserName = "الجندي" }
                session.errorMsg = nil
                goDashboard = true
                dismiss()
            }

            print("✅ دخول جندي بالبصمة")
        } catch {
            await MainActor.run {
                errorMsg = "فشل التحقق بالبصمة أو لا توجد بيانات محفوظة لهذا الحساب."
            }
        }
    }

    @MainActor
    private func proceedToDashboard(name: String) {
        session.currentRole = .soldier
        session.isAuthenticated = true
        session.currentUserName = name
        session.currentServiceId = serviceId
        session.errorMsg = nil
        goDashboard = true
        dismiss()
    }
}

