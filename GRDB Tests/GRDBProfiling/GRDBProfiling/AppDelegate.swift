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

    func testValueNamedPerformance() {
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
    
    func testRecordPerformance() {
        let records = dbQueue.inDatabase { db in
            PerformanceRecord.fetchAll(db, "SELECT * FROM items")
        }
        assert(records[4].i2 == 1)
        assert(records[4].i3 == 0)
        assert(records[5].i2 == 2)
        assert(records[5].i3 == 1)
    }
    
    func testKeyValueCodingPerformance() {
        let records = dbQueue.inDatabase { db in
            Row.fetch(db, "SELECT * FROM items").map { row in
                PerformanceObjCRecord(dictionary: row.toNSDictionary())
            }
        }
        assert(records[4].i2!.intValue == 1)
        assert(records[4].i3!.intValue == 0)
        assert(records[5].i2!.intValue == 2)
        assert(records[5].i3!.intValue == 1)
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
    
    required init(_ row: Row) {
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
        super.init(row)
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

