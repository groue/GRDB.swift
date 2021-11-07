import XCTest
import GRDB
#if GRDB_COMPARE
import SQLite
#endif

private let expectedRowCount = 200_000

/// Here we test the extraction of row values by column name.
class FetchNamedValuesTests: XCTestCase {
    
    func testGRDB() throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("GRDBPerformanceTests.sqlite")
        try generateSQLiteDatabaseIfMissing(at: url, insertedRowCount: expectedRowCount)
        let dbQueue = try DatabaseQueue(path: url.path)
        
        measure {
            var count = 0
            
            try! dbQueue.inDatabase { db in
                let rows = try Row.fetchCursor(db, sql: "SELECT * FROM item")
                while let row = try rows.next() {
                    _ = row["i0"] as Int
                    _ = row["i1"] as Int
                    _ = row["i2"] as Int
                    _ = row["i3"] as Int
                    _ = row["i4"] as Int
                    _ = row["i5"] as Int
                    _ = row["i6"] as Int
                    _ = row["i7"] as Int
                    _ = row["i8"] as Int
                    _ = row["i9"] as Int
                    
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
                    _ = rs.long(forColumn: "i0")
                    _ = rs.long(forColumn: "i1")
                    _ = rs.long(forColumn: "i2")
                    _ = rs.long(forColumn: "i3")
                    _ = rs.long(forColumn: "i4")
                    _ = rs.long(forColumn: "i5")
                    _ = rs.long(forColumn: "i6")
                    _ = rs.long(forColumn: "i7")
                    _ = rs.long(forColumn: "i8")
                    _ = rs.long(forColumn: "i9")
                    
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
            
            for row in try! db.prepare(itemTable) {
                _ = row[i0Column]
                _ = row[i1Column]
                _ = row[i2Column]
                _ = row[i3Column]
                _ = row[i4Column]
                _ = row[i5Column]
                _ = row[i6Column]
                _ = row[i7Column]
                _ = row[i8Column]
                _ = row[i9Column]
                
                count += 1
            }
            
            XCTAssertEqual(count, expectedRowCount)
        }
    }
    #endif
}
