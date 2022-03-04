import XCTest
import GRDB

private class NonDatabaseConvertibleObject: NSObject
{ }

class StatementArgumentsFoundationTests: GRDBTestCase {

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
    
    func testStatementArgumentsArrayInitializer() throws {
        let dbQueue = try makeDatabaseQueue()
        
        try dbQueue.inTransaction { db in
            
            let statement = try db.makeStatement(sql: "INSERT INTO persons (name, age) VALUES (?, ?)")
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
            let rows = try Row.fetchAll(db, sql: "SELECT * FROM persons ORDER BY name")
            XCTAssertEqual(rows.count, 2)
            try XCTAssertEqual(rows[0]["name"] as String, "Arthur")
            try XCTAssertEqual(rows[0]["age"] as Int, 41)
            try XCTAssertEqual(rows[1]["name"] as String, "Barbara")
            try XCTAssertEqual(rows[1]["age"] as Int, 38)
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
            
            let statement = try db.makeStatement(sql: "INSERT INTO persons (name, age) VALUES (:name, :age)")
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
            let rows = try Row.fetchAll(db, sql: "SELECT * FROM persons ORDER BY name")
            XCTAssertEqual(rows.count, 2)
            try XCTAssertEqual(rows[0]["name"] as String, "Arthur")
            try XCTAssertEqual(rows[0]["age"] as Int, 41)
            try XCTAssertEqual(rows[1]["name"] as String, "Barbara")
            try XCTAssertEqual(rows[1]["age"] as Int, 38)
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
