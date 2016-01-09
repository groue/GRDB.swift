import XCTest
import GRDB
import SQLite

// Here we insert rows, referencing statement arguments by index.
class InsertPositionalValuesTests: XCTestCase {
    
    func testFMDB() {
        let databaseFileName = "GRDBPerformanceTests-\(NSProcessInfo.processInfo().globallyUniqueString).sqlite"
        let databasePath = (NSTemporaryDirectory() as NSString).stringByAppendingPathComponent(databaseFileName)
        let _ = try? NSFileManager.defaultManager().removeItemAtPath(databasePath)
        defer { try! NSFileManager.defaultManager().removeItemAtPath(databasePath) }
        let dbQueue = FMDatabaseQueue(path: databasePath)
        dbQueue.inDatabase { db in
            db.executeStatements("CREATE TABLE items (i0 INT, i1 INT, i2 INT, i3 INT, i4 INT, i5 INT, i6 INT, i7 INT, i8 INT, i9 INT)")
        }
        
        measureBlock {
            dbQueue.inTransaction { (db, rollback) -> Void in
                for i in 0..<10_000 {
                    db.executeUpdate("INSERT INTO items (i0, i1, i2, i3, i4, i5, i6, i7, i8, i9) VALUES (?,?,?,?,?,?,?,?,?,?)", withArgumentsInArray: [i, i, i, i, i, i, i, i, i, i])
                }
            }
        }
    }
    
    func testGRDB() {
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
                    try db.execute("INSERT INTO items (i0, i1, i2, i3, i4, i5, i6, i7, i8, i9) VALUES (?,?,?,?,?,?,?,?,?,?)", arguments: [i, i, i, i, i, i, i, i, i, i])
                }
                return .Commit
            }
        }
    }
    
    func testSQLiteSwift() {
        let databaseFileName = "GRDBPerformanceTests-\(NSProcessInfo.processInfo().globallyUniqueString).sqlite"
        let databasePath = (NSTemporaryDirectory() as NSString).stringByAppendingPathComponent(databaseFileName)
        let _ = try? NSFileManager.defaultManager().removeItemAtPath(databasePath)
        defer { try! NSFileManager.defaultManager().removeItemAtPath(databasePath) }
        let db = try! Connection(databasePath)
        try! db.run(itemsTable.create { t in
            t.column(i0Column)
            t.column(i1Column)
            t.column(i2Column)
            t.column(i3Column)
            t.column(i4Column)
            t.column(i5Column)
            t.column(i6Column)
            t.column(i7Column)
            t.column(i8Column)
            t.column(i9Column)
            })
        
        measureBlock {
            try! db.transaction {
                for i in 0..<10_000 {
                    let stmt = db.prepare("INSERT INTO items (i0, i1, i2, i3, i4, i5, i6, i7, i8, i9) VALUES (?,?,?,?,?,?,?,?,?,?)")
                    try stmt.run(i, i, i, i, i, i, i, i, i, i)
                }
            }
        }
    }
    
}
