import SwiftUI

struct WelcomeIntroView: View {
    @EnvironmentObject var session: SessionViewModel
    @State private var showSetup = false
    @State private var isPressingStart = false
    @State private var appear = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [.black, .green.opacity(0.6)],
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Spacer()

                Image("AppLogo")
                    .resizable()
                    .renderingMode(.original)
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(radius: 10)
                    .opacity(appear ? 1 : 0)
                    .scaleEffect(appear ? 1 : 0.92)
                    .animation(.easeOut(duration: 0.6), value: appear)
                    .accessibilityLabel(Text("شعار التطبيق"))

                Text("Smart Military Hub")
                    .font(.title.bold())
                    .foregroundStyle(.white)
                    .opacity(appear ? 1 : 0)
                    .animation(.easeOut(duration: 0.7).delay(0.05), value: appear)

                Text("المستقبل العسكري يبدأ من هنا… ذكاء وانضباط بلا حدود.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .opacity(appear ? 1 : 0)
                    .animation(.easeOut(duration: 0.7).delay(0.1), value: appear)

                Spacer()

                Button {
                    guard !isPressingStart else { return }
                    isPressingStart = true
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    showSetup = true
                } label: {
                    Text("بدء الإعداد")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.white)
                        .foregroundStyle(.black)
                        .clipShape(Capsule())
                        .shadow(radius: 6)
                        .scaleEffect(isPressingStart ? 0.98 : 1)
                        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isPressingStart)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                .accessibilityHint(Text("ينقلك لاختيار الدور: قائد أو جندي"))
            }
        }
        .onAppear { appear = true }
        .fullScreenCover(isPresented: $showSetup, onDismiss: { isPressingStart = false }) {
            RoleGateView()
                .environmentObject(session)
        }
    }
}

#Preview {
    WelcomeIntroView()
        .environmentObject(SessionViewModel())
        .preferredColorScheme(.dark)
}
