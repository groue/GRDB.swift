import UIKit
import GRDB

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    
    func sceneWillEnterForeground(_ scene: UIScene) {
        // or UIApplicationDelegate.applicationWillEnterForeground(_:)
        DatabaseBackgroundScheduler.shared.resume(in: UIApplication.shared)
    }
}
