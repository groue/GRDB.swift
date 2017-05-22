import XCTest
#if GRDBCIPHER
    @testable import GRDBCipher
#elseif GRDBCUSTOMSQLITE
    @testable import GRDBCustomSQLite
#else
    @testable import GRDB
#endif

class StatementSelectionInfoTests : GRDBTestCase {
    
    func testSelectStatement() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute("CREATE TABLE foo (id INTEGER, name TEXT)")
            try db.execute("CREATE TABLE bar (id INTEGER, fooId INTEGER)")
            let statement = try db.makeSelectStatement("SELECT foo.name FROM FOO JOIN BAR ON fooId = foo.id")
            XCTAssertTrue(statement.selectionInfo.contains(anyColumnIn: ["id"], from: "foo"))
            XCTAssertTrue(statement.selectionInfo.contains(anyColumnIn: ["name"], from: "foo"))
            XCTAssertFalse(statement.selectionInfo.contains(anyColumnIn: ["id"], from: "bar"))
            XCTAssertTrue(statement.selectionInfo.contains(anyColumnIn: ["fooId"], from: "bar"))
        }
    }

    func testUpdateStatement() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute("CREATE TABLE foo (id INTEGER, bar TEXT, baz TEXT, qux TEXT)")
            let statement = try db.makeUpdateStatement("UPDATE foo SET bar = 'bar', baz = 'baz' WHERE id = 1")
            XCTAssertFalse(statement.invalidatesDatabaseSchemaCache)
            XCTAssertEqual(statement.databaseEventKinds.count, 1)
            guard case .update(let tableName, let columnNames) = statement.databaseEventKinds[0] else {
                XCTFail()
                return
            }
            XCTAssertEqual(tableName, "foo")
            XCTAssertEqual(columnNames, Set(["bar", "baz"]))
        }
    }

    func testInsertStatement() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute("CREATE TABLE foo (id INTEGER, bar TEXT, baz TEXT, qux TEXT)")
            let statement = try db.makeUpdateStatement("INSERT INTO foo (id, bar) VALUES (1, 'bar')")
            XCTAssertFalse(statement.invalidatesDatabaseSchemaCache)
            XCTAssertEqual(statement.databaseEventKinds.count, 1)
            guard case .insert(let tableName) = statement.databaseEventKinds[0] else {
                XCTFail()
                return
            }
            XCTAssertEqual(tableName, "foo")
        }
    }

    func testDeleteStatement() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute("CREATE TABLE foo (id INTEGER, bar TEXT, baz TEXT, qux TEXT)")
            let statement = try db.makeUpdateStatement("DELETE FROM foo")
            XCTAssertFalse(statement.invalidatesDatabaseSchemaCache)
            XCTAssertEqual(statement.databaseEventKinds.count, 1)
            guard case .delete(let tableName) = statement.databaseEventKinds[0] else {
                XCTFail()
                return
            }
            XCTAssertEqual(tableName, "foo")
        }
    }

    func testUpdateStatementInvalidatesDatabaseSchemaCache() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            do {
                let statement = try db.makeUpdateStatement("CREATE TABLE foo (id INTEGER)")
                XCTAssertFalse(statement.invalidatesDatabaseSchemaCache)
                try statement.execute()
            }
            do {
                let statement = try db.makeUpdateStatement("ALTER TABLE foo ADD COLUMN name TEXT")
                XCTAssertTrue(statement.invalidatesDatabaseSchemaCache)
            }
            do {
                let statement = try db.makeUpdateStatement("DROP TABLE foo")
                XCTAssertTrue(statement.invalidatesDatabaseSchemaCache)
            }
        }
    }
}
