import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class DatabaseErrorTests: GRDBTestCase {
    
    func testDatabaseErrorInTransaction() throws {
        let dbQueue = try makeDatabaseQueue()
        do {
            try dbQueue.inTransaction { db in
                try db.execute("CREATE TABLE persons (id INTEGER PRIMARY KEY)")
                try db.execute("CREATE TABLE pets (masterId INTEGER NOT NULL REFERENCES persons(id), name TEXT)")
                sqlQueries.removeAll()
                try db.execute("INSERT INTO pets (masterId, name) VALUES (?, ?)", arguments: [1, "Bobby"])
                XCTFail()
                return .commit
            }
        } catch let error as DatabaseError {
            XCTAssertEqual(error.resultCode, .SQLITE_CONSTRAINT)
            XCTAssertEqual(error.message!.lowercased(), "foreign key constraint failed") // lowercased: accept multiple SQLite version
            XCTAssertEqual(error.sql!, "INSERT INTO pets (masterId, name) VALUES (?, ?)")
            // SQLITE_CONSTRAINT_FOREIGNKEY was added in SQLite 3.7.16 http://www.sqlite.org/changes.html#version_3_7_16
            // It is available from iOS 8.2 and OS X 10.10 https://github.com/yapstudios/YapDatabase/wiki/SQLite-version-(bundled-with-OS)
            if error.resultCode == error.extendedResultCode {
                XCTAssertEqual(error.description.lowercased(), "sqlite error 19 with statement `insert into pets (masterid, name) values (?, ?)` arguments [1, \"bobby\"]: foreign key constraint failed")
            } else {
                XCTAssertEqual(error.extendedResultCode, .SQLITE_CONSTRAINT_FOREIGNKEY)
                XCTAssertEqual(error.description.lowercased(), "sqlite error 787 with statement `insert into pets (masterid, name) values (?, ?)` arguments [1, \"bobby\"]: foreign key constraint failed")
            }
            
            XCTAssertEqual(sqlQueries.count, 2)
            XCTAssertEqual(sqlQueries[0], "INSERT INTO pets (masterId, name) VALUES (1, 'Bobby')")
            XCTAssertEqual(sqlQueries[1], "ROLLBACK TRANSACTION")
        }
    }

    func testDatabaseErrorInTopLevelSavepoint() throws {
        let dbQueue = try makeDatabaseQueue()
        do {
            try dbQueue.inDatabase { db in
                do {
                    try db.inSavepoint {
                        XCTAssertTrue(db.isInsideTransaction)
                        try db.execute("CREATE TABLE persons (id INTEGER PRIMARY KEY)")
                        try db.execute("CREATE TABLE pets (masterId INTEGER NOT NULL REFERENCES persons(id), name TEXT)")
                        sqlQueries.removeAll()
                        try db.execute("INSERT INTO pets (masterId, name) VALUES (?, ?)", arguments: [1, "Bobby"])
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
            XCTAssertEqual(error.resultCode, .SQLITE_CONSTRAINT)
            XCTAssertEqual(error.message!.lowercased(), "foreign key constraint failed") // lowercased: accept multiple SQLite version
            XCTAssertEqual(error.sql!, "INSERT INTO pets (masterId, name) VALUES (?, ?)")
            // SQLITE_CONSTRAINT_FOREIGNKEY was added in SQLite 3.7.16 http://www.sqlite.org/changes.html#version_3_7_16
            // It is available from iOS 8.2 and OS X 10.10 https://github.com/yapstudios/YapDatabase/wiki/SQLite-version-(bundled-with-OS)
            if error.resultCode == error.extendedResultCode {
                XCTAssertEqual(error.description.lowercased(), "sqlite error 19 with statement `insert into pets (masterid, name) values (?, ?)` arguments [1, \"bobby\"]: foreign key constraint failed")
            } else {
                XCTAssertEqual(error.extendedResultCode, .SQLITE_CONSTRAINT_FOREIGNKEY)
                XCTAssertEqual(error.description.lowercased(), "sqlite error 787 with statement `insert into pets (masterid, name) values (?, ?)` arguments [1, \"bobby\"]: foreign key constraint failed")
            }
        }
    }

    func testDatabaseErrorThrownByUpdateStatementContainSQLAndArguments() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute("CREATE TABLE persons (id INTEGER PRIMARY KEY)")
            try db.execute("CREATE TABLE pets (masterId INTEGER NOT NULL REFERENCES persons(id), name TEXT)")
        }
        
        // db.execute(sql, arguments)
        try dbQueue.inDatabase { db in
            do {
                try db.execute("INSERT INTO pets (masterId, name) VALUES (?, ?)", arguments: [1, "Bobby"])
                XCTFail()
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_CONSTRAINT)
                XCTAssertEqual(error.message!.lowercased(), "foreign key constraint failed") // lowercased: accept multiple SQLite version
                XCTAssertEqual(error.sql!, "INSERT INTO pets (masterId, name) VALUES (?, ?)")
                // SQLITE_CONSTRAINT_FOREIGNKEY was added in SQLite 3.7.16 http://www.sqlite.org/changes.html#version_3_7_16
                // It is available from iOS 8.2 and OS X 10.10 https://github.com/yapstudios/YapDatabase/wiki/SQLite-version-(bundled-with-OS)
                if error.resultCode == error.extendedResultCode {
                    XCTAssertEqual(error.description.lowercased(), "sqlite error 19 with statement `insert into pets (masterid, name) values (?, ?)` arguments [1, \"bobby\"]: foreign key constraint failed")
                } else {
                    XCTAssertEqual(error.extendedResultCode, .SQLITE_CONSTRAINT_FOREIGNKEY)
                    XCTAssertEqual(error.description.lowercased(), "sqlite error 787 with statement `insert into pets (masterid, name) values (?, ?)` arguments [1, \"bobby\"]: foreign key constraint failed")
                }
            }
        }
        
        // statement.execute(arguments)
        try dbQueue.inDatabase { db in
            do {
                let statement = try db.makeUpdateStatement("INSERT INTO pets (masterId, name) VALUES (?, ?)")
                try statement.execute(arguments: [1, "Bobby"])
                XCTFail()
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_CONSTRAINT)
                XCTAssertEqual(error.message!.lowercased(), "foreign key constraint failed") // lowercased: accept multiple SQLite version
                XCTAssertEqual(error.sql!, "INSERT INTO pets (masterId, name) VALUES (?, ?)")
                // SQLITE_CONSTRAINT_FOREIGNKEY was added in SQLite 3.7.16 http://www.sqlite.org/changes.html#version_3_7_16
                // It is available from iOS 8.2 and OS X 10.10 https://github.com/yapstudios/YapDatabase/wiki/SQLite-version-(bundled-with-OS)
                if error.resultCode == error.extendedResultCode {
                    XCTAssertEqual(error.description.lowercased(), "sqlite error 19 with statement `insert into pets (masterid, name) values (?, ?)` arguments [1, \"bobby\"]: foreign key constraint failed")
                } else {
                    XCTAssertEqual(error.extendedResultCode, .SQLITE_CONSTRAINT_FOREIGNKEY)
                    XCTAssertEqual(error.description.lowercased(), "sqlite error 787 with statement `insert into pets (masterid, name) values (?, ?)` arguments [1, \"bobby\"]: foreign key constraint failed")
                }
            }
        }
        
        // statement.execute()
        try dbQueue.inDatabase { db in
            do {
                let statement = try db.makeUpdateStatement("INSERT INTO pets (masterId, name) VALUES (?, ?)")
                statement.arguments = [1, "Bobby"]
                try statement.execute()
                XCTFail()
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_CONSTRAINT)
                XCTAssertEqual(error.message!.lowercased(), "foreign key constraint failed") // lowercased: accept multiple SQLite version
                XCTAssertEqual(error.sql!, "INSERT INTO pets (masterId, name) VALUES (?, ?)")
                // SQLITE_CONSTRAINT_FOREIGNKEY was added in SQLite 3.7.16 http://www.sqlite.org/changes.html#version_3_7_16
                // It is available from iOS 8.2 and OS X 10.10 https://github.com/yapstudios/YapDatabase/wiki/SQLite-version-(bundled-with-OS)
                if error.resultCode == error.extendedResultCode {
                    XCTAssertEqual(error.description.lowercased(), "sqlite error 19 with statement `insert into pets (masterid, name) values (?, ?)` arguments [1, \"bobby\"]: foreign key constraint failed")
                } else {
                    XCTAssertEqual(error.extendedResultCode, .SQLITE_CONSTRAINT_FOREIGNKEY)
                    XCTAssertEqual(error.description.lowercased(), "sqlite error 787 with statement `insert into pets (masterid, name) values (?, ?)` arguments [1, \"bobby\"]: foreign key constraint failed")
                }
            }
        }
    }

    func testDatabaseErrorThrownByExecuteMultiStatementContainSQL() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            do {
                try db.execute(
                    "CREATE TABLE persons (id INTEGER PRIMARY KEY, name TEXT, age INT);" +
                        "CREATE TABLE pets (masterId INTEGER NOT NULL REFERENCES persons(id), name TEXT);" +
                    "INSERT INTO pets (masterId, name) VALUES (1, 'Bobby')")
                XCTFail()
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_CONSTRAINT)
                XCTAssertEqual(error.message!.lowercased(), "foreign key constraint failed") // lowercased: accept multiple SQLite version
                XCTAssertEqual(error.sql!, "INSERT INTO pets (masterId, name) VALUES (1, 'Bobby')")
                // SQLITE_CONSTRAINT_FOREIGNKEY was added in SQLite 3.7.16 http://www.sqlite.org/changes.html#version_3_7_16
                // It is available from iOS 8.2 and OS X 10.10 https://github.com/yapstudios/YapDatabase/wiki/SQLite-version-(bundled-with-OS)
                if error.resultCode == error.extendedResultCode {
                    XCTAssertEqual(error.description.lowercased(), "sqlite error 19 with statement `insert into pets (masterid, name) values (1, 'bobby')`: foreign key constraint failed")
                } else {
                    XCTAssertEqual(error.extendedResultCode, .SQLITE_CONSTRAINT_FOREIGNKEY)
                    XCTAssertEqual(error.description.lowercased(), "sqlite error 787 with statement `insert into pets (masterid, name) values (1, 'bobby')`: foreign key constraint failed")
                }
            }
        }
    }

    func testExtendedResultCodesAreActivated() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "parents") { $0.column("id", .integer).primaryKey() }
            try db.create(table: "children") { $0.column("parentId", .integer).references("parents") }
            do {
                try db.execute("INSERT INTO children (parentId) VALUES (1)")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode.rawValue, 19)           // primary SQLITE_CONSTRAINT
                // SQLITE_CONSTRAINT_FOREIGNKEY was added in SQLite 3.7.16 http://www.sqlite.org/changes.html#version_3_7_16
                // It is available from iOS 8.2 and OS X 10.10 https://github.com/yapstudios/YapDatabase/wiki/SQLite-version-(bundled-with-OS)
                if error.resultCode != error.extendedResultCode {
                    XCTAssertEqual(error.extendedResultCode.rawValue, 787)  // extended SQLITE_CONSTRAINT_FOREIGNKEY
                } else {
                    // TODO: check for another extended result code, because we
                    // didn't prove that extended result codes are activated.
                }
            }
        }
    }
    
    func testNSErrorBridging() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "parents") { $0.column("id", .integer).primaryKey() }
            try db.create(table: "children") { $0.column("parentId", .integer).references("parents") }

            let verifyErrorDomainAndCode: (_ domain: String, _ code: Int) -> () = { domain, code in
                XCTAssertEqual(DatabaseError.errorDomain, "GRDB.DatabaseError")
                XCTAssertEqual(domain, DatabaseError.errorDomain)
                // SQLITE_CONSTRAINT_FOREIGNKEY was added in SQLite 3.7.16 http://www.sqlite.org/changes.html#version_3_7_16
                // It is available from iOS 8.2 and OS X 10.10 https://github.com/yapstudios/YapDatabase/wiki/SQLite-version-(bundled-with-OS)
                if code != 19 {
                    XCTAssertEqual(code, 787) // extended SQLITE_CONSTRAINT_FOREIGNKEY
                } else {
                    // TODO: check for another extended result code, because we
                    // didn't prove that extended result codes are activated.
                }
            }

            // DatabaseError is Error. Test if it can be caught as Error
            do {
                try db.execute("INSERT INTO children (parentId) VALUES (1)")
            } catch {
                verifyErrorDomainAndCode(error._domain, error._code)
            }

            // Test NSError bridging on OS X.
            // Error is not bridged to NSError on Linux: https://bugs.swift.org/browse/SR-3872
            #if !os(Linux)
            do {
                try db.execute("INSERT INTO children (parentId) VALUES (1)")
            } catch let error as NSError {
                verifyErrorDomainAndCode(error.domain, error.code)
            }
            #endif
        }
    }
    
    func testDatabaseErrorFromNSError() {
        let error = NSError(domain: "Custom", code: 123, userInfo: [NSLocalizedDescriptionKey: "something wrong did happen"])
        let dbError = DatabaseError(error: error)
        XCTAssertEqual(dbError.extendedResultCode, .SQLITE_ERROR)
        XCTAssert(dbError.message!.contains("Custom"))
        XCTAssert(dbError.message!.contains("123"))
        XCTAssert(dbError.message!.contains("something wrong did happen"))
    }
    
    func testDatabaseErrorFromDatabaseError() {
        let error = DatabaseError(resultCode: .SQLITE_CONSTRAINT_FOREIGNKEY, message: "something wrong did happen", sql: "some SQL", arguments: [1])
        let dbError = DatabaseError(error: error)
        XCTAssertEqual(dbError.extendedResultCode, .SQLITE_CONSTRAINT_FOREIGNKEY)
        XCTAssertEqual(dbError.message, "something wrong did happen")
        XCTAssertEqual(dbError.sql, "some SQL")
        XCTAssertEqual(dbError.description, error.description)
    }
}
