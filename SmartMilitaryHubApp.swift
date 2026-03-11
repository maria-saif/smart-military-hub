import SwiftUI
import FirebaseCore

@main
struct SmartMilitaryHubApp: App {
    @StateObject private var session = SessionViewModel()

    init() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
    }

    var body: some Scene {
        WindowGroup {
            RootRouter()
                .environmentObject(session)                 
        }
    }
}
