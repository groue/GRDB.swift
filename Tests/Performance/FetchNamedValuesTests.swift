import XCTest
import GRDB
#if GRDB_COMPARE
import SQLite
#endif

private let expectedRowCount = 100_000

/// Here we test the extraction of values by column name.
class FetchNamedValuesTests: XCTestCase {
    
    func testGRDB() throws {
        let databasePath = Bundle(for: type(of: self)).path(forResource: "PerformanceTests", ofType: "sqlite")!
        let dbQueue = try DatabaseQueue(path: databasePath)
        
        measure {
            var count = 0
            
            try! dbQueue.inDatabase { db in
                let rows = try Row.fetchCursor(db, sql: "SELECT * FROM items")
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
    func testFMDB() {
        let databasePath = Bundle(for: type(of: self)).path(forResource: "PerformanceTests", ofType: "sqlite")!
        let dbQueue = FMDatabaseQueue(path: databasePath)!
        
        measure {
            var count = 0
            
            dbQueue.inDatabase { db in
                let rs = try! db.executeQuery("SELECT * FROM items", values: nil)
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
        let databasePath = Bundle(for: type(of: self)).path(forResource: "PerformanceTests", ofType: "sqlite")!
        let db = try Connection(databasePath)
        
        measure {
            var count = 0
            
            for item in try! db.prepare(itemsTable) {
                _ = item[i0Column]
                _ = item[i1Column]
                _ = item[i2Column]
                _ = item[i3Column]
                _ = item[i4Column]
                _ = item[i5Column]
                _ = item[i6Column]
                _ = item[i7Column]
                _ = item[i8Column]
                _ = item[i9Column]
                
                count += 1
            }
            
            XCTAssertEqual(count, expectedRowCount)
        }
    }
    #endif
}
