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
                let counts = try ages.map { try Int.fetchOne(statement, arguments: [$0])! }
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
                let counts = try ages.map { (age: Int) -> Int in
                    statement.arguments = [age]
                    return try Int.fetchOne(statement)!
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
                let counts = try ageDicts.map { dic -> Int in
                    // Make sure we don't trigger a failible initializer
                    let arguments: StatementArguments = StatementArguments(dic)
                    return try Int.fetchOne(statement, arguments: arguments)!
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
                let counts = try ageDicts.map { ageDict -> Int in
                    statement.arguments = StatementArguments(ageDict)
                    return try Int.fetchOne(statement)!
                }
                XCTAssertEqual(counts, [1,2,2,3])
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
    
    func testCachedSelectStatementStepFailure() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            var needsThrow = false
            dbQueue.add(function: DatabaseFunction("bomb", argumentCount: 0, pure: false) { _ in
                if needsThrow {
                    throw DatabaseError(message: "boom")
                }
                return "success"
            })
            try dbQueue.inDatabase { db in
                let sql = "SELECT bomb()"
                
                needsThrow = false
                XCTAssertEqual(try String.fetchAll(db.cachedSelectStatement(sql)), ["success"])
                
                do {
                    needsThrow = true
                    _ = try String.fetchAll(db.cachedSelectStatement(sql))
                    XCTFail()
                } catch let error as DatabaseError {
                    XCTAssertEqual(error.code, 1)
                    XCTAssertEqual(error.message!, "boom")
                    XCTAssertEqual(error.sql!, sql)
                    XCTAssertEqual(error.description, "SQLite error 1 with statement `\(sql)`: boom")
                }
                
                needsThrow = false
                XCTAssertEqual(try String.fetchAll(db.cachedSelectStatement(sql)), ["success"])
            }
        }
    }
}
