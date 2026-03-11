import SwiftUI

struct DashCard<Destination: View>: View {
    var title: String
    var subtitle: String
    var systemImage: String
    var tint: Color = .blue
    var isWide: Bool = false

    let action: () -> Void
    let destination: () -> Destination

    init(title: String,
         subtitle: String,
         systemImage: String,
         tint: Color = .blue,
         isWide: Bool = false,
         action: @escaping () -> Void = {},
         @ViewBuilder destination: @escaping () -> Destination) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.tint = tint
        self.isWide = isWide
        self.action = action
        self.destination = destination
    }

    var body: some View {
        CardNav(
            title: title,
            subtitle: subtitle,
            systemIcon: systemImage
        ) {
            destination()
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0).onChanged { _ in action() }
        )
    }
}
