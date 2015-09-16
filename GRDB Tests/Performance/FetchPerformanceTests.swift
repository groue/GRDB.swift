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
    
    func testMetalFetchPerformance() {
        let databasePath = NSBundle(forClass: self.dynamicType).pathForResource("FetchPerformanceTests", ofType: "sqlite")!
        let dbQueue = try! DatabaseQueue(path: databasePath)
        
        var sum: Int64 = 0
        self.measureBlock {
            dbQueue.inDatabase { db in
                for row in MetalRow.fetch(db, "SELECT * FROM items") {
                    let i0 = row.int64(atIndex: 0)
                    let i1 = row.int64(atIndex: 1)
                    let i2 = row.int64(atIndex: 2)
                    let i3 = row.int64(atIndex: 3)
                    let i4 = row.int64(atIndex: 4)
                    sum += i0 + i1 + i2 + i3 + i4
                }
            }
        }
        XCTAssertEqual(sum, 4999990)
    }
    
    func testRegularFetchPerformance() {
        let databasePath = NSBundle(forClass: self.dynamicType).pathForResource("FetchPerformanceTests", ofType: "sqlite")!
        let dbQueue = try! DatabaseQueue(path: databasePath)
        
        var sum: Int64 = 0
        self.measureBlock {
            dbQueue.inDatabase { db in
                for row in Row.fetch(db, "SELECT * FROM items") {
                    let i0: Int64 = row.value(atIndex: 0)!
                    let i1: Int64 = row.value(atIndex: 1)!
                    let i2: Int64 = row.value(atIndex: 2)!
                    let i3: Int64 = row.value(atIndex: 3)!
                    let i4: Int64 = row.value(atIndex: 4)!
                    sum += i0 + i1 + i2 + i3 + i4
                }
            }
        }
        XCTAssertEqual(sum, 4999990)
    }
    
    func testFMDBFetchPerformance() {
        let databasePath = NSBundle(forClass: self.dynamicType).pathForResource("FetchPerformanceTests", ofType: "sqlite")!
        let dbQueue = FMDatabaseQueue(path: databasePath)
        
        var sum: Int64 = 0
        self.measureBlock {
            dbQueue.inDatabase { db in
                if let rs = db.executeQuery("SELECT * FROM items", withArgumentsInArray: nil) {
                    while rs.next() {
                        let i0 = rs.longLongIntForColumnIndex(0)
                        let i1 = rs.longLongIntForColumnIndex(1)
                        let i2 = rs.longLongIntForColumnIndex(2)
                        let i3 = rs.longLongIntForColumnIndex(3)
                        let i4 = rs.longLongIntForColumnIndex(4)
                        sum += i0 + i1 + i2 + i3 + i4
                    }
                }
            }
        }
        XCTAssertEqual(sum, 4999990)
    }
}
