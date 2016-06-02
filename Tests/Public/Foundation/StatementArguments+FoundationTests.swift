import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class StatementArgumentsFoundationTests: GRDBTestCase {

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
    
    func testStatementArgumentsNSArrayInitializer() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            
            try dbQueue.inTransaction { db in
                
                let statement = try db.makeUpdateStatement("INSERT INTO persons (name, age) VALUES (?, ?)")
                let persons: [NSArray] = [
                    ["Arthur", 41],
                    ["Barbara", 38],
                ]
                for person in persons {
                    try statement.execute(arguments: StatementArguments(person)!)
                }
                
                return .commit
            }
            
            dbQueue.inDatabase { db in
                let rows = Row.fetchAll(db, "SELECT * FROM persons ORDER BY name")
                XCTAssertEqual(rows.count, 2)
                XCTAssertEqual(rows[0].value(named: "name") as String, "Arthur")
                XCTAssertEqual(rows[0].value(named: "age") as Int, 41)
                XCTAssertEqual(rows[1].value(named: "name") as String, "Barbara")
                XCTAssertEqual(rows[1].value(named: "age") as Int, 38)
            }
        }
    }
    
    func testStatementArgumentsNSDictionaryInitializer() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            
            try dbQueue.inTransaction { db in
                
                let statement = try db.makeUpdateStatement("INSERT INTO persons (name, age) VALUES (:name, :age)")
                let persons: [NSDictionary] = [
                    ["name": "Arthur", "age": 41],
                    ["name": "Barbara", "age": 38],
                ]
                for person in persons {
                    try statement.execute(arguments: StatementArguments(person)!)
                }
                
                return .commit
            }
            
            dbQueue.inDatabase { db in
                let rows = Row.fetchAll(db, "SELECT * FROM persons ORDER BY name")
                XCTAssertEqual(rows.count, 2)
                XCTAssertEqual(rows[0].value(named: "name") as String, "Arthur")
                XCTAssertEqual(rows[0].value(named: "age") as Int, 41)
                XCTAssertEqual(rows[1].value(named: "name") as String, "Barbara")
                XCTAssertEqual(rows[1].value(named: "age") as Int, 38)
            }
        }
    }
}
