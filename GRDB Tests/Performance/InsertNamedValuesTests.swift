import XCTest
import GRDB
import SQLite

private let insertedRowCount = 10_000

// Here we insert rows, referencing statement arguments by name.
class InsertNamedValuesTests: XCTestCase {
    
    func testSQLite() {
        let databaseFileName = "GRDBPerformanceTests-\(NSProcessInfo.processInfo().globallyUniqueString).sqlite"
        let databasePath = (NSTemporaryDirectory() as NSString).stringByAppendingPathComponent(databaseFileName)
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
            
            var connection: COpaquePointer = nil
            sqlite3_open_v2(databasePath, &connection, 0x00000004 /*SQLITE_OPEN_CREATE*/ | 0x00000002 /*SQLITE_OPEN_READWRITE*/, nil)
            sqlite3_exec(connection, "CREATE TABLE items (i0 INT, i1 INT, i2 INT, i3 INT, i4 INT, i5 INT, i6 INT, i7 INT, i8 INT, i9 INT)", nil, nil, nil)
            
            sqlite3_exec(connection, "BEGIN TRANSACTION", nil, nil, nil)
            
            var statement: COpaquePointer = nil
            sqlite3_prepare_v2(connection, "INSERT INTO items (i0, i1, i2, i3, i4, i5, i6, i7, i8, i9) VALUES (:i0, :i1, :i2, :i3, :i4, :i5, :i6, :i7, :i8, :i9)", -1, &statement, nil)
            
            let index0 = sqlite3_bind_parameter_index(statement, ":i0")
            let index1 = sqlite3_bind_parameter_index(statement, ":i1")
            let index2 = sqlite3_bind_parameter_index(statement, ":i2")
            let index3 = sqlite3_bind_parameter_index(statement, ":i3")
            let index4 = sqlite3_bind_parameter_index(statement, ":i4")
            let index5 = sqlite3_bind_parameter_index(statement, ":i5")
            let index6 = sqlite3_bind_parameter_index(statement, ":i6")
            let index7 = sqlite3_bind_parameter_index(statement, ":i7")
            let index8 = sqlite3_bind_parameter_index(statement, ":i8")
            let index9 = sqlite3_bind_parameter_index(statement, ":i9")
            
            for i in Int64(0)..<Int64(insertedRowCount) {
                sqlite3_reset(statement)
                sqlite3_bind_int64(statement, index0, i)
                sqlite3_bind_int64(statement, index1, i)
                sqlite3_bind_int64(statement, index2, i)
                sqlite3_bind_int64(statement, index3, i)
                sqlite3_bind_int64(statement, index4, i)
                sqlite3_bind_int64(statement, index5, i)
                sqlite3_bind_int64(statement, index6, i)
                sqlite3_bind_int64(statement, index7, i)
                sqlite3_bind_int64(statement, index8, i)
                sqlite3_bind_int64(statement, index9, i)
                sqlite3_step(statement)
            }
            
            sqlite3_finalize(statement)
            sqlite3_exec(connection, "COMMIT", nil, nil, nil)
            sqlite3_close(connection)
        }
    }
    
    func testFMDB() {
        let databaseFileName = "GRDBPerformanceTests-\(NSProcessInfo.processInfo().globallyUniqueString).sqlite"
        let databasePath = (NSTemporaryDirectory() as NSString).stringByAppendingPathComponent(databaseFileName)
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
            
            let dbQueue = FMDatabaseQueue(path: databasePath)
            dbQueue.inDatabase { db in
                db.executeStatements("CREATE TABLE items (i0 INT, i1 INT, i2 INT, i3 INT, i4 INT, i5 INT, i6 INT, i7 INT, i8 INT, i9 INT)")
            }
            
            dbQueue.inTransaction { (db, rollback) -> Void in
                for i in 0..<insertedRowCount {
                    db.executeUpdate("INSERT INTO items (i0, i1, i2, i3, i4, i5, i6, i7, i8, i9) VALUES (:i0, :i1, :i2, :i3, :i4, :i5, :i6, :i7, :i8, :i9)", withParameterDictionary: ["i0": i, "i1": i, "i2": i, "i3": i, "i4": i, "i5": i, "i6": i, "i7": i, "i8": i, "i9": i])
                }
            }
        }
    }
    
    func testGRDB() {
        let databaseFileName = "GRDBPerformanceTests-\(NSProcessInfo.processInfo().globallyUniqueString).sqlite"
        let databasePath = (NSTemporaryDirectory() as NSString).stringByAppendingPathComponent(databaseFileName)
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
                let statement = try! db.updateStatement("INSERT INTO items (i0, i1, i2, i3, i4, i5, i6, i7, i8, i9) VALUES (:i0, :i1, :i2, :i3, :i4, :i5, :i6, :i7, :i8, :i9)")
                for i in 0..<insertedRowCount {
                    try statement.execute(arguments: ["i0": i, "i1": i, "i2": i, "i3": i, "i4": i, "i5": i, "i6": i, "i7": i, "i8": i, "i9": i])
                }
                return .Commit
            }
        }
    }
    
    func testSQLiteSwift() {
        let databaseFileName = "GRDBPerformanceTests-\(NSProcessInfo.processInfo().globallyUniqueString).sqlite"
        let databasePath = (NSTemporaryDirectory() as NSString).stringByAppendingPathComponent(databaseFileName)
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
