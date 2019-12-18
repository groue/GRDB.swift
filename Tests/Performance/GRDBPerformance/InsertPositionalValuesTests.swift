import XCTest
import SQLite3
import GRDB
#if GRDB_COMPARE
import SQLite
#endif

private let insertedRowCount = 20_000

// Here we insert rows, referencing statement arguments by index.
class InsertPositionalValuesTests: XCTestCase {
    
    func testSQLite() {
        let databaseFileName = "GRDBPerformanceTests-\(ProcessInfo.processInfo.globallyUniqueString).sqlite"
        let databasePath = (NSTemporaryDirectory() as NSString).appendingPathComponent(databaseFileName)
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
            
            var connection: OpaquePointer? = nil
            sqlite3_open_v2(databasePath, &connection, 0x00000004 /*SQLITE_OPEN_CREATE*/ | 0x00000002 /*SQLITE_OPEN_READWRITE*/, nil)
            sqlite3_exec(connection, "CREATE TABLE items (i0 INT, i1 INT, i2 INT, i3 INT, i4 INT, i5 INT, i6 INT, i7 INT, i8 INT, i9 INT)", nil, nil, nil)
            
            sqlite3_exec(connection, "BEGIN TRANSACTION", nil, nil, nil)
            
            var statement: OpaquePointer? = nil
            sqlite3_prepare_v2(connection, "INSERT INTO items (i0, i1, i2, i3, i4, i5, i6, i7, i8, i9) VALUES (?,?,?,?,?,?,?,?,?,?)", -1, &statement, nil)
            
            for i in Int64(0)..<Int64(insertedRowCount) {
                sqlite3_reset(statement)
                sqlite3_bind_int64(statement, 1, i)
                sqlite3_bind_int64(statement, 2, i)
                sqlite3_bind_int64(statement, 3, i)
                sqlite3_bind_int64(statement, 4, i)
                sqlite3_bind_int64(statement, 5, i)
                sqlite3_bind_int64(statement, 6, i)
                sqlite3_bind_int64(statement, 7, i)
                sqlite3_bind_int64(statement, 8, i)
                sqlite3_bind_int64(statement, 9, i)
                sqlite3_bind_int64(statement, 10, i)
                sqlite3_step(statement)
            }
            
            sqlite3_finalize(statement)
            sqlite3_exec(connection, "COMMIT", nil, nil, nil)
            sqlite3_close(connection)
        }
    }
    
    func testGRDB() {
        let databaseFileName = "GRDBPerformanceTests-\(ProcessInfo.processInfo.globallyUniqueString).sqlite"
        let databasePath = (NSTemporaryDirectory() as NSString).appendingPathComponent(databaseFileName)
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
                let statement = try! db.makeUpdateStatement(sql: "INSERT INTO items (i0, i1, i2, i3, i4, i5, i6, i7, i8, i9) VALUES (?,?,?,?,?,?,?,?,?,?)")
                for i in 0..<insertedRowCount {
                    try statement.execute(arguments: [i, i, i, i, i, i, i, i, i, i])
                }
                return .commit
            }
        }
    }
    
    #if GRDB_COMPARE
    func testFMDB() {
        let databaseFileName = "GRDBPerformanceTests-\(ProcessInfo.processInfo.globallyUniqueString).sqlite"
        let databasePath = (NSTemporaryDirectory() as NSString).appendingPathComponent(databaseFileName)
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
            
            let dbQueue = FMDatabaseQueue(path: databasePath)!
            dbQueue.inDatabase { db in
                db.executeStatements("CREATE TABLE items (i0 INT, i1 INT, i2 INT, i3 INT, i4 INT, i5 INT, i6 INT, i7 INT, i8 INT, i9 INT)")
            }
            
            dbQueue.inTransaction { (db, rollback) -> Void in
                db.shouldCacheStatements = true
                for i in 0..<insertedRowCount {
                    db.executeUpdate("INSERT INTO items (i0, i1, i2, i3, i4, i5, i6, i7, i8, i9) VALUES (?,?,?,?,?,?,?,?,?,?)", withArgumentsIn: [i, i, i, i, i, i, i, i, i, i])
                }
            }
        }
    }
    
    func testSQLiteSwift() {
        let databaseFileName = "GRDBPerformanceTests-\(ProcessInfo.processInfo.globallyUniqueString).sqlite"
        let databasePath = (NSTemporaryDirectory() as NSString).appendingPathComponent(databaseFileName)
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
                let stmt = try! db.prepare("INSERT INTO items (i0, i1, i2, i3, i4, i5, i6, i7, i8, i9) VALUES (?,?,?,?,?,?,?,?,?,?)")
                for i in 0..<insertedRowCount {
                    try stmt.run(i, i, i, i, i, i, i, i, i, i)
                }
            }
        }
    }
    #endif
}
