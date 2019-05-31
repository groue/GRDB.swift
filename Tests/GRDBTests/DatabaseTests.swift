import XCTest
#if GRDBCUSTOMSQLITE
    @testable import GRDBCustomSQLite
#else
    #if SWIFT_PACKAGE
        import CSQLite
    #else
        import SQLite3
    #endif
    @testable import GRDB
#endif

class DatabaseTests : GRDBTestCase {
    
    func testCreateTable() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            XCTAssertFalse(try db.tableExists("persons"))
            try db.execute(sql: """
                CREATE TABLE persons (
                    id INTEGER PRIMARY KEY,
                    name TEXT,
                    age INT)
                """)
            XCTAssertTrue(try db.tableExists("persons"))
        }
    }

    func testCreateTemporaryTable() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            XCTAssertFalse(try db.tableExists("persons"))
            try db.execute(sql: """
                CREATE TEMPORARY TABLE persons (
                    id INTEGER PRIMARY KEY,
                    name TEXT,
                    age INT)
                """)
            XCTAssertTrue(try db.tableExists("persons"))
        }
    }

    func testMultipleStatementsWithoutArguments() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            XCTAssertFalse(try db.tableExists("persons"))
            XCTAssertFalse(try db.tableExists("pets"))
            try db.execute(sql: """
                CREATE TABLE persons (id INTEGER PRIMARY KEY, name TEXT, age INT);
                CREATE TABLE pets (id INTEGER PRIMARY KEY, name TEXT, age INT);
                """)
            XCTAssertTrue(try db.tableExists("persons"))
            XCTAssertTrue(try db.tableExists("pets"))
        }
    }

    func testUpdateStatement() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(sql: "CREATE TABLE persons (name TEXT, age INT)")
            
            // The tested function:
            let statement = try db.makeUpdateStatement(sql: "INSERT INTO persons (name, age) VALUES ('Arthur', 41)")
            try statement.execute()
            
            let row = try Row.fetchOne(db, sql: "SELECT * FROM persons")!
            XCTAssertEqual(row[0] as String, "Arthur")
            XCTAssertEqual(row[1] as Int, 41)
        }
    }

    func testUpdateStatementWithArrayBinding() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(sql: "CREATE TABLE persons (name TEXT, age INT)")
            
            let statement = try db.makeUpdateStatement(sql: "INSERT INTO persons (name, age) VALUES (?, ?)")
            try statement.execute(arguments: ["Arthur", 41])
            
            let row = try Row.fetchOne(db, sql: "SELECT * FROM persons")!
            XCTAssertEqual(row[0] as String, "Arthur")
            XCTAssertEqual(row[1] as Int, 41)
        }
    }

    func testUpdateStatementWithDictionaryBinding() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(sql: "CREATE TABLE persons (name TEXT, age INT)")
            
            let statement = try db.makeUpdateStatement(sql: "INSERT INTO persons (name, age) VALUES (:name, :age)")
            try statement.execute(arguments: ["name": "Arthur", "age": 41])
            
            let row = try Row.fetchOne(db, sql: "SELECT * FROM persons")!
            XCTAssertEqual(row[0] as String, "Arthur")
            XCTAssertEqual(row[1] as Int, 41)
        }
    }

    func testDatabaseExecute() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(sql: "CREATE TABLE persons (name TEXT, age INT)")
            
            // The tested function:
            try db.execute(sql: "INSERT INTO persons (name, age) VALUES ('Arthur', 41)")
            
            let row = try Row.fetchOne(db, sql: "SELECT * FROM persons")!
            XCTAssertEqual(row[0] as String, "Arthur")
            XCTAssertEqual(row[1] as Int, 41)
        }
    }

    func testDatabaseExecuteChanges() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            XCTAssertEqual(db.changesCount, 0)
            XCTAssertEqual(db.totalChangesCount, 0)
            XCTAssertEqual(db.lastInsertedRowID, 0)
            
            try db.execute(sql: "CREATE TABLE persons (id INTEGER PRIMARY KEY, name TEXT)")
            
            try db.execute(sql: "INSERT INTO persons (name) VALUES ('Arthur')")
            XCTAssertEqual(db.changesCount, 1)
            XCTAssertEqual(db.totalChangesCount, 1)
            XCTAssertEqual(db.lastInsertedRowID, 1)
            
            try db.execute(sql: "INSERT INTO persons (name) VALUES (?)", arguments: ["Barbara"])
            XCTAssertEqual(db.changesCount, 1)
            XCTAssertEqual(db.totalChangesCount, 2)
            XCTAssertEqual(db.lastInsertedRowID, 2)
            
            try db.execute(sql: "DELETE FROM persons")
            XCTAssertEqual(db.changesCount, 2)
            XCTAssertEqual(db.totalChangesCount, 4)
            XCTAssertEqual(db.lastInsertedRowID, 2)
        }
    }

    func testDatabaseExecuteWithArrayBinding() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(sql: "CREATE TABLE persons (name TEXT, age INT)")
            
            // The tested function:
            try db.execute(sql: "INSERT INTO persons (name, age) VALUES (?, ?)", arguments: ["Arthur", 41])
            
            let row = try Row.fetchOne(db, sql: "SELECT * FROM persons")!
            XCTAssertEqual(row[0] as String, "Arthur")
            XCTAssertEqual(row[1] as Int, 41)
        }
    }

    func testDatabaseExecuteWithDictionaryBinding() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(sql: "CREATE TABLE persons (name TEXT, age INT)")
            
            // The tested function:
            try db.execute(sql: "INSERT INTO persons (name, age) VALUES (:name, :age)", arguments: ["name": "Arthur", "age": 41])
            
            let row = try Row.fetchOne(db, sql: "SELECT * FROM persons")!
            XCTAssertEqual(row[0] as String, "Arthur")
            XCTAssertEqual(row[1] as Int, 41)
        }
    }

    func testSelectStatement() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(sql: "CREATE TABLE persons (name TEXT, age INT)")
            try db.execute(sql: "INSERT INTO persons (name, age) VALUES (:name, :age)", arguments: ["name": "Arthur", "age": 41])
            try db.execute(sql: "INSERT INTO persons (name, age) VALUES (:name, :age)", arguments: ["name": "Barbara", "age": nil])
            
            let statement = try db.makeSelectStatement(sql: "SELECT * FROM persons")
            let rows = try Row.fetchAll(statement)
            XCTAssertEqual(rows.count, 2)
        }
    }

    func testSelectStatementWithArrayBinding() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(sql: "CREATE TABLE persons (name TEXT, age INT)")
            try db.execute(sql: "INSERT INTO persons (name, age) VALUES (:name, :age)", arguments: ["name": "Arthur", "age": 41])
            try db.execute(sql: "INSERT INTO persons (name, age) VALUES (:name, :age)", arguments: ["name": "Barbara", "age": nil])
            
            let statement = try db.makeSelectStatement(sql: "SELECT * FROM persons WHERE name = ?")
            let rows = try Row.fetchAll(statement, arguments: ["Arthur"])
            XCTAssertEqual(rows.count, 1)
        }
    }

    func testSelectStatementWithDictionaryBinding() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(sql: "CREATE TABLE persons (name TEXT, age INT)")
            try db.execute(sql: "INSERT INTO persons (name, age) VALUES (:name, :age)", arguments: ["name": "Arthur", "age": 41])
            try db.execute(sql: "INSERT INTO persons (name, age) VALUES (:name, :age)", arguments: ["name": "Barbara", "age": nil])
            
            let statement = try db.makeSelectStatement(sql: "SELECT * FROM persons WHERE name = :name")
            let rows = try Row.fetchAll(statement, arguments: ["name": "Arthur"])
            XCTAssertEqual(rows.count, 1)
        }
    }

    func testRowValueAtIndex() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(sql: "CREATE TABLE persons (name TEXT, age INT)")
            try db.execute(sql: "INSERT INTO persons (name, age) VALUES (:name, :age)", arguments: ["name": "Arthur", "age": 41])
            try db.execute(sql: "INSERT INTO persons (name, age) VALUES (:name, :age)", arguments: ["name": "Barbara", "age": nil])
            
            var names: [String?] = []
            var ages: [Int?] = []
            let rows = try Row.fetchCursor(db, sql: "SELECT * FROM persons ORDER BY name")
            while let row = try rows.next() {
                // The tested function:
                let name: String? = row[0]
                let age: Int? = row[1]
                names.append(name)
                ages.append(age)
            }
            
            XCTAssertEqual(names[0]!, "Arthur")
            XCTAssertEqual(names[1]!, "Barbara")
            XCTAssertEqual(ages[0]!, 41)
            XCTAssertNil(ages[1])
        }
    }

    func testRowValueNamed() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(sql: "CREATE TABLE persons (name TEXT, age INT)")
            try db.execute(sql: "INSERT INTO persons (name, age) VALUES (:name, :age)", arguments: ["name": "Arthur", "age": 41])
            try db.execute(sql: "INSERT INTO persons (name, age) VALUES (:name, :age)", arguments: ["name": "Barbara", "age": nil])
            
            var names: [String?] = []
            var ages: [Int?] = []
            let rows = try Row.fetchCursor(db, sql: "SELECT * FROM persons ORDER BY name")
            while let row = try rows.next() {
                // The tested function:
                let name: String? = row["name"]
                let age: Int? = row["age"]
                names.append(name)
                ages.append(age)
            }
            
            XCTAssertEqual(names[0]!, "Arthur")
            XCTAssertEqual(names[1]!, "Barbara")
            XCTAssertEqual(ages[0]!, 41)
            XCTAssertNil(ages[1])
        }
    }

    func testDatabaseCanBeUsedOutsideOfDatabaseQueueBlockAsLongAsTheQueueIsCorrect() throws {
        let dbQueue = try makeDatabaseQueue()
        var database: Database? = nil
        dbQueue.inDatabase { db in
            database = db
        }
        try dbQueue.inDatabase { _ in
            try database!.execute(sql: "CREATE TABLE persons (name TEXT)")
        }
    }

    func testFailedCommitIsRollbacked() throws {
        // PRAGMA defer_foreign_keys = ON was introduced in SQLite 3.12.0 http://www.sqlite.org/changes.html#version_3_8_0
        // It is available from iOS 8.2 and OS X 10.10 https://github.com/yapstudios/YapDatabase/wiki/SQLite-version-(bundled-with-OS)
        #if !GRDBCUSTOMSQLITE && !GRDBCIPHER
            guard #available(iOS 8.2, OSX 10.10, *) else {
                return
            }
        #endif
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(sql: "CREATE TABLE parent (id INTEGER PRIMARY KEY)")
            try db.execute(sql: "CREATE TABLE child (parentID INTEGER NOT NULL REFERENCES parent(id))")
        }
        
        do {
            try dbQueue.inTransaction { db in
                do {
                    try db.execute(sql: "PRAGMA defer_foreign_keys = ON")
                    try db.execute(sql: "INSERT INTO child (parentID) VALUES (1)")
                } catch {
                    XCTFail()
                }
                return .commit
            }
            XCTFail()
        } catch let error as DatabaseError {
            XCTAssertEqual(error.resultCode, .SQLITE_CONSTRAINT)
            XCTAssertEqual(error.message!, "FOREIGN KEY constraint failed")
            XCTAssertEqual(error.sql!, "COMMIT TRANSACTION")
            XCTAssertEqual(error.description, "SQLite error 19 with statement `COMMIT TRANSACTION`: FOREIGN KEY constraint failed")
        }
        
        // Make sure we can open another transaction
        try dbQueue.inTransaction { db in .commit }
    }
    
    func testExplicitTransactionManagement() throws {
        let dbQueue = try makeDatabaseQueue()
        
        try dbQueue.writeWithoutTransaction { db in
            try db.beginTransaction()
            XCTAssertEqual(lastSQLQuery, "BEGIN DEFERRED TRANSACTION")
            try db.rollback()
            XCTAssertEqual(lastSQLQuery, "ROLLBACK TRANSACTION")
            try db.beginTransaction(.immediate)
            XCTAssertEqual(lastSQLQuery, "BEGIN IMMEDIATE TRANSACTION")
            try db.commit()
            XCTAssertEqual(lastSQLQuery, "COMMIT TRANSACTION")
        }
    }
    
    // Test an internal API
    func testReadOnly() throws {
        // query_only pragma was added in SQLite 3.8.0 http://www.sqlite.org/changes.html#version_3_8_0
        guard sqlite3_libversion_number() >= 3008000 else {
            return
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(sql: "CREATE TABLE t (id INTEGER PRIMARY KEY)")
            
            // Write access OK
            try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
            
            try db.readOnly {
                do {
                    try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
                    XCTFail()
                } catch let error as DatabaseError {
                    XCTAssertEqual(error.resultCode, .SQLITE_READONLY)
                }
                
                // Reentrancy
                try db.readOnly {
                    do {
                        try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
                        XCTFail()
                    } catch let error as DatabaseError {
                        XCTAssertEqual(error.resultCode, .SQLITE_READONLY)
                    }
                }
                
                // Still read-only
                do {
                    try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
                    XCTFail()
                } catch let error as DatabaseError {
                    XCTAssertEqual(error.resultCode, .SQLITE_READONLY)
                }
            }
            
            // Write access OK
            try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
        }
    }
}
