import XCTest
import SQLite3
import GRDB
#if GRDB_COMPARE
import SQLite
#endif

private let expectedRowCount = 100_000

/// Here we test the extraction of models from rows
class FetchRecordStructTests: XCTestCase {

    func testSQLite() {
        let databasePath = Bundle(for: type(of: self)).path(forResource: "PerformanceTests", ofType: "sqlite")!
        var connection: OpaquePointer? = nil
        sqlite3_open_v2(databasePath, &connection, 0x00000004 /*SQLITE_OPEN_CREATE*/ | 0x00000002 /*SQLITE_OPEN_READWRITE*/, nil)
        
        measure {
            var statement: OpaquePointer? = nil
            sqlite3_prepare_v2(connection, "SELECT * FROM items", -1, &statement, nil)
            
            let columnNames = (Int32(0)..<10).map { String(cString: sqlite3_column_name(statement, $0)) }
            let index0 = Int32(columnNames.index(of: "i0")!)
            let index1 = Int32(columnNames.index(of: "i1")!)
            let index2 = Int32(columnNames.index(of: "i2")!)
            let index3 = Int32(columnNames.index(of: "i3")!)
            let index4 = Int32(columnNames.index(of: "i4")!)
            let index5 = Int32(columnNames.index(of: "i5")!)
            let index6 = Int32(columnNames.index(of: "i6")!)
            let index7 = Int32(columnNames.index(of: "i7")!)
            let index8 = Int32(columnNames.index(of: "i8")!)
            let index9 = Int32(columnNames.index(of: "i9")!)
            
            var items = [ItemStruct]()
            loop: while true {
                switch sqlite3_step(statement) {
                case 101 /*SQLITE_DONE*/:
                    break loop
                case 100 /*SQLITE_ROW*/:
                    let item = ItemStruct(
                        i0: Int(sqlite3_column_int64(statement, index0)),
                        i1: Int(sqlite3_column_int64(statement, index1)),
                        i2: Int(sqlite3_column_int64(statement, index2)),
                        i3: Int(sqlite3_column_int64(statement, index3)),
                        i4: Int(sqlite3_column_int64(statement, index4)),
                        i5: Int(sqlite3_column_int64(statement, index5)),
                        i6: Int(sqlite3_column_int64(statement, index6)),
                        i7: Int(sqlite3_column_int64(statement, index7)),
                        i8: Int(sqlite3_column_int64(statement, index8)),
                        i9: Int(sqlite3_column_int64(statement, index9)))
                    items.append(item)
                    break
                default:
                    XCTFail()
                }
            }
            
            sqlite3_finalize(statement)
            
            XCTAssertEqual(items.count, expectedRowCount)
            XCTAssertEqual(items[0].i0, 0)
            XCTAssertEqual(items[1].i1, 1)
            XCTAssertEqual(items[expectedRowCount-1].i9, expectedRowCount-1)
        }
        
        sqlite3_close(connection)
    }
    
    func testGRDB() throws {
        let databasePath = Bundle(for: type(of: self)).path(forResource: "PerformanceTests", ofType: "sqlite")!
        let dbQueue = try DatabaseQueue(path: databasePath)
        
        measure {
            let items = try! dbQueue.inDatabase { db in
                try ItemStruct.fetchAll(db, sql: "SELECT * FROM items")
            }
            XCTAssertEqual(items.count, expectedRowCount)
            XCTAssertEqual(items[0].i0, 0)
            XCTAssertEqual(items[1].i1, 1)
            XCTAssertEqual(items[expectedRowCount-1].i9, expectedRowCount-1)
        }
    }
    
    #if GRDB_COMPARE
    func testFMDB() {
        // Here we test the loading of an array of Records.
        
        let databasePath = Bundle(for: type(of: self)).path(forResource: "PerformanceTests", ofType: "sqlite")!
        let dbQueue = FMDatabaseQueue(path: databasePath)!
        
        measure {
            var items = [ItemStruct]()
            dbQueue.inDatabase { db in
                let rs = try! db.executeQuery("SELECT * FROM items", values: nil)
                while rs.next() {
                    let item = ItemStruct(dictionary: rs.resultDictionary!)
                    items.append(item)
                }
            }
            XCTAssertEqual(items.count, expectedRowCount)
            XCTAssertEqual(items[0].i0, 0)
            XCTAssertEqual(items[1].i1, 1)
            XCTAssertEqual(items[expectedRowCount-1].i9, expectedRowCount-1)
        }
    }

    func testSQLiteSwift() throws {
        let databasePath = Bundle(for: type(of: self)).path(forResource: "PerformanceTests", ofType: "sqlite")!
        let db = try Connection(databasePath)
        
        measure {
            var items = [ItemStruct]()
            for row in try! db.prepare(itemsTable) {
                let item = ItemStruct(
                    i0: row[i0Column],
                    i1: row[i1Column],
                    i2: row[i2Column],
                    i3: row[i3Column],
                    i4: row[i4Column],
                    i5: row[i5Column],
                    i6: row[i6Column],
                    i7: row[i7Column],
                    i8: row[i8Column],
                    i9: row[i9Column])
                items.append(item)
            }
            XCTAssertEqual(items.count, expectedRowCount)
            XCTAssertEqual(items[0].i0, 0)
            XCTAssertEqual(items[1].i1, 1)
            XCTAssertEqual(items[expectedRowCount-1].i9, expectedRowCount-1)
        }
    }
    #endif
}
