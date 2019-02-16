import XCTest
import GRDB

private let insertedRowCount = 20_000

// Here we insert records.
class InsertRecordCodableTests: XCTestCase {
    
    func testGRDB() {
        let databaseFileName = "GRDBPerformanceTests-\(ProcessInfo.processInfo.globallyUniqueString).sqlite"
        let databasePath = (NSTemporaryDirectory() as NSString).appendingPathComponent(databaseFileName)
        _ = try? FileManager.default.removeItem(atPath: databasePath)
        defer {
            let dbQueue = try! DatabaseQueue(path: databasePath)
            try! dbQueue.inDatabase { db in
                XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM items")!, insertedRowCount)
                XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT MIN(i0) FROM items")!, 0)
                XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT MAX(i9) FROM items")!, insertedRowCount - 1)
            }
            try! FileManager.default.removeItem(atPath: databasePath)
        }
        
        measure {
            _ = try? FileManager.default.removeItem(atPath: databasePath)
            
            let dbQueue = try! DatabaseQueue(path: databasePath)
            try! dbQueue.inDatabase { db in
                try db.execute(sql: "CREATE TABLE items (i0 INT, i1 INT, i2 INT, i3 INT, i4 INT, i5 INT, i6 INT, i7 INT, i8 INT, i9 INT)")
            }
            
            try! dbQueue.inTransaction { db in
                for i in 0..<insertedRowCount {
                    try ItemCodable(i0: i, i1: i, i2: i, i3: i, i4: i, i5: i, i6: i, i7: i, i8: i, i9: i).insert(db)
                }
                return .commit
            }
        }
    }
}
