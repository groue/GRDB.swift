import XCTest
import GRDB
import SQLite

private let expectedRowCount = 100_000

/// Here we test the extraction of values by column name.
class FetchNamedValuesTests: XCTestCase {
    
    func testSQLite() {
        let databasePath = NSBundle(forClass: self.dynamicType).pathForResource("PerformanceTests", ofType: "sqlite")!
        var connection: COpaquePointer = nil
        sqlite3_open_v2(databasePath, &connection, 0x00000004 /*SQLITE_OPEN_CREATE*/ | 0x00000002 /*SQLITE_OPEN_READWRITE*/, nil)
        
        self.measureBlock {
            var count = 0
            
            var statement: COpaquePointer = nil
            sqlite3_prepare_v2(connection, "SELECT * FROM items", -1, &statement, nil)
            
            let columnNames = (Int32(0)..<10).map { String.fromCString(sqlite3_column_name(statement, $0))! }
            let index0 = Int32(columnNames.indexOf("i0")!)
            let index1 = Int32(columnNames.indexOf("i1")!)
            let index2 = Int32(columnNames.indexOf("i2")!)
            let index3 = Int32(columnNames.indexOf("i3")!)
            let index4 = Int32(columnNames.indexOf("i4")!)
            let index5 = Int32(columnNames.indexOf("i5")!)
            let index6 = Int32(columnNames.indexOf("i6")!)
            let index7 = Int32(columnNames.indexOf("i7")!)
            let index8 = Int32(columnNames.indexOf("i8")!)
            let index9 = Int32(columnNames.indexOf("i9")!)
            
            loop: while true {
                switch sqlite3_step(statement) {
                case 101 /*SQLITE_DONE*/:
                    break loop
                case 100 /*SQLITE_ROW*/:
                    let _ = sqlite3_column_int64(statement, index0)
                    let _ = sqlite3_column_int64(statement, index1)
                    let _ = sqlite3_column_int64(statement, index2)
                    let _ = sqlite3_column_int64(statement, index3)
                    let _ = sqlite3_column_int64(statement, index4)
                    let _ = sqlite3_column_int64(statement, index5)
                    let _ = sqlite3_column_int64(statement, index6)
                    let _ = sqlite3_column_int64(statement, index7)
                    let _ = sqlite3_column_int64(statement, index8)
                    let _ = sqlite3_column_int64(statement, index9)
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
                        let _ = rs.longForColumn("i0")
                        let _ = rs.longForColumn("i1")
                        let _ = rs.longForColumn("i2")
                        let _ = rs.longForColumn("i3")
                        let _ = rs.longForColumn("i4")
                        let _ = rs.longForColumn("i5")
                        let _ = rs.longForColumn("i6")
                        let _ = rs.longForColumn("i7")
                        let _ = rs.longForColumn("i8")
                        let _ = rs.longForColumn("i9")
                        
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
                    let _: Int = row.value(named: "i0")
                    let _: Int = row.value(named: "i1")
                    let _: Int = row.value(named: "i2")
                    let _: Int = row.value(named: "i3")
                    let _: Int = row.value(named: "i4")
                    let _: Int = row.value(named: "i5")
                    let _: Int = row.value(named: "i6")
                    let _: Int = row.value(named: "i7")
                    let _: Int = row.value(named: "i8")
                    let _: Int = row.value(named: "i9")
                    
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
            
            for item in db.prepare(itemsTable) {
                let _ = item[i0Column]
                let _ = item[i1Column]
                let _ = item[i2Column]
                let _ = item[i3Column]
                let _ = item[i4Column]
                let _ = item[i5Column]
                let _ = item[i6Column]
                let _ = item[i7Column]
                let _ = item[i8Column]
                let _ = item[i9Column]
                
                count += 1
            }
            
            XCTAssertEqual(count, expectedRowCount)
        }
    }
    
}
