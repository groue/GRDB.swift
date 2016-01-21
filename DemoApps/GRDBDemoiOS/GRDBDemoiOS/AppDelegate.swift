import UIKit
import GRDB

// The shared database queue, stored in a global.
// It is created in AppDelegate.application(_:didFinishLaunchingWithOptions:)
var dbQueue: DatabaseQueue!

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UISplitViewControllerDelegate {
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
                    "lastName TEXT ," +
                    "visible BOOLEAN DEFAULT TRUE ," +
                    "position INTEGER " +
                ")")
        }
        migrator.registerMigration("addPersons") { db in
            try Person(firstName: "Arthur", lastName: "Miller").insert(db)
            try Person(firstName: "Barbra", lastName: "Streisand").insert(db)
            try Person(firstName: "Cinderella").insert(db)
            try Person(firstName: "John", lastName: "Appleseed").insert(db)
            try Person(firstName: "Kate", lastName: "Bell").insert(db)
            try Person(firstName: "Anna", lastName: "Haro").insert(db)
            try Person(firstName: "Daniel", lastName: "Higgins").insert(db)
            try Person(firstName: "David", lastName: "Taylor").insert(db)
            try Person(firstName: "Hank", lastName: "Zakroff").insert(db)
            try Person(firstName: "Steve", lastName: "Jobs").insert(db)
            try Person(firstName: "Bill", lastName: "Gates").insert(db)
            try Person(firstName: "Zlatan", lastName: "Ibrahimovic").insert(db)
            try Person(firstName: "Barack", lastName: "Obama").insert(db)
            try Person(firstName: "François", lastName: "Hollande").insert(db)
            try Person(firstName: "Britney", lastName: "Spears").insert(db)
            try Person(firstName: "Andre", lastName: "Agassi").insert(db)
            try Person(firstName: "Roger", lastName: "Federer").insert(db)
            try Person(firstName: "Rafael", lastName: "Nadal").insert(db)
            try Person(firstName: "Gael", lastName: "Monfils").insert(db)
            try Person(firstName: "Jo Wilfried", lastName: "Tsonga").insert(db)
            try Person(firstName: "Serena", lastName: "Williams").insert(db)
            try Person(firstName: "Venus", lastName: "Williams").insert(db)
            try Person(firstName: "Amélie", lastName: "Poulain").insert(db)
        }
        try! migrator.migrate(dbQueue)
        
        
        // Setup view controllers
        
        let splitViewController = self.window!.rootViewController as! UISplitViewController
        let navigationController = splitViewController.viewControllers[splitViewController.viewControllers.count-1] as! UINavigationController
        navigationController.topViewController!.navigationItem.leftBarButtonItem = splitViewController.displayModeButtonItem()
        splitViewController.delegate = self
        
        return true
    }

    // MARK: - Split view

    func splitViewController(splitViewController: UISplitViewController, collapseSecondaryViewController secondaryViewController:UIViewController, ontoPrimaryViewController primaryViewController:UIViewController) -> Bool {
        guard let secondaryAsNavController = secondaryViewController as? UINavigationController else { return false }
        guard let topAsDetailController = secondaryAsNavController.topViewController as? DetailViewController else { return false }
        if topAsDetailController.person == nil {
            // Return true to indicate that we have handled the collapse by doing nothing; the secondary controller will be discarded.
            return true
        }
        return false
    }

}

