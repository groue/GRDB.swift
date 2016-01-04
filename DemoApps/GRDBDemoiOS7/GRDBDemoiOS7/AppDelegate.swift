import UIKit

// The shared database queue, stored in a global.
// It is created in AppDelegate.application(_:didFinishLaunchingWithOptions:)
var dbQueue: DatabaseQueue!

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        
        // Connect to the database
        
        let documentsPath = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true).first! as NSString
        let databasePath = documentsPath.stringByAppendingPathComponent("db.sqlite")
        dbQueue = try! DatabaseQueue(path: databasePath)
        
        
        // Use DatabaseMigrator to setup the database
        
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createPersons") { db in
            try db.execute(
                "CREATE TABLE persons (" +
                    "id INTEGER PRIMARY KEY, " +
                    "firstName TEXT, " +
                    "lastName TEXT " +
                ")")
        }
        migrator.registerMigration("addPersons") { db in
            try Person(firstName: "Arthur", lastName: "Miller").insert(db)
            try Person(firstName: "Barbra", lastName: "Streisand").insert(db)
            try Person(firstName: "Cinderella").insert(db)
        }
        try! migrator.migrate(dbQueue)
        
        
        return true
    }
}

