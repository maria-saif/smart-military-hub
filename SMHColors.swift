import SwiftUI

extension Color {
    static func smh(_ hex: UInt, alpha: Double = 1.0) -> Color {
        return Color(
            .displayP3,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }
}
