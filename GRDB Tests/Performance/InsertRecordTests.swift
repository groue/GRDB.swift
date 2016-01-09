import XCTest
import GRDB

// Here we insert records.
class InsertRecordTests: XCTestCase {
    
    func testInsertRecordPerformance() {
        let databaseFileName = "GRDBPerformanceTests-\(NSProcessInfo.processInfo().globallyUniqueString).sqlite"
        let databasePath = (NSTemporaryDirectory() as NSString).stringByAppendingPathComponent(databaseFileName)
        let _ = try? NSFileManager.defaultManager().removeItemAtPath(databasePath)
        defer { try! NSFileManager.defaultManager().removeItemAtPath(databasePath) }
        let dbQueue = try! DatabaseQueue(path: databasePath)
        try! dbQueue.inDatabase { db in
            try db.execute("CREATE TABLE items (i0 INT, i1 INT, i2 INT, i3 INT, i4 INT, i5 INT, i6 INT, i7 INT, i8 INT, i9 INT)")
        }
        
        measureBlock {
            try! dbQueue.inTransaction { db in
                for i in 0..<10_000 {
                    let record = Item(i0: i, i1: i, i2: i, i3: i, i4: i, i5: i, i6: i, i7: i, i8: i, i9: i)
                    try record.insert(db)
                }
                return .Commit
            }
        }
    }
    
}
