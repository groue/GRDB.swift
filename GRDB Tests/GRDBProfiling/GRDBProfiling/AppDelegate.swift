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
            var sum: Int64 = 0
            dbQueue.inDatabase { db in
                for row in Row.fetch(db, "SELECT * FROM items") {
                    let i0: Int64 = row.value(atIndex: 0)
                    let i1: Int64 = row.value(atIndex: 1)
                    let i2: Int64 = row.value(atIndex: 2)
                    let i3: Int64 = row.value(atIndex: 3)
                    let i4: Int64 = row.value(atIndex: 4)
                    let i5: Int64 = row.value(atIndex: 5)
                    let i6: Int64 = row.value(atIndex: 6)
                    let i7: Int64 = row.value(atIndex: 7)
                    let i8: Int64 = row.value(atIndex: 8)
                    let i9: Int64 = row.value(atIndex: 9)
                    sum += i0 + i1 + i2 + i3 + i4 + i5 + i6 + i7 + i8 + i9
                }
            }
            print(sum)
        }
    }
}

