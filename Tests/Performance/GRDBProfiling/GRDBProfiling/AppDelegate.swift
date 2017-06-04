//
//  AppDelegate.swift
//  GRDBProfiling
//
//  Created by Gwendal Roué on 15/09/2015.
//  Copyright © 2015 Gwendal Roué. All rights reserved.
//

import Cocoa
import GRDB

let expectedRowCount = 100_000
let insertedRowCount = 20_000

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        fetchPositionalValues()
        fetchNamedValues()
        fetchRecords()
        insertPositionalValues()
        insertNamedValues()
        insertRecords()
    }

    func fetchPositionalValues() {
        let databasePath = Bundle(for: type(of: self)).path(forResource: "ProfilingDatabase", ofType: "sqlite")!
        let dbQueue = try! DatabaseQueue(path: databasePath)
        
        var count = 0
        
        dbQueue.inDatabase { db in
            let rows = try! Row.fetchCursor(db, "SELECT * FROM items")
            while let row = try! rows.next() {
                let _: Int = row.value(atIndex: 0)
                let _: Int = row.value(atIndex: 1)
                let _: Int = row.value(atIndex: 2)
                let _: Int = row.value(atIndex: 3)
                let _: Int = row.value(atIndex: 4)
                let _: Int = row.value(atIndex: 5)
                let _: Int = row.value(atIndex: 6)
                let _: Int = row.value(atIndex: 7)
                let _: Int = row.value(atIndex: 8)
                let _: Int = row.value(atIndex: 9)
                
                count += 1
            }
        }
        
        assert(count == expectedRowCount)
    }
    
    func fetchNamedValues() {
        let databasePath = Bundle(for: type(of: self)).path(forResource: "ProfilingDatabase", ofType: "sqlite")!
        let dbQueue = try! DatabaseQueue(path: databasePath)
        
        var count = 0
        
        dbQueue.inDatabase { db in
            let rows = try! Row.fetchCursor(db, "SELECT * FROM items")
            while let row = try! rows.next() {
                let _: Int = row.value(named: "i0")
                let _: Int = row.value(named: "i1")
                let _: Int = row.value(named: "i2")
                let _: Int = row.value(named: "i3")
                let _: Int = row.value(named: "i4")
                let _: Int = row.value(named: "i5")
                let _: Int = row.value(named: "i6")
                let _: Int = row.value(named: "i7")
                let _: Int = row.value(named: "i8")
                let _: Int = row.value(named: "i9")
                
                count += 1
            }
        }
        
        assert(count == expectedRowCount)
    }
    
    func fetchRecords() {
        let databasePath = Bundle(for: type(of: self)).path(forResource: "ProfilingDatabase", ofType: "sqlite")!
        let dbQueue = try! DatabaseQueue(path: databasePath)
        let items = dbQueue.inDatabase { db in
            try! Item.fetchAll(db)
        }
        assert(items.count == expectedRowCount)
        assert(items[0].i0 == 0)
        assert(items[1].i1 == 1)
        assert(items[expectedRowCount-1].i9 == expectedRowCount-1)
    }
    
    func insertPositionalValues() {
        let databaseFileName = "GRDBPerformanceTests-\(ProcessInfo.processInfo.globallyUniqueString).sqlite"
        let databasePath = (NSTemporaryDirectory() as NSString).appendingPathComponent(databaseFileName)
        defer {
            let dbQueue = try! DatabaseQueue(path: databasePath)
            dbQueue.inDatabase { db in
                assert(try! Int.fetchOne(db, "SELECT COUNT(*) FROM items")! == insertedRowCount)
                assert(try! Int.fetchOne(db, "SELECT MIN(i0) FROM items")! == 0)
                assert(try! Int.fetchOne(db, "SELECT MAX(i9) FROM items")! == insertedRowCount - 1)
            }
            try! FileManager.default.removeItem(atPath: databasePath)
        }
        
        _ = try? FileManager.default.removeItem(atPath: databasePath)
        
        let dbQueue = try! DatabaseQueue(path: databasePath)
        try! dbQueue.inDatabase { db in
            try db.execute("CREATE TABLE items (i0 INT, i1 INT, i2 INT, i3 INT, i4 INT, i5 INT, i6 INT, i7 INT, i8 INT, i9 INT)")
        }
        
        try! dbQueue.inTransaction { db in
            let statement = try! db.makeUpdateStatement("INSERT INTO items (i0, i1, i2, i3, i4, i5, i6, i7, i8, i9) VALUES (?,?,?,?,?,?,?,?,?,?)")
            for i in 0..<insertedRowCount {
                try statement.execute(arguments: [i, i, i, i, i, i, i, i, i, i])
            }
            return .commit
        }
    }
    
    func insertNamedValues() {
        let databaseFileName = "GRDBPerformanceTests-\(ProcessInfo.processInfo.globallyUniqueString).sqlite"
        let databasePath = (NSTemporaryDirectory() as NSString).appendingPathComponent(databaseFileName)
        defer {
            let dbQueue = try! DatabaseQueue(path: databasePath)
            dbQueue.inDatabase { db in
                assert(try! Int.fetchOne(db, "SELECT COUNT(*) FROM items")! == insertedRowCount)
                assert(try! Int.fetchOne(db, "SELECT MIN(i0) FROM items")! == 0)
                assert(try! Int.fetchOne(db, "SELECT MAX(i9) FROM items")! == insertedRowCount - 1)
            }
            try! FileManager.default.removeItem(atPath: databasePath)
        }
        
        _ = try? FileManager.default.removeItem(atPath: databasePath)
        
        let dbQueue = try! DatabaseQueue(path: databasePath)
        try! dbQueue.inDatabase { db in
            try db.execute("CREATE TABLE items (i0 INT, i1 INT, i2 INT, i3 INT, i4 INT, i5 INT, i6 INT, i7 INT, i8 INT, i9 INT)")
        }
        
        try! dbQueue.inTransaction { db in
            let statement = try! db.makeUpdateStatement("INSERT INTO items (i0, i1, i2, i3, i4, i5, i6, i7, i8, i9) VALUES (:i0, :i1, :i2, :i3, :i4, :i5, :i6, :i7, :i8, :i9)")
            for i in 0..<insertedRowCount {
                try statement.execute(arguments: ["i0": i, "i1": i, "i2": i, "i3": i, "i4": i, "i5": i, "i6": i, "i7": i, "i8": i, "i9": i])
            }
            return .commit
        }
    }
    
    func insertRecords() {
        let databaseFileName = "GRDBPerformanceTests-\(ProcessInfo.processInfo.globallyUniqueString).sqlite"
        let databasePath = (NSTemporaryDirectory() as NSString).appendingPathComponent(databaseFileName)
        _ = try? FileManager.default.removeItem(atPath: databasePath)
        defer {
            let dbQueue = try! DatabaseQueue(path: databasePath)
            dbQueue.inDatabase { db in
                assert(try! Int.fetchOne(db, "SELECT COUNT(*) FROM items")! == insertedRowCount)
                assert(try! Int.fetchOne(db, "SELECT MIN(i0) FROM items")! == 0)
                assert(try! Int.fetchOne(db, "SELECT MAX(i9) FROM items")! == insertedRowCount - 1)
            }
            try! FileManager.default.removeItem(atPath: databasePath)
        }
        
        _ = try? FileManager.default.removeItem(atPath: databasePath)
        
        let dbQueue = try! DatabaseQueue(path: databasePath)
        try! dbQueue.inDatabase { db in
            try db.execute("CREATE TABLE items (i0 INT, i1 INT, i2 INT, i3 INT, i4 INT, i5 INT, i6 INT, i7 INT, i8 INT, i9 INT)")
        }
        
        try! dbQueue.inTransaction { db in
            for i in 0..<insertedRowCount {
                try Item(i0: i, i1: i, i2: i, i3: i, i4: i, i5: i, i6: i, i7: i, i8: i, i9: i).insert(db)
            }
            return .commit
        }
    }
}


class Item : Record {
    var i0: Int?
    var i1: Int?
    var i2: Int?
    var i3: Int?
    var i4: Int?
    var i5: Int?
    var i6: Int?
    var i7: Int?
    var i8: Int?
    var i9: Int?
    
    init(i0: Int?, i1: Int?, i2: Int?, i3: Int?, i4: Int?, i5: Int?, i6: Int?, i7: Int?, i8: Int?, i9: Int?) {
        self.i0 = i0
        self.i1 = i1
        self.i2 = i2
        self.i3 = i3
        self.i4 = i4
        self.i5 = i5
        self.i6 = i6
        self.i7 = i7
        self.i8 = i8
        self.i9 = i9
        super.init()
    }
    
    override class var databaseTableName: String {
        return "items"
    }
    
    required init(row: GRDB.Row) {
        i0 = row.value(named: "i0")
        i1 = row.value(named: "i1")
        i2 = row.value(named: "i2")
        i3 = row.value(named: "i3")
        i4 = row.value(named: "i4")
        i5 = row.value(named: "i5")
        i6 = row.value(named: "i6")
        i7 = row.value(named: "i7")
        i8 = row.value(named: "i8")
        i9 = row.value(named: "i9")
        super.init(row: row)
    }
    
    override func encode(to container: inout PersistenceContainer) {
        container["i0"] = i0
        container["i1"] = i1
        container["i2"] = i2
        container["i3"] = i3
        container["i4"] = i4
        container["i5"] = i5
        container["i6"] = i6
        container["i7"] = i7
        container["i8"] = i8
        container["i9"] = i9
    }
}
