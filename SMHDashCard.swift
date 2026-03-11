import SwiftUI

struct SMHDashCard<Destination: View>: View {
    var title: String
    var subtitle: String
    var systemImage: String
    var tint: Color
    var isWide: Bool = false
    var tap: (() -> Void)? = nil
    @ViewBuilder var destination: () -> Destination

    var body: some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 12) {
                Image(systemName: systemImage).font(.title2)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.headline)
                    Text(subtitle).font(.caption).opacity(0.7)
                }
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, minHeight: 90)
            .background(tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
        }
        .simultaneousGesture(TapGesture().onEnded { tap?() })
    }
}
