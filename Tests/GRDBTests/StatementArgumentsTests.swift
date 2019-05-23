import XCTest
#if GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class StatementArgumentsTests: GRDBTestCase {

    override func setup(_ dbWriter: DatabaseWriter) throws {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createPersons") { db in
            try db.execute(sql: """
                CREATE TABLE persons (
                    id INTEGER PRIMARY KEY,
                    firstName TEXT,
                    lastName TEXT,
                    age INT)
                """)
        }
        try migrator.migrate(dbWriter)
    }
    
    func testPositionalStatementArgumentsValidation() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let statement = try db.makeUpdateStatement(sql: "INSERT INTO persons (firstName, age) VALUES (?, ?)")
            
            do {
                // Correct number of arguments
                try statement.validate(arguments: ["foo", 1])
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
            
            do {
                // Missing arguments
                try statement.validate(arguments: [])
                XCTFail("Expected error")
            } catch is DatabaseError {
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
            
            do {
                // Two few arguments
                try statement.validate(arguments: ["foo"])
                XCTFail("Expected error")
            } catch is DatabaseError {
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
            
            do {
                // Two many arguments
                try statement.validate(arguments: ["foo", 1, "bar"])
                XCTFail("Expected error")
            } catch is DatabaseError {
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
            
            do {
                // Missing arguments
                try statement.validate(arguments: [:])
                XCTFail("Expected error")
            } catch is DatabaseError {
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
            
            do {
                // Unmappable arguments
                try statement.validate(arguments: ["firstName": "foo", "age": 1])
                XCTFail("Expected error")
            } catch is DatabaseError {
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testPositionalStatementArguments() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let name = "Arthur"
            let age = 42
            let arguments = StatementArguments([name, age] as [DatabaseValueConvertible?])
            
            let updateStatement = try db.makeUpdateStatement(sql: "INSERT INTO persons (firstName, age) VALUES (?, ?)")
            updateStatement.arguments = arguments
            try updateStatement.execute()
            
            let selectStatement = try db.makeSelectStatement(sql: "SELECT * FROM persons WHERE firstName = ? AND age = ?")
            selectStatement.arguments = arguments
            let row = try Row.fetchOne(selectStatement)!
            
            XCTAssertEqual(row["firstName"] as String, name)
            XCTAssertEqual(row["age"] as Int, age)
        }
    }

    func testUnsafePositionalStatementArguments() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let name = "Arthur"
            let age = 42
            let arguments = StatementArguments([name, age] as [DatabaseValueConvertible?])
            
            let updateStatement = try db.makeUpdateStatement(sql: "INSERT INTO persons (firstName, age) VALUES (?, ?)")
            updateStatement.unsafeSetArguments(arguments)
            try updateStatement.execute()
            
            let selectStatement = try db.makeSelectStatement(sql: "SELECT * FROM persons WHERE firstName = ? AND age = ?")
            selectStatement.unsafeSetArguments(arguments)
            let row = try Row.fetchOne(selectStatement)!
            
            XCTAssertEqual(row["firstName"] as String, name)
            XCTAssertEqual(row["age"] as Int, age)
        }
    }

    func testNamedStatementArgumentsValidation() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let statement = try db.makeUpdateStatement(sql: "INSERT INTO persons (firstName, age) VALUES (:firstName, :age)")
            
            do {
                // Correct number of arguments
                try statement.validate(arguments: ["foo", 1])
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
            
            do {
                // All arguments are mapped
                try statement.validate(arguments: ["firstName": "foo", "age": 1])
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
            
            do {
                // All arguments are mapped
                try statement.validate(arguments: ["firstName": "foo", "age": 1, "bar": "baz"])
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
            
            do {
                // Missing arguments
                try statement.validate(arguments: [])
                XCTFail("Expected error")
            } catch is DatabaseError {
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
            
            do {
                // Missing arguments
                try statement.validate(arguments: ["foo"])
                XCTFail("Expected error")
            } catch is DatabaseError {
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
            
            do {
                // Too many arguments
                try statement.validate(arguments: ["foo", 1, "baz"])
                XCTFail("Expected error")
            } catch is DatabaseError {
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
            
            do {
                // Missing arguments
                try statement.validate(arguments: [:])
                XCTFail("Expected error")
            } catch is DatabaseError {
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
            
            do {
                // Missing arguments
                try statement.validate(arguments: ["firstName": "foo"])
                XCTFail("Expected error")
            } catch is DatabaseError {
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testNamedStatementArguments() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let name = "Arthur"
            let age = 42
            let arguments = StatementArguments(["name": name, "age": age] as [String: DatabaseValueConvertible?])
            
            let updateStatement = try db.makeUpdateStatement(sql: "INSERT INTO persons (firstName, age) VALUES (:name, :age)")
            updateStatement.arguments = arguments
            try updateStatement.execute()
            
            let selectStatement = try db.makeSelectStatement(sql: "SELECT * FROM persons WHERE firstName = :name AND age = :age")
            selectStatement.arguments = arguments
            let row = try Row.fetchOne(selectStatement)!
            
            XCTAssertEqual(row["firstName"] as String, name)
            XCTAssertEqual(row["age"] as Int, age)
        }
    }

    func testUnsafeNamedStatementArguments() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let name = "Arthur"
            let age = 42
            let arguments = StatementArguments(["name": name, "age": age] as [String: DatabaseValueConvertible?])
            
            let updateStatement = try db.makeUpdateStatement(sql: "INSERT INTO persons (firstName, age) VALUES (:name, :age)")
            updateStatement.unsafeSetArguments(arguments)
            try updateStatement.execute()
            
            let selectStatement = try db.makeSelectStatement(sql: "SELECT * FROM persons WHERE firstName = :name AND age = :age")
            selectStatement.unsafeSetArguments(arguments)
            let row = try Row.fetchOne(selectStatement)!
            
            XCTAssertEqual(row["firstName"] as String, name)
            XCTAssertEqual(row["age"] as Int, age)
        }
    }

    func testReusedNamedStatementArgumentsValidation() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let statement = try db.makeUpdateStatement(sql: "INSERT INTO persons (firstName, lastName, age) VALUES (:name, :name, :age)")
            
            do {
                try statement.execute(arguments: ["name": "foo", "age": 1])
                let row = try Row.fetchOne(db, sql: "SELECT * FROM persons")!
                XCTAssertEqual(row["firstName"] as String, "foo")
                XCTAssertEqual(row["lastName"] as String, "foo")
                XCTAssertEqual(row["age"] as Int, 1)
            }
            
            do {
                // Correct number of arguments
                try statement.validate(arguments: ["foo", 1])
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
            
            do {
                // All arguments are mapped
                try statement.validate(arguments: ["name": "foo", "age": 1])
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
            
            do {
                // All arguments are mapped
                try statement.validate(arguments: ["name": "foo", "age": 1, "bar": "baz"])
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
            
            do {
                // Missing arguments
                try statement.validate(arguments: [])
                XCTFail("Expected error")
            } catch is DatabaseError {
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
            
            do {
                // Missing arguments
                try statement.validate(arguments: ["foo"])
                XCTFail("Expected error")
            } catch is DatabaseError {
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
            
            do {
                // Too many arguments
                try statement.validate(arguments: ["foo", 1, "baz"])
                XCTFail("Expected error")
            } catch is DatabaseError {
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
            
            do {
                // Missing arguments
                try statement.validate(arguments: [:])
                XCTFail("Expected error")
            } catch is DatabaseError {
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
            
            do {
                // Missing arguments
                try statement.validate(arguments: ["name": "foo"])
                XCTFail("Expected error")
            } catch is DatabaseError {
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
        }
    }


    func testReusedNamedStatementArguments() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let name = "Arthur"
            let age = 42
            let arguments = StatementArguments(["name": name, "age": age] as [String: DatabaseValueConvertible?])
            
            let updateStatement = try db.makeUpdateStatement(sql: "INSERT INTO persons (firstName, lastName, age) VALUES (:name, :name, :age)")
            updateStatement.arguments = arguments
            try updateStatement.execute()
            
            let selectStatement = try db.makeSelectStatement(sql: "SELECT * FROM persons WHERE firstName = :name AND lastName = :name AND age = :age")
            selectStatement.arguments = arguments
            let row = try Row.fetchOne(selectStatement)!
            
            XCTAssertEqual(row["firstName"] as String, name)
            XCTAssertEqual(row["age"] as Int, age)
        }
    }

    func testUnsafeReusedNamedStatementArguments() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let name = "Arthur"
            let age = 42
            let arguments = StatementArguments(["name": name, "age": age] as [String: DatabaseValueConvertible?])
            
            let updateStatement = try db.makeUpdateStatement(sql: "INSERT INTO persons (firstName, lastName, age) VALUES (:name, :name, :age)")
            updateStatement.unsafeSetArguments(arguments)
            try updateStatement.execute()
            
            let selectStatement = try db.makeSelectStatement(sql: "SELECT * FROM persons WHERE firstName = :name AND lastName = :name AND age = :age")
            selectStatement.unsafeSetArguments(arguments)
            let row = try Row.fetchOne(selectStatement)!
            
            XCTAssertEqual(row["firstName"] as String, name)
            XCTAssertEqual(row["age"] as Int, age)
        }
    }

    func testMixedArguments() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let sql = "SELECT ?2 AS two, :foo AS foo, ?1 AS one, :foo AS foo2, :bar AS bar"
            let row = try Row.fetchOne(db, sql: sql, arguments: [1, 2, "bar"] + ["foo": "foo"])!
            XCTAssertEqual(row, ["two": 2, "foo": "foo", "one": 1, "foo2": "foo", "bar": "bar"])
        }
    }

    func testAppendContentsOf() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            do {
                var arguments: StatementArguments = [1, 2]
                let replacedValues = arguments.append(contentsOf: [3, 4])
                XCTAssert(replacedValues.isEmpty)
                
                let row = try Row.fetchOne(db, sql: "SELECT ?, ?, ?, ?", arguments: arguments)!
                XCTAssertEqual(row, ["?": 1, "?": 2, "?": 3, "?": 4])
            }
            
            do {
                var arguments: StatementArguments = ["foo": "foo", "bar": "bar", "toto": "titi"]
                let replacedValues = arguments.append(contentsOf: ["foo": "qux", "bar": "baz", "tata": "tutu"])
                XCTAssertEqual(replacedValues, ["foo": "foo".databaseValue, "bar": "bar".databaseValue])
                
                let row = try Row.fetchOne(db, sql: "SELECT :foo, :bar, :toto, :tata", arguments: arguments)!
                XCTAssertEqual(row, [":foo": "qux", ":bar": "baz", ":toto": "titi", ":tata": "tutu"])
            }
            
            do {
                var arguments: StatementArguments = [1, 2]
                let replacedValues = arguments.append(contentsOf: ["foo": "qux", "bar": "baz", "tata": "tutu"])
                XCTAssert(replacedValues.isEmpty)
                
                let row = try Row.fetchOne(db, sql: "SELECT ?, :foo, :bar, ?, :tata", arguments: arguments)!
                XCTAssertEqual(row, ["?": 1, ":foo": "qux", ":bar": "baz", "?": 2, ":tata": "tutu"])
            }
        }
    }

    func testPlusOperator() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            do {
                let arguments: StatementArguments = [1, 2] + [3, 4]
                let row = try Row.fetchOne(db, sql: "SELECT ?, ?, ?, ?", arguments: arguments)!
                XCTAssertEqual(row, ["?": 1, "?": 2, "?": 3, "?": 4])
            }
            
            do {
                // + does not allow overrides
                let arguments: StatementArguments = ["foo": "foo", "bar": "bar", "toto": "titi"] + ["tata": "tutu"]
                let row = try Row.fetchOne(db, sql: "SELECT :foo, :bar, :toto, :tata", arguments: arguments)!
                XCTAssertEqual(row, [":foo": "foo", ":bar": "bar", ":toto": "titi", ":tata": "tutu"])
            }
            
            do {
                let arguments: StatementArguments = [1, 2] + ["foo": "qux", "bar": "baz", "tata": "tutu"]
                let row = try Row.fetchOne(db, sql: "SELECT ?, :foo, :bar, ?, :tata", arguments: arguments)!
                XCTAssertEqual(row, ["?": 1, ":foo": "qux", ":bar": "baz", "?": 2, ":tata": "tutu"])
            }
        }
    }

    func testOverflowPlusOperator() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            do {
                let arguments: StatementArguments = [1, 2] &+ [3, 4]
                let row = try Row.fetchOne(db, sql: "SELECT ?, ?, ?, ?", arguments: arguments)!
                XCTAssertEqual(row, ["?": 1, "?": 2, "?": 3, "?": 4])
            }
            
            do {
                // &+ does not allow overrides
                let arguments: StatementArguments = ["foo": "foo", "bar": "bar", "toto": "titi"] &+ ["foo": "qux", "bar": "baz", "tata": "tutu"]
                let row = try Row.fetchOne(db, sql: "SELECT :foo, :bar, :toto, :tata", arguments: arguments)!
                XCTAssertEqual(row, [":foo": "qux", ":bar": "baz", ":toto": "titi", ":tata": "tutu"])
            }
            
            do {
                let arguments: StatementArguments = [1, 2] &+ ["foo": "qux", "bar": "baz", "tata": "tutu"]
                let row = try Row.fetchOne(db, sql: "SELECT ?, :foo, :bar, ?, :tata", arguments: arguments)!
                XCTAssertEqual(row, ["?": 1, ":foo": "qux", ":bar": "baz", "?": 2, ":tata": "tutu"])
            }
        }
    }

    func testPlusEqualOperator() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            do {
                var arguments: StatementArguments = [1, 2]
                arguments += [3, 4]
                let row = try Row.fetchOne(db, sql: "SELECT ?, ?, ?, ?", arguments: arguments)!
                XCTAssertEqual(row, ["?": 1, "?": 2, "?": 3, "?": 4])
            }
            
            do {
                // += does not allow overrides
                var arguments: StatementArguments = ["foo": "foo", "bar": "bar", "toto": "titi"]
                arguments += ["tata": "tutu"]
                let row = try Row.fetchOne(db, sql: "SELECT :foo, :bar, :toto, :tata", arguments: arguments)!
                XCTAssertEqual(row, [":foo": "foo", ":bar": "bar", ":toto": "titi", ":tata": "tutu"])
            }
            
            do {
                var arguments: StatementArguments = [1, 2]
                arguments += ["foo": "qux", "bar": "baz", "tata": "tutu"]
                let row = try Row.fetchOne(db, sql: "SELECT ?, :foo, :bar, ?, :tata", arguments: arguments)!
                XCTAssertEqual(row, ["?": 1, ":foo": "qux", ":bar": "baz", "?": 2, ":tata": "tutu"])
            }
        }
    }
}
