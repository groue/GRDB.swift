import XCTest
#if GRDBCUSTOMSQLITE
    @testable import GRDBCustomSQLite
#else
    #if GRDBCIPHER
        import SQLCipher
    #elseif SWIFT_PACKAGE
        import CSQLite
    #else
        import SQLite3
    #endif
    @testable import GRDB
#endif

class DatabaseRegionTests : GRDBTestCase {
    
    func testRegionEquatable() {
        // An array of distinct selection infos
        let regions = [
            DatabaseRegion.fullDatabase,
            DatabaseRegion(),
            DatabaseRegion(table: "foo"),
            DatabaseRegion(table: "FOO"), // selection info is case-sensitive on table name
            DatabaseRegion(table: "foo", columns: ["a", "b"]),
            DatabaseRegion(table: "foo", columns: ["A", "B"]), // selection info is case-sensitive on columns names
            DatabaseRegion(table: "foo", columns: ["b", "c"]),
            DatabaseRegion(table: "foo", rowIds: [1, 2]),
            DatabaseRegion(table: "foo", rowIds: [2, 3]),
            DatabaseRegion(table: "bar")]
        
        for (i1, s1) in regions.enumerated() {
            for (i2, s2) in regions.enumerated() {
                if i1 == i2 {
                    XCTAssertEqual(s1, s2)
                } else {
                    XCTAssertNotEqual(s1, s2)
                }
            }
        }
    }
    
    func testRegionUnion() {
        let regions = [
            DatabaseRegion.fullDatabase,
            DatabaseRegion(),
            DatabaseRegion(table: "foo"),
            DatabaseRegion(table: "foo", columns: ["a", "b"]),
            DatabaseRegion(table: "foo", columns: ["b", "c"]),
            DatabaseRegion(table: "foo", rowIds: [1, 2]),
            DatabaseRegion(table: "foo", rowIds: [2, 3]),
            DatabaseRegion(table: "bar")]
        
        var unions: [DatabaseRegion] = []
        for s1 in regions {
            for s2 in regions {
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
    
    func testRegionUnionOfColumnsAndRows() {
        let regions = [
            DatabaseRegion(table: "foo", columns: ["a"]).intersection(DatabaseRegion(table: "foo", rowIds: [1])),
            DatabaseRegion(table: "foo", columns: ["b"]).intersection(DatabaseRegion(table: "foo", rowIds: [2])),
            ]
        
        var unions: [DatabaseRegion] = []
        for s1 in regions {
            for s2 in regions {
                unions.append(s1.union(s2))
            }
        }
        
        XCTAssertEqual(unions.map { $0.description }, ["foo(a)[1]", "foo(a,b)[1,2]", "foo(a,b)[1,2]", "foo(b)[2]"])
    }
    
    func testRegionIntersection() {
        let regions = [
            DatabaseRegion.fullDatabase,
            DatabaseRegion(),
            DatabaseRegion(table: "foo"),
            DatabaseRegion(table: "foo", columns: ["a", "b"]),
            DatabaseRegion(table: "foo", columns: ["b", "c"]),
            DatabaseRegion(table: "foo", rowIds: [1, 2]),
            DatabaseRegion(table: "foo", rowIds: [2, 3]),
            DatabaseRegion(table: "bar")]
        
        var intersection: [DatabaseRegion] = []
        for s1 in regions {
            for s2 in regions {
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
    
    func testRegionIntersectionOfColumnsAndRows() {
        let regions = [
            DatabaseRegion(table: "foo", columns: ["a"]).intersection(DatabaseRegion(table: "foo", rowIds: [1])),
            DatabaseRegion(table: "foo", columns: ["b"]).intersection(DatabaseRegion(table: "foo", rowIds: [2])),
            ]
        
        var intersection: [DatabaseRegion] = []
        for s1 in regions {
            for s2 in regions {
                intersection.append(s1.intersection(s2))
            }
        }
        
        XCTAssertEqual(intersection.map { $0.description }, ["foo(a)[1]", "empty", "empty", "foo(b)[2]"])
    }

    func testSelectStatement() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(sql: "CREATE TABLE foo (id INTEGER, name TEXT)")
            try db.execute(sql: "CREATE TABLE bar (id INTEGER, fooId INTEGER)")
            
            do {
                let statement = try db.makeSelectStatement(sql: "SELECT foo.name FROM FOO JOIN BAR ON fooId = foo.id")
                let expectedRegion = DatabaseRegion(table: "foo", columns: ["name", "id"])
                    .union(DatabaseRegion(table: "bar", columns: ["fooId"]))
                XCTAssertEqual(statement.databaseRegion, expectedRegion)
                XCTAssertEqual(statement.databaseRegion.description, "bar(fooId),foo(id,name)")
            }
            do {
                let statement = try db.makeSelectStatement(sql: "SELECT COUNT(*) FROM foo")
                if sqlite3_libversion_number() < 3019000 {
                    let expectedRegion = DatabaseRegion.fullDatabase
                    XCTAssertEqual(statement.databaseRegion, expectedRegion)
                    XCTAssertEqual(statement.databaseRegion.description, "full database")
                } else {
                    let expectedRegion = DatabaseRegion(table: "foo")
                    XCTAssertEqual(statement.databaseRegion, expectedRegion)
                    XCTAssertEqual(statement.databaseRegion.description, "foo(*)")
                }
            }
        }
    }
    
    func testRegionRowIds() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(sql: "CREATE TABLE foo (id INTEGER PRIMARY KEY, a TEXT)")
            struct Record: TableRecord {
                static let databaseTableName = "foo"
            }
            
            // Undefined rowIds
            
            do {
                let request = Record.all()
                try XCTAssertEqual(request.databaseRegion(db).description, "foo(a,id)")
            }
            do {
                let request = Record.filter(Column("a") == 1)
                try XCTAssertEqual(request.databaseRegion(db).description, "foo(a,id)")
            }
            do {
                let request = Record.filter(Column("id") >= 1)
                try XCTAssertEqual(request.databaseRegion(db).description, "foo(a,id)")
            }
            
            do {
                let request = Record.filter((Column("id") == 1) || (Column("a") == "foo"))
                try XCTAssertEqual(request.databaseRegion(db).description, "foo(a,id)")
            }

            // No rowId
            
            do {
                let request = Record.filter(Column("id") == nil)
                try XCTAssertEqual(request.databaseRegion(db).description, "empty")
            }

            do {
                let request = Record.filter(Column("id") === nil)
                try XCTAssertEqual(request.databaseRegion(db).description, "empty")
            }
            
            do {
                let request = Record.filter(nil == Column("id"))
                try XCTAssertEqual(request.databaseRegion(db).description, "empty")
            }
            
            do {
                let request = Record.filter(nil === Column("id"))
                try XCTAssertEqual(request.databaseRegion(db).description, "empty")
            }
            
            do {
                let request = Record.filter((Column("id") == 1) && (Column("id") == 2))
                try XCTAssertEqual(request.databaseRegion(db).description, "empty")
            }
            do {
                let request = Record.filter(key: 1).filter(key: 2)
                try XCTAssertEqual(request.databaseRegion(db).description, "empty")
            }

            // Single rowId
            
            do {
                let request = Record.filter(Column("id") == 1)
                try XCTAssertEqual(request.databaseRegion(db).description, "foo(a,id)[1]")
            }
            do {
                let request = Record.filter(Column("id") === 1)
                try XCTAssertEqual(request.databaseRegion(db).description, "foo(a,id)[1]")
            }
            do {
                let request = Record.filter(Column("id") == 1 && Column("a") == "foo")
                try XCTAssertEqual(request.databaseRegion(db).description, "foo(a,id)[1]")
            }
            do {
                let request = Record.filter(Column.rowID == 1)
                try XCTAssertEqual(request.databaseRegion(db).description, "foo(a,id)[1]")
            }
            do {
                let request = Record.filter(1 == Column("id"))
                try XCTAssertEqual(request.databaseRegion(db).description, "foo(a,id)[1]")
            }
            do {
                let request = Record.filter(1 === Column("id"))
                try XCTAssertEqual(request.databaseRegion(db).description, "foo(a,id)[1]")
            }
            do {
                let request = Record.filter(1 === Column.rowID)
                try XCTAssertEqual(request.databaseRegion(db).description, "foo(a,id)[1]")
            }
            do {
                let request = Record.filter(key: 1)
                try XCTAssertEqual(request.databaseRegion(db).description, "foo(a,id)[1]")
            }
            do {
                let request = Record.filter(key: 1).filter(key: 1)
                try XCTAssertEqual(request.databaseRegion(db).description, "foo(a,id)[1]")
            }
            do {
                let request = Record.filter(key: 1).filter(Column("a") == "foo")
                try XCTAssertEqual(request.databaseRegion(db).description, "foo(a,id)[1]")
            }

            // Multiple rowIds
            
            do {
                let request = Record.filter(Column("id") == 1 || Column.rowID == 2)
                try XCTAssertEqual(request.databaseRegion(db).description, "foo(a,id)[1,2]")
            }
            do {
                let request = Record.filter((Column("id") == 1 && Column("a") == "foo") || Column.rowID == 2)
                try XCTAssertEqual(request.databaseRegion(db).description, "foo(a,id)[1,2]")
            }
            do {
                let request = Record.filter([1, 2, 3].contains(Column("id")))
                try XCTAssertEqual(request.databaseRegion(db).description, "foo(a,id)[1,2,3]")
            }
            do {
                let request = Record.filter([1, 2, 3].contains(Column.rowID))
                try XCTAssertEqual(request.databaseRegion(db).description, "foo(a,id)[1,2,3]")
            }
            do {
                let request = Record.filter(keys: [1, 2, 3])
                try XCTAssertEqual(request.databaseRegion(db).description, "foo(a,id)[1,2,3]")
            }
        }
    }
    
    func testDatabaseRegionOfJoinedRequests() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(sql: "CREATE TABLE a (id INTEGER PRIMARY KEY, name TEXT)")
            try db.execute(sql: "CREATE TABLE b (id INTEGER PRIMARY KEY, name TEXT, aid INTEGER REFERENCES a(id))")
            try db.execute(sql: "CREATE TABLE c (id INTEGER PRIMARY KEY, name TEXT, aid INTEGER REFERENCES a(id))")
            struct A: TableRecord {
                static let databaseTableName = "a"
                static let b = hasOne(B.self)
                static let c = hasMany(C.self)
            }
            struct B: TableRecord {
                static let databaseTableName = "b"
                static let a = belongsTo(A.self)
            }
            struct C: TableRecord {
                static let databaseTableName = "c"
            }
            do {
                let request = A.filter(key: 1)
                    .including(optional: A.b.filter(key: 2))
                    .including(optional: A.c.filter(keys: [1, 2, 3]))
                // This test will fail when we are able to improve regions of joined requestt
                try XCTAssertEqual(request.databaseRegion(db).description, "a(id,name)[1],b(aid,id,name),c(aid,id,name)")
            }
            do {
                let request = B.filter(key: 1)
                    .including(optional: B.a.filter(key: 2)
                        .including(optional: A.c.filter(keys: [1, 2, 3])))
                // This test will fail when we are able to improve regions of joined requestt
                try XCTAssertEqual(request.databaseRegion(db).description, "a(id,name),b(aid,id,name)[1],c(aid,id,name)")
            }
        }
    }
    
    func testDatabaseRegionOfDerivedRequests() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(sql: "CREATE TABLE foo (id INTEGER PRIMARY KEY, a TEXT)")
            struct Record: TableRecord {
                static let databaseTableName = "foo"
            }
            
            let request = Record.filter(keys: [1, 2, 3])
            try XCTAssertEqual(request.databaseRegion(db).description, "foo(a,id)[1,2,3]")

            do {
                let derivedRequest: AnyFetchRequest<Row> = AnyFetchRequest(request)
                try XCTAssertEqual(derivedRequest.databaseRegion(db).description, "foo(a,id)[1,2,3]")
            }
            do {
                let derivedRequest: AdaptedFetchRequest = request.adapted { db in SuffixRowAdapter(fromIndex: 1) }
                try XCTAssertEqual(derivedRequest.databaseRegion(db).description, "foo(a,id)[1,2,3]")
            }
            do {
                // SQL request loses region info
                let derivedRequest = try SQLRequest(db, request: request)
                try XCTAssertEqual(derivedRequest.databaseRegion(db).description, "foo(a,id)")
            }
        }
    }
    
    func testUpdateStatement() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(sql: "CREATE TABLE foo (id INTEGER, bar TEXT, baz TEXT, qux TEXT)")
            let statement = try db.makeUpdateStatement(sql: "UPDATE foo SET bar = 'bar', baz = 'baz' WHERE id = 1")
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
    
    func testRowIdNameInSelectStatement() throws {
        // Here we test that sqlite authorizer gives the "ROWID" name to
        // the rowid column, regardless of its name in the request (rowid, oid, _rowid_)
        //
        // See also testRowIdNameInUpdateStatement
        
        guard sqlite3_libversion_number() < 3019003 else {
            // This test fails on SQLite 3.19.3 (iOS 11.2) and SQLite 3.21.0 (custom build),
            // but succeeds on SQLite 3.16.0 (iOS 10.3.1).
            // TODO: evaluate the consequences
            return
        }
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(sql: "CREATE TABLE foo (name TEXT)")
            do {
                let statement = try db.makeSelectStatement(sql: "SELECT rowid FROM FOO")
                let expectedRegion = DatabaseRegion(table: "foo", columns: ["ROWID"])
                XCTAssertEqual(statement.databaseRegion, expectedRegion)
                XCTAssertEqual(statement.databaseRegion.description, "foo(ROWID)")
            }
            do {
                let statement = try db.makeSelectStatement(sql: "SELECT _ROWID_ FROM FOO")
                let expectedRegion = DatabaseRegion(table: "foo", columns: ["ROWID"])
                XCTAssertEqual(statement.databaseRegion, expectedRegion)
                XCTAssertEqual(statement.databaseRegion.description, "foo(ROWID)")
            }
            do {
                let statement = try db.makeSelectStatement(sql: "SELECT oID FROM FOO")
                let expectedRegion = DatabaseRegion(table: "foo", columns: ["ROWID"])
                XCTAssertEqual(statement.databaseRegion, expectedRegion)
                XCTAssertEqual(statement.databaseRegion.description, "foo(ROWID)")
            }
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
            try db.execute(sql: "CREATE TABLE foo (name TEXT)")
            do {
                let statement = try db.makeUpdateStatement(sql: "UPDATE foo SET rowid = 1")
                XCTAssertEqual(statement.databaseEventKinds.count, 1)
                guard case .update(let tableName, let columnNames) = statement.databaseEventKinds[0] else {
                    XCTFail()
                    return
                }
                XCTAssertEqual(tableName, "foo")
                XCTAssertEqual(columnNames, ["ROWID"])
            }
            do {
                let statement = try db.makeUpdateStatement(sql: "UPDATE foo SET _ROWID_ = 1")
                XCTAssertEqual(statement.databaseEventKinds.count, 1)
                guard case .update(let tableName, let columnNames) = statement.databaseEventKinds[0] else {
                    XCTFail()
                    return
                }
                XCTAssertEqual(tableName, "foo")
                XCTAssertEqual(columnNames, ["ROWID"])
            }
            do {
                let statement = try db.makeUpdateStatement(sql: "UPDATE foo SET oID = 1")
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
            try db.execute(sql: "CREATE TABLE foo (id INTEGER, bar TEXT, baz TEXT, qux TEXT)")
            let statement = try db.makeUpdateStatement(sql: "INSERT INTO foo (id, bar) VALUES (1, 'bar')")
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
            try db.execute(sql: "CREATE TABLE foo (id INTEGER, bar TEXT, baz TEXT, qux TEXT)")
            let statement = try db.makeUpdateStatement(sql: "DELETE FROM foo")
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
                let statement = try db.makeUpdateStatement(sql: "CREATE TABLE foo (id INTEGER)")
                XCTAssertTrue(statement.invalidatesDatabaseSchemaCache)
                try statement.execute()
            }
            do {
                let statement = try db.makeUpdateStatement(sql: "ALTER TABLE foo ADD COLUMN name TEXT")
                XCTAssertTrue(statement.invalidatesDatabaseSchemaCache)
            }
            do {
                let statement = try db.makeUpdateStatement(sql: "DROP TABLE foo")
                XCTAssertTrue(statement.invalidatesDatabaseSchemaCache)
            }
        }
    }
    
    func testRegionIsModifiedByDatabaseEvent() {
        do {
            // Empty selection
            let region = DatabaseRegion()
            XCTAssertEqual(region.description, "empty")
            
            do {
                let eventKind = DatabaseEventKind.insert(tableName: "foo")
                XCTAssertFalse(region.isModified(byEventsOfKind: eventKind))
                // Can't test for individual events due to DatabaseRegion.isModified(by:) precondition
            }

            do {
                let eventKind = DatabaseEventKind.delete(tableName: "foo")
                XCTAssertFalse(region.isModified(byEventsOfKind: eventKind))
                // Can't test for individual events due to DatabaseRegion.isModified(by:) precondition
            }
            
            do {
                let eventKind = DatabaseEventKind.update(tableName: "foo", columnNames: ["a", "b"])
                XCTAssertFalse(region.isModified(byEventsOfKind: eventKind))
                // Can't test for individual events due to DatabaseRegion.isModified(by:) precondition
            }
        }
        
        do {
            // Full database selection
            let region = DatabaseRegion.fullDatabase
            XCTAssertEqual(region.description, "full database")
            
            do {
                let tableName = "foo"
                tableName.withCString { tableNameCString in
                    let eventKind = DatabaseEventKind.insert(tableName: tableName)
                    let event = DatabaseEvent(kind: .insert, rowID: 1, databaseNameCString: nil, tableNameCString: tableNameCString)
                    XCTAssertTrue(region.isModified(byEventsOfKind: eventKind))
                    XCTAssertTrue(region.isModified(by: event))
                }
            }
            
            do {
                let tableName = "foo"
                tableName.withCString { tableNameCString in
                    let eventKind = DatabaseEventKind.delete(tableName: tableName)
                    let event = DatabaseEvent(kind: .delete, rowID: 1, databaseNameCString: nil, tableNameCString: tableNameCString)
                    XCTAssertTrue(region.isModified(byEventsOfKind: eventKind))
                    XCTAssertTrue(region.isModified(by: event))
                }
            }
            
            do {
                let tableName = "foo"
                tableName.withCString { tableNameCString in
                    let eventKind = DatabaseEventKind.update(tableName: tableName, columnNames: ["a", "b"])
                    let event = DatabaseEvent(kind: .update, rowID: 1, databaseNameCString: nil, tableNameCString: tableNameCString)
                    XCTAssertTrue(region.isModified(byEventsOfKind: eventKind))
                    XCTAssertTrue(region.isModified(by: event))
                }
            }
        }
        
        do {
            // Complex selection
            let region = DatabaseRegion(table: "foo")
                .union(DatabaseRegion(table: "bar", columns: ["a"])
                    .intersection(DatabaseRegion(table: "bar", rowIds: [1])))
            XCTAssertEqual(region.description, "bar(a)[1],foo(*)")
            
            do {
                let tableName = "foo"
                tableName.withCString { tableNameCString in
                    let eventKind = DatabaseEventKind.insert(tableName: tableName)
                    let event1 = DatabaseEvent(kind: .insert, rowID: 1, databaseNameCString: nil, tableNameCString: tableNameCString)
                    let event2 = DatabaseEvent(kind: .insert, rowID: 2, databaseNameCString: nil, tableNameCString: tableNameCString)
                    XCTAssertTrue(region.isModified(byEventsOfKind: eventKind))
                    XCTAssertTrue(region.isModified(by: event1))
                    XCTAssertTrue(region.isModified(by: event2))
                }
            }
            
            do {
                let tableName = "foo"
                tableName.withCString { tableNameCString in
                    let eventKind = DatabaseEventKind.delete(tableName: tableName)
                    let event1 = DatabaseEvent(kind: .delete, rowID: 1, databaseNameCString: nil, tableNameCString: tableNameCString)
                    let event2 = DatabaseEvent(kind: .delete, rowID: 2, databaseNameCString: nil, tableNameCString: tableNameCString)
                    XCTAssertTrue(region.isModified(byEventsOfKind: eventKind))
                    XCTAssertTrue(region.isModified(by: event1))
                    XCTAssertTrue(region.isModified(by: event2))
                }
            }
            
            do {
                let tableName = "foo"
                tableName.withCString { tableNameCString in
                    let eventKind = DatabaseEventKind.update(tableName: tableName, columnNames: ["a", "b"])
                    let event1 = DatabaseEvent(kind: .update, rowID: 1, databaseNameCString: nil, tableNameCString: tableNameCString)
                    let event2 = DatabaseEvent(kind: .update, rowID: 2, databaseNameCString: nil, tableNameCString: tableNameCString)
                    XCTAssertTrue(region.isModified(byEventsOfKind: eventKind))
                    XCTAssertTrue(region.isModified(by: event1))
                    XCTAssertTrue(region.isModified(by: event2))
                }
            }
            
            do {
                let tableName = "bar"
                tableName.withCString { tableNameCString in
                    let eventKind = DatabaseEventKind.insert(tableName: tableName)
                    let event1 = DatabaseEvent(kind: .insert, rowID: 1, databaseNameCString: nil, tableNameCString: tableNameCString)
                    let event2 = DatabaseEvent(kind: .insert, rowID: 2, databaseNameCString: nil, tableNameCString: tableNameCString)
                    XCTAssertTrue(region.isModified(byEventsOfKind: eventKind))
                    XCTAssertTrue(region.isModified(by: event1))
                    XCTAssertFalse(region.isModified(by: event2))
                }
            }
            
            do {
                let tableName = "bar"
                tableName.withCString { tableNameCString in
                    let eventKind = DatabaseEventKind.delete(tableName: tableName)
                    let event1 = DatabaseEvent(kind: .delete, rowID: 1, databaseNameCString: nil, tableNameCString: tableNameCString)
                    let event2 = DatabaseEvent(kind: .delete, rowID: 2, databaseNameCString: nil, tableNameCString: tableNameCString)
                    XCTAssertTrue(region.isModified(byEventsOfKind: eventKind))
                    XCTAssertTrue(region.isModified(by: event1))
                    XCTAssertFalse(region.isModified(by: event2))
                }
            }
            
            do {
                let tableName = "bar"
                tableName.withCString { tableNameCString in
                    let eventKind = DatabaseEventKind.update(tableName: tableName, columnNames: ["a", "b"])
                    let event1 = DatabaseEvent(kind: .update, rowID: 1, databaseNameCString: nil, tableNameCString: tableNameCString)
                    let event2 = DatabaseEvent(kind: .update, rowID: 2, databaseNameCString: nil, tableNameCString: tableNameCString)
                    XCTAssertTrue(region.isModified(byEventsOfKind: eventKind))
                    XCTAssertTrue(region.isModified(by: event1))
                    XCTAssertFalse(region.isModified(by: event2))
                }
            }
            
            do {
                let eventKind = DatabaseEventKind.update(tableName: "bar", columnNames: ["b", "c"])
                XCTAssertFalse(region.isModified(byEventsOfKind: eventKind))
                // Can't test for individual events due to DatabaseRegion.isModified(by:) precondition
            }
            
            do {
                let eventKind = DatabaseEventKind.insert(tableName: "qux")
                XCTAssertFalse(region.isModified(byEventsOfKind: eventKind))
                // Can't test for individual events due to DatabaseRegion.isModified(by:) precondition
            }
            
            do {
                let eventKind = DatabaseEventKind.delete(tableName: "qux")
                XCTAssertFalse(region.isModified(byEventsOfKind: eventKind))
                // Can't test for individual events due to DatabaseRegion.isModified(by:) precondition
            }
            
            do {
                let eventKind = DatabaseEventKind.update(tableName: "qux", columnNames: ["a", "b"])
                XCTAssertFalse(region.isModified(byEventsOfKind: eventKind))
                // Can't test for individual events due to DatabaseRegion.isModified(by:) precondition
            }
        }
    }
    
    // Regression test for https://github.com/groue/GRDB.swift/issues/514
    func testIssue514() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.execute(sql: """
                CREATE TABLE a (id INTEGER PRIMARY KEY, name TEXT);
                CREATE TABLE b (id TEXT, name TEXT);
                """)
            
            // INTEGER PRIMARY KEY
            do {
                // TODO: contact SQLite and ask if this test is expected to fail
//                let statement = try db.makeSelectStatement(sql: "SELECT id FROM a")
//                let expectedRegion = DatabaseRegion(table: "a", columns: ["id"])
//                XCTAssertEqual(statement.databaseRegion, expectedRegion)
            }
            do {
                let statement = try db.makeSelectStatement(sql: "SELECT name FROM a")
                let expectedRegion = DatabaseRegion(table: "a", columns: ["name"])
                XCTAssertEqual(statement.databaseRegion, expectedRegion)
            }
            do {
                let statement = try db.makeSelectStatement(sql: "SELECT id, name FROM a")
                let expectedRegion = DatabaseRegion(table: "a", columns: ["id", "name"])
                XCTAssertEqual(statement.databaseRegion, expectedRegion)
            }
            
            // TEXT primary key
            do {
                let statement = try db.makeSelectStatement(sql: "SELECT id FROM b")
                let expectedRegion = DatabaseRegion(table: "b", columns: ["id"])
                XCTAssertEqual(statement.databaseRegion, expectedRegion)
            }
            do {
                let statement = try db.makeSelectStatement(sql: "SELECT name FROM b")
                let expectedRegion = DatabaseRegion(table: "b", columns: ["name"])
                XCTAssertEqual(statement.databaseRegion, expectedRegion)
            }
            do {
                let statement = try db.makeSelectStatement(sql: "SELECT id, name FROM b")
                let expectedRegion = DatabaseRegion(table: "b", columns: ["id", "name"])
                XCTAssertEqual(statement.databaseRegion, expectedRegion)
            }
        }
    }
}
