import XCTest
import GRDB

class RowAdapterTests: GRDBTestCase {
    
    func testRowAdapter() {
        let dbQueue = DatabaseQueue()
        dbQueue.inDatabase { db in
            let adapter = RowAdapter(
                mapping: ["id": "fooid", "val": "FOOVAL"],   // case insensitivity of base column names
                subrowMappings: [
                    "foo": ["id": "barid", "val": "barval"]])
            let row = Row.fetchOne(db, "SELECT 1 AS fooid, 'foo' AS fooval, 2 as barid, 'bar' AS barval", adapter: adapter)!
            
            
            // # Column names
            
            XCTAssertEqual(row.value(named: "id") as Int, 1)
            XCTAssertEqual(row.value(named: "val") as String, "foo")
            // Case insensitivity of mapped column names
            XCTAssertEqual(row.value(named: "ID") as Int, 1)
            
            XCTAssertEqual(row.databaseValue(named: "id"), 1.databaseValue)
            XCTAssertEqual(row.databaseValue(named: "val"), "foo".databaseValue)
            // Case insensitivity of mapped column names
            XCTAssertEqual(row.databaseValue(named: "ID"), 1.databaseValue)
            
            // Column presence
            XCTAssertTrue(row.hasColumn("id"))
            XCTAssertTrue(row.hasColumn("val"))
            // Case insensitivity of mapped column names
            XCTAssertTrue(row.hasColumn("ID"))
            
            // Missing column in base row is missing in the mapped row
            XCTAssertFalse(row.hasColumn("missing"))
            XCTAssertTrue(row.value(named: "missing") == nil)
            
            // Column that exists in base row but is not mapped is missing from mapped row
            XCTAssertFalse(row.hasColumn("barid"))
            XCTAssertTrue(row.value(named: "barid") == nil)
            
            
            // # Column as an ordered collection preserves ordering of base row
            
            XCTAssertEqual(row.count, 2)
            
            XCTAssertEqual(row.value(atIndex: 0) as Int, 1)
            XCTAssertEqual(row.value(atIndex: 1) as String, "foo")
            
            XCTAssertEqual(row.databaseValue(atIndex: 0), 1.databaseValue)
            XCTAssertEqual(row.databaseValue(atIndex: 1), "foo".databaseValue)
            
            XCTAssertEqual(Array(row.columnNames), ["id", "val"])
            XCTAssertEqual(Array(row.databaseValues), [1.databaseValue, "foo".databaseValue])
            
            let pairs = row.map { (columnName: $0, databaseValue: $1) }
            XCTAssertEqual(pairs[0].columnName, "id")
            XCTAssertEqual(pairs[0].databaseValue, 1.databaseValue)
            XCTAssertEqual(pairs[1].columnName, "val")
            XCTAssertEqual(pairs[1].databaseValue, "foo".databaseValue)
            
            
            // # Row equality
            
            XCTAssertEqual(row, Row.fetchOne(db, "SELECT 1 AS id, 'foo' AS val")!)
            XCTAssertNotEqual(row, Row.fetchOne(db, "SELECT 'foo' AS val, 1 AS id")!)
            
            
            // # Subrows
            
            XCTAssertEqual(row.subrows.count, 1)
            XCTAssertEqual(Array(row.subrows.keys), ["foo"])
            let row2 = row.subrows["foo"]!
            XCTAssertEqual(row2.count, 2)
            XCTAssertEqual(row2.value(named: "id") as Int, 2)
            XCTAssertEqual(row2.value(named: "val") as String, "bar")
            XCTAssertTrue(row2.subrows.isEmpty)
        }
    }

}
