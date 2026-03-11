import UIKit
import FirebaseCore
import FirebaseAppCheck

final class SMHAppDelegate: NSObject, UIApplicationDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {

        let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        guard !isPreview else { return true }

        #if DEBUG
        AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
        #endif

        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
            print("🔥 Firebase configured (SMHAppDelegate)")
        }
        return true
    }
}
