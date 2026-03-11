import SwiftUI

struct SMHReadinessRing: View {
    var progress: Double = 0.7
    var body: some View {
        ZStack {
            Circle().stroke(lineWidth: 8).opacity(0.2)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}
