import UIKit
import GRDB

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        DatabaseBackgroundScheduler.shared.resume(in: application)
    }
}
