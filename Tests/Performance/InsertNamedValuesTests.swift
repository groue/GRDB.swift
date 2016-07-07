import XCTest
import GRDB
import SQLite

private let insertedRowCount = 20_000

// Here we insert rows, referencing statement arguments by name.
class InsertNamedValuesTests: XCTestCase {
    
    func testFMDB() {
        let databaseFileName = "GRDBPerformanceTests-\(NSProcessInfo.processInfo.globallyUniqueString).sqlite"
        let databasePath = (NSTemporaryDirectory() as NSString).appendingPathComponent(databaseFileName)
        defer {
            let dbQueue = try! DatabaseQueue(path: databasePath)
            dbQueue.inDatabase { db in
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM items")!, insertedRowCount)
                XCTAssertEqual(Int.fetchOne(db, "SELECT MIN(i0) FROM items")!, 0)
                XCTAssertEqual(Int.fetchOne(db, "SELECT MAX(i9) FROM items")!, insertedRowCount - 1)
            }
            try! FileManager.default.removeItem(atPath: databasePath)
        }
        
        measureBlock {
            _ = try? FileManager.default.removeItem(atPath: databasePath)
            
            let dbQueue = FMDatabaseQueue(path: databasePath)
            dbQueue.inDatabase { db in
                db.executeStatements("CREATE TABLE items (i0 INT, i1 INT, i2 INT, i3 INT, i4 INT, i5 INT, i6 INT, i7 INT, i8 INT, i9 INT)")
            }
            
            dbQueue.inTransaction { (db, rollback) -> Void in
                db.setShouldCacheStatements(true)
                for i in 0..<insertedRowCount {
                    db.executeUpdate("INSERT INTO items (i0, i1, i2, i3, i4, i5, i6, i7, i8, i9) VALUES (:i0, :i1, :i2, :i3, :i4, :i5, :i6, :i7, :i8, :i9)", withParameterDictionary: ["i0": i, "i1": i, "i2": i, "i3": i, "i4": i, "i5": i, "i6": i, "i7": i, "i8": i, "i9": i])
                }
            }
        }
    }
    
    func testGRDB() {
        let databaseFileName = "GRDBPerformanceTests-\(NSProcessInfo.processInfo.globallyUniqueString).sqlite"
        let databasePath = (NSTemporaryDirectory() as NSString).appendingPathComponent(databaseFileName)
        defer {
            let dbQueue = try! DatabaseQueue(path: databasePath)
            dbQueue.inDatabase { db in
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM items")!, insertedRowCount)
                XCTAssertEqual(Int.fetchOne(db, "SELECT MIN(i0) FROM items")!, 0)
                XCTAssertEqual(Int.fetchOne(db, "SELECT MAX(i9) FROM items")!, insertedRowCount - 1)
            }
            try! FileManager.default.removeItem(atPath: databasePath)
        }
        
        measureBlock {
            _ = try? FileManager.default.removeItem(atPath: databasePath)
            
            let dbQueue = try! DatabaseQueue(path: databasePath)
            try! dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE items (i0 INT, i1 INT, i2 INT, i3 INT, i4 INT, i5 INT, i6 INT, i7 INT, i8 INT, i9 INT)")
            }
            
            try! dbQueue.inTransaction { db in
                let statement = try! db.makeUpdateStatement("INSERT INTO items (i0, i1, i2, i3, i4, i5, i6, i7, i8, i9) VALUES (:i0, :i1, :i2, :i3, :i4, :i5, :i6, :i7, :i8, :i9)")
                for i in 0..<insertedRowCount {
                    try statement.execute(arguments: ["i0": i, "i1": i, "i2": i, "i3": i, "i4": i, "i5": i, "i6": i, "i7": i, "i8": i, "i9": i])
                }
                return .commit
            }
        }
    }
    
    func testSQLiteSwift() {
        let databaseFileName = "GRDBPerformanceTests-\(NSProcessInfo.processInfo.globallyUniqueString).sqlite"
        let databasePath = (NSTemporaryDirectory() as NSString).appendingPathComponent(databaseFileName)
        defer {
            let dbQueue = try! DatabaseQueue(path: databasePath)
            dbQueue.inDatabase { db in
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM items")!, insertedRowCount)
                XCTAssertEqual(Int.fetchOne(db, "SELECT MIN(i0) FROM items")!, 0)
                XCTAssertEqual(Int.fetchOne(db, "SELECT MAX(i9) FROM items")!, insertedRowCount - 1)
            }
            try! FileManager.default.removeItem(atPath: databasePath)
        }
        
        measureBlock {
            _ = try? FileManager.default.removeItem(atPath: databasePath)
            
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
            
            try! db.transaction {
                for i in 0..<insertedRowCount {
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
