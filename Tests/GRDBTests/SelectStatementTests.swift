import XCTest
#if GRDBCUSTOMSQLITE
    @testable import GRDBCustomSQLite
#else
    #if GRDBCIPHER
        import SQLCipher
    #elseif SWIFT_PACKAGE
        import CSQLite
    #else
        import SQLite3
    #endif
    @testable import GRDB
#endif

class SelectStatementTests : GRDBTestCase {
    
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
            let statement = try db.makeSelectStatement(sql: sql)
            let cursor = try statement.makeCursor()
            
            // Check that StatementCursor gives access to the raw SQLite API
            XCTAssertEqual(String(cString: sqlite3_column_name(cursor._statement.sqliteStatement, 0)), "firstName")
            
            XCTAssertFalse(try cursor.next() == nil)
            XCTAssertFalse(try cursor.next() == nil)
            XCTAssertTrue(try cursor.next() == nil) // end
            XCTAssertTrue(try cursor.next() == nil) // past the end
        }
    }
    
    func testStatementCursorStepFailure() throws {
        let dbQueue = try makeDatabaseQueue()
        let customError = NSError(domain: "Custom", code: 0xDEAD)
        dbQueue.add(function: DatabaseFunction("throw", argumentCount: 0, pure: true) { _ in throw customError })
        try dbQueue.inDatabase { db in
            func test(_ cursor: StatementCursor) throws {
                let sql = cursor._statement.sql
                do {
                    _ = try cursor.next()
                    XCTFail()
                } catch let error as DatabaseError {
                    XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
                    XCTAssertEqual(error.message, "\(customError)")
                    XCTAssertEqual(error.sql!, sql)
                    XCTAssertEqual(error.description, "SQLite error 1 with statement `\(sql)`: \(customError)")
                }
                do {
                    _ = try cursor.next()
                    XCTFail()
                } catch is DatabaseError {
                    // Various SQLite and SQLCipher versions don't emit the same
                    // error. What we care about is that there is an error.
                }
            }
            try test(db.makeSelectStatement(sql: "SELECT throw(), NULL").makeCursor())
            try test(db.makeSelectStatement(sql: "SELECT 0, throw(), NULL").makeCursor())
        }
    }
    
    func testArrayStatementArguments() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let statement = try db.makeSelectStatement(sql: "SELECT COUNT(*) FROM persons WHERE age < ?")
            let ages = [20, 30, 40, 50]
            let counts = try ages.map { try Int.fetchOne(statement, arguments: [$0])! }
            XCTAssertEqual(counts, [1,2,2,3])
        }
    }

    func testStatementArgumentsSetterWithArray() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let statement = try db.makeSelectStatement(sql: "SELECT COUNT(*) FROM persons WHERE age < ?")
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
            let statement = try db.makeSelectStatement(sql: "SELECT COUNT(*) FROM persons WHERE age < :age")
            let ageDicts: [[String: DatabaseValueConvertible?]] = [["age": 20], ["age": 30], ["age": 40], ["age": 50]]
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
            let statement = try db.makeSelectStatement(sql: "SELECT COUNT(*) FROM persons WHERE age < :age")
            let ageDicts: [[String: DatabaseValueConvertible?]] = [["age": 20], ["age": 30], ["age": 40], ["age": 50]]
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
                _ = try db.makeSelectStatement(sql: "SELECT * FROM blah")
                XCTFail()
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
                XCTAssertEqual(error.message!, "no such table: blah")
                XCTAssertEqual(error.sql!, "SELECT * FROM blah")
                XCTAssertEqual(error.description, "SQLite error 1 with statement `SELECT * FROM blah`: no such table: blah")
            }
        }
    }

    func testCachedSelectStatementStepFailure() throws {
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
            XCTAssertEqual(try String.fetchAll(db.cachedSelectStatement(sql: sql)), ["success"])
            
            do {
                needsThrow = true
                _ = try String.fetchAll(db.cachedSelectStatement(sql: sql))
                XCTFail()
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
                XCTAssertEqual(error.message!, "boom")
                XCTAssertEqual(error.sql!, sql)
                XCTAssertEqual(error.description, "SQLite error 1 with statement `\(sql)`: boom")
            }
            
            needsThrow = false
            XCTAssertEqual(try String.fetchAll(db.cachedSelectStatement(sql: sql)), ["success"])
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
                    return region.isModified(byEventsOfKind: eventKind)
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
                t.column("id", .integer).primaryKey()
                t.column("id3", .integer).references("table3", column: "id", onDelete: .cascade, onUpdate: .cascade)
                t.column("id4", .integer).references("table4", column: "id", onDelete: .setNull, onUpdate: .cascade)
                t.column("a", .integer)
                t.column("b", .integer)
            }
            try db.create(table: "table2") { t in
                t.column("id", .integer).primaryKey()
                t.column("a", .integer)
                t.column("b", .integer)
            }
            try db.create(table: "table3") { t in
                t.column("id", .integer).primaryKey()
            }
            try db.create(table: "table4") { t in
                t.column("id", .integer).primaryKey()
            }
            try db.create(table: "table5") { t in
                t.column("id", .integer).primaryKey()
            }
            try db.execute(sql: "CREATE TRIGGER table5trigger AFTER INSERT ON table5 BEGIN INSERT INTO table1 (id3, id4, a, b) VALUES (NULL, NULL, 0, 0); END")
            
            let statements = try [
                db.makeSelectStatement(sql: "SELECT * FROM table1"),
                db.makeSelectStatement(sql: "SELECT id, id3, a FROM table1"),
                db.makeSelectStatement(sql: "SELECT table1.id, table1.a, table2.a FROM table1 JOIN table2 ON table1.id = table2.id"),
                
                // This last request triggers its observer or not, depending on the SQLite version.
                // Before SQLite 3.19.0, its region is doubtful, and every database change is deemed impactful.
                // Starting SQLite 3.19.0, it knows that only table1 is involved.
                //
                // See doubtfulCountFunction below
                db.makeSelectStatement(sql: "SELECT COUNT(*) FROM table1"),
            ]
            
            let doubtfulCountFunction = (sqlite3_libversion_number() < 3019000)
            
            let observers = statements.map { Observer(region: $0.databaseRegion) }
            if doubtfulCountFunction {
                XCTAssertEqual(observers.map { $0.region.description }, ["table1(a,b,id,id3,id4)","table1(a,id,id3)", "table1(a,id),table2(a,id)", "full database"])
            } else {
                XCTAssertEqual(observers.map { $0.region.description }, ["table1(a,b,id,id3,id4)","table1(a,id,id3)", "table1(a,id),table2(a,id)", "table1(*)"])
            }
            
            for observer in observers {
                db.add(transactionObserver: observer)
            }
            
            try db.execute(sql: "INSERT INTO table3 (id) VALUES (1)")
            try db.execute(sql: "INSERT INTO table4 (id) VALUES (1)")
            try db.execute(sql: "INSERT INTO table1 (id, a, b, id3, id4) VALUES (NULL, 0, 0, 1, 1)")
            XCTAssertEqual(observers.map { $0.triggered }, [true, true, true, true])
            
            try db.execute(sql: "INSERT INTO table2 (id, a, b) VALUES (NULL, 0, 0)")
            XCTAssertEqual(observers.map { $0.triggered }, [false, false, true, doubtfulCountFunction])
            
            try db.execute(sql: "UPDATE table1 SET a = 1")
            XCTAssertEqual(observers.map { $0.triggered }, [true, true, true, true])
            
            try db.execute(sql: "UPDATE table1 SET b = 1")
            XCTAssertEqual(observers.map { $0.triggered }, [true, false, false, true])
            
            try db.execute(sql: "UPDATE table2 SET a = 1")
            XCTAssertEqual(observers.map { $0.triggered }, [false, false, true, doubtfulCountFunction])
            
            try db.execute(sql: "UPDATE table2 SET b = 1")
            XCTAssertEqual(observers.map { $0.triggered }, [false, false, false, doubtfulCountFunction])
            
            try db.execute(sql: "UPDATE table3 SET id = 2 WHERE id = 1")
            XCTAssertEqual(observers.map { $0.triggered }, [true, true, false, true])
            
            try db.execute(sql: "UPDATE table4 SET id = 2 WHERE id = 1")
            XCTAssertEqual(observers.map { $0.triggered }, [true, false, false, true])
            
            try db.execute(sql: "DELETE FROM table4")
            XCTAssertEqual(observers.map { $0.triggered }, [true, false, false, true])
            
            try db.execute(sql: "INSERT INTO table4 (id) VALUES (1)")
            try db.execute(sql: "DELETE FROM table4")
            XCTAssertEqual(observers.map { $0.triggered }, [false, false, false, doubtfulCountFunction])
            
            try db.execute(sql: "DELETE FROM table3")
            XCTAssertEqual(observers.map { $0.triggered }, [true, true, true, true])
            
            try db.execute(sql: "INSERT INTO table5 (id) VALUES (NULL)")
            XCTAssertEqual(observers.map { $0.triggered }, [true, true, true, true])
        }
    }
}
