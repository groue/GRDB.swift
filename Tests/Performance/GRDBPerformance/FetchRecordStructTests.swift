import XCTest
import GRDB
import SQLite3
#if GRDB_COMPARE
import SQLite
#endif

private let expectedRowCount = 200_000

private struct Item {
    var i0: Int
    var i1: Int
    var i2: Int
    var i3: Int
    var i4: Int
    var i5: Int
    var i6: Int
    var i7: Int
    var i8: Int
    var i9: Int
}

// GRDB support
extension Item: FetchableRecord, TableRecord {
    init(row: GRDB.Row) {
        i0 = row["i0"]
        i1 = row["i1"]
        i2 = row["i2"]
        i3 = row["i3"]
        i4 = row["i4"]
        i5 = row["i5"]
        i6 = row["i6"]
        i7 = row["i7"]
        i8 = row["i8"]
        i9 = row["i9"]
    }
}

/// Here we test the extraction of a plain Swift struct
class FetchRecordStructTests: XCTestCase {

    func testSQLite() throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("GRDBPerformanceTests.sqlite")
        try generateSQLiteDatabaseIfMissing(at: url, insertedRowCount: expectedRowCount)
        var connection: OpaquePointer? = nil
        sqlite3_open_v2(url.path, &connection, 0x00000004 /*SQLITE_OPEN_CREATE*/ | 0x00000002 /*SQLITE_OPEN_READWRITE*/, nil)
        
        measure {
            var statement: OpaquePointer? = nil
            sqlite3_prepare_v2(connection, "SELECT * FROM item", -1, &statement, nil)
            
            let columnNames = (Int32(0)..<10).map { String(cString: sqlite3_column_name(statement, $0)) }
            let index0 = Int32(columnNames.firstIndex(of: "i0")!)
            let index1 = Int32(columnNames.firstIndex(of: "i1")!)
            let index2 = Int32(columnNames.firstIndex(of: "i2")!)
            let index3 = Int32(columnNames.firstIndex(of: "i3")!)
            let index4 = Int32(columnNames.firstIndex(of: "i4")!)
            let index5 = Int32(columnNames.firstIndex(of: "i5")!)
            let index6 = Int32(columnNames.firstIndex(of: "i6")!)
            let index7 = Int32(columnNames.firstIndex(of: "i7")!)
            let index8 = Int32(columnNames.firstIndex(of: "i8")!)
            let index9 = Int32(columnNames.firstIndex(of: "i9")!)
            
            var items = [Item]()
            loop: while true {
                switch sqlite3_step(statement) {
                case 101 /*SQLITE_DONE*/:
                    break loop
                case 100 /*SQLITE_ROW*/:
                    let item = Item(
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
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("GRDBPerformanceTests.sqlite")
        try generateSQLiteDatabaseIfMissing(at: url, insertedRowCount: expectedRowCount)
        let dbQueue = try DatabaseQueue(path: url.path)
        
        measure {
            let items = try! dbQueue.inDatabase { db in
                try Item.fetchAll(db)
            }
            XCTAssertEqual(items.count, expectedRowCount)
            XCTAssertEqual(items[0].i0, 0)
            XCTAssertEqual(items[1].i1, 1)
            XCTAssertEqual(items[expectedRowCount-1].i9, expectedRowCount-1)
        }
    }
    
    #if GRDB_COMPARE
    func testFMDB() throws {
        // Here we test the loading of an array of Records.
        
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("GRDBPerformanceTests.sqlite")
        try generateSQLiteDatabaseIfMissing(at: url, insertedRowCount: expectedRowCount)
        let dbQueue = FMDatabaseQueue(path: url.path)!
        
        measure {
            var items = [Item]()
            dbQueue.inDatabase { db in
                let rs = try! db.executeQuery("SELECT * FROM item", values: nil)
                while rs.next() {
                    let dict = rs.resultDictionary!
                    let item = Item(
                        i0: dict["i0"] as! Int,
                        i1: dict["i1"] as! Int,
                        i2: dict["i2"] as! Int,
                        i3: dict["i3"] as! Int,
                        i4: dict["i4"] as! Int,
                        i5: dict["i5"] as! Int,
                        i6: dict["i6"] as! Int,
                        i7: dict["i7"] as! Int,
                        i8: dict["i8"] as! Int,
                        i9: dict["i9"] as! Int)
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
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("GRDBPerformanceTests.sqlite")
        try generateSQLiteDatabaseIfMissing(at: url, insertedRowCount: expectedRowCount)
        let db = try Connection(url.path)
        
        measure {
            var items = [Item]()
            for row in try! db.prepare(itemTable) {
                let item = Item(
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
