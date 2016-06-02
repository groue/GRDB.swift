import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class SelectStatementTests : GRDBTestCase {
    
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
            
            try db.execute("INSERT INTO persons (name, age) VALUES (?,?)", arguments: ["Arthur", 41])
            try db.execute("INSERT INTO persons (name, age) VALUES (?,?)", arguments: ["Barbara", 26])
            try db.execute("INSERT INTO persons (name, age) VALUES (?,?)", arguments: ["Craig", 13])
        }
        try migrator.migrate(dbWriter)
    }
    
    func testArrayStatementArguments() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let statement = try db.makeSelectStatement("SELECT COUNT(*) FROM persons WHERE age < ?")
                let ages = [20, 30, 40, 50]
                let counts = ages.map { Int.fetchOne(statement, arguments: [$0])! }
                XCTAssertEqual(counts, [1,2,2,3])
            }
        }
    }
    
    func testStatementArgumentsSetterWithArray() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let statement = try db.makeSelectStatement("SELECT COUNT(*) FROM persons WHERE age < ?")
                let ages = [20, 30, 40, 50]
                let counts = ages.map { (age: Int) -> Int in
                    statement.arguments = [age]
                    return Int.fetchOne(statement)!
                }
                XCTAssertEqual(counts, [1,2,2,3])
            }
        }
    }
    
    func testDictionaryStatementArguments() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let statement = try db.makeSelectStatement("SELECT COUNT(*) FROM persons WHERE age < :age")
                // TODO: Remove this explicit type declaration required by rdar://22357375
                let ageDicts: [[String: DatabaseValueConvertible?]] = [["age": 20], ["age": 30], ["age": 40], ["age": 50]]
                let counts = ageDicts.map { dic -> Int in
                    // Make sure we don't trigger a failible initializer
                    let arguments: StatementArguments = StatementArguments(dic)
                    return Int.fetchOne(statement, arguments: arguments)!
                }
                XCTAssertEqual(counts, [1,2,2,3])
            }
        }
    }
    
    func testStatementArgumentsSetterWithDictionary() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let statement = try db.makeSelectStatement("SELECT COUNT(*) FROM persons WHERE age < :age")
                // TODO: Remove this explicit type declaration required by rdar://22357375
                let ageDicts: [[String: DatabaseValueConvertible?]] = [["age": 20], ["age": 30], ["age": 40], ["age": 50]]
                let counts = ageDicts.map { ageDict -> Int in
                    statement.arguments = StatementArguments(ageDict)
                    return Int.fetchOne(statement)!
                }
                XCTAssertEqual(counts, [1,2,2,3])
            }
        }
    }
    
    func testRowSequenceCanBeFetchedTwice() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let statement = try db.makeSelectStatement("SELECT * FROM persons ORDER BY name")
                var names1 = Row.fetch(statement).map { $0.value(named: "name") as String }
                var names2 = Row.fetch(statement).map { $0.value(named: "name") as String }
                
                XCTAssertEqual(names1[0], "Arthur")
                XCTAssertEqual(names1[1], "Barbara")
                XCTAssertEqual(names1[2], "Craig")
                XCTAssertEqual(names2[0], "Arthur")
                XCTAssertEqual(names2[1], "Barbara")
                XCTAssertEqual(names2[2], "Craig")
            }
        }
    }

    func testRowSequenceCanBeIteratedTwice() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let statement = try db.makeSelectStatement("SELECT * FROM persons ORDER BY name")
                let rows = Row.fetch(statement)
                var names1 = rows.map { $0.value(named: "name") as String }
                var names2 = rows.map { $0.value(named: "name") as String }
                
                XCTAssertEqual(names1[0], "Arthur")
                XCTAssertEqual(names1[1], "Barbara")
                XCTAssertEqual(names1[2], "Craig")
                XCTAssertEqual(names2[0], "Arthur")
                XCTAssertEqual(names2[1], "Barbara")
                XCTAssertEqual(names2[2], "Craig")
            }
        }
    }
    
    func testValueSequenceCanBeFetchedTwice() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let statement = try db.makeSelectStatement("SELECT name FROM persons ORDER BY name")
                var names1 = Array(String.fetch(statement))
                var names2 = Array(String.fetch(statement))
                
                XCTAssertEqual(names1[0], "Arthur")
                XCTAssertEqual(names1[1], "Barbara")
                XCTAssertEqual(names1[2], "Craig")
                XCTAssertEqual(names2[0], "Arthur")
                XCTAssertEqual(names2[1], "Barbara")
                XCTAssertEqual(names2[2], "Craig")
            }
        }
    }
    
    func testValueSequenceCanBeIteratedTwice() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let statement = try db.makeSelectStatement("SELECT name FROM persons ORDER BY name")
                let nameSequence = String.fetch(statement)
                var names1 = Array(nameSequence)
                var names2 = Array(nameSequence)
                
                XCTAssertEqual(names1[0], "Arthur")
                XCTAssertEqual(names1[1], "Barbara")
                XCTAssertEqual(names1[2], "Craig")
                XCTAssertEqual(names2[0], "Arthur")
                XCTAssertEqual(names2[1], "Barbara")
                XCTAssertEqual(names2[2], "Craig")
            }
        }
    }
    
    func testDatabaseErrorThrownBySelectStatementContainSQL() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                do {
                    _ = try db.makeSelectStatement("SELECT * FROM blah")
                    XCTFail()
                } catch let error as DatabaseError {
                    XCTAssertEqual(error.code, 1)
                    XCTAssertEqual(error.message!, "no such table: blah")
                    XCTAssertEqual(error.sql!, "SELECT * FROM blah")
                    XCTAssertEqual(error.description, "SQLite error 1 with statement `SELECT * FROM blah`: no such table: blah")
                }
            }
        }
    }
}
