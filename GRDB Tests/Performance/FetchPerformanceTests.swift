import XCTest
import GRDB

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
}
