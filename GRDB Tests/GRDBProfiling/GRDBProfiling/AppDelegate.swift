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
        
        let databasePath = "/tmp/GRDBProfiling.sqlite"
        do { try NSFileManager.defaultManager().removeItemAtPath(databasePath) } catch { }
        dbQueue = try! DatabaseQueue(path: databasePath)
        populateDatabase()
        readFromDatabase()
    }
    
    func populateDatabase() {
        try! dbQueue.inTransaction { db in
            try db.execute(
                "CREATE TABLE items (" +
                    "i0 INT, " +
                    "i1 INT, " +
                    "i2 INT, " +
                    "i3 INT, " +
                    "i4 INT " +
                ")")
            for i in 0..<10000 {
                try db.execute("INSERT INTO items (i0, i1, i2, i3, i4) VALUES (?,?,?,?,?)", arguments: [i, i+1, i+2, i+3, i+4])
            }
            return .Commit
        }
    }
    
    func readFromDatabase() {
        for _ in 0..<100 {
            var sum: Int64 = 0
            dbQueue.inDatabase { db in
                for row in Row.metalFetch(db, "SELECT * FROM items") {
                    let i0 = row.metalInt64(atIndex: 0)
                    let i1 = row.metalInt64(atIndex: 1)
                    let i2 = row.metalInt64(atIndex: 2)
                    let i3 = row.metalInt64(atIndex: 3)
                    let i4 = row.metalInt64(atIndex: 4)
                    sum += i0 + i1 + i2 + i3 + i4
                }
            }
            print(sum)
        }
    }
}

