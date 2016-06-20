import XCTest
#if USING_SQLCIPHER
    @testable import GRDBCipher
#elseif USING_CUSTOMSQLITE
    @testable import GRDBCustomSQLite
#else
    @testable import GRDB
#endif

class StatementInformationTests : GRDBTestCase {
    
    func testSelectStatement() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE foo (id INTEGER)")
                try db.execute("CREATE TABLE bar (id INTEGER, fooId INTEGER)")
                let statement = try db.selectStatement("SELECT * FROM FOO JOIN BAR ON fooId = foo.id")
                XCTAssertEqual(statement.readTables, ["foo": Set(["id"]), "bar": Set(["id", "fooId"])])
            }
        }
    }
    
    func testUpdateStatement() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE foo (id INTEGER, bar TEXT, baz TEXT, qux TEXT)")
                let statement = try db.updateStatement("UPDATE foo SET bar = 'bar', baz = 'baz' WHERE id = 1")
                XCTAssertFalse(statement.invalidatesDatabaseSchemaCache)
                XCTAssertEqual(statement.databaseEventKinds.count, 1)
                guard case .Update(let tableName, let columnNames) = statement.databaseEventKinds[0] else {
                    XCTFail()
                    return
                }
                XCTAssertEqual(tableName, "foo")
                XCTAssertEqual(columnNames, Set(["bar", "baz"]))
            }
        }
    }
    
    func testInsertStatement() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE foo (id INTEGER, bar TEXT, baz TEXT, qux TEXT)")
                let statement = try db.updateStatement("INSERT INTO foo (id, bar) VALUES (1, 'bar')")
                XCTAssertFalse(statement.invalidatesDatabaseSchemaCache)
                XCTAssertEqual(statement.databaseEventKinds.count, 1)
                guard case .Insert(let tableName) = statement.databaseEventKinds[0] else {
                    XCTFail()
                    return
                }
                XCTAssertEqual(tableName, "foo")
            }
        }
    }
    
    func testDeleteStatement() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE foo (id INTEGER, bar TEXT, baz TEXT, qux TEXT)")
                let statement = try db.updateStatement("DELETE FROM foo")
                XCTAssertFalse(statement.invalidatesDatabaseSchemaCache)
                XCTAssertEqual(statement.databaseEventKinds.count, 1)
                guard case .Delete(let tableName) = statement.databaseEventKinds[0] else {
                    XCTFail()
                    return
                }
                XCTAssertEqual(tableName, "foo")
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
