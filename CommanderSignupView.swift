import SwiftUI

struct CommanderSignupView: View {
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

                    TextField("الرتبة (ملازم/نقيب/رائد…)", text: $vm.rank)
                    TextField("الوحدة / اللواء", text: $vm.unit)
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
                        Task { await vm.signupCommander() }
                    } label: {
                        if vm.isLoading {
                            ProgressView()
                        } else {
                            Text("إنشاء حساب قائد").frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(vm.isLoading)
                }
            }
            .navigationTitle("تسجيل قائد")
            .alert("تم إنشاء الحساب", isPresented: $vm.isDone) {
                Button("حسناً") { }
            }
        }
    }
}

#Preview { CommanderSignupView() }
