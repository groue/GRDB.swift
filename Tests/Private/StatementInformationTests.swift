import XCTest
@testable import GRDB

class StatementInformationTests : GRDBTestCase {
    
    func testSelectStatementSourceTables() {
        assertNoError {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE foo (id INTEGER)")
                try db.execute("CREATE TABLE bar (id INTEGER, fooId INTEGER)")
                let statement = try db.selectStatement("SELECT * FROM FOO JOIN BAR ON fooId = foo.id")
                XCTAssertTrue(statement.sourceTables.count == 2)
                XCTAssertTrue(statement.sourceTables.contains("foo"))
                XCTAssertTrue(statement.sourceTables.contains("bar"))
            }
        }
    }
    
    func testUpdateStatementReadOnly() {
        assertNoError {
            try dbQueue.inDatabase { db in
                do {
                    let statement = try db.updateStatement("CREATE TABLE foo (id INTEGER)")
                    XCTAssertFalse(statement.readOnly)
                    try statement.execute()
                }
                do {
                    let statement = try db.updateStatement("INSERT INTO foo (id) VALUES (1)")
                    XCTAssertFalse(statement.readOnly)
                }
                do {
                    let statement = try db.updateStatement("SELECT * FROM foo")
                    XCTAssertTrue(statement.readOnly)
                }
            }
        }
    }
    
    func testSelectStatementReadOnly() {
        assertNoError {
            try dbQueue.inDatabase { db in
                do {
                    let statement = try db.selectStatement("CREATE TABLE foo (id INTEGER)")
                    XCTAssertFalse(statement.readOnly)
                    _ = Row.fetch(statement).generate().next()
                }
                do {
                    let statement = try db.selectStatement("INSERT INTO foo (id) VALUES (1)")
                    XCTAssertFalse(statement.readOnly)
                }
                do {
                    let statement = try db.selectStatement("SELECT * FROM foo")
                    XCTAssertTrue(statement.readOnly)
                }
            }
        }
    }
    
    func testUpdateStatementInvalidatesDatabaseSchemaCache() {
        assertNoError {
            try dbQueue.inDatabase { db in
                do {
                    let statement = try db.updateStatement("CREATE TABLE foo (id INTEGER)")
                    XCTAssertFalse(statement.invalidatesDatabaseSchemaCache)
                    try statement.execute()
                }
                do {
                    let statement = try db.updateStatement("ALTER TABLE foo ADD COLUMN name TEXT")
                    XCTAssertTrue(statement.invalidatesDatabaseSchemaCache)
                }
                do {
                    let statement = try db.updateStatement("DROP TABLE foo")
                    XCTAssertTrue(statement.invalidatesDatabaseSchemaCache)
                }
            }
        }
    }
}
