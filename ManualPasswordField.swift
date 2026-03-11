import SwiftUI

struct ManualPasswordField: View {
    @Binding var text: String
    var placeholder: String = "كلمة المرور"
    @State private var isSecure = true

    var body: some View {
        HStack(spacing: 8) {
            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                        .textContentType(.password)
                        .autocorrectionDisabled(true)
                } else {
                    TextField(placeholder, text: $text)
                        .textContentType(.password)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                }
            }
            Button { isSecure.toggle() } label: {
                Image(systemName: isSecure ? "eye.slash" : "eye").imageScale(.medium)
            }
            .buttonStyle(.plain)
        }
    }
}
