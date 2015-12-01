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
        testValueAtIndexPerformance()
        testValueNamedPerformance()
        testRecordPerformance()
        testKeyValueCodingPerformance()
    }
    
    func testValueAtIndexPerformance() {
        for _ in 0..<10 {
            dbQueue.inDatabase { db in
                for row in Row.fetch(db, "SELECT * FROM items") {
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
                }
            }
        }
    }

    func testValueNamedPerformance() {
        for _ in 0..<10 {
            dbQueue.inDatabase { db in
                for row in Row.fetch(db, "SELECT * FROM items") {
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
                }
            }
        }
    }
    
    func testRecordPerformance() {
        for _ in 0..<10 {
            let records = dbQueue.inDatabase { db in
                PerformanceRecord.fetchAll(db, "SELECT * FROM items")
            }
            precondition(records[4].i2 == 1)
            precondition(records[4].i3 == 0)
            precondition(records[5].i2 == 2)
            precondition(records[5].i3 == 1)
        }
    }
    
    func testKeyValueCodingPerformance() {
        for _ in 0..<10 {
            let records = dbQueue.inDatabase { db in
                Row.fetch(db, "SELECT * FROM items").map { row in
                    PerformanceObjCRecord(dictionary: row.toNSDictionary())
                }
            }
            precondition(records[4].i2!.intValue == 1)
            precondition(records[4].i3!.intValue == 0)
            precondition(records[5].i2!.intValue == 2)
            precondition(records[5].i3!.intValue == 1)
        }
    }
}


class PerformanceRecord : Record {
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
    
    
    // Record
    
    required init(row: Row) {
        super.init(row: row)
    }
    
    override func updateFromRow(row: Row) {
        if let dbv = row["i0"] { i0 = dbv.value() }
        if let dbv = row["i1"] { i1 = dbv.value() }
        if let dbv = row["i2"] { i2 = dbv.value() }
        if let dbv = row["i3"] { i3 = dbv.value() }
        if let dbv = row["i4"] { i4 = dbv.value() }
        if let dbv = row["i5"] { i5 = dbv.value() }
        if let dbv = row["i6"] { i6 = dbv.value() }
        if let dbv = row["i7"] { i7 = dbv.value() }
        if let dbv = row["i8"] { i8 = dbv.value() }
        if let dbv = row["i9"] { i9 = dbv.value() }
        super.updateFromRow(row)
    }
}

class PerformanceObjCRecord : NSObject {
    var i0: NSNumber?
    var i1: NSNumber?
    var i2: NSNumber?
    var i3: NSNumber?
    var i4: NSNumber?
    var i5: NSNumber?
    var i6: NSNumber?
    var i7: NSNumber?
    var i8: NSNumber?
    var i9: NSNumber?
    
    init(dictionary: NSDictionary) {
        super.init()
        for (key, value) in dictionary {
            setValue(value, forKey: key as! String)
        }
    }
}

