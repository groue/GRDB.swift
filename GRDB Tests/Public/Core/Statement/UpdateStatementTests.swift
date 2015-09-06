import XCTest
import GRDB

class UpdateStatementTests : GRDBTestCase {
    
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
    
    func testTrailingSemiColonIsAcceptedAndOptional() {
        assertNoError {
            try dbQueue.inTransaction { db in
                try db.updateStatement("INSERT INTO persons (name, age) VALUES ('Arthur', ?)").execute()
                try db.updateStatement("INSERT INTO persons (name, age) VALUES ('', ?)").execute()
                try db.updateStatement("INSERT INTO persons (name, age) VALUES ('Arthur', ?);").execute()
                try db.updateStatement("INSERT INTO persons (name, age) VALUES ('', ?);").execute()
                return .Commit
            }
        }
        
        dbQueue.inDatabase { db in
            let rows = Row.fetchAll(db, "SELECT * FROM persons ORDER BY name")
            XCTAssertEqual(rows.count, 4)
            XCTAssertEqual(rows[0].value(named: "name")! as String, "Arthur")
            XCTAssertEqual(rows[1].value(named: "name")! as String, "Arthur")
            XCTAssertEqual(rows[2].value(named: "name")! as String, "")
            XCTAssertEqual(rows[3].value(named: "name")! as String, "")
        }
    }
    
    func testArrayStatementArguments() {
        assertNoError {
            
            try dbQueue.inTransaction { db in
                
                let statement = try db.updateStatement("INSERT INTO persons (name, age) VALUES (?, ?)")
                let persons = [
                    ["Arthur", 41],
                    [""],
                ]
                for person in persons {
                    try statement.execute(arguments: StatementArguments(person))
                }
                
                return .Commit
            }
            
            dbQueue.inDatabase { db in
                let rows = Row.fetchAll(db, "SELECT * FROM persons ORDER BY name")
                XCTAssertEqual(rows.count, 2)
                XCTAssertEqual(rows[0].value(named: "name")! as String, "Arthur")
                XCTAssertEqual(rows[0].value(named: "age")! as Int, 41)
                XCTAssertEqual(rows[1].value(named: "name")! as String, "")
                XCTAssertTrue(rows[1].value(named: "age") == nil)
            }
        }
    }
    
    func testStatementArgumentsSetterWithArray() {
        assertNoError {
            
            try dbQueue.inTransaction { db in
                
                let statement = try db.updateStatement("INSERT INTO persons (name, age) VALUES (?, ?)")
                let persons = [
                    ["Arthur", 41],
                    [""],
                ]
                for person in persons {
                    statement.arguments = StatementArguments(person)
                    try statement.execute()
                }
                
                return .Commit
            }
            
            dbQueue.inDatabase { db in
                let rows = Row.fetchAll(db, "SELECT * FROM persons ORDER BY name")
                XCTAssertEqual(rows.count, 2)
                XCTAssertEqual(rows[0].value(named: "name")! as String, "Arthur")
                XCTAssertEqual(rows[0].value(named: "age")! as Int, 41)
                XCTAssertEqual(rows[1].value(named: "name")! as String, "")
                XCTAssertTrue(rows[1].value(named: "age") == nil)
            }
        }
    }
    
    func testDictionaryStatementArguments() {
        assertNoError {
            
            try dbQueue.inTransaction { db in
                
                let statement = try db.updateStatement("INSERT INTO persons (name, age) VALUES (:name, :age)")
                let persons = [
                    ["name": "Arthur", "age": 41],
                    ["name": ""],
                ]
                for person in persons {
                    try statement.execute(arguments: StatementArguments(person))
                }
                
                return .Commit
            }
            
            dbQueue.inDatabase { db in
                let rows = Row.fetchAll(db, "SELECT * FROM persons ORDER BY name")
                XCTAssertEqual(rows.count, 2)
                XCTAssertEqual(rows[0].value(named: "name")! as String, "Arthur")
                XCTAssertEqual(rows[0].value(named: "age")! as Int, 41)
                XCTAssertEqual(rows[1].value(named: "name")! as String, "")
                XCTAssertTrue(rows[1].value(named: "age") == nil)
            }
        }
    }
    
    func testStatementArgumentsSetterWithDictionary() {
        assertNoError {
            
            try dbQueue.inTransaction { db in
                
                let statement = try db.updateStatement("INSERT INTO persons (name, age) VALUES (:name, :age)")
                let persons = [
                    ["name": "Arthur", "age": 41],
                    ["name": ""],
                ]
                for person in persons {
                    statement.arguments = StatementArguments(person)
                    try statement.execute()
                }
                
                return .Commit
            }
            
            dbQueue.inDatabase { db in
                let rows = Row.fetchAll(db, "SELECT * FROM persons ORDER BY name")
                XCTAssertEqual(rows.count, 2)
                XCTAssertEqual(rows[0].value(named: "name")! as String, "Arthur")
                XCTAssertEqual(rows[0].value(named: "age")! as Int, 41)
                XCTAssertEqual(rows[1].value(named: "name")! as String, "")
                XCTAssertTrue(rows[1].value(named: "age") == nil)
            }
        }
    }
}
