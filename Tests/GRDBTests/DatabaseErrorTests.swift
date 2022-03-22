import XCTest
import GRDB

class DatabaseErrorTests: GRDBTestCase {
    
    func testDatabaseErrorMessage() {
        // We don't test for actual messages, since they may depend on SQLite version
        XCTAssertEqual(DatabaseError().resultCode, .SQLITE_ERROR)
        XCTAssertNotNil(DatabaseError().message)
        XCTAssertNotNil(DatabaseError(resultCode: .SQLITE_BUSY).message)
        XCTAssertNotEqual(DatabaseError().message, DatabaseError(resultCode: .SQLITE_BUSY).message)
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
            XCTAssert(error.extendedResultCode == .SQLITE_CONSTRAINT_FOREIGNKEY)
            XCTAssertEqual(error.resultCode, .SQLITE_CONSTRAINT)
            XCTAssertEqual(error.message!.lowercased(), "foreign key constraint failed") // lowercased: accept multiple SQLite version
            XCTAssertEqual(error.sql!, "INSERT INTO pets (masterId, name) VALUES (?, ?)")
            XCTAssertEqual(error.description.lowercased(), "sqlite error 19: foreign key constraint failed - while executing `insert into pets (masterid, name) values (?, ?)`")
            XCTAssertEqual(error.expandedDescription.lowercased(), "sqlite error 19: foreign key constraint failed - while executing `insert into pets (masterid, name) values (?, ?)` with arguments [1, \"bobby\"]")
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
            XCTAssert(error.extendedResultCode == .SQLITE_CONSTRAINT_FOREIGNKEY)
            XCTAssertEqual(error.resultCode, .SQLITE_CONSTRAINT)
            XCTAssertEqual(error.message!.lowercased(), "foreign key constraint failed") // lowercased: accept multiple SQLite version
            XCTAssertEqual(error.sql!, "INSERT INTO pets (masterId, name) VALUES (?, ?)")
            XCTAssertEqual(error.description.lowercased(), "sqlite error 19: foreign key constraint failed - while executing `insert into pets (masterid, name) values (?, ?)`")
            XCTAssertEqual(error.expandedDescription.lowercased(), "sqlite error 19: foreign key constraint failed - while executing `insert into pets (masterid, name) values (?, ?)` with arguments [1, \"bobby\"]")
        }
    }

    func testDatabaseErrorThrownByUpdateStatementContainSQLAndNoPrivateArguments() throws {
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
                XCTAssert(error.extendedResultCode == .SQLITE_CONSTRAINT_FOREIGNKEY)
                XCTAssertEqual(error.resultCode, .SQLITE_CONSTRAINT)
                XCTAssertEqual(error.message!.lowercased(), "foreign key constraint failed") // lowercased: accept multiple SQLite version
                XCTAssertEqual(error.sql!, "INSERT INTO pets (masterId, name) VALUES (?, ?)")
                XCTAssertEqual(error.description.lowercased(), "sqlite error 19: foreign key constraint failed - while executing `insert into pets (masterid, name) values (?, ?)`")
                XCTAssertEqual(error.expandedDescription.lowercased(), "sqlite error 19: foreign key constraint failed - while executing `insert into pets (masterid, name) values (?, ?)` with arguments [1, \"bobby\"]")
            }
        }
        
        // statement.execute(arguments)
        try dbQueue.inDatabase { db in
            do {
                let statement = try db.makeStatement(sql: "INSERT INTO pets (masterId, name) VALUES (?, ?)")
                try statement.execute(arguments: [1, "Bobby"])
                XCTFail()
            } catch let error as DatabaseError {
                XCTAssert(error.extendedResultCode == .SQLITE_CONSTRAINT_FOREIGNKEY)
                XCTAssertEqual(error.resultCode, .SQLITE_CONSTRAINT)
                XCTAssertEqual(error.message!.lowercased(), "foreign key constraint failed") // lowercased: accept multiple SQLite version
                XCTAssertEqual(error.sql!, "INSERT INTO pets (masterId, name) VALUES (?, ?)")
                XCTAssertEqual(error.description.lowercased(), "sqlite error 19: foreign key constraint failed - while executing `insert into pets (masterid, name) values (?, ?)`")
                XCTAssertEqual(error.expandedDescription.lowercased(), "sqlite error 19: foreign key constraint failed - while executing `insert into pets (masterid, name) values (?, ?)` with arguments [1, \"bobby\"]")
            }
        }
        
        // statement.execute()
        try dbQueue.inDatabase { db in
            do {
                let statement = try db.makeStatement(sql: "INSERT INTO pets (masterId, name) VALUES (?, ?)")
                statement.arguments = [1, "Bobby"]
                try statement.execute()
                XCTFail()
            } catch let error as DatabaseError {
                XCTAssert(error.extendedResultCode == .SQLITE_CONSTRAINT_FOREIGNKEY)
                XCTAssertEqual(error.resultCode, .SQLITE_CONSTRAINT)
                XCTAssertEqual(error.message!.lowercased(), "foreign key constraint failed") // lowercased: accept multiple SQLite version
                XCTAssertEqual(error.sql!, "INSERT INTO pets (masterId, name) VALUES (?, ?)")
                XCTAssertEqual(error.description.lowercased(), "sqlite error 19: foreign key constraint failed - while executing `insert into pets (masterid, name) values (?, ?)`")
                XCTAssertEqual(error.expandedDescription.lowercased(), "sqlite error 19: foreign key constraint failed - while executing `insert into pets (masterid, name) values (?, ?)` with arguments [1, \"bobby\"]")
            }
        }
    }

    func testDatabaseErrorThrownByUpdateStatementContainSQLAndPublicArguments() throws {
        // Opt in for public statement arguments
        dbConfiguration.publicStatementArguments = true
        
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
                XCTAssert(error.extendedResultCode == .SQLITE_CONSTRAINT_FOREIGNKEY)
                XCTAssertEqual(error.resultCode, .SQLITE_CONSTRAINT)
                XCTAssertEqual(error.message!.lowercased(), "foreign key constraint failed") // lowercased: accept multiple SQLite version
                XCTAssertEqual(error.sql!, "INSERT INTO pets (masterId, name) VALUES (?, ?)")
                XCTAssertEqual(error.description.lowercased(), "sqlite error 19: foreign key constraint failed - while executing `insert into pets (masterid, name) values (?, ?)` with arguments [1, \"bobby\"]")
                XCTAssertEqual(error.expandedDescription.lowercased(), "sqlite error 19: foreign key constraint failed - while executing `insert into pets (masterid, name) values (?, ?)` with arguments [1, \"bobby\"]")
            }
        }
        
        // statement.execute(arguments)
        try dbQueue.inDatabase { db in
            do {
                let statement = try db.makeStatement(sql: "INSERT INTO pets (masterId, name) VALUES (?, ?)")
                try statement.execute(arguments: [1, "Bobby"])
                XCTFail()
            } catch let error as DatabaseError {
                XCTAssert(error.extendedResultCode == .SQLITE_CONSTRAINT_FOREIGNKEY)
                XCTAssertEqual(error.resultCode, .SQLITE_CONSTRAINT)
                XCTAssertEqual(error.message!.lowercased(), "foreign key constraint failed") // lowercased: accept multiple SQLite version
                XCTAssertEqual(error.sql!, "INSERT INTO pets (masterId, name) VALUES (?, ?)")
                XCTAssertEqual(error.description.lowercased(), "sqlite error 19: foreign key constraint failed - while executing `insert into pets (masterid, name) values (?, ?)` with arguments [1, \"bobby\"]")
                XCTAssertEqual(error.expandedDescription.lowercased(), "sqlite error 19: foreign key constraint failed - while executing `insert into pets (masterid, name) values (?, ?)` with arguments [1, \"bobby\"]")
            }
        }
        
        // statement.execute()
        try dbQueue.inDatabase { db in
            do {
                let statement = try db.makeStatement(sql: "INSERT INTO pets (masterId, name) VALUES (?, ?)")
                statement.arguments = [1, "Bobby"]
                try statement.execute()
                XCTFail()
            } catch let error as DatabaseError {
                XCTAssert(error.extendedResultCode == .SQLITE_CONSTRAINT_FOREIGNKEY)
                XCTAssertEqual(error.resultCode, .SQLITE_CONSTRAINT)
                XCTAssertEqual(error.message!.lowercased(), "foreign key constraint failed") // lowercased: accept multiple SQLite version
                XCTAssertEqual(error.sql!, "INSERT INTO pets (masterId, name) VALUES (?, ?)")
                XCTAssertEqual(error.description.lowercased(), "sqlite error 19: foreign key constraint failed - while executing `insert into pets (masterid, name) values (?, ?)` with arguments [1, \"bobby\"]")
                XCTAssertEqual(error.expandedDescription.lowercased(), "sqlite error 19: foreign key constraint failed - while executing `insert into pets (masterid, name) values (?, ?)` with arguments [1, \"bobby\"]")
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
                XCTAssert(error.extendedResultCode == .SQLITE_CONSTRAINT_FOREIGNKEY)
                XCTAssertEqual(error.resultCode, .SQLITE_CONSTRAINT)
                XCTAssertEqual(error.message!.lowercased(), "foreign key constraint failed") // lowercased: accept multiple SQLite version
                XCTAssertEqual(error.sql!, "INSERT INTO pets (masterId, name) VALUES (1, 'Bobby')")
                XCTAssertEqual(error.description.lowercased(), "sqlite error 19: foreign key constraint failed - while executing `insert into pets (masterid, name) values (1, 'bobby')`")
                XCTAssertEqual(error.expandedDescription.lowercased(), "sqlite error 19: foreign key constraint failed - while executing `insert into pets (masterid, name) values (1, 'bobby')`")
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
                XCTAssert(error.extendedResultCode == .SQLITE_CONSTRAINT_FOREIGNKEY)
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
                XCTAssertEqual(error.code, 787)
                XCTAssertNotNil(error.localizedFailureReason)
            }
        }
    }
}
