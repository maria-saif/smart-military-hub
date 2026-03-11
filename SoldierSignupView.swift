import SwiftUI

struct SoldierSignupView: View {
    @StateObject private var vm = SignupVM()

    var body: some View {
        NavigationStack {
            Form {
                Section("البيانات الأساسية") {
                    TextField("الاسم الكامل", text: $vm.fullName)
                        .textInputAutocapitalization(.words)
                    TextField("الرقم العسكري / الهوية", text: $vm.militaryId)
                        .keyboardType(.numberPad)
                    DatePicker("تاريخ الميلاد", selection: $vm.dob, displayedComponents: .date)
                    TextField("الرتبة (جندي/عريف...)", text: $vm.rank)
                    TextField("الوحدة / الكتيبة", text: $vm.unit)
                }

                Section("التواصل") {
                    TextField("رقم الجوال", text: $vm.phone)
                        .keyboardType(.phonePad)
                    TextField("البريد الإلكتروني", text: $vm.email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                }

                Section("الأمان") {
                    ManualPasswordField(text: $vm.password, placeholder: "كلمة المرور (+8 أحرف وأرقام)")
                    ManualPasswordField(text: $vm.confirmPassword, placeholder: "تأكيد كلمة المرور")
                }

                if let err = vm.error {
                    Section { Text(err).foregroundColor(.red) }
                }

                Section {
                    Button {
                        Task { await vm.signupSoldier() }
                    } label: {
                        if vm.isLoading {
                            ProgressView()
                        } else {
                            Text("إنشاء حساب جندي").frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(vm.isLoading)
                }
            }
            .navigationTitle("تسجيل جندي")
            .alert("تم إنشاء الحساب", isPresented: $vm.isDone) {
                Button("حسناً") { }
            }
        }
    }
}

#Preview { SoldierSignupView() }
