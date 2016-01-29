//
//  AppDelegate.swift
//  iOS
//
//  Created by Gwendal Roué on 08/07/2015.
//  Copyright © 2015 Gwendal Roué. All rights reserved.
//

import UIKit
import GRDB

var dbQueue: DatabaseQueue!

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UISplitViewControllerDelegate {

    var window: UIWindow?


    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        // Override point for customization after application launch.
        let splitViewController = self.window!.rootViewController as! UISplitViewController
        let navigationController = splitViewController.viewControllers[splitViewController.viewControllers.count-1] as! UINavigationController
        navigationController.topViewController!.navigationItem.leftBarButtonItem = splitViewController.displayModeButtonItem()
        splitViewController.delegate = self
        
        // Database
        dbQueue = DatabaseQueue()
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createPersons") { db in
            try db.execute("CREATE TABLE persons (id INTEGER PRIMARY KEY, firstName TEXT, lastName TEXT)")
        }
        migrator.registerMigration("addPersons") { db in
            try Person(firstName: "Arthur", lastName: "Miller").insert(db)
            try Person(firstName: "Barbara", lastName: "Streisand").insert(db)
            try Person(firstName: "Cinderella").insert(db)
        }
        try! migrator.migrate(dbQueue)
        
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

