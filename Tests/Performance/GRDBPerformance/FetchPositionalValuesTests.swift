import XCTest
import GRDB
#if GRDBCIPHER
import SQLCipher
#else
import SQLite3
#endif
#if GRDB_COMPARE
import SQLite
#endif

private let expectedRowCount = 200_000

/// Here we test the extraction of row values by column index.
class FetchPositionalValuesTests: XCTestCase {
    
    func testSQLite() throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("GRDBPerformanceTests.sqlite")
        try generateSQLiteDatabaseIfMissing(at: url, insertedRowCount: expectedRowCount)
        var connection: OpaquePointer? = nil
        sqlite3_open_v2(url.path, &connection, 0x00000004 /*SQLITE_OPEN_CREATE*/ | 0x00000002 /*SQLITE_OPEN_READWRITE*/, nil)
        
        let options = XCTMeasureOptions()
        options.iterationCount = 50
        measure(options: options) {
            var count = 0
            var statement: OpaquePointer? = nil
            sqlite3_prepare_v2(connection, "SELECT * FROM item", -1, &statement, nil)
            
            loop: while true {
                switch sqlite3_step(statement) {
                case 101 /*SQLITE_DONE*/:
                    break loop
                case 100 /*SQLITE_ROW*/:
                    _ = sqlite3_column_int64(statement, 0)
                    _ = sqlite3_column_int64(statement, 1)
                    _ = sqlite3_column_int64(statement, 2)
                    _ = sqlite3_column_int64(statement, 3)
                    _ = sqlite3_column_int64(statement, 4)
                    _ = sqlite3_column_int64(statement, 5)
                    _ = sqlite3_column_int64(statement, 6)
                    _ = sqlite3_column_int64(statement, 7)
                    _ = sqlite3_column_int64(statement, 8)
                    _ = sqlite3_column_int64(statement, 9)
                    break
                default:
                    XCTFail()
                }
                
                count += 1
            }
            
            sqlite3_finalize(statement)
            
            XCTAssertEqual(count, expectedRowCount)
        }
        
        sqlite3_close(connection)
    }
    
    func testGRDB() throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("GRDBPerformanceTests.sqlite")
        try generateSQLiteDatabaseIfMissing(at: url, insertedRowCount: expectedRowCount)
        let dbQueue = try DatabaseQueue(path: url.path)
        
        let options = XCTMeasureOptions()
        options.iterationCount = 50
        measure(options: options) {
            var count = 0
            
            try! dbQueue.inDatabase { db in
                let rows = try Row.fetchCursor(db, sql: "SELECT * FROM item")
                while let row = try rows.next() {
                    _ = row[0] as Int
                    _ = row[1] as Int
                    _ = row[2] as Int
                    _ = row[3] as Int
                    _ = row[4] as Int
                    _ = row[5] as Int
                    _ = row[6] as Int
                    _ = row[7] as Int
                    _ = row[8] as Int
                    _ = row[9] as Int
                    
                    count += 1
                }
            }
            
            XCTAssertEqual(count, expectedRowCount)
        }
    }
    
    #if GRDB_COMPARE
    func testFMDB() throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("GRDBPerformanceTests.sqlite")
        try generateSQLiteDatabaseIfMissing(at: url, insertedRowCount: expectedRowCount)
        let dbQueue = FMDatabaseQueue(path: url.path)!
        
        measure {
            var count = 0
            
            dbQueue.inDatabase { db in
                let rs = try! db.executeQuery("SELECT * FROM item", values: nil)
                while rs.next() {
                    _ = rs.long(forColumnIndex: 0)
                    _ = rs.long(forColumnIndex: 1)
                    _ = rs.long(forColumnIndex: 2)
                    _ = rs.long(forColumnIndex: 3)
                    _ = rs.long(forColumnIndex: 4)
                    _ = rs.long(forColumnIndex: 5)
                    _ = rs.long(forColumnIndex: 6)
                    _ = rs.long(forColumnIndex: 7)
                    _ = rs.long(forColumnIndex: 8)
                    _ = rs.long(forColumnIndex: 9)
                    
                    count += 1
                }
            }
            
            XCTAssertEqual(count, expectedRowCount)
        }
    }
    
    func testSQLiteSwift() throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("GRDBPerformanceTests.sqlite")
        try generateSQLiteDatabaseIfMissing(at: url, insertedRowCount: expectedRowCount)
        let db = try Connection(url.path)
        
        measure {
            var count = 0
            
            for row in try! db.prepare("SELECT * FROM item") {
                // Direct Int extraction is not supported.
                _ = Int(row[0] as! Int64)
                _ = Int(row[1] as! Int64)
                _ = Int(row[2] as! Int64)
                _ = Int(row[3] as! Int64)
                _ = Int(row[4] as! Int64)
                _ = Int(row[5] as! Int64)
                _ = Int(row[6] as! Int64)
                _ = Int(row[7] as! Int64)
                _ = Int(row[8] as! Int64)
                _ = Int(row[9] as! Int64)
                
                count += 1
            }
            
            XCTAssertEqual(count, expectedRowCount)
        }
    }
    #endif
}
