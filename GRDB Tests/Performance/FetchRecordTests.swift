import XCTest
import GRDB
import SQLite

/// Here we test the extraction of models from rows
class FetchRecordTests: XCTestCase {

    func testFMDB() {
        // Here we test the loading of an array of Records.
        
        let databasePath = NSBundle(forClass: self.dynamicType).pathForResource("PerformanceTests", ofType: "sqlite")!
        let dbQueue = FMDatabaseQueue(path: databasePath)
        
        self.measureBlock {
            var records = [Item]()
            dbQueue.inDatabase { db in
                if let rs = db.executeQuery("SELECT * FROM items", withArgumentsInArray: nil) {
                    while rs.next() {
                        let record = Item(dictionary: rs.resultDictionary())
                        records.append(record)
                    }
                }
            }
            XCTAssertEqual(records[0].i0, 0)
            XCTAssertEqual(records[1].i1, 1)
            XCTAssertEqual(records[9999].i9, 9999)
        }
    }

    func testGRDB() {
        let databasePath = NSBundle(forClass: self.dynamicType).pathForResource("PerformanceTests", ofType: "sqlite")!
        let dbQueue = try! DatabaseQueue(path: databasePath)
        
        measureBlock {
            let records = dbQueue.inDatabase { db in
                Item.fetchAll(db, "SELECT * FROM items")
            }
            XCTAssertEqual(records[0].i0, 0)
            XCTAssertEqual(records[1].i1, 1)
            XCTAssertEqual(records[9999].i9, 9999)
        }
    }

    func testSQLiteSwift() {
        let databasePath = NSBundle(forClass: self.dynamicType).pathForResource("PerformanceTests", ofType: "sqlite")!
        let db = try! Connection(databasePath)
        
        self.measureBlock {
            var records = [Item]()
            for row in db.prepare(itemsTable) {
                let record = Item(
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
                records.append(record)
            }
            XCTAssertEqual(records[0].i0, 0)
            XCTAssertEqual(records[1].i1, 1)
            XCTAssertEqual(records[9999].i9, 9999)
        }
    }
}
