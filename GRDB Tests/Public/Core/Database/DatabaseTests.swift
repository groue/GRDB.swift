import XCTest
import GRDB

class DatabaseTests : GRDBTestCase {
    
    func testCreateTable() {
        assertNoError {
            try dbQueue.inDatabase { db in
                XCTAssertFalse(db.tableExists("persons"))
                try db.execute(
                    "CREATE TABLE persons (" +
                        "id INTEGER PRIMARY KEY, " +
                        "name TEXT, " +
                        "age INT)")
                XCTAssertTrue(db.tableExists("persons"))
            }
        }
    }
    
    func testMultipleStatementsWithoutArguments() {
        assertNoError {
            try dbQueue.inDatabase { db in
                XCTAssertFalse(db.tableExists("persons"))
                XCTAssertFalse(db.tableExists("pets"))
                try db.executeMultiStatement(
                    "CREATE TABLE persons (id INTEGER PRIMARY KEY, name TEXT, age INT);" +
                    "CREATE TABLE pets (id INTEGER PRIMARY KEY, name TEXT, age INT);")
                XCTAssertTrue(db.tableExists("persons"))
                XCTAssertTrue(db.tableExists("pets"))
            }
        }
    }
    
    func testUpdateStatement() {
        assertNoError {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE persons (name TEXT, age INT)")
                
                // The tested function:
                let statement = try db.updateStatement("INSERT INTO persons (name, age) VALUES ('Arthur', 41)")
                try statement.execute()
                
                let row = Row.fetchOne(db, "SELECT * FROM persons")!
                XCTAssertEqual(row.value(atIndex: 0)! as String, "Arthur")
                XCTAssertEqual(row.value(atIndex: 1)! as Int, 41)
            }
        }
    }
    
    func testUpdateStatementWithArrayBinding() {
        assertNoError {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE persons (name TEXT, age INT)")
                
                let statement = try db.updateStatement("INSERT INTO persons (name, age) VALUES (?, ?)")
                try statement.execute(arguments: ["Arthur", 41])
                
                let row = Row.fetchOne(db, "SELECT * FROM persons")!
                XCTAssertEqual(row.value(atIndex: 0)! as String, "Arthur")
                XCTAssertEqual(row.value(atIndex: 1)! as Int, 41)
            }
        }
    }
    
    func testUpdateStatementWithDictionaryBinding() {
        assertNoError {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE persons (name TEXT, age INT)")
                
                let statement = try db.updateStatement("INSERT INTO persons (name, age) VALUES (:name, :age)")
                try statement.execute(arguments: ["name": "Arthur", "age": 41])
                
                let row = Row.fetchOne(db, "SELECT * FROM persons")!
                XCTAssertEqual(row.value(atIndex: 0)! as String, "Arthur")
                XCTAssertEqual(row.value(atIndex: 1)! as Int, 41)
            }
        }
    }
    
    func testDatabaseExecute() {
        assertNoError {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE persons (name TEXT, age INT)")
                
                // The tested function:
                try db.execute("INSERT INTO persons (name, age) VALUES ('Arthur', 41)")
                
                let row = Row.fetchOne(db, "SELECT * FROM persons")!
                XCTAssertEqual(row.value(atIndex: 0)! as String, "Arthur")
                XCTAssertEqual(row.value(atIndex: 1)! as Int, 41)
            }
        }
    }
    
    func testChangesReturnedByDatabaseExecute() {
        assertNoError {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE persons (id INTEGER PRIMARY KEY, name TEXT)")
                
                let changes1 = try db.execute("INSERT INTO persons (name) VALUES ('Arthur')")
                XCTAssertEqual(changes1.changedRowCount, 1)
                XCTAssertEqual(changes1.insertedRowID, 1)
                
                let changes2 = try db.execute("INSERT INTO persons (name) VALUES (?)", arguments: ["Barbara"])
                XCTAssertEqual(changes2.changedRowCount, 1)
                XCTAssertEqual(changes2.insertedRowID, 2)
                
                let changes3 = try db.execute("DELETE FROM persons")
                XCTAssertEqual(changes3.changedRowCount, 2)
            }
        }
    }
    
    func testDatabaseExecuteWithArrayBinding() {
        assertNoError {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE persons (name TEXT, age INT)")
                
                // The tested function:
                try db.execute("INSERT INTO persons (name, age) VALUES (?, ?)", arguments: ["Arthur", 41])
                
                let row = Row.fetchOne(db, "SELECT * FROM persons")!
                XCTAssertEqual(row.value(atIndex: 0)! as String, "Arthur")
                XCTAssertEqual(row.value(atIndex: 1)! as Int, 41)
            }
        }
    }
    
    func testDatabaseExecuteWithDictionaryBinding() {
        assertNoError {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE persons (name TEXT, age INT)")
                
                // The tested function:
                try db.execute("INSERT INTO persons (name, age) VALUES (:name, :age)", arguments: ["name": "Arthur", "age": 41])
                
                let row = Row.fetchOne(db, "SELECT * FROM persons")!
                XCTAssertEqual(row.value(atIndex: 0)! as String, "Arthur")
                XCTAssertEqual(row.value(atIndex: 1)! as Int, 41)
            }
        }
    }
    
    func testSelectStatement() {
        assertNoError {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE persons (name TEXT, age INT)")
                try db.execute("INSERT INTO persons (name, age) VALUES (:name, :age)", arguments: ["name": "Arthur", "age": 41])
                try db.execute("INSERT INTO persons (name, age) VALUES (:name, :age)", arguments: ["name": "Barbara"])
                
                let statement = db.selectStatement("SELECT * FROM persons")
                let rows = Row.fetchAll(statement)
                XCTAssertEqual(rows.count, 2)
            }
        }
    }
    
    func testSelectStatementWithArrayBinding() {
        assertNoError {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE persons (name TEXT, age INT)")
                try db.execute("INSERT INTO persons (name, age) VALUES (:name, :age)", arguments: ["name": "Arthur", "age": 41])
                try db.execute("INSERT INTO persons (name, age) VALUES (:name, :age)", arguments: ["name": "Barbara"])
                
                let statement = db.selectStatement("SELECT * FROM persons WHERE name = ?")
                let rows = Row.fetchAll(statement, arguments: ["Arthur"])
                XCTAssertEqual(rows.count, 1)
            }
        }
    }
    
    func testSelectStatementWithDictionaryBinding() {
        assertNoError {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE persons (name TEXT, age INT)")
                try db.execute("INSERT INTO persons (name, age) VALUES (:name, :age)", arguments: ["name": "Arthur", "age": 41])
                try db.execute("INSERT INTO persons (name, age) VALUES (:name, :age)", arguments: ["name": "Barbara"])
                
                let statement = db.selectStatement("SELECT * FROM persons WHERE name = :name")
                let rows = Row.fetchAll(statement, arguments: ["name": "Arthur"])
                XCTAssertEqual(rows.count, 1)
            }
        }
    }
    
    func testRowValueAtIndex() {
        assertNoError {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE persons (name TEXT, age INT)")
                try db.execute("INSERT INTO persons (name, age) VALUES (:name, :age)", arguments: ["name": "Arthur", "age": 41])
                try db.execute("INSERT INTO persons (name, age) VALUES (:name, :age)", arguments: ["name": "Barbara"])
                
                var names: [String?] = []
                var ages: [Int?] = []
                let rows = Row.fetch(db, "SELECT * FROM persons ORDER BY name")
                for row in rows {
                    // The tested function:
                    let name: String? = row.value(atIndex: 0)
                    let age: Int? = row.value(atIndex: 1)
                    names.append(name)
                    ages.append(age)
                }
                
                XCTAssertEqual(names[0]!, "Arthur")
                XCTAssertEqual(names[1]!, "Barbara")
                XCTAssertEqual(ages[0]!, 41)
                XCTAssertNil(ages[1])
            }
        }
    }
    
    func testRowValueNamed() {
        assertNoError {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE persons (name TEXT, age INT)")
                try db.execute("INSERT INTO persons (name, age) VALUES (:name, :age)", arguments: ["name": "Arthur", "age": 41])
                try db.execute("INSERT INTO persons (name, age) VALUES (:name, :age)", arguments: ["name": "Barbara"])
                
                var names: [String?] = []
                var ages: [Int?] = []
                let rows = Row.fetch(db, "SELECT * FROM persons ORDER BY name")
                for row in rows {
                    // The tested function:
                    let name: String? = row.value(named: "name")
                    let age: Int? = row.value(named: "age")
                    names.append(name)
                    ages.append(age)
                }
                
                XCTAssertEqual(names[0]!, "Arthur")
                XCTAssertEqual(names[1]!, "Barbara")
                XCTAssertEqual(ages[0]!, 41)
                XCTAssertNil(ages[1])
            }
        }
    }
    
    func testRowSequenceCanBeIteratedIndependentlyFromSQLiteStatement() {
        assertNoError {
            var rows: [Row] = []
            try dbQueue.inTransaction { db in
                try db.execute("CREATE TABLE persons (name TEXT, age INT)")
                try db.execute("INSERT INTO persons (name, age) VALUES (:name, :age)", arguments: ["name": "Arthur", "age": 41])
                try db.execute("INSERT INTO persons (name, age) VALUES (:name, :age)", arguments: ["name": "Barbara"])
                
                rows = Array(Row.fetch(db, "SELECT * FROM persons ORDER BY name"))
                return .Commit
            }
            
            var names: [String?] = []
            var ages: [Int?] = []
            
            for row in rows {
                let name: String? = row.value(named: "name")
                let age: Int? = row.value(named: "age")
                names.append(name)
                ages.append(age)
            }
            
            XCTAssertEqual(names[0]!, "Arthur")
            XCTAssertEqual(names[1]!, "Barbara")
            XCTAssertEqual(ages[0]!, 41)
            XCTAssertNil(ages[1])
        }
    }
    
    func testRowSequenceCanBeIteratedTwice() {
        assertNoError {
            try dbQueue.inTransaction { db in
                try db.execute("CREATE TABLE persons (name TEXT)")
                try db.execute("INSERT INTO persons (name) VALUES (:name)", arguments: ["name": "Arthur"])
                try db.execute("INSERT INTO persons (name) VALUES (:name)", arguments: ["name": "Barbara"])
                
                let rows = Row.fetch(db, "SELECT * FROM persons ORDER BY name")
                var names1: [String?] = rows.map { $0.value(named: "name") as String? }
                var names2: [String?] = rows.map { $0.value(named: "name") as String? }
                
                XCTAssertEqual(names1[0]!, "Arthur")
                XCTAssertEqual(names1[1]!, "Barbara")
                XCTAssertEqual(names2[0]!, "Arthur")
                XCTAssertEqual(names2[1]!, "Barbara")
                
                return .Commit
            }
        }
    }
    
    func testValueSequenceCanBeIteratedTwice() {
        assertNoError {
            try dbQueue.inTransaction { db in
                try db.execute("CREATE TABLE persons (name TEXT)")
                try db.execute("INSERT INTO persons (name) VALUES (:name)", arguments: ["name": "Arthur"])
                try db.execute("INSERT INTO persons (name) VALUES (:name)", arguments: ["name": "Barbara"])
                
                let nameSequence = String.fetch(db, "SELECT name FROM persons ORDER BY name")
                var names1: [String?] = Array(nameSequence).map { $0 }
                var names2: [String?] = Array(nameSequence).map { $0 }
                
                XCTAssertEqual(names1[0]!, "Arthur")
                XCTAssertEqual(names1[1]!, "Barbara")
                XCTAssertEqual(names2[0]!, "Arthur")
                XCTAssertEqual(names2[1]!, "Barbara")
                
                return .Commit
            }
        }
    }
    
    func testREADME() {
        assertNoError {
            // DatabaseMigrator sets up migrations:
            
            var migrator = DatabaseMigrator()
            migrator.registerMigration("createPersons") { db in
                try db.execute(
                    "CREATE TABLE persons (" +
                        "id INTEGER PRIMARY KEY, " +
                        "name TEXT, " +
                        "age INT" +
                    ")")
            }
            migrator.registerMigration("createPets") { db in
                // Support for foreign keys is enabled by default:
                try db.execute(
                    "CREATE TABLE pets (" +
                        "id INTEGER PRIMARY KEY, " +
                        "masterID INTEGER NOT NULL " +
                        "         REFERENCES persons(id) " +
                        "         ON DELETE CASCADE ON UPDATE CASCADE, " +
                        "name TEXT" +
                    ")")
            }
            
            try migrator.migrate(dbQueue)
            
            
            // Transactions:
            
            try dbQueue.inTransaction { db in
                try db.execute(
                    "INSERT INTO persons (name, age) VALUES (?, ?)",
                    arguments: ["Arthur", 36])
                
                try db.execute(
                    "INSERT INTO persons (name, age) VALUES (:name, :age)",
                    arguments: ["name": "Barbara", "age": 37])
                
                return .Commit
            }
            
            
            // Fetching rows and values:
            
            dbQueue.inDatabase { db in
                for row in Row.fetch(db, "SELECT * FROM persons") {
                    // Leverage Swift type inference
                    let name: String? = row.value(atIndex: 1)
                    
                    // Force unwrap when column is NOT NULL
                    let id: Int64 = row.value(named: "id")!
                    
                    // Both Int and Int64 are supported
                    let age: Int? = row.value(named: "age")
                    
                    print("id: \(id), name: \(name), age: \(age)")
                }
                
                // Value sequences require explicit `type` parameter
                for name in String.fetch(db, "SELECT name FROM persons") {
                    // name is `String?` because some rows may have a NULL name.
                    print(name)
                }
            }
            
            
            // Extracting values out of a database block:
            
            let names = dbQueue.inDatabase { db in
                String.fetch(db, "SELECT name FROM persons ORDER BY name").map { $0! }
            }
            XCTAssertEqual(names, ["Arthur", "Barbara"])
        }
    }
}
