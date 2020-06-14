import UIKit
import GRDB

// The shared application database
var appDatabase: AppDatabase!

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        try! setupDatabase(application)
        return true
    }
    
    private func setupDatabase(_ application: UIApplication) throws {
        // AppDelegate is responsible for chosing the location of the database file.
        // See https://github.com/groue/GRDB.swift/blob/master/README.md#database-connections
        let databaseURL = try FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("db.sqlite")
        let dbQueue = try DatabaseQueue(path: databaseURL.path)
        
        // Create the shared application database
        appDatabase = try AppDatabase(dbQueue)
    }
}
