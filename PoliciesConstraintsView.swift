import SwiftUI

struct PoliciesConstraintsView: View {
    @Binding var constraints: SchedulingConstraints

    @State private var maxConsecutiveNights = 2
    @State private var balanceLoad = true
    @State private var allowOvertime = false

    var body: some View {
        Form {
            Section("القيود الأساسية") {
                Stepper("الحد الأقصى للساعات/الأسبوع: \(constraints.maxHoursPerWeek)",
                        value: $constraints.maxHoursPerWeek, in: 8...84, step: 1)

                Stepper("الراحة الدنيا بين الشفتات (ساعات): \(constraints.minRestHoursBetweenShifts)",
                        value: $constraints.minRestHoursBetweenShifts, in: 0...24, step: 1)

                Toggle("تجنّب انحياز الليالي", isOn: $constraints.avoidNightBias)
            }

            Section("خيارات متقدمة (محلية)") {
                Stepper("أقصى ليالٍ متتالية: \(maxConsecutiveNights)",
                        value: $maxConsecutiveNights, in: 0...5)

                Toggle("موازنة الحمل بين الجنود", isOn: $balanceLoad)
                Toggle("السماح بساعات إضافية", isOn: $allowOvertime)

                Text("سيتم تطبيق هذه السياسات أثناء توليد الجدول.")
                    .foregroundStyle(.secondary)
                    .font(.footnote)
            }
        }
        .navigationTitle("الأوامر / القيود")
    }
}
