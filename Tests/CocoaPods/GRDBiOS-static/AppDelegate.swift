import GRDB
import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Test GRDB
        _ = try! DatabaseQueue()
        
        // test SQLITE_ENABLE_FTS5
        _ = FTS5.self
        
        // test_SQLITE_ENABLE_PREUPDATE_HOOK
        _ = DatabasePreUpdateEvent.self
        
        // test C functions
        _ = sqlite3_libversion_number()
        
        return true
    }
}
