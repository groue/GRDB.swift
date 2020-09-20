import UIKit
import GRDB

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Setup database. Error handling left as an exercise for the reader.
        try! setupDatabase()
        return true
    }
    
    // MARK: UISceneSession Lifecycle
    
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
    
    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
    
    // MARK: - Database Setup
    
    private func setupDatabase() throws {
        // AppDelegate chooses the location of the database file.
        // See https://github.com/groue/GRDB.swift/blob/master/README.md#database-connections
        let databaseURL = try FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("db.sqlite")
        let dbQueue = try DatabaseQueue(path: databaseURL.path)
        
        // Create the shared application database
        let database = try AppDatabase(dbQueue)
        
        // Populate the database if it is empty, for better demo purpose.
        try database.createRandomPlayersIfEmpty()
        
        // Expose it to the rest of the application
        AppDatabase.shared = database
    }
}
