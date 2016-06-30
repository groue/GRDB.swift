import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class DatabaseErrorTests: GRDBTestCase {
    
    func testDatabaseErrorInTransaction() {
        assertNoError {
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
                XCTAssertEqual(error.code, 19) // SQLITE_CONSTRAINT
                XCTAssertEqual(error.message!.lowercased(), "foreign key constraint failed") // lowercased: accept multiple SQLite version
                XCTAssertEqual(error.sql!, "INSERT INTO pets (masterId, name) VALUES (?, ?)")
                XCTAssertEqual(error.description.lowercased(), "sqlite error 19 with statement `insert into pets (masterid, name) values (?, ?)` arguments [1, \"bobby\"]: foreign key constraint failed")
                
                XCTAssertEqual(sqlQueries.count, 2)
                XCTAssertEqual(sqlQueries[0], "INSERT INTO pets (masterId, name) VALUES (1, 'Bobby')")
                XCTAssertEqual(sqlQueries[1], "ROLLBACK TRANSACTION")
            }
        }
    }
    
    func testDatabaseErrorInTopLevelSavepoint() {
        assertNoError {
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
                XCTAssertEqual(error.code, 19) // SQLITE_CONSTRAINT
                XCTAssertEqual(error.message!.lowercased(), "foreign key constraint failed") // lowercased: accept multiple SQLite version
                XCTAssertEqual(error.sql!, "INSERT INTO pets (masterId, name) VALUES (?, ?)")
                XCTAssertEqual(error.description.lowercased(), "sqlite error 19 with statement `insert into pets (masterid, name) values (?, ?)` arguments [1, \"bobby\"]: foreign key constraint failed")
            }
        }
    }
    
    func testDatabaseErrorThrownByUpdateStatementContainSQLAndArguments() {
        assertNoError {
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
                    XCTAssertEqual(error.code, 19) // SQLITE_CONSTRAINT
                    XCTAssertEqual(error.message!.lowercased(), "foreign key constraint failed") // lowercased: accept multiple SQLite version
                    XCTAssertEqual(error.sql!, "INSERT INTO pets (masterId, name) VALUES (?, ?)")
                    XCTAssertEqual(error.description.lowercased(), "sqlite error 19 with statement `insert into pets (masterid, name) values (?, ?)` arguments [1, \"bobby\"]: foreign key constraint failed")
                }
            }
            
            // statement.execute(arguments)
            try dbQueue.inDatabase { db in
                do {
                    let statement = try db.makeUpdateStatement("INSERT INTO pets (masterId, name) VALUES (?, ?)")
                    try statement.execute(arguments: [1, "Bobby"])
                    XCTFail()
                } catch let error as DatabaseError {
                    XCTAssertEqual(error.code, 19) // SQLITE_CONSTRAINT
                    XCTAssertEqual(error.message!.lowercased(), "foreign key constraint failed") // lowercased: accept multiple SQLite version
                    XCTAssertEqual(error.sql!, "INSERT INTO pets (masterId, name) VALUES (?, ?)")
                    XCTAssertEqual(error.description.lowercased(), "sqlite error 19 with statement `insert into pets (masterid, name) values (?, ?)` arguments [1, \"bobby\"]: foreign key constraint failed")
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
                    XCTAssertEqual(error.code, 19) // SQLITE_CONSTRAINT
                    XCTAssertEqual(error.message!.lowercased(), "foreign key constraint failed") // lowercased: accept multiple SQLite version
                    XCTAssertEqual(error.sql!, "INSERT INTO pets (masterId, name) VALUES (?, ?)")
                    XCTAssertEqual(error.description.lowercased(), "sqlite error 19 with statement `insert into pets (masterid, name) values (?, ?)` arguments [1, \"bobby\"]: foreign key constraint failed")
                }
            }
        }
    }
    
    func testDatabaseErrorThrownByExecuteMultiStatementContainSQL() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                do {
                    try db.execute(
                        "CREATE TABLE persons (id INTEGER PRIMARY KEY, name TEXT, age INT);" +
                            "CREATE TABLE pets (masterId INTEGER NOT NULL REFERENCES persons(id), name TEXT);" +
                        "INSERT INTO pets (masterId, name) VALUES (1, 'Bobby')")
                    XCTFail()
                } catch let error as DatabaseError {
                    XCTAssertEqual(error.code, 19) // SQLITE_CONSTRAINT
                    XCTAssertEqual(error.message!.lowercased(), "foreign key constraint failed") // lowercased: accept multiple SQLite version
                    XCTAssertEqual(error.sql!, "INSERT INTO pets (masterId, name) VALUES (1, 'Bobby')")
                    XCTAssertEqual(error.description.lowercased(), "sqlite error 19 with statement `insert into pets (masterid, name) values (1, 'bobby')`: foreign key constraint failed")
                }
            }
        }
    }

}
