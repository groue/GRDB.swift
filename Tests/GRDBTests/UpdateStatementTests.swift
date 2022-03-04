import XCTest
import GRDB

class UpdateStatementTests : GRDBTestCase {
    
    override func setup(_ dbWriter: DatabaseWriter) throws {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createPersons") { db in
            try db.execute(sql: """
                CREATE TABLE persons (
                    id INTEGER PRIMARY KEY,
                    creationDate TEXT,
                    name TEXT NOT NULL,
                    age INT)
                """)
        }
        try migrator.migrate(dbWriter)
    }
    
    func testTrailingSemicolonAndWhiteSpaceIsAcceptedAndOptional() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inTransaction { db in
            try db.makeStatement(sql: "INSERT INTO persons (name) VALUES ('Arthur');").execute()
            try db.makeStatement(sql: "INSERT INTO persons (name) VALUES ('Barbara')\n \t").execute()
            try db.makeStatement(sql: "INSERT INTO persons (name) VALUES ('Craig'); ; ;").execute()
            try db.makeStatement(sql: "INSERT INTO persons (name) VALUES ('Daniel');\n \t").execute()
            return .commit
        }
        try dbQueue.inDatabase { db in
            let names = try String.fetchAll(db, sql: "SELECT name FROM persons ORDER BY name")
            XCTAssertEqual(names, ["Arthur", "Barbara", "Craig", "Daniel"])
        }
    }
    
    func testStatementSQL() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try XCTAssertEqual(db.makeStatement(sql: "INSERT INTO persons (name, age) VALUES ('Arthur', ?)").sql, "INSERT INTO persons (name, age) VALUES ('Arthur', ?)")
            try XCTAssertEqual(db.makeStatement(sql: " INSERT INTO persons (name, age) VALUES ('Arthur', ?) ; ").sql, "INSERT INTO persons (name, age) VALUES ('Arthur', ?)")
        }
    }

    func testArrayStatementArguments() throws {
        let dbQueue = try makeDatabaseQueue()
        
        try dbQueue.inTransaction { db in
            
            let statement = try db.makeStatement(sql: "INSERT INTO persons (name, age) VALUES (?, ?)")
            let persons: [[DatabaseValueConvertible?]] = [
                ["Arthur", 41],
                ["Barbara", nil],
                ]
            for person in persons {
                try statement.execute(arguments: StatementArguments(person))
            }
            
            return .commit
        }
        
        try dbQueue.inDatabase { db in
            let rows = try Row.fetchAll(db, sql: "SELECT * FROM persons ORDER BY name")
            XCTAssertEqual(rows.count, 2)
            try XCTAssertEqual(rows[0]["name"] as String, "Arthur")
            try XCTAssertEqual(rows[0]["age"] as Int, 41)
            try XCTAssertEqual(rows[1]["name"] as String, "Barbara")
            try XCTAssertTrue((rows[1]["age"] as DatabaseValue).isNull)
        }
    }

    func testStatementArgumentsSetterWithArray() throws {
        let dbQueue = try makeDatabaseQueue()
        
        try dbQueue.inTransaction { db in
            
            let statement = try db.makeStatement(sql: "INSERT INTO persons (name, age) VALUES (?, ?)")
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
        
        try dbQueue.inDatabase { db in
            let rows = try Row.fetchAll(db, sql: "SELECT * FROM persons ORDER BY name")
            XCTAssertEqual(rows.count, 2)
            try XCTAssertEqual(rows[0]["name"] as String, "Arthur")
            try XCTAssertEqual(rows[0]["age"] as Int, 41)
            try XCTAssertEqual(rows[1]["name"] as String, "Barbara")
            try XCTAssertTrue((rows[1]["age"] as DatabaseValue).isNull)
        }
    }

    func testDictionaryStatementArguments() throws {
        let dbQueue = try makeDatabaseQueue()
        
        try dbQueue.inTransaction { db in
            
            let statement = try db.makeStatement(sql: "INSERT INTO persons (name, age) VALUES (:name, :age)")
            let persons: [[String: DatabaseValueConvertible?]] = [
                ["name": "Arthur", "age": 41],
                ["name": "Barbara", "age": nil],
                ]
            for person in persons {
                try statement.execute(arguments: StatementArguments(person))
            }
            
            return .commit
        }
        
        try dbQueue.inDatabase { db in
            let rows = try Row.fetchAll(db, sql: "SELECT * FROM persons ORDER BY name")
            XCTAssertEqual(rows.count, 2)
            try XCTAssertEqual(rows[0]["name"] as String, "Arthur")
            try XCTAssertEqual(rows[0]["age"] as Int, 41)
            try XCTAssertEqual(rows[1]["name"] as String, "Barbara")
            try XCTAssertTrue((rows[1]["age"] as DatabaseValue).isNull)
        }
    }

    func testStatementArgumentsSetterWithDictionary() throws {
        let dbQueue = try makeDatabaseQueue()
        
        try dbQueue.inTransaction { db in
            
            let statement = try db.makeStatement(sql: "INSERT INTO persons (name, age) VALUES (:name, :age)")
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
        
        try dbQueue.inDatabase { db in
            let rows = try Row.fetchAll(db, sql: "SELECT * FROM persons ORDER BY name")
            XCTAssertEqual(rows.count, 2)
            try XCTAssertEqual(rows[0]["name"] as String, "Arthur")
            try XCTAssertEqual(rows[0]["age"] as Int, 41)
            try XCTAssertEqual(rows[1]["name"] as String, "Barbara")
            try XCTAssertTrue((rows[1]["age"] as DatabaseValue).isNull)
        }
    }

    func testUpdateStatementAcceptsSelectQueries() throws {
        // This test makes sure we do not introduce any regression for
        // https://github.com/groue/GRDB.swift/issues/15
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(sql: "SELECT 1")
            let statement = try db.makeStatement(sql: "SELECT 1")
            try statement.execute()
        }
    }
    
    func testUpdateStatementAcceptsSelectQueriesAndConsumeAllRows() throws {
        let dbQueue = try makeDatabaseQueue()
        var index = 0
        try dbQueue.inDatabase { db in
            db.add(function: DatabaseFunction("seq", argumentCount: 0, pure: false) { _ in
                defer { index += 1 }
                return index
            })
            try db.execute(sql: "SELECT seq() UNION ALL SELECT seq() UNION ALL SELECT seq()")
            let statement = try db.makeStatement(sql: "SELECT seq() UNION ALL SELECT seq() UNION ALL SELECT seq()")
            try statement.execute()
        }
        XCTAssertEqual(index, 3 + 3)
    }

    func testExecuteNothing() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(sql: "")
            try db.execute(sql: " ")
            try db.execute(sql: ";")
            try db.execute(sql: ";;")
            try db.execute(sql: " \n;\t; ")
            try db.execute(sql: "-- comment")
            try db.execute(sql: "-- comment\\n; -----ignored")
        }
    }
    
    func testExecuteMultipleStatement() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(sql: "CREATE TABLE wines (name TEXT, color INT); CREATE TABLE books (name TEXT, age INT)")
            XCTAssertTrue(try db.tableExists("wines"))
            XCTAssertTrue(try db.tableExists("books"))
        }
    }

    func testExecuteMultipleStatementWithTrailingWhiteSpace() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(sql: "CREATE TABLE wines (name TEXT, color INT); CREATE TABLE books (name TEXT, age INT)\n \t")
            XCTAssertTrue(try db.tableExists("wines"))
            XCTAssertTrue(try db.tableExists("books"))
        }
    }

    func testExecuteMultipleStatementWithTrailingSemicolonAndWhiteSpace() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(sql: "CREATE TABLE wines (name TEXT, color INT); CREATE TABLE books (name TEXT, age INT);\n \t")
            XCTAssertTrue(try db.tableExists("wines"))
            XCTAssertTrue(try db.tableExists("books"))
        }
    }

    func testExecuteMultipleStatementWithPlentyOfSemicolonsAndWhiteSpaceAndComments() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(sql: """
                ;;
                CREATE TABLE wines ( -- create a table
                name TEXT, -- the name
                color INT);
                ;\t;
                -- create another table
                CREATE TABLE books (name TEXT, age INT); \
                 \t; ;
                """)
            XCTAssertTrue(try db.tableExists("wines"))
            XCTAssertTrue(try db.tableExists("books"))
        }
    }
    
    func testExecuteMultipleStatementWithNamedArguments() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inTransaction { db in
            try db.execute(sql: """
                INSERT INTO persons (name, age) VALUES ('Arthur', :age1);
                INSERT INTO persons (name, age) VALUES ('Arthur', :age2);
                """, arguments: ["age1": 41, "age2": 32])
            XCTAssertEqual(try Int.fetchAll(db, sql: "SELECT age FROM persons ORDER BY age"), [32, 41])
            return .rollback
        }
        
        try dbQueue.inTransaction { db in
            try db.execute(sql: """
                INSERT INTO persons (name, age) VALUES ('Arthur', :age1);
                INSERT INTO persons (name, age) VALUES ('Arthur', :age2);
                """, arguments: [41, 32])
            XCTAssertEqual(try Int.fetchAll(db, sql: "SELECT age FROM persons ORDER BY age"), [32, 41])
            return .rollback
        }
    }

    func testExecuteMultipleStatementWithReusedNamedArguments() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inTransaction { db in
            try db.execute(sql: """
                INSERT INTO persons (name, age) VALUES ('Arthur', :age);
                INSERT INTO persons (name, age) VALUES ('Arthur', :age);
                """, arguments: ["age": 41])
            XCTAssertEqual(try Int.fetchAll(db, sql: "SELECT age FROM persons"), [41, 41])
            return .rollback
        }
        
        try dbQueue.inTransaction { db in
            try db.execute(sql: """
                INSERT INTO persons (name, age) VALUES ('Arthur', :age);
                INSERT INTO persons (name, age) VALUES ('Arthur', :age);
                """, arguments: ["age": 41])
            XCTAssertEqual(try Int.fetchAll(db, sql: "SELECT age FROM persons"), [41, 41])
            return .rollback
        }
    }
    
    func testExecuteMultipleStatementWithPositionalArguments() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inTransaction { db in
            try db.execute(sql: """
                INSERT INTO persons (name, age) VALUES ('Arthur', ?);
                INSERT INTO persons (name, age) VALUES ('Arthur', ?);
                """, arguments: [41, 32])
            XCTAssertEqual(try Int.fetchAll(db, sql: "SELECT age FROM persons ORDER BY age"), [32, 41])
            return .rollback
        }
    }
    
    func testExecuteMultipleStatementWithTooManyArguments() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inTransaction { db in
            do {
                try db.execute(sql: "", arguments: [1])
                XCTFail()
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_MISUSE)
                XCTAssertEqual(error.message!, "wrong number of statement arguments: 1")
                XCTAssertEqual(error.description, "SQLite error 21: wrong number of statement arguments: 1")
            }
            return .rollback
        }
        
        try dbQueue.inTransaction { db in
            do {
                try db.execute(sql: """
                    INSERT INTO persons (name, age) VALUES ('Arthur', ?);
                    INSERT INTO persons (name, age) VALUES ('Arthur', ?);
                    """, arguments: [41, 32, 666])
                XCTFail()
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_MISUSE)
                XCTAssertEqual(error.message!, "wrong number of statement arguments: 3")
                XCTAssertEqual(error.description, "SQLite error 21: wrong number of statement arguments: 3")
            }
            
            // Both statements were run
            let count = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM persons")!
            XCTAssertEqual(count, 2)
            
            return .rollback
        }
    }
    
    func testExecuteMultipleStatementWithTooFewArguments() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inTransaction { db in
            do {
                try db.execute(sql: """
                    INSERT INTO persons (name, age) VALUES ('Arthur', ?);
                    INSERT INTO persons (name, age) VALUES ('Arthur', ?);
                    """, arguments: [41])
                XCTFail()
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_MISUSE)
                XCTAssertEqual(error.message!, "wrong number of statement arguments: 0")
                XCTAssertEqual(error.description, """
                    SQLite error 21: wrong number of statement arguments: 0 \
                    - while executing `INSERT INTO persons (name, age) VALUES ('Arthur', ?)`
                    """)
            }
            
            // First statement did run
            let count = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM persons")!
            XCTAssertEqual(count, 1)
            
            return .rollback
        }
    }

    func testDatabaseErrorThrownByUpdateStatementContainSQL() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            do {
                _ = try db.makeStatement(sql: "UPDATE blah SET id = 12")
                XCTFail()
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
                XCTAssertEqual(error.message!, "no such table: blah")
                XCTAssertEqual(error.sql!, "UPDATE blah SET id = 12")
                XCTAssertEqual(error.description, "SQLite error 1: no such table: blah - while executing `UPDATE blah SET id = 12`")
            }
        }
    }
    
    func testMultipleValidStatementsError() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            do {
                _ = try db.makeStatement(sql: "UPDATE persons SET age = 1; UPDATE persons SET age = 2;")
                XCTFail("Expected error")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_MISUSE)
                XCTAssertEqual(error.message!, """
                    Multiple statements found. To execute multiple statements, \
                    use Database.execute(sql:) or Database.allStatements(sql:) instead.
                    """)
                XCTAssertEqual(error.sql!, "UPDATE persons SET age = 1; UPDATE persons SET age = 2;")
                XCTAssertEqual(error.description, """
                    SQLite error 21: Multiple statements found. To execute multiple statements, \
                    use Database.execute(sql:) or Database.allStatements(sql:) instead. \
                    - while executing `UPDATE persons SET age = 1; UPDATE persons SET age = 2;`
                    """)
            }
        }
    }

    func testMultipleStatementsWithSecondOneInvalidError() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            do {
                _ = try db.makeStatement(sql: "UPDATE persons SET age = 1;x")
                XCTFail("Expected error")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_MISUSE)
                XCTAssertEqual(error.message!, """
                    Multiple statements found. To execute multiple statements, \
                    use Database.execute(sql:) or Database.allStatements(sql:) instead.
                    """)
                XCTAssertEqual(error.sql!, "UPDATE persons SET age = 1;x")
                XCTAssertEqual(error.description, """
                    SQLite error 21: Multiple statements found. To execute multiple statements, \
                    use Database.execute(sql:) or Database.allStatements(sql:) instead. \
                    - while executing `UPDATE persons SET age = 1;x`
                    """)
            }
        }
    }
    
    func testExecuteSQLLiteral() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.execute(literal: SQL(sql: """
                CREATE TABLE t(a);
                INSERT INTO t(a) VALUES (?);
                INSERT INTO t(a) VALUES (?);
                """, arguments: [1, 2]))
            let value = try Int.fetchOne(db, sql: "SELECT SUM(a) FROM t")
            XCTAssertEqual(value, 3)
        }
    }
    
    func testExecuteSQLLiteralWithInterpolation() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.execute(literal: """
                CREATE TABLE t(a);
                INSERT INTO t(a) VALUES (\(1));
                INSERT INTO t(a) VALUES (\(2));
                """)
            let value = try Int.fetchOne(db, sql: "SELECT SUM(a) FROM t")
            XCTAssertEqual(value, 3)
        }
    }
}
