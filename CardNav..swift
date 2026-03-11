import SwiftUI

public struct CardNav<Destination: View>: View {
    let title: String
    let subtitle: String
    let systemIcon: String
    let destination: Destination

    public init(title: String,
                subtitle: String,
                systemIcon: String,
                @ViewBuilder destination: () -> Destination) {
        self.title = title
        self.subtitle = subtitle
        self.systemIcon = systemIcon
        self.destination = destination()
    }

    public var body: some View {
        NavigationLink(destination: destination) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: systemIcon)
                    .font(.title2)
                    .foregroundColor(.white)
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.75))   
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
