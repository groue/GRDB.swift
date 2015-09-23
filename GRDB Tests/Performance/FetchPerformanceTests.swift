import XCTest
import GRDB

class PerformanceItem : Record {
    var i0: Int64?
    var i1: Int64?
    var i2: Int64?
    var i3: Int64?
    var i4: Int64?
    var i5: Int64?
    var i6: Int64?
    var i7: Int64?
    var i8: Int64?
    var i9: Int64?
    
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

class FetchPerformanceTests: XCTestCase {
    // This is not a test, but a function which generates the FetchPerformanceTests.sqlite resource.
//    func testPopulateDatabase() {
//        let databasePath = "/tmp/FetchPerformanceTests.sqlite"
//        do {
//            let dbQueue = try! DatabaseQueue(path: databasePath)
//            try! dbQueue.inTransaction { db in
//                try db.execute("CREATE TABLE items (i0 INT, i1 INT, i2 INT, i3 INT, i4 INT, i5 INT, i6 INT, i7 INT, i8 INT, i9 INT)")
//                for i in 0..<100_000 {
//                    try db.execute("INSERT INTO items (i0, i1, i2, i3, i4, i5, i6, i7, i8, i9) VALUES (?,?,?,?,?,?,?,?,?,?)", arguments: [i%1, i%2, i%3, i%4, i%5, i%7, i%8, i%9, i%10])
//                }
//                return .Commit
//            }
//        }
//        
//    }
    
    
    // MARK: - Value at index
    
    func testGRDBValueAtIndexPerformance() {
        let databasePath = NSBundle(forClass: self.dynamicType).pathForResource("FetchPerformanceTests", ofType: "sqlite")!
        let dbQueue = try! DatabaseQueue(path: databasePath)
        
        self.measureBlock {
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
    
    func testFMDBValueAtIndexPerformance() {
        let databasePath = NSBundle(forClass: self.dynamicType).pathForResource("FetchPerformanceTests", ofType: "sqlite")!
        let dbQueue = FMDatabaseQueue(path: databasePath)
        
        self.measureBlock {
            dbQueue.inDatabase { db in
                if let rs = db.executeQuery("SELECT * FROM items", withArgumentsInArray: nil) {
                    while rs.next() {
                        let _ = rs.longLongIntForColumnIndex(0)
                        let _ = rs.longLongIntForColumnIndex(1)
                        let _ = rs.longLongIntForColumnIndex(2)
                        let _ = rs.longLongIntForColumnIndex(3)
                        let _ = rs.longLongIntForColumnIndex(4)
                        let _ = rs.longLongIntForColumnIndex(5)
                        let _ = rs.longLongIntForColumnIndex(6)
                        let _ = rs.longLongIntForColumnIndex(7)
                        let _ = rs.longLongIntForColumnIndex(8)
                        let _ = rs.longLongIntForColumnIndex(9)
                    }
                }
            }
        }
    }
    
    
    // MARK: - Value named
    
    func testGRDBValueNamedPerformance() {
        let databasePath = NSBundle(forClass: self.dynamicType).pathForResource("FetchPerformanceTests", ofType: "sqlite")!
        let dbQueue = try! DatabaseQueue(path: databasePath)
        
        self.measureBlock {
            dbQueue.inDatabase { db in
                for row in Row.fetch(db, "SELECT * FROM items") {
                    let _: Int64 = row.value(named: "i0")
                    let _: Int64 = row.value(named: "i1")
                    let _: Int64 = row.value(named: "i2")
                    let _: Int64 = row.value(named: "i3")
                    let _: Int64 = row.value(named: "i4")
                    let _: Int64 = row.value(named: "i5")
                    let _: Int64 = row.value(named: "i6")
                    let _: Int64 = row.value(named: "i7")
                    let _: Int64 = row.value(named: "i8")
                    let _: Int64 = row.value(named: "i9")
                }
            }
        }
    }
    
    func testFMDBValueNamedPerformance() {
        let databasePath = NSBundle(forClass: self.dynamicType).pathForResource("FetchPerformanceTests", ofType: "sqlite")!
        let dbQueue = FMDatabaseQueue(path: databasePath)
        
        self.measureBlock {
            dbQueue.inDatabase { db in
                if let rs = db.executeQuery("SELECT * FROM items", withArgumentsInArray: nil) {
                    while rs.next() {
                        let _ = rs.longLongIntForColumn("i0")
                        let _ = rs.longLongIntForColumn("i1")
                        let _ = rs.longLongIntForColumn("i2")
                        let _ = rs.longLongIntForColumn("i3")
                        let _ = rs.longLongIntForColumn("i4")
                        let _ = rs.longLongIntForColumn("i5")
                        let _ = rs.longLongIntForColumn("i6")
                        let _ = rs.longLongIntForColumn("i7")
                        let _ = rs.longLongIntForColumn("i8")
                        let _ = rs.longLongIntForColumn("i9")
                    }
                }
            }
        }
    }
    
    
    // MARK: - Records
    
    func testGRDBRecordPerformance() {
        let databasePath = NSBundle(forClass: self.dynamicType).pathForResource("FetchPerformanceTests", ofType: "sqlite")!
        let dbQueue = try! DatabaseQueue(path: databasePath)
        
        self.measureBlock {
            let items = dbQueue.inDatabase { db in
                PerformanceItem.fetchAll(db, "SELECT * FROM items")
            }
            XCTAssertEqual(items[4].i2, 1)
            XCTAssertEqual(items[4].i3, 0)
            XCTAssertEqual(items[5].i2, 2)
            XCTAssertEqual(items[5].i3, 1)
        }
    }
    
    func testFMDBRecordPerformance() {
        let databasePath = NSBundle(forClass: self.dynamicType).pathForResource("FetchPerformanceTests", ofType: "sqlite")!
        let dbQueue = FMDatabaseQueue(path: databasePath)
        
        self.measureBlock {
            var items = [PerformanceItem]()
            dbQueue.inDatabase { db in
                if let rs = db.executeQuery("SELECT * FROM items", withArgumentsInArray: nil) {
                    while rs.next() {
                        let item = PerformanceItem()
                        item.i0 = rs.longLongIntForColumn("i0")
                        item.i1 = rs.longLongIntForColumn("i1")
                        item.i2 = rs.longLongIntForColumn("i2")
                        item.i3 = rs.longLongIntForColumn("i3")
                        item.i4 = rs.longLongIntForColumn("i4")
                        item.i5 = rs.longLongIntForColumn("i5")
                        item.i6 = rs.longLongIntForColumn("i6")
                        item.i7 = rs.longLongIntForColumn("i7")
                        item.i8 = rs.longLongIntForColumn("i8")
                        item.i9 = rs.longLongIntForColumn("i9")
                        item.databaseEdited = false
                        items.append(item)
                    }
                }
            }
            XCTAssertEqual(items[4].i2, 1)
            XCTAssertEqual(items[4].i3, 0)
            XCTAssertEqual(items[5].i2, 2)
            XCTAssertEqual(items[5].i3, 1)
        }
    }
}
