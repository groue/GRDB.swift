import XCTest
import GRDB

private let insertedRowCount = 20_000

// Here we insert records.
class InsertRecordTests: XCTestCase {
    
    func testGRDB() {
        let databaseFileName = "GRDBPerformanceTests-\(NSProcessInfo.processInfo().globallyUniqueString).sqlite"
        let databasePath = (NSTemporaryDirectory() as NSString).stringByAppendingPathComponent(databaseFileName)
        let _ = try? NSFileManager.defaultManager().removeItemAtPath(databasePath)
        defer {
            let dbQueue = try! DatabaseQueue(path: databasePath)
            dbQueue.inDatabase { db in
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM items")!, insertedRowCount)
                XCTAssertEqual(Int.fetchOne(db, "SELECT MIN(i0) FROM items")!, 0)
                XCTAssertEqual(Int.fetchOne(db, "SELECT MAX(i9) FROM items")!, insertedRowCount - 1)
            }
            try! NSFileManager.defaultManager().removeItemAtPath(databasePath)
        }
        
        measureBlock {
            let _ = try? NSFileManager.defaultManager().removeItemAtPath(databasePath)
            
            let dbQueue = try! DatabaseQueue(path: databasePath)
            try! dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE items (i0 INT, i1 INT, i2 INT, i3 INT, i4 INT, i5 INT, i6 INT, i7 INT, i8 INT, i9 INT)")
            }
            
            try! dbQueue.inTransaction { db in
                for i in 0..<insertedRowCount {
                    try Item(i0: i, i1: i, i2: i, i3: i, i4: i, i5: i, i6: i, i7: i, i8: i, i9: i).insert(db)
                }
                return .Commit
            }
        }
    }
    
}
