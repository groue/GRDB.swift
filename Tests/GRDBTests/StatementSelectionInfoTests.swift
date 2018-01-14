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
    
    func testRowIdNameInSelectStatement() throws {
        // Here we test that sqlite authorizer gives the "ROWID" name to
        // the rowid column, regardless of its name in the request (rowid, oid, _rowid_)
        //
        // See also testRowIdNameInUpdateStatement
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute("CREATE TABLE foo (name TEXT)")
            do {
                let statement = try db.makeSelectStatement("SELECT rowid FROM FOO")
                XCTAssertTrue(statement.selectionInfo.contains(anyColumnIn: ["ROWID"], from: "foo"))
            }
            do {
                let statement = try db.makeSelectStatement("SELECT _ROWID_ FROM FOO")
                XCTAssertTrue(statement.selectionInfo.contains(anyColumnIn: ["ROWID"], from: "foo"))
            }
            do {
                let statement = try db.makeSelectStatement("SELECT oID FROM FOO")
                XCTAssertTrue(statement.selectionInfo.contains(anyColumnIn: ["ROWID"], from: "foo"))
            }
        }
    }
    
    func testSelectionInfoRowIds() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute("CREATE TABLE foo (id INTEGER PRIMARY KEY, a TEXT)")
            struct Record: TableMapping {
                static let databaseTableName = "foo"
            }
            
            // Undefined rowIds
            
            do {
                let request = Record.all()
                try XCTAssertNil(request.selectionInfo(db).rowIds)
            }
            do {
                let request = Record.filter(Column("a") == 1)
                try XCTAssertNil(request.selectionInfo(db).rowIds)
            }
            do {
                let request = Record.filter(Column("id") >= 1)
                try XCTAssertNil(request.selectionInfo(db).rowIds)
            }
            
            do {
                let request = Record.filter((Column("id") == 1) || (Column("a") == "foo"))
                try XCTAssertNil(request.selectionInfo(db).rowIds)
            }

            // No rowId
            
            do {
                let request = Record.filter(Column("id") == nil)
                try XCTAssertEqual(request.selectionInfo(db).rowIds!, [])
            }

            do {
                let request = Record.filter(Column("id") === nil)
                try XCTAssertEqual(request.selectionInfo(db).rowIds!, [])
            }
            
            do {
                let request = Record.filter(nil == Column("id"))
                try XCTAssertEqual(request.selectionInfo(db).rowIds!, [])
            }
            
            do {
                let request = Record.filter(nil === Column("id"))
                try XCTAssertEqual(request.selectionInfo(db).rowIds!, [])
            }
            
            do {
                let request = Record.filter((Column("id") == 1) && (Column("id") == 2))
                try XCTAssertEqual(request.selectionInfo(db).rowIds!, [])
            }
            do {
                let request = Record.filter(key: 1).filter(key: 2)
                try XCTAssertEqual(request.selectionInfo(db).rowIds!, [])
            }

            // Single rowId
            
            do {
                let request = Record.filter(Column("id") == 1)
                try XCTAssertEqual(request.selectionInfo(db).rowIds!, [1])
            }
            do {
                let request = Record.filter(Column("id") === 1)
                try XCTAssertEqual(request.selectionInfo(db).rowIds!, [1])
            }
            do {
                let request = Record.filter(Column("id") == 1 && Column("a") == "foo")
                try XCTAssertEqual(request.selectionInfo(db).rowIds!, [1])
            }
            do {
                let request = Record.filter(Column.rowID == 1)
                try XCTAssertEqual(request.selectionInfo(db).rowIds!, [1])
            }
            do {
                let request = Record.filter(1 == Column("id"))
                try XCTAssertEqual(request.selectionInfo(db).rowIds!, [1])
            }
            do {
                let request = Record.filter(1 === Column("id"))
                try XCTAssertEqual(request.selectionInfo(db).rowIds!, [1])
            }
            do {
                let request = Record.filter(1 === Column.rowID)
                try XCTAssertEqual(request.selectionInfo(db).rowIds!, [1])
            }
            do {
                let request = Record.filter(key: 1)
                try XCTAssertEqual(request.selectionInfo(db).rowIds!, [1])
            }
            do {
                let request = Record.filter(key: 1).filter(key: 1)
                try XCTAssertEqual(request.selectionInfo(db).rowIds!, [1])
            }
            do {
                let request = Record.filter(key: 1).filter(Column("a") == "foo")
                try XCTAssertEqual(request.selectionInfo(db).rowIds!, [1])
            }

            // Multiple rowIds
            
            do {
                let request = Record.filter(Column("id") == 1 || Column.rowID == 2)
                try XCTAssertEqual(request.selectionInfo(db).rowIds!, [1, 2])
            }
            do {
                let request = Record.filter([1, 2, 3].contains(Column("id")))
                try XCTAssertEqual(request.selectionInfo(db).rowIds!, [1, 2, 3])
            }
            do {
                let request = Record.filter([1, 2, 3].contains(Column.rowID))
                try XCTAssertEqual(request.selectionInfo(db).rowIds!, [1, 2, 3])
            }
            do {
                let request = Record.filter(keys: [1, 2, 3])
                try XCTAssertEqual(request.selectionInfo(db).rowIds!, [1, 2, 3])
            }
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
    
    func testRowIdNameInUpdateStatement() throws {
        // Here we test that sqlite authorizer gives the "ROWID" name to
        // the rowid column, regardless of its name in the request (rowid, oid, _rowid_)
        //
        // See also testRowIdNameInSelectStatement
        
        guard sqlite3_libversion_number() > 3007013 else {
            // This test fails on iOS 8.1 (SQLite 3.7.13)
            // TODO: evaluate the consequences
            return
        }
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute("CREATE TABLE foo (name TEXT)")
            do {
                let statement = try db.makeUpdateStatement("UPDATE foo SET rowid = 1")
                XCTAssertEqual(statement.databaseEventKinds.count, 1)
                guard case .update(let tableName, let columnNames) = statement.databaseEventKinds[0] else {
                    XCTFail()
                    return
                }
                XCTAssertEqual(tableName, "foo")
                XCTAssertEqual(columnNames, ["ROWID"])
            }
            do {
                let statement = try db.makeUpdateStatement("UPDATE foo SET _ROWID_ = 1")
                XCTAssertEqual(statement.databaseEventKinds.count, 1)
                guard case .update(let tableName, let columnNames) = statement.databaseEventKinds[0] else {
                    XCTFail()
                    return
                }
                XCTAssertEqual(tableName, "foo")
                XCTAssertEqual(columnNames, ["ROWID"])
            }
            do {
                let statement = try db.makeUpdateStatement("UPDATE foo SET oID = 1")
                XCTAssertEqual(statement.databaseEventKinds.count, 1)
                guard case .update(let tableName, let columnNames) = statement.databaseEventKinds[0] else {
                    XCTFail()
                    return
                }
                XCTAssertEqual(tableName, "foo")
                XCTAssertEqual(columnNames, ["ROWID"])
            }
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
