import XCTest
@testable import GRDB

class SelectStatementTests : GRDBTestCase {
    
    override func setup(_ dbWriter: some DatabaseWriter) throws {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createPersons") { db in
            try db.execute(sql: """
                CREATE TABLE persons (
                    id INTEGER PRIMARY KEY,
                    creationDate TEXT,
                    name TEXT NOT NULL,
                    age INT)
                """)
            
            try db.execute(sql: "INSERT INTO persons (name, age) VALUES (?,?)", arguments: ["Arthur", 41])
            try db.execute(sql: "INSERT INTO persons (name, age) VALUES (?,?)", arguments: ["Barbara", 26])
            try db.execute(sql: "INSERT INTO persons (name, age) VALUES (?,?)", arguments: ["Craig", 13])
        }
        try migrator.migrate(dbWriter)
    }
    
    func testStatementCursor() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let sql = "SELECT 'Arthur' AS firstName, 'Martin' AS lastName UNION ALL SELECT 'Barbara', 'Gourde'"
            let statement = try db.makeStatement(sql: sql)
            let cursor = try statement.makeCursor()
            
            // Test that cursor provides statement information
            XCTAssertEqual(cursor.sql, sql)
            XCTAssertEqual(cursor.arguments, [])
            XCTAssertEqual(cursor.columnCount, 2)
            XCTAssertEqual(cursor.columnNames, ["firstName", "lastName"])
            XCTAssertEqual(cursor.databaseRegion.description, "empty")
            
            XCTAssertFalse(try cursor.next() == nil)
            XCTAssertFalse(try cursor.next() == nil)
            XCTAssertTrue(try cursor.next() == nil) // end
            XCTAssertTrue(try cursor.next() == nil) // past the end
        }
    }
    
    func testStatementCursorStepFailure() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let customError = NSError(domain: "Custom", code: 0xDEAD)
            db.add(function: DatabaseFunction("throw", argumentCount: 0, pure: true) { _ in throw customError })
            func test(_ cursor: StatementCursor) throws {
                let sql = cursor.sql
                do {
                    _ = try cursor.next()
                    XCTFail()
                } catch let error as DatabaseError {
                    XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
                    XCTAssertEqual(error.message, "\(customError)")
                    XCTAssertEqual(error.sql!, sql)
                    XCTAssertEqual(error.description, "SQLite error 1: \(customError) - while executing `\(sql)`")
                }
                do {
                    _ = try cursor.next()
                    XCTFail()
                } catch is DatabaseError {
                    // Various SQLite and SQLCipher versions don't emit the same
                    // error. What we care about is that there is an error.
                }
            }
            try test(db.makeStatement(sql: "SELECT throw(), NULL").makeCursor())
            try test(db.makeStatement(sql: "SELECT 0, throw(), NULL").makeCursor())
        }
    }
    
    func testArrayStatementArguments() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let statement = try db.makeStatement(sql: "SELECT COUNT(*) FROM persons WHERE age < ?")
            let ages = [20, 30, 40, 50]
            let counts = try ages.map { try Int.fetchOne(statement, arguments: [$0])! }
            XCTAssertEqual(counts, [1,2,2,3])
        }
    }

    func testStatementArgumentsSetterWithArray() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let statement = try db.makeStatement(sql: "SELECT COUNT(*) FROM persons WHERE age < ?")
            let ages = [20, 30, 40, 50]
            let counts = try ages.map { (age: Int) -> Int in
                statement.arguments = [age]
                return try Int.fetchOne(statement)!
            }
            XCTAssertEqual(counts, [1,2,2,3])
        }
    }

    func testDictionaryStatementArguments() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let statement = try db.makeStatement(sql: "SELECT COUNT(*) FROM persons WHERE age < :age")
            let ageDicts: [[String: (any DatabaseValueConvertible)?]] = [["age": 20], ["age": 30], ["age": 40], ["age": 50]]
            let counts = try ageDicts.map { dic -> Int in
                // Make sure we don't trigger a failible initializer
                let arguments: StatementArguments = StatementArguments(dic)
                return try Int.fetchOne(statement, arguments: arguments)!
            }
            XCTAssertEqual(counts, [1,2,2,3])
        }
    }

    func testStatementArgumentsSetterWithDictionary() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let statement = try db.makeStatement(sql: "SELECT COUNT(*) FROM persons WHERE age < :age")
            let ageDicts: [[String: (any DatabaseValueConvertible)?]] = [["age": 20], ["age": 30], ["age": 40], ["age": 50]]
            let counts = try ageDicts.map { ageDict -> Int in
                statement.arguments = StatementArguments(ageDict)
                return try Int.fetchOne(statement)!
            }
            XCTAssertEqual(counts, [1,2,2,3])
        }
    }

    func testDatabaseErrorThrownBySelectStatementContainSQL() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            do {
                _ = try db.makeStatement(sql: "SELECT * FROM blah")
                XCTFail()
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
                XCTAssertEqual(error.message!, "no such table: blah")
                XCTAssertEqual(error.sql!, "SELECT * FROM blah")
                XCTAssertEqual(error.description, "SQLite error 1: no such table: blah - while executing `SELECT * FROM blah`")
            }
        }
    }

    func testCachedSelectStatementStepFailure() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let needsThrowMutex = Mutex(false)
            db.add(function: DatabaseFunction("bomb", argumentCount: 0, pure: false) { _ in
                if needsThrowMutex.load() {
                    throw DatabaseError(message: "boom")
                }
                return "success"
            })
            let sql = "SELECT bomb()"
            
            needsThrowMutex.store(false)
            XCTAssertEqual(try String.fetchAll(db.cachedStatement(sql: sql)), ["success"])
            
            do {
                needsThrowMutex.store(true)
                _ = try String.fetchAll(db.cachedStatement(sql: sql))
                XCTFail()
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
                XCTAssertEqual(error.message!, "boom")
                XCTAssertEqual(error.sql!, sql)
                XCTAssertEqual(error.description, "SQLite error 1: boom - while executing `\(sql)`")
            }
            
            needsThrowMutex.store(false)
            XCTAssertEqual(try String.fetchAll(db.cachedStatement(sql: sql)), ["success"])
        }
    }
    
    func testConsumeMultipleStatements() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.writeWithoutTransaction { db in
            do {
                // SQL, no argument
                let statements = try db.allStatements(sql: """
                    SELECT age FROM persons ORDER BY age;
                    SELECT age FROM persons ORDER BY age DESC;
                    """)
                let ages = try Array(statements.flatMap { try Int.fetchCursor($0) })
                XCTAssertEqual(ages, [13, 26, 41, 41, 26, 13])
            }
            do {
                // Literal, no argument
                let statements = try db.allStatements(literal: """
                    SELECT age FROM persons ORDER BY age;
                    SELECT age FROM persons ORDER BY age DESC;
                    """)
                let ages = try Array(statements.flatMap { try Int.fetchCursor($0) })
                XCTAssertEqual(ages, [13, 26, 41, 41, 26, 13])
            }
            
            do {
                // SQL, missing arguments
                let statements = try db.allStatements(sql: """
                    SELECT count(*) FROM persons WHERE age > ?;
                    SELECT count(*) FROM persons WHERE age < ?;
                    """)
                let counts = try Array(statements.map { try
                    Int.fetchOne($0, arguments: [30])!
                })
                XCTAssertEqual(counts, [1, 2])
            }
            do {
                // Literal, missing arguments
                let statements = try db.allStatements(literal: """
                    SELECT count(*) FROM persons WHERE age > ?;
                    SELECT count(*) FROM persons WHERE age < ?;
                    """)
                let counts = try Array(statements.map { try
                    Int.fetchOne($0, arguments: [30])!
                })
                XCTAssertEqual(counts, [1, 2])
            }
            
            do {
                // SQL, matching arguments
                let statements = try db.allStatements(sql: """
                    SELECT name FROM persons WHERE name = ?;
                    SELECT name FROM persons WHERE age > ? ORDER BY name;
                    """, arguments: ["Arthur", 20])
                let names = try Array(statements.map { try String.fetchAll($0) })
                XCTAssertEqual(names, [["Arthur"], ["Arthur", "Barbara"]])
            }
            do {
                // Literal, matching arguments
                let statements = try db.allStatements(literal: """
                    SELECT name FROM persons WHERE name = \("Arthur");
                    SELECT name FROM persons WHERE age > \(20) ORDER BY name;
                    """)
                let names = try Array(statements.map { try String.fetchAll($0) })
                XCTAssertEqual(names, [["Arthur"], ["Arthur", "Barbara"]])
            }
            
            do {
                // SQL, too few arguments
                let statements = try db.allStatements(sql: """
                    SELECT name FROM persons WHERE name = ?;
                    SELECT name FROM persons WHERE age > ? ORDER BY name;
                    """, arguments: ["Arthur"])
                _ = try Array(statements.map { try String.fetchAll($0) })
                XCTFail("Expected Error")
            } catch DatabaseError.SQLITE_MISUSE {
                // OK
            }
            do {
                // Literal, too few arguments
                let statements = try db.allStatements(literal: """
                    SELECT name FROM persons WHERE name = \("Arthur");
                    SELECT name FROM persons WHERE age > ? ORDER BY name;
                    """)
                _ = try Array(statements.map { try String.fetchAll($0) })
                XCTFail("Expected Error")
            } catch DatabaseError.SQLITE_MISUSE {
                // OK
            }
            
            do {
                // SQL, too many arguments
                let statements = try db.allStatements(sql: """
                    SELECT name FROM persons WHERE name = ?;
                    SELECT name FROM persons WHERE age > ? ORDER BY name;
                    """, arguments: ["Arthur", 20, 55])
                _ = try Array(statements.map { try String.fetchAll($0) })
                XCTFail("Expected Error")
            } catch DatabaseError.SQLITE_MISUSE {
                // OK
            }
            
            do {
                // Mix statement kinds
                let statements = try db.allStatements(literal: """
                    CREATE TABLE t(a);
                    INSERT INTO t VALUES (0);
                    SELECT a FROM t ORDER BY a;
                    INSERT INTO t VALUES (1);
                    SELECT a FROM t ORDER BY a;
                    """)
                let values = try Array(statements.map { try Int.fetchAll($0) })
                XCTAssertEqual(values, [[], [], [0], [], [0, 1]])
            }
        }
    }
    
    func testRegion() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.writeWithoutTransaction { db in
            class Observer: TransactionObserver {
                private var didChange = false
                var triggered = false
                let region: DatabaseRegion
                
                init(region: DatabaseRegion) {
                    self.region = region
                }
                
                func observes(eventsOfKind eventKind: DatabaseEventKind) -> Bool {
                    region.isModified(byEventsOfKind: eventKind)
                }
                
                func databaseDidChange(with event: DatabaseEvent) {
                    didChange = true
                }
                
                func databaseDidCommit(_ db: Database) {
                    triggered = didChange
                    didChange = false
                }
                
                func databaseDidRollback(_ db: Database) {
                    didChange = false
                }
            }
            
            try db.create(table: "table1") { t in
                t.primaryKey("id", .integer)
                t.column("id3", .integer).references("table3", column: "id", onDelete: .cascade, onUpdate: .cascade)
                t.column("id4", .integer).references("table4", column: "id", onDelete: .setNull, onUpdate: .cascade)
                t.column("a", .integer)
                t.column("b", .integer)
            }
            try db.create(table: "table2") { t in
                t.primaryKey("id", .integer)
                t.column("a", .integer)
                t.column("b", .integer)
            }
            try db.create(table: "table3") { t in
                t.primaryKey("id", .integer)
            }
            try db.create(table: "table4") { t in
                t.primaryKey("id", .integer)
            }
            try db.create(table: "table5") { t in
                t.primaryKey("id", .integer)
            }
            try db.execute(sql: "CREATE TRIGGER table5trigger AFTER INSERT ON table5 BEGIN INSERT INTO table1 (id3, id4, a, b) VALUES (NULL, NULL, 0, 0); END")
            
            let statements = try [
                db.makeStatement(sql: "SELECT * FROM table1"),
                db.makeStatement(sql: "SELECT id, id3, a FROM table1"),
                db.makeStatement(sql: "SELECT table1.id, table1.a, table2.a FROM table1 JOIN table2 ON table1.id = table2.id"),
                db.makeStatement(sql: "SELECT COUNT(*) FROM table1"),
            ]
            
            let observers = statements.map { Observer(region: $0.databaseRegion) }
            XCTAssertEqual(observers.map { $0.region.description }, ["table1(a,b,id,id3,id4)","table1(a,id,id3)", "table1(a,id),table2(a,id)", "table1(*)"])
            
            for observer in observers {
                db.add(transactionObserver: observer)
            }
            
            try db.execute(sql: "INSERT INTO table3 (id) VALUES (1)")
            try db.execute(sql: "INSERT INTO table4 (id) VALUES (1)")
            try db.execute(sql: "INSERT INTO table1 (id, a, b, id3, id4) VALUES (NULL, 0, 0, 1, 1)")
            XCTAssertEqual(observers.map(\.triggered), [true, true, true, true])
            
            try db.execute(sql: "INSERT INTO table2 (id, a, b) VALUES (NULL, 0, 0)")
            XCTAssertEqual(observers.map(\.triggered), [false, false, true, false])
            
            try db.execute(sql: "UPDATE table1 SET a = 1")
            XCTAssertEqual(observers.map(\.triggered), [true, true, true, true])
            
            try db.execute(sql: "UPDATE table1 SET b = 1")
            XCTAssertEqual(observers.map(\.triggered), [true, false, false, true])
            
            try db.execute(sql: "UPDATE table2 SET a = 1")
            XCTAssertEqual(observers.map(\.triggered), [false, false, true, false])
            
            try db.execute(sql: "UPDATE table2 SET b = 1")
            XCTAssertEqual(observers.map(\.triggered), [false, false, false, false])
            
            try db.execute(sql: "UPDATE table3 SET id = 2 WHERE id = 1")
            XCTAssertEqual(observers.map(\.triggered), [true, true, false, true])
            
            try db.execute(sql: "UPDATE table4 SET id = 2 WHERE id = 1")
            XCTAssertEqual(observers.map(\.triggered), [true, false, false, true])
            
            try db.execute(sql: "DELETE FROM table4")
            XCTAssertEqual(observers.map(\.triggered), [true, false, false, true])
            
            try db.execute(sql: "INSERT INTO table4 (id) VALUES (1)")
            try db.execute(sql: "DELETE FROM table4")
            XCTAssertEqual(observers.map(\.triggered), [false, false, false, false])
            
            try db.execute(sql: "DELETE FROM table3")
            XCTAssertEqual(observers.map(\.triggered), [true, true, true, true])
            
            try db.execute(sql: "INSERT INTO table5 (id) VALUES (NULL)")
            XCTAssertEqual(observers.map(\.triggered), [true, true, true, true])
        }
    }
}
