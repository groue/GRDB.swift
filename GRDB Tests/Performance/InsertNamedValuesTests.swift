import XCTest
import GRDB
import SQLite

// Here we insert rows, referencing statement arguments by name.
class InsertNamedValuesTests: XCTestCase {
    
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
                    db.executeUpdate("INSERT INTO items (i0, i1, i2, i3, i4, i5, i6, i7, i8, i9) VALUES (:i0, :i1, :i2, :i3, :i4, :i5, :i6, :i7, :i8, :i9)", withParameterDictionary: ["i0": i, "i1": i, "i2": i, "i3": i, "i4": i, "i5": i, "i6": i, "i7": i, "i8": i, "i9": i])
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
                    try db.execute("INSERT INTO items (i0, i1, i2, i3, i4, i5, i6, i7, i8, i9) VALUES (:i0, :i1, :i2, :i3, :i4, :i5, :i6, :i7, :i8, :i9)", arguments: ["i0": i, "i1": i, "i2": i, "i3": i, "i4": i, "i5": i, "i6": i, "i7": i, "i8": i, "i9": i])
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
                    try db.run(itemsTable.insert(
                        i0Column <- i,
                        i1Column <- i,
                        i2Column <- i,
                        i3Column <- i,
                        i4Column <- i,
                        i5Column <- i,
                        i6Column <- i,
                        i7Column <- i,
                        i8Column <- i,
                        i9Column <- i))
                }
            }
        }
    }
    
}
