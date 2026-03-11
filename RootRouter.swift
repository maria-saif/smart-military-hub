import SwiftUI

struct RootRouter: View {
    @EnvironmentObject var session: SessionViewModel

    var body: some View {
        Group {
            if session.isAuthenticated {
                if let role = session.currentRole {
                    switch role {
                    case .commander:
                        CommanderDashboardView()
                    case .soldier:
                        SoldierDashboardView()
                    }
                } else {
                    RoleGateView()
                }
            } else {
                WelcomeIntroView()
            }
        }
        .transition(.opacity.combined(with: .scale))
        .animation(.easeInOut, value: session.isAuthenticated)
    }
}
