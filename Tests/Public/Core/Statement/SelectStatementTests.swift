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
    
    func testArrayStatementArguments() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let statement = try db.makeSelectStatement("SELECT COUNT(*) FROM persons WHERE age < ?")
            let ages = [20, 30, 40, 50]
            let counts = try ages.map { try Int.fetchOne(statement, arguments: [$0])! }
            XCTAssertEqual(counts, [1,2,2,3])
        }
    }

    func testStatementArgumentsSetterWithArray() throws {
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

    func testDictionaryStatementArguments() throws {
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

    func testStatementArgumentsSetterWithDictionary() throws {
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

    func testDatabaseErrorThrownBySelectStatementContainSQL() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            do {
                _ = try db.makeSelectStatement("SELECT * FROM blah")
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
            XCTAssertEqual(try String.fetchAll(db.cachedSelectStatement(sql)), ["success"])
            
            do {
                needsThrow = true
                _ = try String.fetchAll(db.cachedSelectStatement(sql))
                XCTFail()
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
                XCTAssertEqual(error.message!, "boom")
                XCTAssertEqual(error.sql!, sql)
                XCTAssertEqual(error.description, "SQLite error 1 with statement `\(sql)`: boom")
            }
            
            needsThrow = false
            XCTAssertEqual(try String.fetchAll(db.cachedSelectStatement(sql)), ["success"])
        }
    }
    
    func testSelectionInfo() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            class Observer: TransactionObserver {
                private var didChange: Bool = false
                var triggered: Bool = false
                let selectionInfo: SelectStatement.SelectionInfo
                
                init(selectionInfo: SelectStatement.SelectionInfo) {
                    self.selectionInfo = selectionInfo
                }
                
                func observes(eventsOfKind eventKind: DatabaseEventKind) -> Bool {
                    return eventKind.impacts(selectionInfo)
                }
                
                func databaseDidChange(with event: DatabaseEvent) {
                    didChange = true
                }
                
                func databaseWillCommit() throws { }
                
                func databaseDidCommit(_ db: Database) {
                    triggered = didChange
                    didChange = false
                }
                
                func databaseDidRollback(_ db: Database) {
                    didChange = false
                }
                
                #if SQLITE_ENABLE_PREUPDATE_HOOK
                func databaseWillChange(with event: DatabasePreUpdateEvent) { }
                #endif
            }
            
            try db.create(table: "table1") { t in
                t.column("id", .integer).primaryKey()
                t.column("a", .integer)
                t.column("b", .integer)
            }
            try db.create(table: "table2") { t in
                t.column("id", .integer).primaryKey()
                t.column("a", .integer)
                t.column("b", .integer)
            }
            
            let statement1 = try db.makeSelectStatement("SELECT * FROM table1")
            let statement2 = try db.makeSelectStatement("SELECT id, a FROM table1")
            let statement3 = try db.makeSelectStatement("SELECT table1.id, table1.a, table2.a FROM table1 JOIN table2 ON table1.id = table2.id")
            
            let observer1 = Observer(selectionInfo: statement1.selectionInfo)
            let observer2 = Observer(selectionInfo: statement2.selectionInfo)
            let observer3 = Observer(selectionInfo: statement3.selectionInfo)
            
            db.add(transactionObserver: observer1)
            db.add(transactionObserver: observer2)
            db.add(transactionObserver: observer3)
            
            try db.execute("INSERT INTO table1 (id, a, b) VALUES (NULL, 0, 0)")
            XCTAssertTrue(observer1.triggered)
            XCTAssertTrue(observer2.triggered)
            XCTAssertTrue(observer3.triggered)
            
            try db.execute("INSERT INTO table2 (id, a, b) VALUES (NULL, 0, 0)")
            XCTAssertFalse(observer1.triggered)
            XCTAssertFalse(observer2.triggered)
            XCTAssertTrue(observer3.triggered)
            
            try db.execute("UPDATE table1 SET a = 1")
            XCTAssertTrue(observer1.triggered)
            XCTAssertTrue(observer2.triggered)
            XCTAssertTrue(observer3.triggered)
            
            try db.execute("UPDATE table1 SET b = 1")
            XCTAssertTrue(observer1.triggered)
            XCTAssertFalse(observer2.triggered)
            XCTAssertFalse(observer3.triggered)
            
            try db.execute("UPDATE table2 SET a = 1")
            XCTAssertFalse(observer1.triggered)
            XCTAssertFalse(observer2.triggered)
            XCTAssertTrue(observer3.triggered)
            
            try db.execute("UPDATE table2 SET b = 1")
            XCTAssertFalse(observer1.triggered)
            XCTAssertFalse(observer2.triggered)
            XCTAssertFalse(observer3.triggered)
        }
    }
}
