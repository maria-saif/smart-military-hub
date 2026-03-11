import SwiftUI

struct EmergencyKPIV2 {
    let coverage: Double
    let avgHours: Double
    let days: Int
    let templatesPerDay: Int
}

enum EmergencyDefaultsV2 {
    static let templates12h: [ShiftTemplate] = [
        .init(id: UUID(), name: "نهاري",
              start: DateComponents(hour: 6),
              end:   DateComponents(hour: 18),
              isNight: false),
        .init(id: UUID(), name: "ليلي",
              start: DateComponents(hour: 18),
              end:   DateComponents(hour: 6),
              isNight: true)
    ]
    static let templates8h: [ShiftTemplate] = [
        .init(id: UUID(), name: "صباحي",
              start: DateComponents(hour: 6),
              end:   DateComponents(hour: 14),
              isNight: false),
        .init(id: UUID(), name: "مسائي",
              start: DateComponents(hour: 14),
              end:   DateComponents(hour: 22),
              isNight: false),
        .init(id: UUID(), name: "ليلي",
              start: DateComponents(hour: 22),
              end:   DateComponents(hour: 6),
              isNight: true)
    ]
}

struct EmergencyToast: Identifiable, Equatable {
    enum Kind { case success, error, info }
    var id = UUID()
    var kind: Kind
    var message: String
    static func success(_ m: String) -> EmergencyToast { .init(kind: .success, message: m) }
    static func error(_ m: String) -> EmergencyToast { .init(kind: .error, message: m) }
    static func info(_ m: String) -> EmergencyToast { .init(kind: .info, message: m) }
}

struct EmergencyToastView: View {
    let toast: EmergencyToast
    private var base: Color {
        switch toast.kind {
        case .success: return .green
        case .error:   return .red
        case .info:    return .blue
        }
    }
    private var icon: String {
        switch toast.kind {
        case .success: return "checkmark.seal.fill"
        case .error:   return "xmark.octagon.fill"
        case .info:    return "info.circle.fill"
        }
    }
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(.white)
            Text(toast.message).foregroundStyle(.white)
            Spacer()
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(
            LinearGradient(colors: [base.opacity(0.9), base.opacity(0.7)],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: Capsule()
        )
        .shadow(radius: 10, y: 6)
        .padding(.horizontal, 16)
    }
}

extension DemoData {
    static func nextDays(_ n: Int) -> [Date] {
        let cal = Calendar.current
        return (0..<max(1,n)).compactMap {
            cal.date(byAdding: .day, value: $0, to: cal.startOfDay(for: Date()))
        }
    }
}
