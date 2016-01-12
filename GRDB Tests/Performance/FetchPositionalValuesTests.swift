import XCTest
import GRDB
import SQLite

private let expectedRowCount = 100_000

/// Here we test the extraction of values by column index.
class FetchPositionalValuesTests: XCTestCase {
    
    func testSQLite() {
        let databasePath = NSBundle(forClass: self.dynamicType).pathForResource("PerformanceTests", ofType: "sqlite")!
        var connection: COpaquePointer = nil
        sqlite3_open_v2(databasePath, &connection, 0x00000004 /*SQLITE_OPEN_CREATE*/ | 0x00000002 /*SQLITE_OPEN_READWRITE*/, nil)
        
        self.measureBlock {
            var count = 0
            var statement: COpaquePointer = nil
            sqlite3_prepare_v2(connection, "SELECT * FROM items", -1, &statement, nil)
            
            loop: while true {
                switch sqlite3_step(statement) {
                case 101 /*SQLITE_DONE*/:
                    break loop
                case 100 /*SQLITE_ROW*/:
                    let _ = sqlite3_column_int64(statement, 0)
                    let _ = sqlite3_column_int64(statement, 1)
                    let _ = sqlite3_column_int64(statement, 2)
                    let _ = sqlite3_column_int64(statement, 3)
                    let _ = sqlite3_column_int64(statement, 4)
                    let _ = sqlite3_column_int64(statement, 5)
                    let _ = sqlite3_column_int64(statement, 6)
                    let _ = sqlite3_column_int64(statement, 7)
                    let _ = sqlite3_column_int64(statement, 8)
                    let _ = sqlite3_column_int64(statement, 9)
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
    
    func testFMDB() {
        let databasePath = NSBundle(forClass: self.dynamicType).pathForResource("PerformanceTests", ofType: "sqlite")!
        let dbQueue = FMDatabaseQueue(path: databasePath)
        
        self.measureBlock {
            var count = 0
            
            dbQueue.inDatabase { db in
                if let rs = db.executeQuery("SELECT * FROM items", withArgumentsInArray: nil) {
                    while rs.next() {
                        let _ = rs.longForColumnIndex(0)
                        let _ = rs.longForColumnIndex(1)
                        let _ = rs.longForColumnIndex(2)
                        let _ = rs.longForColumnIndex(3)
                        let _ = rs.longForColumnIndex(4)
                        let _ = rs.longForColumnIndex(5)
                        let _ = rs.longForColumnIndex(6)
                        let _ = rs.longForColumnIndex(7)
                        let _ = rs.longForColumnIndex(8)
                        let _ = rs.longForColumnIndex(9)
                        
                        count += 1
                    }
                }
            }
            
            XCTAssertEqual(count, expectedRowCount)
        }
    }
    
    func testGRDB() {
        let databasePath = NSBundle(forClass: self.dynamicType).pathForResource("PerformanceTests", ofType: "sqlite")!
        let dbQueue = try! DatabaseQueue(path: databasePath)
        
        measureBlock {
            var count = 0
            
            dbQueue.inDatabase { db in
                for row in Row.fetch(db, "SELECT * FROM items") {
                    let _: Int = row.value(atIndex: 0)
                    let _: Int = row.value(atIndex: 1)
                    let _: Int = row.value(atIndex: 2)
                    let _: Int = row.value(atIndex: 3)
                    let _: Int = row.value(atIndex: 4)
                    let _: Int = row.value(atIndex: 5)
                    let _: Int = row.value(atIndex: 6)
                    let _: Int = row.value(atIndex: 7)
                    let _: Int = row.value(atIndex: 8)
                    let _: Int = row.value(atIndex: 9)
                    
                    count += 1
                }
            }
            
            XCTAssertEqual(count, expectedRowCount)
        }
    }
    
    func testSQLiteSwift() {
        let databasePath = NSBundle(forClass: self.dynamicType).pathForResource("PerformanceTests", ofType: "sqlite")!
        let db = try! Connection(databasePath)
        
        self.measureBlock {
            var count = 0
            
            for row in try! db.prepare("SELECT * FROM items") {
                // Direct Int extraction is not supported.
                let _ = Int(row[0] as! Int64)
                let _ = Int(row[1] as! Int64)
                let _ = Int(row[2] as! Int64)
                let _ = Int(row[3] as! Int64)
                let _ = Int(row[4] as! Int64)
                let _ = Int(row[5] as! Int64)
                let _ = Int(row[6] as! Int64)
                let _ = Int(row[7] as! Int64)
                let _ = Int(row[8] as! Int64)
                let _ = Int(row[9] as! Int64)
                
                count += 1
            }
            
            XCTAssertEqual(count, expectedRowCount)
        }
    }
    
}
