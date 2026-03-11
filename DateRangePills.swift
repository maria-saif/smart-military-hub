import SwiftUI

struct DateRangePills: View {
    @Binding var days: [Date]
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(days, id: \.self) { d in
                    Text(d, style: .date)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                }
            }
        }
    }
}
