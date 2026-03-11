import SwiftUI

struct SupportView: View {
    @State private var category = "تقني"
    @State private var message = ""
    let cats = ["تقني", "الوصول/حساب", "تطبيقات ميدانية", "أخرى"]

    var body: some View {
        Form {
            Picker("نوع البلاغ", selection: $category) {
                ForEach(cats, id: \.self) { Text($0) }
            }
            Section("وصف المشكلة") {
                TextEditor(text: $message).frame(minHeight: 120)
            }
            Button("إرسال البلاغ") { }
            Section("سجل البلاغات") {
                Label("مغلق: مشكلة مزامنة", systemImage: "checkmark.circle")
                Label("مفتوح: تعطل شاشة المكتبة", systemImage: "exclamationmark.circle")
            }
        }
        .navigationTitle("الدعم الفني")
        .environment(\.layoutDirection, .rightToLeft)
    }
}
