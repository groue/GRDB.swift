import XCTest
import GRDB

class RowAdapterTests: GRDBTestCase {
    
    func testRowAdapter() {
        let dbQueue = DatabaseQueue()
        dbQueue.inDatabase { db in
            let adapter = RowAdapter(
                mapping: ["id": "fooid", "val": "fooval"],
                subrows: [
                    "foo": ["id": "barid", "val": "barval"],
                    "odd": ["id": "missingid"]])
            let row = Row.fetchOne(db, "SELECT 1 AS fooid, 'toto' AS fooval, 2 as barid, 'tata' AS barval", adapter: adapter)!
            
            print(row)                  // <Row id:1 val:"toto">
            XCTAssertEqual(row.count, 2)
            XCTAssertEqual(row.value(named: "id") as Int, 1)
            XCTAssertEqual(row.value(named: "val") as String, "toto")
            XCTAssertEqual(row.databaseValue(named: "id"), 1.databaseValue)
            XCTAssertEqual(row.databaseValue(named: "val"), "toto".databaseValue)
            XCTAssertTrue(row.value(named: "barid") == nil)
            XCTAssertTrue(row.value(named: "missing") == nil)
            XCTAssertTrue(row.hasColumn("id"))
            XCTAssertTrue(row.hasColumn("val"))
            XCTAssertFalse(row.hasColumn("barid"))
            XCTAssertFalse(row.hasColumn("missing"))
            // TODO: test row.value(atIndex: 0) and row.value(atIndex: 1)
            // TODO: test for (key, value) in row { ... }
            
            let row2 = row.subrows["foo"]!
            XCTAssertEqual(row2.count, 2)
            XCTAssertEqual(row2.value(named: "id") as Int, 2)
            XCTAssertEqual(row2.value(named: "val") as String, "tata")
            
            let row3 = row.subrows["odd"]!
            XCTAssertEqual(row3.count, 1)
            XCTAssertTrue(row3.value(named: "id") == nil)
        }
    }

}
