//
//  AppDelegate.swift
//  GRDBProfiling
//
//  Created by Gwendal Roué on 15/09/2015.
//  Copyright © 2015 Gwendal Roué. All rights reserved.
//

import Cocoa
import GRDB

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    var dbQueue: DatabaseQueue!
    
    func applicationDidFinishLaunching(aNotification: NSNotification) {
        let databasePath = NSBundle.mainBundle().pathForResource("ProfilingDatabase", ofType: "sqlite")!
        dbQueue = try! DatabaseQueue(path: databasePath)
        readFromDatabase()
    }
    
    func readFromDatabase() {
        for _ in 0..<100 {
            dbQueue.inDatabase { db in
                for row in Row.fetch(db, "SELECT * FROM items") {
                    let _: Int64 = row.value(atIndex: 0)
                    let _: Int64 = row.value(atIndex: 1)
                    let _: Int64 = row.value(atIndex: 2)
                    let _: Int64 = row.value(atIndex: 3)
                    let _: Int64 = row.value(atIndex: 4)
                    let _: Int64 = row.value(atIndex: 5)
                    let _: Int64 = row.value(atIndex: 6)
                    let _: Int64 = row.value(atIndex: 7)
                    let _: Int64 = row.value(atIndex: 8)
                    let _: Int64 = row.value(atIndex: 9)
                }
            }
        }
    }
}

