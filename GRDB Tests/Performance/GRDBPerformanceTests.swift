import XCTest
import GRDB

class GRDBPerformanceTests: XCTestCase {
    
    // This is not a test, but a function which generates the FetchPerformanceTests.sqlite resource.
    func populateDatabase() {
        let databasePath = "/tmp/FetchPerformanceTests.sqlite"
        do {
            let dbQueue = try! DatabaseQueue(path: databasePath)
            try! dbQueue.inTransaction { db in
                try db.execute("CREATE TABLE items (i0 INT, i1 INT, i2 INT, i3 INT, i4 INT, i5 INT, i6 INT, i7 INT, i8 INT, i9 INT)")
                for i in 0..<100_000 {
                    try db.execute("INSERT INTO items (i0, i1, i2, i3, i4, i5, i6, i7, i8, i9) VALUES (?,?,?,?,?,?,?,?,?,?)", arguments: [i%1, i%2, i%3, i%4, i%5, i%6, i%7, i%8, i%9, i%10])
                }
                return .Commit
            }
        }
    }
    
    func testValueAtIndexPerformance() {
        // Here we test the extraction of values by column index.
        
        let databasePath = NSBundle(forClass: self.dynamicType).pathForResource("FetchPerformanceTests", ofType: "sqlite")!
        let dbQueue = try! DatabaseQueue(path: databasePath)
        
        self.measureBlock {
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
        // Here we test the extraction of values by column name.
        
        let databasePath = NSBundle(forClass: self.dynamicType).pathForResource("FetchPerformanceTests", ofType: "sqlite")!
        let dbQueue = try! DatabaseQueue(path: databasePath)
        
        self.measureBlock {
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
        // Here we test that we can load "records".
        //
        // Two constraints:
        //
        // 1. Records MUST be initialized from a row, or a row-like object like
        //    a dictionary: rows MUST be introspectable by column name, so that
        //    the record can pick the columns it wants.
        //
        // 2. Fetched records MUST be flagged as having no change.
        
        let databasePath = NSBundle(forClass: self.dynamicType).pathForResource("FetchPerformanceTests", ofType: "sqlite")!
        let dbQueue = try! DatabaseQueue(path: databasePath)
        
        self.measureBlock {
            let records = dbQueue.inDatabase { db in
                PerformanceRecord.fetchAll(db, "SELECT * FROM items")
            }
            XCTAssertEqual(records[4].i2, 1)
            XCTAssertEqual(records[4].i3, 0)
            XCTAssertEqual(records[5].i2, 2)
            XCTAssertEqual(records[5].i3, 1)
        }
    }
}
