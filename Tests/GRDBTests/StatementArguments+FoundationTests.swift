import XCTest
#if GRDBCIPHER
    import GRDBCipher
#elseif GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

private class NonDatabaseConvertibleObject: NSObject
{ }

class StatementArgumentsFoundationTests: GRDBTestCase {

    override func setup(_ dbWriter: DatabaseWriter) throws {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createPersons") { db in
            try db.execute("""
                CREATE TABLE persons (
                    id INTEGER PRIMARY KEY,
                    creationDate TEXT,
                    name TEXT NOT NULL,
                    age INT)
                """)
        }
        try migrator.migrate(dbWriter)
    }
    
    func testStatementArgumentsArrayInitializer() throws {
        let dbQueue = try makeDatabaseQueue()
        
        try dbQueue.inTransaction { db in
            
            let statement = try db.makeUpdateStatement("INSERT INTO persons (name, age) VALUES (?, ?)")
            let persons: [[Any]] = [
                ["Arthur", 41],
                ["Barbara", 38],
                ]
            for person in persons {
                try statement.execute(arguments: StatementArguments(person)!)
            }
            
            return .commit
        }
        
        try dbQueue.inDatabase { db in
            let rows = try Row.fetchAll(db, "SELECT * FROM persons ORDER BY name")
            XCTAssertEqual(rows.count, 2)
            XCTAssertEqual(rows[0]["name"] as String, "Arthur")
            XCTAssertEqual(rows[0]["age"] as Int, 41)
            XCTAssertEqual(rows[1]["name"] as String, "Barbara")
            XCTAssertEqual(rows[1]["age"] as Int, 38)
        }
    }

    func testStatementArgumentsNSArrayInitializerFromInvalidNSArray() {
        let persons = [ // NSArray, because of the heterogeneous values
            ["Arthur", NonDatabaseConvertibleObject()],
            ["Barbara", NonDatabaseConvertibleObject()],
            ]
        
        for person in persons {
            XCTAssertNil(StatementArguments(person))
        }
    }
    
    func testStatementArgumentsDictionaryInitializer() throws {
        let dbQueue = try makeDatabaseQueue()
        
        try dbQueue.inTransaction { db in
            
            let statement = try db.makeUpdateStatement("INSERT INTO persons (name, age) VALUES (:name, :age)")
            let persons: [[AnyHashable: Any]] = [
                ["name": "Arthur", "age": 41],
                ["name": "Barbara", "age": 38],
                ]
            for person in persons {
                try statement.execute(arguments: StatementArguments(person)!)
            }
            
            return .commit
        }
        
        try dbQueue.inDatabase { db in
            let rows = try Row.fetchAll(db, "SELECT * FROM persons ORDER BY name")
            XCTAssertEqual(rows.count, 2)
            XCTAssertEqual(rows[0]["name"] as String, "Arthur")
            XCTAssertEqual(rows[0]["age"] as Int, 41)
            XCTAssertEqual(rows[1]["name"] as String, "Barbara")
            XCTAssertEqual(rows[1]["age"] as Int, 38)
        }
    }

    func testStatementArgumentsNSDictionaryInitializerFromInvalidNSDictionary() {
        let dictionary: [AnyHashable: Any] = ["a": NSObject()]
        let arguments = StatementArguments(dictionary)
        XCTAssertTrue(arguments == nil)
        
        let dictionaryInvalidKeyType: [AnyHashable: Any] = [NSNumber(value: 1): "bar"]
        let arguments2 = StatementArguments(dictionaryInvalidKeyType)
        XCTAssertTrue(arguments2 == nil)
    }
}
