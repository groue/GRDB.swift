import XCTest
#if GRDBCIPHER
    @testable import GRDBCipher
#elseif GRDBCUSTOMSQLITE
    @testable import GRDBCustomSQLite
#else
    #if SWIFT_PACKAGE
        import CSQLite
    #else
        import SQLite3
    #endif
    @testable import GRDB
#endif

class DatabaseSelectionInfoTests : GRDBTestCase {
    
    func testSelectionInfoEquatable() {
        let selectionInfos = [
            DatabaseSelectionInfo.fullDatabase,
            DatabaseSelectionInfo(),
            DatabaseSelectionInfo(table: "foo"),
            DatabaseSelectionInfo(table: "FOO"), // selection info is case-sensitive on table name
            DatabaseSelectionInfo(table: "foo", columns: ["a", "b"]),
            DatabaseSelectionInfo(table: "foo", columns: ["A", "B"]), // selection info is case-sensitive on columns names
            DatabaseSelectionInfo(table: "foo", columns: ["b", "c"]),
            DatabaseSelectionInfo(table: "foo", rowIds: [1, 2]),
            DatabaseSelectionInfo(table: "foo", rowIds: [2, 3]),
            DatabaseSelectionInfo(table: "bar")]
        
        for (i1, s1) in selectionInfos.enumerated() {
            for (i2, s2) in selectionInfos.enumerated() {
                if i1 == i2 {
                    XCTAssertEqual(s1, s2)
                } else {
                    XCTAssertNotEqual(s1, s2)
                }
            }
        }
    }
    
    func testSelectionInfoUnion() {
        let selectionInfos = [
            DatabaseSelectionInfo.fullDatabase,
            DatabaseSelectionInfo(),
            DatabaseSelectionInfo(table: "foo"),
            DatabaseSelectionInfo(table: "foo", columns: ["a", "b"]),
            DatabaseSelectionInfo(table: "foo", columns: ["b", "c"]),
            DatabaseSelectionInfo(table: "foo", rowIds: [1, 2]),
            DatabaseSelectionInfo(table: "foo", rowIds: [2, 3]),
            DatabaseSelectionInfo(table: "bar")]
        
        var unions: [DatabaseSelectionInfo] = []
        for s1 in selectionInfos {
            for s2 in selectionInfos {
                unions.append(s1.union(s2))
            }
        }
        
        XCTAssertEqual(unions.map { $0.description }, [
            "full database",
            "full database",
            "full database",
            "full database",
            "full database",
            "full database",
            "full database",
            "full database",
            
            "full database",
            "empty",
            "foo(*)",
            "foo(a,b)",
            "foo(b,c)",
            "foo(*)[1,2]",
            "foo(*)[2,3]",
            "bar(*)",
            
            "full database",
            "foo(*)",
            "foo(*)",
            "foo(*)",
            "foo(*)",
            "foo(*)",
            "foo(*)",
            "bar(*),foo(*)",
            
            "full database",
            "foo(a,b)",
            "foo(*)",
            "foo(a,b)",
            "foo(a,b,c)",
            "foo(*)",
            "foo(*)",
            "bar(*),foo(a,b)",
            
            "full database",
            "foo(b,c)",
            "foo(*)",
            "foo(a,b,c)",
            "foo(b,c)",
            "foo(*)",
            "foo(*)",
            "bar(*),foo(b,c)",
            
            "full database",
            "foo(*)[1,2]",
            "foo(*)",
            "foo(*)",
            "foo(*)",
            "foo(*)[1,2]",
            "foo(*)[1,2,3]",
            "bar(*),foo(*)[1,2]",
            
            "full database",
            "foo(*)[2,3]",
            "foo(*)",
            "foo(*)",
            "foo(*)",
            "foo(*)[1,2,3]",
            "foo(*)[2,3]",
            "bar(*),foo(*)[2,3]",
            
            "full database",
            "bar(*)",
            "bar(*),foo(*)",
            "bar(*),foo(a,b)",
            "bar(*),foo(b,c)",
            "bar(*),foo(*)[1,2]",
            "bar(*),foo(*)[2,3]",
            "bar(*)"])
    }
    
    func testSelectionInfoIntersection() {
        let selectionInfos = [
            DatabaseSelectionInfo.fullDatabase,
            DatabaseSelectionInfo(),
            DatabaseSelectionInfo(table: "foo"),
            DatabaseSelectionInfo(table: "foo", columns: ["a", "b"]),
            DatabaseSelectionInfo(table: "foo", columns: ["b", "c"]),
            DatabaseSelectionInfo(table: "foo", rowIds: [1, 2]),
            DatabaseSelectionInfo(table: "foo", rowIds: [2, 3]),
            DatabaseSelectionInfo(table: "bar")]
        
        var intersection: [DatabaseSelectionInfo] = []
        for s1 in selectionInfos {
            for s2 in selectionInfos {
                intersection.append(s1.intersection(s2))
            }
        }
        
        XCTAssertEqual(intersection.map { $0.description }, [
            "full database",
            "empty",
            "foo(*)",
            "foo(a,b)",
            "foo(b,c)",
            "foo(*)[1,2]",
            "foo(*)[2,3]",
            "bar(*)",
            
            "empty",
            "empty",
            "empty",
            "empty",
            "empty",
            "empty",
            "empty",
            "empty",
            
            "foo(*)",
            "empty",
            "foo(*)",
            "foo(a,b)",
            "foo(b,c)",
            "foo(*)[1,2]",
            "foo(*)[2,3]",
            "empty",
            
            "foo(a,b)",
            "empty",
            "foo(a,b)",
            "foo(a,b)",
            "foo(b)",
            "foo(a,b)[1,2]",
            "foo(a,b)[2,3]",
            "empty",
            
            "foo(b,c)",
            "empty",
            "foo(b,c)",
            "foo(b)",
            "foo(b,c)",
            "foo(b,c)[1,2]",
            "foo(b,c)[2,3]",
            "empty",
            
            "foo(*)[1,2]",
            "empty",
            "foo(*)[1,2]",
            "foo(a,b)[1,2]",
            "foo(b,c)[1,2]",
            "foo(*)[1,2]",
            "foo(*)[2]",
            "empty",
            
            "foo(*)[2,3]",
            "empty",
            "foo(*)[2,3]",
            "foo(a,b)[2,3]",
            "foo(b,c)[2,3]",
            "foo(*)[2]",
            "foo(*)[2,3]",
            "empty",
            
            "bar(*)",
            "empty",
            "empty",
            "empty",
            "empty",
            "empty",
            "empty",
            "bar(*)"])
    }
    
    func testSelectStatement() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute("CREATE TABLE foo (id INTEGER, name TEXT)")
            try db.execute("CREATE TABLE bar (id INTEGER, fooId INTEGER)")
            
            do {
                let statement = try db.makeSelectStatement("SELECT foo.name FROM FOO JOIN BAR ON fooId = foo.id")
                let expectedSelectionInfo = DatabaseSelectionInfo(table: "foo", columns: ["name", "id"])
                    .union(DatabaseSelectionInfo(table: "bar", columns: ["fooId"]))
                XCTAssertEqual(statement.selectionInfo, expectedSelectionInfo)
                XCTAssertEqual(statement.selectionInfo.description, "bar(fooId),foo(id,name)")
            }
            do {
                let statement = try db.makeSelectStatement("SELECT COUNT(*) FROM foo")
                if sqlite3_libversion_number() < 3019000 {
                    let expectedSelectionInfo = DatabaseSelectionInfo.fullDatabase
                    XCTAssertEqual(statement.selectionInfo, expectedSelectionInfo)
                    XCTAssertEqual(statement.selectionInfo.description, "full database")
                } else {
                    let expectedSelectionInfo = DatabaseSelectionInfo(table: "foo")
                    XCTAssertEqual(statement.selectionInfo, expectedSelectionInfo)
                    XCTAssertEqual(statement.selectionInfo.description, "foo(*)")
                }
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
                try XCTAssertEqual(request.selectionInfo(db).description, "foo(a,id)")
            }
            do {
                let request = Record.filter(Column("a") == 1)
                try XCTAssertEqual(request.selectionInfo(db).description, "foo(a,id)")
            }
            do {
                let request = Record.filter(Column("id") >= 1)
                try XCTAssertEqual(request.selectionInfo(db).description, "foo(a,id)")
            }
            
            do {
                let request = Record.filter((Column("id") == 1) || (Column("a") == "foo"))
                try XCTAssertEqual(request.selectionInfo(db).description, "foo(a,id)")
            }

            // No rowId
            
            do {
                let request = Record.filter(Column("id") == nil)
                try XCTAssertEqual(request.selectionInfo(db).description, "empty")
            }

            do {
                let request = Record.filter(Column("id") === nil)
                try XCTAssertEqual(request.selectionInfo(db).description, "empty")
            }
            
            do {
                let request = Record.filter(nil == Column("id"))
                try XCTAssertEqual(request.selectionInfo(db).description, "empty")
            }
            
            do {
                let request = Record.filter(nil === Column("id"))
                try XCTAssertEqual(request.selectionInfo(db).description, "empty")
            }
            
            do {
                let request = Record.filter((Column("id") == 1) && (Column("id") == 2))
                try XCTAssertEqual(request.selectionInfo(db).description, "empty")
            }
            do {
                let request = Record.filter(key: 1).filter(key: 2)
                try XCTAssertEqual(request.selectionInfo(db).description, "empty")
            }

            // Single rowId
            
            do {
                let request = Record.filter(Column("id") == 1)
                try XCTAssertEqual(request.selectionInfo(db).description, "foo(a,id)[1]")
            }
            do {
                let request = Record.filter(Column("id") === 1)
                try XCTAssertEqual(request.selectionInfo(db).description, "foo(a,id)[1]")
            }
            do {
                let request = Record.filter(Column("id") == 1 && Column("a") == "foo")
                try XCTAssertEqual(request.selectionInfo(db).description, "foo(a,id)[1]")
            }
            do {
                let request = Record.filter(Column.rowID == 1)
                try XCTAssertEqual(request.selectionInfo(db).description, "foo(a,id)[1]")
            }
            do {
                let request = Record.filter(1 == Column("id"))
                try XCTAssertEqual(request.selectionInfo(db).description, "foo(a,id)[1]")
            }
            do {
                let request = Record.filter(1 === Column("id"))
                try XCTAssertEqual(request.selectionInfo(db).description, "foo(a,id)[1]")
            }
            do {
                let request = Record.filter(1 === Column.rowID)
                try XCTAssertEqual(request.selectionInfo(db).description, "foo(a,id)[1]")
            }
            do {
                let request = Record.filter(key: 1)
                try XCTAssertEqual(request.selectionInfo(db).description, "foo(a,id)[1]")
            }
            do {
                let request = Record.filter(key: 1).filter(key: 1)
                try XCTAssertEqual(request.selectionInfo(db).description, "foo(a,id)[1]")
            }
            do {
                let request = Record.filter(key: 1).filter(Column("a") == "foo")
                try XCTAssertEqual(request.selectionInfo(db).description, "foo(a,id)[1]")
            }

            // Multiple rowIds
            
            do {
                let request = Record.filter(Column("id") == 1 || Column.rowID == 2)
                try XCTAssertEqual(request.selectionInfo(db).description, "foo(a,id)[1,2]")
            }
            do {
                let request = Record.filter([1, 2, 3].contains(Column("id")))
                try XCTAssertEqual(request.selectionInfo(db).description, "foo(a,id)[1,2,3]")
            }
            do {
                let request = Record.filter([1, 2, 3].contains(Column.rowID))
                try XCTAssertEqual(request.selectionInfo(db).description, "foo(a,id)[1,2,3]")
            }
            do {
                let request = Record.filter(keys: [1, 2, 3])
                try XCTAssertEqual(request.selectionInfo(db).description, "foo(a,id)[1,2,3]")
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
