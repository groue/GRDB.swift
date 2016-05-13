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
            let row = Row.fetchOne(db, "SELECT 1 AS fooid, 'foo' AS fooval, 2 as barid, 'bar' AS barval", adapter: adapter)!
            
            // # Row values
            
            XCTAssertEqual(row.count, 2)
            XCTAssertEqual(row.value(named: "id") as Int, 1)
            XCTAssertEqual(row.value(named: "val") as String, "foo")
            XCTAssertEqual(row.databaseValue(named: "id"), 1.databaseValue)
            XCTAssertEqual(row.databaseValue(named: "val"), "foo".databaseValue)
            XCTAssertTrue(row.value(named: "barid") == nil)
            XCTAssertTrue(row.value(named: "missing") == nil)
            XCTAssertTrue(row.hasColumn("id"))
            XCTAssertTrue(row.hasColumn("val"))
            XCTAssertFalse(row.hasColumn("barid"))
            XCTAssertFalse(row.hasColumn("missing"))
            // TODO: test row.value(atIndex: 0) and row.value(atIndex: 1)
            // TODO: test for (key, value) in row { ... }
            
            
            // # Row equality
            
            // One of this tests is failing - can't know which one because dictionaries are unordered.
            // TODO: think about that.
            let altRow1 = Row.fetchOne(db, "SELECT 1 AS id, 'foo' AS val")!
            XCTAssertEqual(row, altRow1)
            let altRow2 = Row.fetchOne(db, "SELECT 'foo' AS val, 1 AS id")!
            XCTAssertEqual(row, altRow2)
            
            
            // # Subrows
            
            let row2 = row.subrows["foo"]!
            XCTAssertEqual(row2.count, 2)
            XCTAssertEqual(row2.value(named: "id") as Int, 2)
            XCTAssertEqual(row2.value(named: "val") as String, "bar")
            
            let row3 = row.subrows["odd"]!
            XCTAssertEqual(row3.count, 1)
            XCTAssertTrue(row3.value(named: "id") == nil)
        }
    }

}
