import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

private class NonDatabaseConvertibleObject: NSObject
{ }

class StatementArgumentsFoundationTests: GRDBTestCase {

    override func setUpDatabase(dbWriter: DatabaseWriter) throws {
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
                
                let statement = try db.updateStatement("INSERT INTO persons (name, age) VALUES (?, ?)")
                let persons = [ // NSArray, because of the heterogeneous values
                    ["Arthur", 41],
                    ["Barbara", 38],
                ]
                for person in persons {
                    try statement.execute(arguments: StatementArguments(person)!)
                }
                
                return .Commit
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
    
    func testStatementArgumentsNSArrayInitializerFromInvalidNSArray() {
        let persons = [ // NSArray, because of the heterogeneous values
            ["Arthur", NonDatabaseConvertibleObject()],
            ["Barbara", NonDatabaseConvertibleObject()],
            ]
        
        for person in persons {
            XCTAssertNil(StatementArguments(person))
        }
    }
    
    func testStatementArgumentsNSDictionaryInitializer() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            
            try dbQueue.inTransaction { db in
                
                let statement = try db.updateStatement("INSERT INTO persons (name, age) VALUES (:name, :age)")
                let persons = [// NSDictionary, because of the heterogeneous values
                    ["name": "Arthur", "age": 41],
                    ["name": "Barbara", "age": 38],
                ]
                for person in persons {
                    try statement.execute(arguments: StatementArguments(person)!)
                }
                
                return .Commit
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
    
    func testStatementArgumentsNSDictionaryInitializerFromInvalidNSDictionary() {
        let dictionary: NSDictionary = ["a": NSObject()]
        let arguments = StatementArguments(dictionary)
        XCTAssertTrue(arguments == nil)
        
        let dictionaryInvalidKeyType: NSDictionary = [NSNumber(integer: 1): "bar"]
        let arguments2 = StatementArguments(dictionaryInvalidKeyType)
        XCTAssertTrue(arguments2 == nil)
    }
}
