import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class DatabaseTests : GRDBTestCase {
    
    func testCreateTable() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                XCTAssertFalse(db.tableExists("persons"))
                try db.execute(
                    "CREATE TABLE persons (" +
                        "id INTEGER PRIMARY KEY, " +
                        "name TEXT, " +
                        "age INT)")
                XCTAssertTrue(db.tableExists("persons"))
            }
        }
    }
    
    func testCreateTemporaryTable() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                XCTAssertFalse(db.tableExists("persons"))
                try db.execute(
                    "CREATE TEMPORARY TABLE persons (" +
                        "id INTEGER PRIMARY KEY, " +
                        "name TEXT, " +
                    "age INT)")
                XCTAssertTrue(db.tableExists("persons"))
            }
        }
    }
    
    func testMultipleStatementsWithoutArguments() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                XCTAssertFalse(db.tableExists("persons"))
                XCTAssertFalse(db.tableExists("pets"))
                try db.execute(
                    "CREATE TABLE persons (id INTEGER PRIMARY KEY, name TEXT, age INT);" +
                    "CREATE TABLE pets (id INTEGER PRIMARY KEY, name TEXT, age INT);")
                XCTAssertTrue(db.tableExists("persons"))
                XCTAssertTrue(db.tableExists("pets"))
            }
        }
    }
    
    func testUpdateStatement() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE persons (name TEXT, age INT)")
                
                // The tested function:
                let statement = try db.makeUpdateStatement("INSERT INTO persons (name, age) VALUES ('Arthur', 41)")
                try statement.execute()
                
                let row = Row.fetchOne(db, "SELECT * FROM persons")!
                XCTAssertEqual(row.value(atIndex: 0) as String, "Arthur")
                XCTAssertEqual(row.value(atIndex: 1) as Int, 41)
            }
        }
    }
    
    func testUpdateStatementWithArrayBinding() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE persons (name TEXT, age INT)")
                
                let statement = try db.makeUpdateStatement("INSERT INTO persons (name, age) VALUES (?, ?)")
                try statement.execute(arguments: ["Arthur", 41])
                
                let row = Row.fetchOne(db, "SELECT * FROM persons")!
                XCTAssertEqual(row.value(atIndex: 0) as String, "Arthur")
                XCTAssertEqual(row.value(atIndex: 1) as Int, 41)
            }
        }
    }
    
    func testUpdateStatementWithDictionaryBinding() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE persons (name TEXT, age INT)")
                
                let statement = try db.makeUpdateStatement("INSERT INTO persons (name, age) VALUES (:name, :age)")
                try statement.execute(arguments: ["name": "Arthur", "age": 41])
                
                let row = Row.fetchOne(db, "SELECT * FROM persons")!
                XCTAssertEqual(row.value(atIndex: 0) as String, "Arthur")
                XCTAssertEqual(row.value(atIndex: 1) as Int, 41)
            }
        }
    }
    
    func testDatabaseExecute() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE persons (name TEXT, age INT)")
                
                // The tested function:
                try db.execute("INSERT INTO persons (name, age) VALUES ('Arthur', 41)")
                
                let row = Row.fetchOne(db, "SELECT * FROM persons")!
                XCTAssertEqual(row.value(atIndex: 0) as String, "Arthur")
                XCTAssertEqual(row.value(atIndex: 1) as Int, 41)
            }
        }
    }
    
    func testDatabaseExecuteChanges() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                XCTAssertEqual(db.changesCount, 0)
                XCTAssertEqual(db.totalChangesCount, 0)
                XCTAssertEqual(db.lastInsertedRowID, 0)
                
                try db.execute("CREATE TABLE persons (id INTEGER PRIMARY KEY, name TEXT)")
                
                try db.execute("INSERT INTO persons (name) VALUES ('Arthur')")
                XCTAssertEqual(db.changesCount, 1)
                XCTAssertEqual(db.totalChangesCount, 1)
                XCTAssertEqual(db.lastInsertedRowID, 1)
                
                try db.execute("INSERT INTO persons (name) VALUES (?)", arguments: ["Barbara"])
                XCTAssertEqual(db.changesCount, 1)
                XCTAssertEqual(db.totalChangesCount, 2)
                XCTAssertEqual(db.lastInsertedRowID, 2)
                
                try db.execute("DELETE FROM persons")
                XCTAssertEqual(db.changesCount, 2)
                XCTAssertEqual(db.totalChangesCount, 4)
                XCTAssertEqual(db.lastInsertedRowID, 2)
            }
        }
    }
    
    func testDatabaseExecuteWithArrayBinding() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE persons (name TEXT, age INT)")
                
                // The tested function:
                try db.execute("INSERT INTO persons (name, age) VALUES (?, ?)", arguments: ["Arthur", 41])
                
                let row = Row.fetchOne(db, "SELECT * FROM persons")!
                XCTAssertEqual(row.value(atIndex: 0) as String, "Arthur")
                XCTAssertEqual(row.value(atIndex: 1) as Int, 41)
            }
        }
    }
    
    func testDatabaseExecuteWithDictionaryBinding() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE persons (name TEXT, age INT)")
                
                // The tested function:
                try db.execute("INSERT INTO persons (name, age) VALUES (:name, :age)", arguments: ["name": "Arthur", "age": 41])
                
                let row = Row.fetchOne(db, "SELECT * FROM persons")!
                XCTAssertEqual(row.value(atIndex: 0) as String, "Arthur")
                XCTAssertEqual(row.value(atIndex: 1) as Int, 41)
            }
        }
    }
    
    func testSelectStatement() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE persons (name TEXT, age INT)")
                try db.execute("INSERT INTO persons (name, age) VALUES (:name, :age)", arguments: ["name": "Arthur", "age": 41])
                try db.execute("INSERT INTO persons (name, age) VALUES (:name, :age)", arguments: ["name": "Barbara", "age": nil])
                
                let statement = try db.makeSelectStatement("SELECT * FROM persons")
                let rows = Row.fetchAll(statement)
                XCTAssertEqual(rows.count, 2)
            }
        }
    }
    
    func testSelectStatementWithArrayBinding() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE persons (name TEXT, age INT)")
                try db.execute("INSERT INTO persons (name, age) VALUES (:name, :age)", arguments: ["name": "Arthur", "age": 41])
                try db.execute("INSERT INTO persons (name, age) VALUES (:name, :age)", arguments: ["name": "Barbara", "age": nil])
                
                let statement = try db.makeSelectStatement("SELECT * FROM persons WHERE name = ?")
                let rows = Row.fetchAll(statement, arguments: ["Arthur"])
                XCTAssertEqual(rows.count, 1)
            }
        }
    }
    
    func testSelectStatementWithDictionaryBinding() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE persons (name TEXT, age INT)")
                try db.execute("INSERT INTO persons (name, age) VALUES (:name, :age)", arguments: ["name": "Arthur", "age": 41])
                try db.execute("INSERT INTO persons (name, age) VALUES (:name, :age)", arguments: ["name": "Barbara", "age": nil])
                
                let statement = try db.makeSelectStatement("SELECT * FROM persons WHERE name = :name")
                let rows = Row.fetchAll(statement, arguments: ["name": "Arthur"])
                XCTAssertEqual(rows.count, 1)
            }
        }
    }
    
    func testRowValueAtIndex() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE persons (name TEXT, age INT)")
                try db.execute("INSERT INTO persons (name, age) VALUES (:name, :age)", arguments: ["name": "Arthur", "age": 41])
                try db.execute("INSERT INTO persons (name, age) VALUES (:name, :age)", arguments: ["name": "Barbara", "age": nil])
                
                var names: [String?] = []
                var ages: [Int?] = []
                let rows = Row.fetch(db, "SELECT * FROM persons ORDER BY name")
                for row in rows {
                    // The tested function:
                    let name: String? = row.value(atIndex: 0)
                    let age: Int? = row.value(atIndex: 1)
                    names.append(name)
                    ages.append(age)
                }
                
                XCTAssertEqual(names[0]!, "Arthur")
                XCTAssertEqual(names[1]!, "Barbara")
                XCTAssertEqual(ages[0]!, 41)
                XCTAssertNil(ages[1])
            }
        }
    }
    
    func testRowValueNamed() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE persons (name TEXT, age INT)")
                try db.execute("INSERT INTO persons (name, age) VALUES (:name, :age)", arguments: ["name": "Arthur", "age": 41])
                try db.execute("INSERT INTO persons (name, age) VALUES (:name, :age)", arguments: ["name": "Barbara", "age": nil])
                
                var names: [String?] = []
                var ages: [Int?] = []
                let rows = Row.fetch(db, "SELECT * FROM persons ORDER BY name")
                for row in rows {
                    // The tested function:
                    let name: String? = row.value(named: "name")
                    let age: Int? = row.value(named: "age")
                    names.append(name)
                    ages.append(age)
                }
                
                XCTAssertEqual(names[0]!, "Arthur")
                XCTAssertEqual(names[1]!, "Barbara")
                XCTAssertEqual(ages[0]!, 41)
                XCTAssertNil(ages[1])
            }
        }
    }
    
    func testRowSequenceCanBeIteratedTwice() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inTransaction { db in
                try db.execute("CREATE TABLE persons (name TEXT)")
                try db.execute("INSERT INTO persons (name) VALUES (:name)", arguments: ["name": "Arthur"])
                try db.execute("INSERT INTO persons (name) VALUES (:name)", arguments: ["name": "Barbara"])
                
                let rows = Row.fetch(db, "SELECT * FROM persons ORDER BY name")
                var names1: [String?] = rows.map { $0.value(named: "name") as String? }
                var names2: [String?] = rows.map { $0.value(named: "name") as String? }
                
                XCTAssertEqual(names1[0]!, "Arthur")
                XCTAssertEqual(names1[1]!, "Barbara")
                XCTAssertEqual(names2[0]!, "Arthur")
                XCTAssertEqual(names2[1]!, "Barbara")
                
                return .commit
            }
        }
    }
    
    func testValueSequenceCanBeIteratedTwice() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inTransaction { db in
                try db.execute("CREATE TABLE persons (name TEXT)")
                try db.execute("INSERT INTO persons (name) VALUES (:name)", arguments: ["name": "Arthur"])
                try db.execute("INSERT INTO persons (name) VALUES (:name)", arguments: ["name": "Barbara"])
                
                let nameSequence = String.fetch(db, "SELECT name FROM persons ORDER BY name")
                var names1 = Array(nameSequence)
                var names2 = Array(nameSequence)
                
                XCTAssertEqual(names1[0], "Arthur")
                XCTAssertEqual(names1[1], "Barbara")
                XCTAssertEqual(names2[0], "Arthur")
                XCTAssertEqual(names2[1], "Barbara")
                
                return .commit
            }
        }
    }
    
    func testDatabaseCanBeUsedOutsideOfDatabaseQueueBlockAsLongAsTheQueueIsCorrect() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            var database: Database? = nil
            dbQueue.inDatabase { db in
                database = db
            }
            try dbQueue.inDatabase { _ in
                try database!.execute("CREATE TABLE persons (name TEXT)")
            }
        }
    }
    
    func testFailedCommitIsRollbacked() {
        // PRAGMA defer_foreign_keys = ON was introduced in SQLite 3.12.0 http://www.sqlite.org/changes.html#version_3_8_0
        // It is available from iOS 8.2 and OS X 10.10 https://github.com/yapstudios/YapDatabase/wiki/SQLite-version-(bundled-with-OS)
        guard #available(iOS 8.2, OSX 10.10, *) else {
            return
        }
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE parent (id INTEGER PRIMARY KEY)")
                try db.execute("CREATE TABLE child (parentID INTEGER NOT NULL REFERENCES parent(id))")
            }
            
            do {
                try dbQueue.inTransaction { db in
                    do {
                        try db.execute("PRAGMA defer_foreign_keys = ON")
                        try db.execute("INSERT INTO child (parentID) VALUES (1)")
                    } catch {
                        XCTFail()
                    }
                    return .commit
                }
                XCTFail()
            } catch let error as DatabaseError {
                XCTAssertEqual(error.code, 19) // SQLITE_CONSTRAINT
                XCTAssertEqual(error.message!, "FOREIGN KEY constraint failed")
                XCTAssertEqual(error.sql!, "COMMIT TRANSACTION")
                XCTAssertEqual(error.description, "SQLite error 19 with statement `COMMIT TRANSACTION`: FOREIGN KEY constraint failed")
            }
            
            // Make sure we can open another transaction
            try dbQueue.inTransaction { db in .commit }
        }
    }
}
