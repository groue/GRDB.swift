import XCTest
@testable import GRDB

class DatabaseErrorFromSelectStatementTests: GRDBTestCase {
    
    func testDatabaseErrorThrownBySelectStatementContainSQL() {
        dbQueue.inDatabase { db in
            do {
                let _ = try SelectStatement(database: db, sql: "SELECT * FROM blah")
                XCTFail()
            } catch let error as DatabaseError {
                XCTAssertEqual(error.code, 1)
                XCTAssertEqual(error.message!, "no such table: blah")
                XCTAssertEqual(error.sql!, "SELECT * FROM blah")
                XCTAssertEqual(error.description, "SQLite error 1 with statement `SELECT * FROM blah`: no such table: blah")
            } catch {
                XCTFail("\(error)")
            }
        }
    }
}
