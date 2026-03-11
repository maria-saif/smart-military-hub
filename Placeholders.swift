import SwiftUI


struct ReadinessView: View {
    var body: some View {
        Text("مؤشرات الجاهزية (قريبًا)")
            .padding()
            .navigationTitle("الجاهزية")
    }
}

struct ReportsView: View {
    var body: some View {
        Text("التقارير الذكية (قريبًا)")
            .padding()
            .navigationTitle("التقارير")
    }
}

struct AlertsView: View {
    var body: some View {
        Text("التنبيهات الذكية (قريبًا)")
            .padding()
            .navigationTitle("التنبيهات")
    }
}

struct EmergencyModeView: View {
    var body: some View {
        Text("وضع الطوارئ (قريبًا)")
            .padding()
            .navigationTitle("الطوارئ")
    }
}
