import XCTest
#if GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class DatabaseErrorTests: GRDBTestCase {
    
    func testDatabaseErrorMessage() {
        // Error messages are not always available
        if #available(iOS 8.2, OSX 10.10, OSXApplicationExtension 10.10, iOSApplicationExtension 8.2, *) {
            // We don't test for actual messages, since they may depend on SQLite version
            XCTAssertEqual(DatabaseError().resultCode, .SQLITE_ERROR)
            XCTAssertNotNil(DatabaseError().message)
            XCTAssertNotNil(DatabaseError(resultCode: .SQLITE_BUSY).message)
            XCTAssertNotEqual(DatabaseError().message, DatabaseError(resultCode: .SQLITE_BUSY).message)
        }
    }
    
    func testDatabaseErrorInTransaction() throws {
        let dbQueue = try makeDatabaseQueue()
        do {
            try dbQueue.inTransaction { db in
                try db.execute(sql: "CREATE TABLE persons (id INTEGER PRIMARY KEY)")
                try db.execute(sql: "CREATE TABLE pets (masterId INTEGER NOT NULL REFERENCES persons(id), name TEXT)")
                sqlQueries.removeAll()
                try db.execute(sql: "INSERT INTO pets (masterId, name) VALUES (?, ?)", arguments: [1, "Bobby"])
                XCTFail()
                return .commit
            }
        } catch let error as DatabaseError {
            // SQLITE_CONSTRAINT_FOREIGNKEY was added in SQLite 3.7.16 http://www.sqlite.org/changes.html#version_3_7_16
            // It is available from iOS 8.2 and OS X 10.10 https://github.com/yapstudios/YapDatabase/wiki/SQLite-version-(bundled-with-OS)
            XCTAssert((error.resultCode == error.extendedResultCode) || error.extendedResultCode == .SQLITE_CONSTRAINT_FOREIGNKEY)
            XCTAssertEqual(error.resultCode, .SQLITE_CONSTRAINT)
            XCTAssertEqual(error.message!.lowercased(), "foreign key constraint failed") // lowercased: accept multiple SQLite version
            XCTAssertEqual(error.sql!, "INSERT INTO pets (masterId, name) VALUES (?, ?)")
            // SQLITE_CONSTRAINT_FOREIGNKEY was added in SQLite 3.7.16 http://www.sqlite.org/changes.html#version_3_7_16
            // It is available from iOS 8.2 and OS X 10.10 https://github.com/yapstudios/YapDatabase/wiki/SQLite-version-(bundled-with-OS)
            XCTAssertEqual(error.description.lowercased(), "sqlite error 19 with statement `insert into pets (masterid, name) values (?, ?)` arguments [1, \"bobby\"]: foreign key constraint failed")
            
            XCTAssertEqual(sqlQueries.count, 2)
            XCTAssertEqual(sqlQueries[0], "INSERT INTO pets (masterId, name) VALUES (1, 'Bobby')")
            XCTAssertEqual(sqlQueries[1], "ROLLBACK TRANSACTION")
        }
    }

    func testDatabaseErrorInTopLevelSavepoint() throws {
        let dbQueue = try makeDatabaseQueue()
        do {
            try dbQueue.writeWithoutTransaction { db in
                do {
                    try db.inSavepoint {
                        XCTAssertTrue(db.isInsideTransaction)
                        try db.execute(sql: "CREATE TABLE persons (id INTEGER PRIMARY KEY)")
                        try db.execute(sql: "CREATE TABLE pets (masterId INTEGER NOT NULL REFERENCES persons(id), name TEXT)")
                        sqlQueries.removeAll()
                        try db.execute(sql: "INSERT INTO pets (masterId, name) VALUES (?, ?)", arguments: [1, "Bobby"])
                        XCTFail()
                        return .commit
                    }
                    XCTFail()
                } catch {
                    XCTAssertFalse(db.isInsideTransaction)
                    throw error
                }
            }
        } catch let error as DatabaseError {
            // SQLITE_CONSTRAINT_FOREIGNKEY was added in SQLite 3.7.16 http://www.sqlite.org/changes.html#version_3_7_16
            // It is available from iOS 8.2 and OS X 10.10 https://github.com/yapstudios/YapDatabase/wiki/SQLite-version-(bundled-with-OS)
            XCTAssert((error.resultCode == error.extendedResultCode) || error.extendedResultCode == .SQLITE_CONSTRAINT_FOREIGNKEY)
            XCTAssertEqual(error.resultCode, .SQLITE_CONSTRAINT)
            XCTAssertEqual(error.message!.lowercased(), "foreign key constraint failed") // lowercased: accept multiple SQLite version
            XCTAssertEqual(error.sql!, "INSERT INTO pets (masterId, name) VALUES (?, ?)")
            XCTAssertEqual(error.description.lowercased(), "sqlite error 19 with statement `insert into pets (masterid, name) values (?, ?)` arguments [1, \"bobby\"]: foreign key constraint failed")
        }
    }

    func testDatabaseErrorThrownByUpdateStatementContainSQLAndArguments() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(sql: "CREATE TABLE persons (id INTEGER PRIMARY KEY)")
            try db.execute(sql: "CREATE TABLE pets (masterId INTEGER NOT NULL REFERENCES persons(id), name TEXT)")
        }
        
        // db.execute(sql, arguments)
        try dbQueue.inDatabase { db in
            do {
                try db.execute(sql: "INSERT INTO pets (masterId, name) VALUES (?, ?)", arguments: [1, "Bobby"])
                XCTFail()
            } catch let error as DatabaseError {
                // SQLITE_CONSTRAINT_FOREIGNKEY was added in SQLite 3.7.16 http://www.sqlite.org/changes.html#version_3_7_16
                // It is available from iOS 8.2 and OS X 10.10 https://github.com/yapstudios/YapDatabase/wiki/SQLite-version-(bundled-with-OS)
                XCTAssert((error.resultCode == error.extendedResultCode) || error.extendedResultCode == .SQLITE_CONSTRAINT_FOREIGNKEY)
                XCTAssertEqual(error.resultCode, .SQLITE_CONSTRAINT)
                XCTAssertEqual(error.message!.lowercased(), "foreign key constraint failed") // lowercased: accept multiple SQLite version
                XCTAssertEqual(error.sql!, "INSERT INTO pets (masterId, name) VALUES (?, ?)")
                XCTAssertEqual(error.description.lowercased(), "sqlite error 19 with statement `insert into pets (masterid, name) values (?, ?)` arguments [1, \"bobby\"]: foreign key constraint failed")
            }
        }
        
        // statement.execute(arguments)
        try dbQueue.inDatabase { db in
            do {
                let statement = try db.makeUpdateStatement(sql: "INSERT INTO pets (masterId, name) VALUES (?, ?)")
                try statement.execute(arguments: [1, "Bobby"])
                XCTFail()
            } catch let error as DatabaseError {
                // SQLITE_CONSTRAINT_FOREIGNKEY was added in SQLite 3.7.16 http://www.sqlite.org/changes.html#version_3_7_16
                // It is available from iOS 8.2 and OS X 10.10 https://github.com/yapstudios/YapDatabase/wiki/SQLite-version-(bundled-with-OS)
                XCTAssert((error.resultCode == error.extendedResultCode) || error.extendedResultCode == .SQLITE_CONSTRAINT_FOREIGNKEY)
                XCTAssertEqual(error.resultCode, .SQLITE_CONSTRAINT)
                XCTAssertEqual(error.message!.lowercased(), "foreign key constraint failed") // lowercased: accept multiple SQLite version
                XCTAssertEqual(error.sql!, "INSERT INTO pets (masterId, name) VALUES (?, ?)")
                XCTAssertEqual(error.description.lowercased(), "sqlite error 19 with statement `insert into pets (masterid, name) values (?, ?)` arguments [1, \"bobby\"]: foreign key constraint failed")
            }
        }
        
        // statement.execute()
        try dbQueue.inDatabase { db in
            do {
                let statement = try db.makeUpdateStatement(sql: "INSERT INTO pets (masterId, name) VALUES (?, ?)")
                statement.arguments = [1, "Bobby"]
                try statement.execute()
                XCTFail()
            } catch let error as DatabaseError {
                // SQLITE_CONSTRAINT_FOREIGNKEY was added in SQLite 3.7.16 http://www.sqlite.org/changes.html#version_3_7_16
                // It is available from iOS 8.2 and OS X 10.10 https://github.com/yapstudios/YapDatabase/wiki/SQLite-version-(bundled-with-OS)
                XCTAssert((error.resultCode == error.extendedResultCode) || error.extendedResultCode == .SQLITE_CONSTRAINT_FOREIGNKEY)
                XCTAssertEqual(error.resultCode, .SQLITE_CONSTRAINT)
                XCTAssertEqual(error.message!.lowercased(), "foreign key constraint failed") // lowercased: accept multiple SQLite version
                XCTAssertEqual(error.sql!, "INSERT INTO pets (masterId, name) VALUES (?, ?)")
                XCTAssertEqual(error.description.lowercased(), "sqlite error 19 with statement `insert into pets (masterid, name) values (?, ?)` arguments [1, \"bobby\"]: foreign key constraint failed")
            }
        }
    }

    func testDatabaseErrorThrownByExecuteMultiStatementContainSQL() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            do {
                try db.execute(sql: """
                    CREATE TABLE persons (id INTEGER PRIMARY KEY, name TEXT, age INT);
                    CREATE TABLE pets (masterId INTEGER NOT NULL REFERENCES persons(id), name TEXT);
                    INSERT INTO pets (masterId, name) VALUES (1, 'Bobby')
                    """)
                XCTFail()
            } catch let error as DatabaseError {
                // SQLITE_CONSTRAINT_FOREIGNKEY was added in SQLite 3.7.16 http://www.sqlite.org/changes.html#version_3_7_16
                // It is available from iOS 8.2 and OS X 10.10 https://github.com/yapstudios/YapDatabase/wiki/SQLite-version-(bundled-with-OS)
                XCTAssert((error.resultCode == error.extendedResultCode) || error.extendedResultCode == .SQLITE_CONSTRAINT_FOREIGNKEY)
                XCTAssertEqual(error.resultCode, .SQLITE_CONSTRAINT)
                XCTAssertEqual(error.message!.lowercased(), "foreign key constraint failed") // lowercased: accept multiple SQLite version
                XCTAssertEqual(error.sql!, "INSERT INTO pets (masterId, name) VALUES (1, 'Bobby')")
                XCTAssertEqual(error.description.lowercased(), "sqlite error 19 with statement `insert into pets (masterid, name) values (1, 'bobby')`: foreign key constraint failed")
            }
        }
    }

    func testExtendedResultCodesAreActivated() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "parents") { $0.column("id", .integer).primaryKey() }
            try db.create(table: "children") { $0.column("parentId", .integer).references("parents") }
            do {
                try db.execute(sql: "INSERT INTO children (parentId) VALUES (1)")
            } catch let error as DatabaseError {
                // SQLITE_CONSTRAINT_FOREIGNKEY was added in SQLite 3.7.16 http://www.sqlite.org/changes.html#version_3_7_16
                // It is available from iOS 8.2 and OS X 10.10 https://github.com/yapstudios/YapDatabase/wiki/SQLite-version-(bundled-with-OS)
                XCTAssert((error.resultCode == error.extendedResultCode) || error.extendedResultCode == .SQLITE_CONSTRAINT_FOREIGNKEY)
                XCTAssertEqual(error.resultCode.rawValue, 19)           // primary SQLITE_CONSTRAINT
            }
        }
    }
    
    func testNSErrorBridging() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "parents") { $0.column("id", .integer).primaryKey() }
            try db.create(table: "children") { $0.column("parentId", .integer).references("parents") }
            do {
                try db.execute(sql: "INSERT INTO children (parentId) VALUES (1)")
            } catch let error as NSError {
                XCTAssertEqual(DatabaseError.errorDomain, "GRDB.DatabaseError")
                XCTAssertEqual(error.domain, DatabaseError.errorDomain)
                // SQLITE_CONSTRAINT_FOREIGNKEY was added in SQLite 3.7.16 http://www.sqlite.org/changes.html#version_3_7_16
                // It is available from iOS 8.2 and OS X 10.10 https://github.com/yapstudios/YapDatabase/wiki/SQLite-version-(bundled-with-OS)
                XCTAssert([19, 787].contains(error.code))
            }
        }
    }

}
