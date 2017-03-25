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
            XCTAssertEqual(error.description.lowercased(), "sqlite error 787 with statement `insert into pets (masterid, name) values (?, ?)` arguments [1, \"bobby\"]: foreign key constraint failed")
            
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
            XCTAssertEqual(error.description.lowercased(), "sqlite error 787 with statement `insert into pets (masterid, name) values (?, ?)` arguments [1, \"bobby\"]: foreign key constraint failed")
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
                XCTAssertEqual(error.description.lowercased(), "sqlite error 787 with statement `insert into pets (masterid, name) values (?, ?)` arguments [1, \"bobby\"]: foreign key constraint failed")
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
                XCTAssertEqual(error.description.lowercased(), "sqlite error 787 with statement `insert into pets (masterid, name) values (?, ?)` arguments [1, \"bobby\"]: foreign key constraint failed")
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
                XCTAssertEqual(error.description.lowercased(), "sqlite error 787 with statement `insert into pets (masterid, name) values (?, ?)` arguments [1, \"bobby\"]: foreign key constraint failed")
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
                XCTAssertEqual(error.description.lowercased(), "sqlite error 787 with statement `insert into pets (masterid, name) values (1, 'bobby')`: foreign key constraint failed")
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
                XCTAssertEqual(error.extendedResultCode.rawValue, 787)  // extended SQLITE_CONSTRAINT_FOREIGNKEY
            }
        }
    }
    
    func testNSErrorBridging() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "parents") { $0.column("id", .integer).primaryKey() }
            try db.create(table: "children") { $0.column("parentId", .integer).references("parents") }
            do {
                try db.execute("INSERT INTO children (parentId) VALUES (1)")
            } catch let error as NSError {
                XCTAssertEqual(DatabaseError.errorDomain, "GRDB.DatabaseError")
                XCTAssertEqual(error.domain, DatabaseError.errorDomain)
                XCTAssertEqual(error.code, 787) // extended SQLITE_CONSTRAINT_FOREIGNKEY
            }
        }
    }

}
