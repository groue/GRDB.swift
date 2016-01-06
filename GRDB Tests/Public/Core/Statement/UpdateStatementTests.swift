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
                try db.updateStatement("INSERT INTO persons (name) VALUES ('Arthur')").execute()
                try db.updateStatement("INSERT INTO persons (name) VALUES ('Barbara');").execute()
                return .Commit
            }
        }
        
        dbQueue.inDatabase { db in
            let rows = Row.fetchAll(db, "SELECT * FROM persons ORDER BY name")
            XCTAssertEqual(rows.count, 2)
            XCTAssertEqual(rows[0].value(named: "name") as String, "Arthur")
            XCTAssertEqual(rows[1].value(named: "name") as String, "Barbara")
        }
    }
    
    func testArrayStatementArguments() {
        assertNoError {
            
            try dbQueue.inTransaction { db in
                
                let statement = try db.updateStatement("INSERT INTO persons (name, age) VALUES (?, ?)")
                let persons: [[DatabaseValueConvertible?]] = [
                    ["Arthur", 41],
                    ["Barbara", nil],
                ]
                for person in persons {
                    try statement.execute(arguments: StatementArguments(person))
                }
                
                return .Commit
            }
            
            dbQueue.inDatabase { db in
                let rows = Row.fetchAll(db, "SELECT * FROM persons ORDER BY name")
                XCTAssertEqual(rows.count, 2)
                XCTAssertEqual(rows[0].value(named: "name") as String, "Arthur")
                XCTAssertEqual(rows[0].value(named: "age") as Int, 41)
                XCTAssertEqual(rows[1].value(named: "name") as String, "Barbara")
                XCTAssertTrue(rows[1]["age"]!.isNull)
            }
        }
    }
    
    func testStatementArgumentsSetterWithArray() {
        assertNoError {
            
            try dbQueue.inTransaction { db in
                
                let statement = try db.updateStatement("INSERT INTO persons (name, age) VALUES (?, ?)")
                let persons: [[DatabaseValueConvertible?]] = [
                    ["Arthur", 41],
                    ["Barbara", nil],
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
                XCTAssertEqual(rows[0].value(named: "name") as String, "Arthur")
                XCTAssertEqual(rows[0].value(named: "age") as Int, 41)
                XCTAssertEqual(rows[1].value(named: "name") as String, "Barbara")
                XCTAssertTrue(rows[1]["age"]!.isNull)
            }
        }
    }
    
    func testDictionaryStatementArguments() {
        assertNoError {
            
            try dbQueue.inTransaction { db in
                
                let statement = try db.updateStatement("INSERT INTO persons (name, age) VALUES (:name, :age)")
                let persons: [[String: DatabaseValueConvertible?]] = [
                    ["name": "Arthur", "age": 41],
                    ["name": "Barbara", "age": nil],
                ]
                for person in persons {
                    try statement.execute(arguments: StatementArguments(person))
                }
                
                return .Commit
            }
            
            dbQueue.inDatabase { db in
                let rows = Row.fetchAll(db, "SELECT * FROM persons ORDER BY name")
                XCTAssertEqual(rows.count, 2)
                XCTAssertEqual(rows[0].value(named: "name") as String, "Arthur")
                XCTAssertEqual(rows[0].value(named: "age") as Int, 41)
                XCTAssertEqual(rows[1].value(named: "name") as String, "Barbara")
                XCTAssertTrue(rows[1]["age"]!.isNull)
            }
        }
    }
    
    func testStatementArgumentsSetterWithDictionary() {
        assertNoError {
            
            try dbQueue.inTransaction { db in
                
                let statement = try db.updateStatement("INSERT INTO persons (name, age) VALUES (:name, :age)")
                let persons: [[String: DatabaseValueConvertible?]] = [
                    ["name": "Arthur", "age": 41],
                    ["name": "Barbara", "age": nil],
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
                XCTAssertEqual(rows[0].value(named: "name") as String, "Arthur")
                XCTAssertEqual(rows[0].value(named: "age") as Int, 41)
                XCTAssertEqual(rows[1].value(named: "name") as String, "Barbara")
                XCTAssertTrue(rows[1]["age"]!.isNull)
            }
        }
    }
    
    func testUpdateStatementAcceptsSelectQueries() {
        // This test makes sure we do not introduce any regression for
        // https://github.com/groue/GRDB.swift/issues/15
        assertNoError {
            try dbQueue.inDatabase { db in
                try db.execute("SELECT 1")
            }
        }
    }
    
    func testExecuteMultipleStatement() {
        assertNoError {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE wines (name TEXT, color INT); CREATE TABLE books (name TEXT, age INT)")
                XCTAssertTrue(db.tableExists("wines"))
                XCTAssertTrue(db.tableExists("books"))
            }
        }
    }
    
    func testExecuteMultipleStatementWithNamedArguments() {
        assertNoError {
            try dbQueue.inTransaction { db in
                try db.execute(
                    "INSERT INTO persons (name) VALUES (:name1);" +
                    "INSERT INTO persons (name) VALUES (:name2);",
                    arguments: ["name1": "Arthur", "name2": "Barbara"])
                XCTAssertEqual(String.fetchAll(db, "SELECT name FROM persons ORDER BY name"), ["Arthur", "Barbara"])
                return .Rollback
            }
            
            try dbQueue.inTransaction { db in
                do {
                    // Too few arguments
                    try db.execute(
                        "INSERT INTO persons (name) VALUES (:name1);" +
                        "INSERT INTO persons (name) VALUES (:name2);",
                        arguments: ["name1": "Arthur"])
                    XCTFail("Expected Error")
                } catch {
                    // Global fail
                    XCTAssertEqual(String.fetchAll(db, "SELECT name FROM persons ORDER BY name"), [String]())
                }
                return .Rollback
                
            }
        }
    }
    
    func testExecuteMultipleStatementWithReusedNamedArguments() {
        assertNoError {
            try dbQueue.inTransaction { db in
                try db.execute(
                    "INSERT INTO persons (name) VALUES (:name);" +
                    "INSERT INTO persons (name) VALUES (:name);",
                    arguments: ["name": "Arthur"])
                XCTAssertEqual(String.fetchAll(db, "SELECT name FROM persons"), ["Arthur", "Arthur"])
                return .Rollback
            }
        }
    }
    
    func testExecuteMultipleStatementWithPositionalArguments() {
        assertNoError {
            try dbQueue.inTransaction { db in
                try db.execute(
                    "INSERT INTO persons (name) VALUES (?);" +
                    "INSERT INTO persons (name) VALUES (?);",
                    arguments: ["Arthur", "Barbara"])
                XCTAssertEqual(String.fetchAll(db, "SELECT name FROM persons ORDER BY name"), ["Arthur", "Barbara"])
                return .Rollback
            }
            
            try dbQueue.inTransaction { db in
                do {
                    // Too few arguments
                    try db.execute(
                        "INSERT INTO persons (name) VALUES (?);" +
                        "INSERT INTO persons (name) VALUES (?);",
                        arguments: ["Arthur"])
                    XCTFail("Expected Error")
                } catch {
                    // Global fail
                    XCTAssertEqual(String.fetchAll(db, "SELECT name FROM persons ORDER BY name"), [String]())
                }
                
                return .Rollback
            }
            
            try dbQueue.inTransaction { db in
                do {
                    // Too many arguments
                    try db.execute(
                        "INSERT INTO persons (name) VALUES (?);" +
                        "INSERT INTO persons (name) VALUES (?);",
                        arguments: ["Arthur", "Barbara", "Craig"])
                    XCTFail("Expected Error")
                } catch {
                    // Global fail
                    XCTAssertEqual(String.fetchAll(db, "SELECT name FROM persons ORDER BY name"), [String]())
                }
                return .Rollback
            }
        }
    }
}
