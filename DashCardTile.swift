import SwiftUI

struct DashCardTile: View {
    let title: String
    let subtitle: String
    let systemIcon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: systemIcon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.95))
                    .frame(width: 36, height: 36)
                    .background(.white.opacity(0.08),
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                Spacer(minLength: 8)
            }
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(LinearGradient(colors: [.white.opacity(0.06), .white.opacity(0.03)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        )
        .contentShape(Rectangle())
    }
}
