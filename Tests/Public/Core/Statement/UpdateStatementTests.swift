import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class UpdateStatementTests : GRDBTestCase {
    
    override func setup(_ dbWriter: DatabaseWriter) throws {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createPersons") { db in
            try db.execute(
                "CREATE TABLE persons (" +
                    "id INTEGER PRIMARY KEY, " +
                    "creationDate TEXT, " +
                    "name TEXT NOT NULL, " +
                    "age INT" +
                ")")
        }
        try migrator.migrate(dbWriter)
    }
    
    func testTrailingSemicolonAndWhiteSpaceIsAcceptedAndOptional() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inTransaction { db in
                try db.makeUpdateStatement("INSERT INTO persons (name) VALUES ('Arthur');").execute()
                try db.makeUpdateStatement("INSERT INTO persons (name) VALUES ('Barbara')\n \t").execute()
                try db.makeUpdateStatement("INSERT INTO persons (name) VALUES ('Craig');").execute()
                try db.makeUpdateStatement("INSERT INTO persons (name) VALUES ('Daniel');\n \t").execute()
                return .commit
            }
            dbQueue.inDatabase { db in
                let names = String.fetchAll(db, "SELECT name FROM persons ORDER BY name")
                XCTAssertEqual(names, ["Arthur", "Barbara", "Craig", "Daniel"])
            }
        }
    }
    
    func testArrayStatementArguments() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            
            try dbQueue.inTransaction { db in
                
                let statement = try db.makeUpdateStatement("INSERT INTO persons (name, age) VALUES (?, ?)")
                let persons: [[DatabaseValueConvertible?]] = [
                    ["Arthur", 41],
                    ["Barbara", nil],
                ]
                for person in persons {
                    try statement.execute(arguments: StatementArguments(person))
                }
                
                return .commit
            }
            
            dbQueue.inDatabase { db in
                let rows = Row.fetchAll(db, "SELECT * FROM persons ORDER BY name")
                XCTAssertEqual(rows.count, 2)
                XCTAssertEqual(rows[0].value(named: "name") as String, "Arthur")
                XCTAssertEqual(rows[0].value(named: "age") as Int, 41)
                XCTAssertEqual(rows[1].value(named: "name") as String, "Barbara")
                XCTAssertTrue((rows[1].value(named: "age") as DatabaseValue).isNull)
            }
        }
    }
    
    func testStatementArgumentsSetterWithArray() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            
            try dbQueue.inTransaction { db in
                
                let statement = try db.makeUpdateStatement("INSERT INTO persons (name, age) VALUES (?, ?)")
                let persons: [[DatabaseValueConvertible?]] = [
                    ["Arthur", 41],
                    ["Barbara", nil],
                ]
                for person in persons {
                    statement.arguments = StatementArguments(person)
                    try statement.execute()
                }
                
                return .commit
            }
            
            dbQueue.inDatabase { db in
                let rows = Row.fetchAll(db, "SELECT * FROM persons ORDER BY name")
                XCTAssertEqual(rows.count, 2)
                XCTAssertEqual(rows[0].value(named: "name") as String, "Arthur")
                XCTAssertEqual(rows[0].value(named: "age") as Int, 41)
                XCTAssertEqual(rows[1].value(named: "name") as String, "Barbara")
                XCTAssertTrue((rows[1].value(named: "age") as DatabaseValue).isNull)
            }
        }
    }
    
    func testDictionaryStatementArguments() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            
            try dbQueue.inTransaction { db in
                
                let statement = try db.makeUpdateStatement("INSERT INTO persons (name, age) VALUES (:name, :age)")
                let persons: [[String: DatabaseValueConvertible?]] = [
                    ["name": "Arthur", "age": 41],
                    ["name": "Barbara", "age": nil],
                ]
                for person in persons {
                    try statement.execute(arguments: StatementArguments(person))
                }
                
                return .commit
            }
            
            dbQueue.inDatabase { db in
                let rows = Row.fetchAll(db, "SELECT * FROM persons ORDER BY name")
                XCTAssertEqual(rows.count, 2)
                XCTAssertEqual(rows[0].value(named: "name") as String, "Arthur")
                XCTAssertEqual(rows[0].value(named: "age") as Int, 41)
                XCTAssertEqual(rows[1].value(named: "name") as String, "Barbara")
                XCTAssertTrue((rows[1].value(named: "age") as DatabaseValue).isNull)
            }
        }
    }
    
    func testStatementArgumentsSetterWithDictionary() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            
            try dbQueue.inTransaction { db in
                
                let statement = try db.makeUpdateStatement("INSERT INTO persons (name, age) VALUES (:name, :age)")
                let persons: [[String: DatabaseValueConvertible?]] = [
                    ["name": "Arthur", "age": 41],
                    ["name": "Barbara", "age": nil],
                ]
                for person in persons {
                    statement.arguments = StatementArguments(person)
                    try statement.execute()
                }
                
                return .commit
            }
            
            dbQueue.inDatabase { db in
                let rows = Row.fetchAll(db, "SELECT * FROM persons ORDER BY name")
                XCTAssertEqual(rows.count, 2)
                XCTAssertEqual(rows[0].value(named: "name") as String, "Arthur")
                XCTAssertEqual(rows[0].value(named: "age") as Int, 41)
                XCTAssertEqual(rows[1].value(named: "name") as String, "Barbara")
                XCTAssertTrue((rows[1].value(named: "age") as DatabaseValue).isNull)
            }
        }
    }
    
    func testUpdateStatementAcceptsSelectQueries() {
        // This test makes sure we do not introduce any regression for
        // https://github.com/groue/GRDB.swift/issues/15
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("SELECT 1")
            }
        }
    }
    
    func testExecuteMultipleStatement() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE wines (name TEXT, color INT); CREATE TABLE books (name TEXT, age INT)")
                XCTAssertTrue(db.tableExists("wines"))
                XCTAssertTrue(db.tableExists("books"))
            }
        }
    }
    
    func testExecuteMultipleStatementWithTrailingWhiteSpace() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE wines (name TEXT, color INT); CREATE TABLE books (name TEXT, age INT)\n \t")
                XCTAssertTrue(db.tableExists("wines"))
                XCTAssertTrue(db.tableExists("books"))
            }
        }
    }
    
    func testExecuteMultipleStatementWithTrailingSemicolonAndWhiteSpace() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE wines (name TEXT, color INT); CREATE TABLE books (name TEXT, age INT);\n \t")
                XCTAssertTrue(db.tableExists("wines"))
                XCTAssertTrue(db.tableExists("books"))
            }
        }
    }
    
    func testExecuteMultipleStatementWithNamedArguments() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inTransaction { db in
                try db.execute(
                    "INSERT INTO persons (name, age) VALUES ('Arthur', :age1);" +
                    "INSERT INTO persons (name, age) VALUES ('Arthur', :age2);",
                    arguments: ["age1": 41, "age2": 32])
                XCTAssertEqual(Int.fetchAll(db, "SELECT age FROM persons ORDER BY age"), [32, 41])
                return .rollback
            }
            
            try dbQueue.inTransaction { db in
                try db.execute(
                    "INSERT INTO persons (name, age) VALUES ('Arthur', :age1);" +
                    "INSERT INTO persons (name, age) VALUES ('Arthur', :age2);",
                    arguments: [41, 32])
                XCTAssertEqual(Int.fetchAll(db, "SELECT age FROM persons ORDER BY age"), [32, 41])
                return .rollback
            }
        }
    }
    
    func testExecuteMultipleStatementWithReusedNamedArguments() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inTransaction { db in
                try db.execute(
                    "INSERT INTO persons (name, age) VALUES ('Arthur', :age);" +
                    "INSERT INTO persons (name, age) VALUES ('Arthur', :age);",
                    arguments: ["age": 41])
                XCTAssertEqual(Int.fetchAll(db, "SELECT age FROM persons"), [41, 41])
                return .rollback
            }
            
//            // The test below fails because 41 in consumed by the first statement,
//            // leaving no argument for the second statement.
//            //
//            // TODO? make it work
//            try dbQueue.inTransaction { db in
//                try db.execute(
//                    "INSERT INTO persons (name, age) VALUES ('Arthur', :age);" +
//                    "INSERT INTO persons (name, age) VALUES ('Arthur', :age);",
//                    arguments: [41])
//                XCTAssertEqual(Int.fetchAll(db, "SELECT age FROM persons"), [41, 41])
//                return .rollback
//            }
        }
    }
    
    func testExecuteMultipleStatementWithPositionalArguments() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inTransaction { db in
                try db.execute(
                    "INSERT INTO persons (name, age) VALUES ('Arthur', ?);" +
                    "INSERT INTO persons (name, age) VALUES ('Arthur', ?);",
                    arguments: [41, 32])
                XCTAssertEqual(Int.fetchAll(db, "SELECT age FROM persons ORDER BY age"), [32, 41])
                return .rollback
            }
        }
    }
    
    func testDatabaseErrorThrownByUpdateStatementContainSQL() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                do {
                    _ = try db.makeUpdateStatement("UPDATE blah SET id = 12")
                    XCTFail()
                } catch let error as DatabaseError {
                    XCTAssertEqual(error.code, 1)
                    XCTAssertEqual(error.message!, "no such table: blah")
                    XCTAssertEqual(error.sql!, "UPDATE blah SET id = 12")
                    XCTAssertEqual(error.description, "SQLite error 1 with statement `UPDATE blah SET id = 12`: no such table: blah")
                }
            }
        }
    }
    
    func testMultipleValidStatementsError() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                do {
                    _ = try db.makeUpdateStatement("UPDATE persons SET age = 1; UPDATE persons SET age = 2;")
                    XCTFail("Expected error")
                } catch let error as DatabaseError {
                    XCTAssertEqual(error.code, 21)  // SQLITE_MISUSE
                    XCTAssertEqual(error.message!, "Multiple statements found. To execute multiple statements, use Database.execute() instead.")
                    XCTAssertEqual(error.sql!, "UPDATE persons SET age = 1; UPDATE persons SET age = 2;")
                    XCTAssertEqual(error.description, "SQLite error 21 with statement `UPDATE persons SET age = 1; UPDATE persons SET age = 2;`: Multiple statements found. To execute multiple statements, use Database.execute() instead.")
                }
            }
        }
    }
    
    func testMultipleStatementsWithSecondOneInvalidError() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                do {
                    _ = try db.makeUpdateStatement("UPDATE persons SET age = 1;x")
                    XCTFail("Expected error")
                } catch let error as DatabaseError {
                    XCTAssertEqual(error.code, 21)  // SQLITE_MISUSE
                    XCTAssertEqual(error.message!, "Multiple statements found. To execute multiple statements, use Database.execute() instead.")
                    XCTAssertEqual(error.sql!, "UPDATE persons SET age = 1;x")
                    XCTAssertEqual(error.description, "SQLite error 21 with statement `UPDATE persons SET age = 1;x`: Multiple statements found. To execute multiple statements, use Database.execute() instead.")
                }
            }
        }
    }
}
