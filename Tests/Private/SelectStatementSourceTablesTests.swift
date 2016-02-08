import XCTest
@testable import GRDB

class SelectStatementSourceTablesTests : GRDBTestCase {
    
    func testSourceTables() {
        assertNoError {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE foo (id INTEGER)")
                try db.execute("CREATE TABLE bar (id INTEGER, fooId INTEGER)")
                let statement = try db.selectStatement("SELECT * FROM Foo JOIN Bar ON fooId = foo.id")
                XCTAssertTrue(statement.sourceTables.count == 2)
                XCTAssertTrue(statement.sourceTables.contains("foo"))
                XCTAssertTrue(statement.sourceTables.contains("bar"))
            }
        }
    }
}
