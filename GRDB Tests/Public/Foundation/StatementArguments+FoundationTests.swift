import XCTest
import GRDB

class StatementArgumentsFoundationTests: GRDBTestCase {

    override func setUp() {
        super.setUp()
        
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
        
        assertNoError {
            try migrator.migrate(dbQueue)
        }
    }
    
    func testStatementArgumentsNSArrayInitializer() {
        assertNoError {
            
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
    
    func testStatementArgumentsNSDictionaryInitializer() {
        assertNoError {
            
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
}
