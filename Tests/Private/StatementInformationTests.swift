import XCTest
#if USING_SQLCIPHER
    @testable import GRDBCipher
#elseif USING_CUSTOMSQLITE
    @testable import GRDBCustomSQLite
#else
    @testable import GRDB
#endif

class StatementInformationTests : GRDBTestCase {
    
    func testSelectStatementSourceTables() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
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
    
    func testUpdateStatementInvalidatesDatabaseSchemaCache() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
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
