//
//  DatabaseTests.swift
//  GRDB
//
//  Created by Gwendal Roué on 30/06/2015.
//  Copyright © 2015 Stephen Celis. All rights reserved.
//

import XCTest
import GRDB

class DatabaseTests: GRDBTests {
    
    func testCreateTable() {
        assertNoError {
            try dbQueue.inDatabase { db -> Void in
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
    
    func testUpdateStatement() {
        assertNoError {
            try dbQueue.inDatabase { db -> Void in
                try db.execute("CREATE TABLE persons (name TEXT, age INT)")
                
                // The tested function:
                let statement = try db.updateStatement("INSERT INTO persons (name, age) VALUES ('Arthur', 41)")
                try statement.execute()
                
                let row = fetchOneRow(db, sql: "SELECT * FROM persons")!
                XCTAssertEqual(row.value(atIndex: 0)! as String, "Arthur")
                XCTAssertEqual(row.value(atIndex: 1)! as Int, 41)
            }
        }
    }
    
    func testUpdateStatementIndexedBinding() {
        assertNoError {
            try dbQueue.inDatabase { db -> Void in
                try db.execute("CREATE TABLE persons (name TEXT, age INT)")
                
                let statement = try db.updateStatement("INSERT INTO persons (name, age) VALUES (?, ?)")
                // The tested function:
                statement.bind("Arthur", atIndex: 1)
                statement.bind(41, atIndex: 2)
                try statement.execute()
                
                let row = fetchOneRow(db, sql: "SELECT * FROM persons")!
                XCTAssertEqual(row.value(atIndex: 0)! as String, "Arthur")
                XCTAssertEqual(row.value(atIndex: 1)! as Int, 41)
            }
        }
    }
    
    func testUpdateStatementKeyedBinding() {
        assertNoError {
            try dbQueue.inDatabase { db -> Void in
                try db.execute("CREATE TABLE persons (name TEXT, age INT)")
                
                let statement = try db.updateStatement("INSERT INTO persons (name, age) VALUES (:name, :age)")
                // The tested function:
                statement.bind("Arthur", forKey: ":name")
                statement.bind(41, forKey: ":age")
                try statement.execute()
                
                let row = fetchOneRow(db, sql: "SELECT * FROM persons")!
                XCTAssertEqual(row.value(atIndex: 0)! as String, "Arthur")
                XCTAssertEqual(row.value(atIndex: 1)! as Int, 41)
            }
        }
    }
    
    func testUpdateStatementArrayBinding() {
        assertNoError {
            try dbQueue.inDatabase { db -> Void in
                try db.execute("CREATE TABLE persons (name TEXT, age INT)")
                
                let statement = try db.updateStatement("INSERT INTO persons (name, age) VALUES (?, ?)")
                // The tested function:
                statement.bind(["Arthur", 41])
                try statement.execute()
                
                let row = fetchOneRow(db, sql: "SELECT * FROM persons")!
                XCTAssertEqual(row.value(atIndex: 0)! as String, "Arthur")
                XCTAssertEqual(row.value(atIndex: 1)! as Int, 41)
            }
        }
    }
    
    func testUpdateStatementDictionaryBinding() {
        assertNoError {
            try dbQueue.inDatabase { db -> Void in
                try db.execute("CREATE TABLE persons (name TEXT, age INT)")
                
                let statement = try db.updateStatement("INSERT INTO persons (name, age) VALUES (:name, :age)")
                // The tested function:
                statement.bind([":name": "Arthur", ":age": 41])
                try statement.execute()
                
                let row = fetchOneRow(db, sql: "SELECT * FROM persons")!
                XCTAssertEqual(row.value(atIndex: 0)! as String, "Arthur")
                XCTAssertEqual(row.value(atIndex: 1)! as Int, 41)
            }
        }
    }
    
    func testUpdateStatementWithArrayBinding() {
        assertNoError {
            try dbQueue.inDatabase { db -> Void in
                try db.execute("CREATE TABLE persons (name TEXT, age INT)")
                
                // The tested function:
                let statement = try db.updateStatement("INSERT INTO persons (name, age) VALUES (?, ?)", bindings: ["Arthur", 41])
                try statement.execute()
                
                let row = fetchOneRow(db, sql: "SELECT * FROM persons")!
                XCTAssertEqual(row.value(atIndex: 0)! as String, "Arthur")
                XCTAssertEqual(row.value(atIndex: 1)! as Int, 41)
            }
        }
    }
    
    func testUpdateStatementWithDictionaryBinding() {
        assertNoError {
            try dbQueue.inDatabase { db -> Void in
                try db.execute("CREATE TABLE persons (name TEXT, age INT)")
                
                // The tested function:
                let statement = try db.updateStatement("INSERT INTO persons (name, age) VALUES (:name, :age)", bindings: [":name": "Arthur", ":age": 41])
                try statement.execute()
                
                let row = fetchOneRow(db, sql: "SELECT * FROM persons")!
                XCTAssertEqual(row.value(atIndex: 0)! as String, "Arthur")
                XCTAssertEqual(row.value(atIndex: 1)! as Int, 41)
            }
        }
    }
    
    func testDatabaseExecute() {
        assertNoError {
            try dbQueue.inDatabase { db -> Void in
                try db.execute("CREATE TABLE persons (name TEXT, age INT)")
                
                // The tested function:
                try db.execute("INSERT INTO persons (name, age) VALUES ('Arthur', 41)")
                
                let row = fetchOneRow(db, sql: "SELECT * FROM persons")!
                XCTAssertEqual(row.value(atIndex: 0)! as String, "Arthur")
                XCTAssertEqual(row.value(atIndex: 1)! as Int, 41)
            }
        }
    }
    
    func testDatabaseExecuteWithArrayBinding() {
        assertNoError {
            try dbQueue.inDatabase { db -> Void in
                try db.execute("CREATE TABLE persons (name TEXT, age INT)")
                
                // The tested function:
                try db.execute("INSERT INTO persons (name, age) VALUES (?, ?)", bindings: ["Arthur", 41])
                
                let row = fetchOneRow(db, sql: "SELECT * FROM persons")!
                XCTAssertEqual(row.value(atIndex: 0)! as String, "Arthur")
                XCTAssertEqual(row.value(atIndex: 1)! as Int, 41)
            }
        }
    }
    
    func testDatabaseExecuteWithDictionaryBinding() {
        assertNoError {
            try dbQueue.inDatabase { db -> Void in
                try db.execute("CREATE TABLE persons (name TEXT, age INT)")
                
                // The tested function:
                try db.execute("INSERT INTO persons (name, age) VALUES (:name, :age)", bindings: [":name": "Arthur", ":age": 41])
                
                let row = fetchOneRow(db, sql: "SELECT * FROM persons")!
                XCTAssertEqual(row.value(atIndex: 0)! as String, "Arthur")
                XCTAssertEqual(row.value(atIndex: 1)! as Int, 41)
            }
        }
    }
    
    func testSelectStatement() {
        assertNoError {
            try dbQueue.inDatabase { db -> Void in
                try db.execute("CREATE TABLE persons (name TEXT, age INT)")
                try db.execute("INSERT INTO persons (name, age) VALUES (:name, :age)", bindings: [":name": "Arthur", ":age": 41])
                try db.execute("INSERT INTO persons (name, age) VALUES (:name, :age)", bindings: [":name": "Barbara"])
                
                // The tested function:
                let statement = try db.selectStatement("SELECT * FROM persons")
                
                let rows = fetchAllRows(statement)
                XCTAssertEqual(rows.count, 2)
            }
        }
    }
    
    func testSelectStatementIndexedBinding() {
        assertNoError {
            try dbQueue.inDatabase { db -> Void in
                try db.execute("CREATE TABLE persons (name TEXT, age INT)")
                try db.execute("INSERT INTO persons (name, age) VALUES (:name, :age)", bindings: [":name": "Arthur", ":age": 41])
                try db.execute("INSERT INTO persons (name, age) VALUES (:name, :age)", bindings: [":name": "Barbara"])
                
                let statement = try db.selectStatement("SELECT * FROM persons WHERE name = ?")
                // The tested function:
                statement.bind("Arthur", atIndex: 1)
                
                let rows = fetchAllRows(statement)
                XCTAssertEqual(rows.count, 1)
            }
        }
    }
    
    func testSelectStatementKeyedBinding() {
        assertNoError {
            try dbQueue.inDatabase { db -> Void in
                try db.execute("CREATE TABLE persons (name TEXT, age INT)")
                try db.execute("INSERT INTO persons (name, age) VALUES (:name, :age)", bindings: [":name": "Arthur", ":age": 41])
                try db.execute("INSERT INTO persons (name, age) VALUES (:name, :age)", bindings: [":name": "Barbara"])
                
                let statement = try db.selectStatement("SELECT * FROM persons WHERE name = :name")
                // The tested function:
                statement.bind("Arthur", forKey: ":name")
                
                let rows = fetchAllRows(statement)
                XCTAssertEqual(rows.count, 1)
            }
        }
    }
    
    func testSelectStatementArrayBinding() {
        assertNoError {
            try dbQueue.inDatabase { db -> Void in
                try db.execute("CREATE TABLE persons (name TEXT, age INT)")
                try db.execute("INSERT INTO persons (name, age) VALUES (:name, :age)", bindings: [":name": "Arthur", ":age": 41])
                try db.execute("INSERT INTO persons (name, age) VALUES (:name, :age)", bindings: [":name": "Barbara"])
                
                let statement = try db.selectStatement("SELECT * FROM persons WHERE name = ?")
                // The tested function:
                statement.bind(["Arthur"])
                
                let rows = fetchAllRows(statement)
                XCTAssertEqual(rows.count, 1)
            }
        }
    }
    
    func testSelectStatementDictionaryBinding() {
        assertNoError {
            try dbQueue.inDatabase { db -> Void in
                try db.execute("CREATE TABLE persons (name TEXT, age INT)")
                try db.execute("INSERT INTO persons (name, age) VALUES (:name, :age)", bindings: [":name": "Arthur", ":age": 41])
                try db.execute("INSERT INTO persons (name, age) VALUES (:name, :age)", bindings: [":name": "Barbara"])
                
                let statement = try db.selectStatement("SELECT * FROM persons WHERE name = :name")
                // The tested function:
                statement.bind([":name": "Arthur"])
                
                let rows = fetchAllRows(statement)
                XCTAssertEqual(rows.count, 1)
            }
        }
    }
    
    func testSelectStatementWithArrayBinding() {
        assertNoError {
            try dbQueue.inDatabase { db -> Void in
                try db.execute("CREATE TABLE persons (name TEXT, age INT)")
                try db.execute("INSERT INTO persons (name, age) VALUES (:name, :age)", bindings: [":name": "Arthur", ":age": 41])
                try db.execute("INSERT INTO persons (name, age) VALUES (:name, :age)", bindings: [":name": "Barbara"])
                
                // The tested function:
                let statement = try db.selectStatement("SELECT * FROM persons WHERE name = ?", bindings: ["Arthur"])
                
                let rows = fetchAllRows(statement)
                XCTAssertEqual(rows.count, 1)
            }
        }
    }
    
    func testSelectStatementWithDictionaryBinding() {
        assertNoError {
            try dbQueue.inDatabase { db -> Void in
                try db.execute("CREATE TABLE persons (name TEXT, age INT)")
                try db.execute("INSERT INTO persons (name, age) VALUES (:name, :age)", bindings: [":name": "Arthur", ":age": 41])
                try db.execute("INSERT INTO persons (name, age) VALUES (:name, :age)", bindings: [":name": "Barbara"])
                
                // The tested function:
                let statement = try db.selectStatement("SELECT * FROM persons WHERE name = :name", bindings: [":name": "Arthur"])
                
                let rows = fetchAllRows(statement)
                XCTAssertEqual(rows.count, 1)
            }
        }
    }
    
    func testRowValueAtIndex() {
        assertNoError {
            try dbQueue.inDatabase { db -> Void in
                try db.execute("CREATE TABLE persons (name TEXT, age INT)")
                try db.execute("INSERT INTO persons (name, age) VALUES (:name, :age)", bindings: [":name": "Arthur", ":age": 41])
                try db.execute("INSERT INTO persons (name, age) VALUES (:name, :age)", bindings: [":name": "Barbara"])
                
                var names: [String?] = []
                var ages: [Int?] = []
                let rows = fetchRows(db, sql: "SELECT * FROM persons ORDER BY name")
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
            try dbQueue.inDatabase { db -> Void in
                try db.execute("CREATE TABLE persons (name TEXT, age INT)")
                try db.execute("INSERT INTO persons (name, age) VALUES (:name, :age)", bindings: [":name": "Arthur", ":age": 41])
                try db.execute("INSERT INTO persons (name, age) VALUES (:name, :age)", bindings: [":name": "Barbara"])
                
                var names: [String?] = []
                var ages: [Int?] = []
                let rows = fetchRows(db, sql: "SELECT * FROM persons ORDER BY name")
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
    
    func testFetchRowsCacheSQLiteResults() {
        assertNoError {
            let rows = try dbQueue.inDatabase { db -> [Row] in
                try db.execute("CREATE TABLE persons (name TEXT, age INT)")
                try db.execute("INSERT INTO persons (name, age) VALUES (:name, :age)", bindings: [":name": "Arthur", ":age": 41])
                try db.execute("INSERT INTO persons (name, age) VALUES (:name, :age)", bindings: [":name": "Barbara"])
                
                let rows = fetchRows(db, sql: "SELECT * FROM persons ORDER BY name")
                // The array iterates all rows
                return Array(rows)
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
    
    func testREADME() {
        assertNoError {
            // DatabaseMigrator sets up migrations:
            
            var migrator = DatabaseMigrator()
            migrator.registerMigration("createPersons") { db in
                try db.execute(
                    "CREATE TABLE persons (" +
                        "id INTEGER PRIMARY KEY, " +
                        "name TEXT, " +
                    "age INT)")
            }
            migrator.registerMigration("createPets") { db in
                // Support for foreign keys is enabled by default:
                try db.execute(
                    "CREATE TABLE pets (" +
                        "id INTEGER PRIMARY KEY, " +
                        "masterID INTEGER NOT NULL " +
                        "         REFERENCES persons(id) " +
                        "         ON DELETE CASCADE ON UPDATE CASCADE, " +
                    "name TEXT)")
            }
            
            try migrator.migrate(dbQueue)
            
            
            // Transactions:
            
            try dbQueue.inTransaction { db in
                try db.execute(
                    "INSERT INTO persons (name, age) VALUES (?, ?)",
                    bindings: ["Arthur", 36])
                
                try db.execute(
                    "INSERT INTO persons (name, age) VALUES (:name, :age)",
                    bindings: [":name": "Barbara", ":age": 37])
                
                return .Commit
            }
            
            
            // Fetching rows and values:
            
            try dbQueue.inDatabase { db -> Void in
                for row in fetchRows(db, sql: "SELECT * FROM persons") {
                    // Leverage Swift type inference
                    let name: String? = row.value(atIndex: 1)
                    
                    // Force unwrap when column is NOT NULL
                    let id: Int64 = row.value(named: "id")!
                    
                    // Both Int and Int64 are supported
                    let age: Int? = row.value(named: "age")
                    
                    print("id: \(id), name: \(name), age: \(age)")
                }
                
                // Value sequences require explicit `type` parameter
                for name in fetchValues(String.self, db: db, sql: "SELECT name FROM persons") {
                    // name is `String?` because some rows may have a NULL name.
                    print(name)
                }
            }
            
            
            // Extracting values out of a database block:
            
            let names = try dbQueue.inDatabase { db in
                fetchValues(String.self, db: db, sql: "SELECT name FROM persons ORDER BY name").map { $0! }
            }
            XCTAssertEqual(names, ["Arthur", "Barbara"])
        }
    }
}
