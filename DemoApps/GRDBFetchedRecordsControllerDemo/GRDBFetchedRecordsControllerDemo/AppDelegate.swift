import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        // Setup database
        setupDatabase()
        return true
    }
    
    func applicationDidReceiveMemoryWarning(application: UIApplication) {
        // Release as much memory as possible.
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0)) {
            dbQueue.releaseMemory()
        }
    }
    
    func applicationDidEnterBackground(application: UIApplication) {
        let task = application.beginBackgroundTaskWithExpirationHandler(nil)
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            // Release as much memory as possible.
            dbQueue.releaseMemory()
            application.endBackgroundTask(task)
        }
    }
}
