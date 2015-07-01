//
//  DatabaseTests.swift
//  GRDB
//
//  Created by Gwendal Roué on 30/06/2015.
//  Copyright © 2015 Stephen Celis. All rights reserved.
//

import XCTest
import GRDB

class DatabaseTests: XCTestCase {
    var databasePath: String!
    var dbQueue: DatabaseQueue!
    
    override func setUp() {
        self.databasePath = "/tmp/GRDB.sqlite"
        do { try NSFileManager.defaultManager().removeItemAtPath(databasePath) } catch { }
        let configuration = DatabaseConfiguration(verbose: true)
        self.dbQueue = try! DatabaseQueue(path: databasePath, configuration: configuration)
    }
    
    override func tearDown() {
        self.dbQueue = nil
        try! NSFileManager.defaultManager().removeItemAtPath(databasePath)
    }
    
    func testCreateTable() {
        do {
            try dbQueue.inDatabase { db -> Void in
                XCTAssertFalse(db.tableExist("persons"))
                try db.execute(
                    "CREATE TABLE persons (" +
                        "id INTEGER PRIMARY KEY, " +
                        "name TEXT, " +
                        "age INT)")
                XCTAssertTrue(db.tableExist("persons"))
            }
        } catch let error as GRDB.Error {
            XCTFail("error code \(error.code): \(error.message)")
        } catch {
            XCTFail("error: \(error)")
        }
    }
    
    func testUpdateStatement() {
        do {
            try dbQueue.inDatabase { db -> Void in
                try db.execute("CREATE TABLE persons (name TEXT, age INT)")
                
                // The tested function:
                let statement = try db.updateStatement("INSERT INTO persons (name, age) VALUES ('Arthur', 41)")
                try statement.execute()
                
                let row = try db.fetchFirstRow("SELECT * FROM persons")!
                XCTAssertEqual(row.value(atIndex: 0)! as String, "Arthur")
                XCTAssertEqual(row.value(atIndex: 1)! as Int, 41)
            }
        } catch let error as GRDB.Error {
            XCTFail("error code \(error.code): \(error.message)")
        } catch {
            XCTFail("error: \(error)")
        }
    }
    
    func testUpdateStatementIndexedBinding() {
        do {
            try dbQueue.inDatabase { db -> Void in
                try db.execute("CREATE TABLE persons (name TEXT, age INT)")
                
                let statement = try db.updateStatement("INSERT INTO persons (name, age) VALUES (?, ?)")
                // The tested function:
                statement.bind("Arthur", atIndex: 1)
                statement.bind(41, atIndex: 2)
                try statement.execute()
                
                let row = try db.fetchFirstRow("SELECT * FROM persons")!
                XCTAssertEqual(row.value(atIndex: 0)! as String, "Arthur")
                XCTAssertEqual(row.value(atIndex: 1)! as Int, 41)
            }
        } catch let error as GRDB.Error {
            XCTFail("error code \(error.code): \(error.message)")
        } catch {
            XCTFail("error: \(error)")
        }
    }
    
    func testUpdateStatementKeyedBinding() {
        do {
            try dbQueue.inDatabase { db -> Void in
                try db.execute("CREATE TABLE persons (name TEXT, age INT)")
                
                let statement = try db.updateStatement("INSERT INTO persons (name, age) VALUES (:name, :age)")
                // The tested function:
                statement.bind("Arthur", forKey: ":name")
                statement.bind(41, forKey: ":age")
                try statement.execute()
                
                let row = try db.fetchFirstRow("SELECT * FROM persons")!
                XCTAssertEqual(row.value(atIndex: 0)! as String, "Arthur")
                XCTAssertEqual(row.value(atIndex: 1)! as Int, 41)
            }
        } catch let error as GRDB.Error {
            XCTFail("error code \(error.code): \(error.message)")
        } catch {
            XCTFail("error: \(error)")
        }
    }
    
    func testUpdateStatementArrayBinding() {
        do {
            try dbQueue.inDatabase { db -> Void in
                try db.execute("CREATE TABLE persons (name TEXT, age INT)")
                
                let statement = try db.updateStatement("INSERT INTO persons (name, age) VALUES (?, ?)")
                // The tested function:
                statement.bind(["Arthur", 41])
                try statement.execute()
                
                let row = try db.fetchFirstRow("SELECT * FROM persons")!
                XCTAssertEqual(row.value(atIndex: 0)! as String, "Arthur")
                XCTAssertEqual(row.value(atIndex: 1)! as Int, 41)
            }
        } catch let error as GRDB.Error {
            XCTFail("error code \(error.code): \(error.message)")
        } catch {
            XCTFail("error: \(error)")
        }
    }
    
    func testUpdateStatementDictionaryBinding() {
        do {
            try dbQueue.inDatabase { db -> Void in
                try db.execute("CREATE TABLE persons (name TEXT, age INT)")
                
                let statement = try db.updateStatement("INSERT INTO persons (name, age) VALUES (:name, :age)")
                // The tested function:
                statement.bind([":name": "Arthur", ":age": 41])
                try statement.execute()
                
                let row = try db.fetchFirstRow("SELECT * FROM persons")!
                XCTAssertEqual(row.value(atIndex: 0)! as String, "Arthur")
                XCTAssertEqual(row.value(atIndex: 1)! as Int, 41)
            }
        } catch let error as GRDB.Error {
            XCTFail("error code \(error.code): \(error.message)")
        } catch {
            XCTFail("error: \(error)")
        }
    }
    
    func testUpdateStatementWithArrayBinding() {
        do {
            try dbQueue.inDatabase { db -> Void in
                try db.execute("CREATE TABLE persons (name TEXT, age INT)")
                
                // The tested function:
                let statement = try db.updateStatement("INSERT INTO persons (name, age) VALUES (?, ?)", bindings: ["Arthur", 41])
                try statement.execute()
                
                let row = try db.fetchFirstRow("SELECT * FROM persons")!
                XCTAssertEqual(row.value(atIndex: 0)! as String, "Arthur")
                XCTAssertEqual(row.value(atIndex: 1)! as Int, 41)
            }
        } catch let error as GRDB.Error {
            XCTFail("error code \(error.code): \(error.message)")
        } catch {
            XCTFail("error: \(error)")
        }
    }
    
    func testUpdateStatementWithDictionaryBinding() {
        do {
            try dbQueue.inDatabase { db -> Void in
                try db.execute("CREATE TABLE persons (name TEXT, age INT)")
                
                // The tested function:
                let statement = try db.updateStatement("INSERT INTO persons (name, age) VALUES (:name, :age)", bindings: [":name": "Arthur", ":age": 41])
                try statement.execute()
                
                let row = try db.fetchFirstRow("SELECT * FROM persons")!
                XCTAssertEqual(row.value(atIndex: 0)! as String, "Arthur")
                XCTAssertEqual(row.value(atIndex: 1)! as Int, 41)
            }
        } catch let error as GRDB.Error {
            XCTFail("error code \(error.code): \(error.message)")
        } catch {
            XCTFail("error: \(error)")
        }
    }
    
    func testDatabaseExecute() {
        do {
            try dbQueue.inDatabase { db -> Void in
                try db.execute("CREATE TABLE persons (name TEXT, age INT)")
                
                // The tested function:
                try db.execute("INSERT INTO persons (name, age) VALUES ('Arthur', 41)")
                
                let row = try db.fetchFirstRow("SELECT * FROM persons")!
                XCTAssertEqual(row.value(atIndex: 0)! as String, "Arthur")
                XCTAssertEqual(row.value(atIndex: 1)! as Int, 41)
            }
        } catch let error as GRDB.Error {
            XCTFail("error code \(error.code): \(error.message)")
        } catch {
            XCTFail("error: \(error)")
        }
    }
    
    func testDatabaseExecuteWithArrayBinding() {
        do {
            try dbQueue.inDatabase { db -> Void in
                try db.execute("CREATE TABLE persons (name TEXT, age INT)")
                
                // The tested function:
                try db.execute("INSERT INTO persons (name, age) VALUES (?, ?)", bindings: ["Arthur", 41])
                
                let row = try db.fetchFirstRow("SELECT * FROM persons")!
                XCTAssertEqual(row.value(atIndex: 0)! as String, "Arthur")
                XCTAssertEqual(row.value(atIndex: 1)! as Int, 41)
            }
        } catch let error as GRDB.Error {
            XCTFail("error code \(error.code): \(error.message)")
        } catch {
            XCTFail("error: \(error)")
        }
    }
    
    func testDatabaseExecuteWithDictionaryBinding() {
        do {
            try dbQueue.inDatabase { db -> Void in
                try db.execute("CREATE TABLE persons (name TEXT, age INT)")
                
                // The tested function:
                try db.execute("INSERT INTO persons (name, age) VALUES (:name, :age)", bindings: [":name": "Arthur", ":age": 41])
                
                let row = try db.fetchFirstRow("SELECT * FROM persons")!
                XCTAssertEqual(row.value(atIndex: 0)! as String, "Arthur")
                XCTAssertEqual(row.value(atIndex: 1)! as Int, 41)
            }
        } catch let error as GRDB.Error {
            XCTFail("error code \(error.code): \(error.message)")
        } catch {
            XCTFail("error: \(error)")
        }
    }
    
    func testSelectStatement() {
        do {
            try dbQueue.inDatabase { db -> Void in
                try db.execute("CREATE TABLE persons (name TEXT, age INT)")
                try db.execute("INSERT INTO persons (name, age) VALUES (:name, :age)", bindings: [":name": "Arthur", ":age": 41])
                try db.execute("INSERT INTO persons (name, age) VALUES (:name, :age)", bindings: [":name": "Barbara"])
                
                // The tested function:
                let statement = try db.selectStatement("SELECT * FROM persons")
                
                let rows = Array(statement.fetchRows())
                XCTAssertEqual(rows.count, 2)
            }
        } catch let error as GRDB.Error {
            XCTFail("error code \(error.code): \(error.message)")
        } catch {
            XCTFail("error: \(error)")
        }
    }
    
    func testSelectStatementIndexedBinding() {
        do {
            try dbQueue.inDatabase { db -> Void in
                try db.execute("CREATE TABLE persons (name TEXT, age INT)")
                try db.execute("INSERT INTO persons (name, age) VALUES (:name, :age)", bindings: [":name": "Arthur", ":age": 41])
                try db.execute("INSERT INTO persons (name, age) VALUES (:name, :age)", bindings: [":name": "Barbara"])
                
                let statement = try db.selectStatement("SELECT * FROM persons WHERE name = ?")
                // The tested function:
                statement.bind("Arthur", atIndex: 1)
                
                let rows = Array(statement.fetchRows())
                XCTAssertEqual(rows.count, 1)
            }
        } catch let error as GRDB.Error {
            XCTFail("error code \(error.code): \(error.message)")
        } catch {
            XCTFail("error: \(error)")
        }
    }
    
    func testSelectStatementKeyedBinding() {
        do {
            try dbQueue.inDatabase { db -> Void in
                try db.execute("CREATE TABLE persons (name TEXT, age INT)")
                try db.execute("INSERT INTO persons (name, age) VALUES (:name, :age)", bindings: [":name": "Arthur", ":age": 41])
                try db.execute("INSERT INTO persons (name, age) VALUES (:name, :age)", bindings: [":name": "Barbara"])
                
                let statement = try db.selectStatement("SELECT * FROM persons WHERE name = :name")
                // The tested function:
                statement.bind("Arthur", forKey: ":name")
                
                let rows = Array(statement.fetchRows())
                XCTAssertEqual(rows.count, 1)
            }
        } catch let error as GRDB.Error {
            XCTFail("error code \(error.code): \(error.message)")
        } catch {
            XCTFail("error: \(error)")
        }
    }
    
    func testSelectStatementArrayBinding() {
        do {
            try dbQueue.inDatabase { db -> Void in
                try db.execute("CREATE TABLE persons (name TEXT, age INT)")
                try db.execute("INSERT INTO persons (name, age) VALUES (:name, :age)", bindings: [":name": "Arthur", ":age": 41])
                try db.execute("INSERT INTO persons (name, age) VALUES (:name, :age)", bindings: [":name": "Barbara"])
                
                let statement = try db.selectStatement("SELECT * FROM persons WHERE name = ?")
                // The tested function:
                statement.bind(["Arthur"])
                
                let rows = Array(statement.fetchRows())
                XCTAssertEqual(rows.count, 1)
            }
        } catch let error as GRDB.Error {
            XCTFail("error code \(error.code): \(error.message)")
        } catch {
            XCTFail("error: \(error)")
        }
    }
    
    func testSelectStatementDictionaryBinding() {
        do {
            try dbQueue.inDatabase { db -> Void in
                try db.execute("CREATE TABLE persons (name TEXT, age INT)")
                try db.execute("INSERT INTO persons (name, age) VALUES (:name, :age)", bindings: [":name": "Arthur", ":age": 41])
                try db.execute("INSERT INTO persons (name, age) VALUES (:name, :age)", bindings: [":name": "Barbara"])
                
                let statement = try db.selectStatement("SELECT * FROM persons WHERE name = :name")
                // The tested function:
                statement.bind([":name": "Arthur"])
                
                let rows = Array(statement.fetchRows())
                XCTAssertEqual(rows.count, 1)
            }
        } catch let error as GRDB.Error {
            XCTFail("error code \(error.code): \(error.message)")
        } catch {
            XCTFail("error: \(error)")
        }
    }
    
    func testSelectStatementWithArrayBinding() {
        do {
            try dbQueue.inDatabase { db -> Void in
                try db.execute("CREATE TABLE persons (name TEXT, age INT)")
                try db.execute("INSERT INTO persons (name, age) VALUES (:name, :age)", bindings: [":name": "Arthur", ":age": 41])
                try db.execute("INSERT INTO persons (name, age) VALUES (:name, :age)", bindings: [":name": "Barbara"])
                
                // The tested function:
                let statement = try db.selectStatement("SELECT * FROM persons WHERE name = ?", bindings: ["Arthur"])
                
                let rows = Array(statement.fetchRows())
                XCTAssertEqual(rows.count, 1)
            }
        } catch let error as GRDB.Error {
            XCTFail("error code \(error.code): \(error.message)")
        } catch {
            XCTFail("error: \(error)")
        }
    }
    
    func testSelectStatementWithDictionaryBinding() {
        do {
            try dbQueue.inDatabase { db -> Void in
                try db.execute("CREATE TABLE persons (name TEXT, age INT)")
                try db.execute("INSERT INTO persons (name, age) VALUES (:name, :age)", bindings: [":name": "Arthur", ":age": 41])
                try db.execute("INSERT INTO persons (name, age) VALUES (:name, :age)", bindings: [":name": "Barbara"])
                
                // The tested function:
                let statement = try db.selectStatement("SELECT * FROM persons WHERE name = :name", bindings: [":name": "Arthur"])
                
                let rows = Array(statement.fetchRows())
                XCTAssertEqual(rows.count, 1)
            }
        } catch let error as GRDB.Error {
            XCTFail("error code \(error.code): \(error.message)")
        } catch {
            XCTFail("error: \(error)")
        }
    }
    
    func testRowValueAtIndex() {
        do {
            try dbQueue.inDatabase { db -> Void in
                try db.execute("CREATE TABLE persons (name TEXT, age INT)")
                try db.execute("INSERT INTO persons (name, age) VALUES (:name, :age)", bindings: [":name": "Arthur", ":age": 41])
                try db.execute("INSERT INTO persons (name, age) VALUES (:name, :age)", bindings: [":name": "Barbara"])
                
                var names: [String?] = []
                var ages: [Int?] = []
                let rows = try db.fetchRows("SELECT * FROM persons ORDER BY name")
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
        } catch let error as GRDB.Error {
            XCTFail("error code \(error.code): \(error.message)")
        } catch {
            XCTFail("error: \(error)")
        }
    }
    
    func testRowValueNamed() {
        do {
            try dbQueue.inDatabase { db -> Void in
                try db.execute("CREATE TABLE persons (name TEXT, age INT)")
                try db.execute("INSERT INTO persons (name, age) VALUES (:name, :age)", bindings: [":name": "Arthur", ":age": 41])
                try db.execute("INSERT INTO persons (name, age) VALUES (:name, :age)", bindings: [":name": "Barbara"])
                
                var names: [String?] = []
                var ages: [Int?] = []
                let rows = try db.fetchRows("SELECT * FROM persons ORDER BY name")
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
        } catch let error as GRDB.Error {
            XCTFail("error code \(error.code): \(error.message)")
        } catch {
            XCTFail("error: \(error)")
        }
    }
    
    func testFetchRowsCacheSQLiteResults() {
        do {
            let rows = try dbQueue.inDatabase { db -> [Row] in
                try db.execute("CREATE TABLE persons (name TEXT, age INT)")
                try db.execute("INSERT INTO persons (name, age) VALUES (:name, :age)", bindings: [":name": "Arthur", ":age": 41])
                try db.execute("INSERT INTO persons (name, age) VALUES (:name, :age)", bindings: [":name": "Barbara"])
                
                let rows = try db.fetchRows("SELECT * FROM persons ORDER BY name")
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
        } catch let error as GRDB.Error {
            XCTFail("error code \(error.code): \(error.message)")
        } catch {
            XCTFail("error: \(error)")
        }
    }
    
    func testFuck() {
        do {
            let rows = try dbQueue.inDatabase { db -> AnySequence<Row> in
                try db.execute("CREATE TABLE persons (name TEXT, age INT)")
                try db.execute("INSERT INTO persons (name, age) VALUES (:name, :age)", bindings: [":name": "Arthur", ":age": 41])
                try db.execute("INSERT INTO persons (name, age) VALUES (:name, :age)", bindings: [":name": "Barbara"])
                
                let rows = try db.fetchRows("SELECT * FROM persons ORDER BY name")
                // The array iterates all rows
                return rows
            }
            
            // The problem is that the statement has escaped the
            // dbQueue.inDatabase block: it looks like the rows have already
            // been loaded. But they are actually not.
            //
            // We must find a way to prevent this, and tell users to wrap the
            // sequence in an array (have the block return Array(rows)).
            
            XCTFail("this code should not run")
            
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
        } catch let error as GRDB.Error {
            XCTFail("error code \(error.code): \(error.message)")
        } catch {
            XCTFail("error: \(error)")
        }
    }
    
    // TODO: test RAII (database, statement)
    
    func testDatabase() {
        do {
            let configuration = DatabaseConfiguration(verbose: true)
            let dbQueue = try DatabaseQueue(path: "/tmp/GRDB.sqlite", configuration: configuration)
            
            try dbQueue.inTransaction { db -> Void in
                try db.execute("DROP TABLE IF EXISTS persons")
                try db.execute(
                    "CREATE TABLE persons (" +
                    "id INTEGER PRIMARY KEY, " +
                    "name TEXT, " +
                    "age INT)")
                
                let statement = try db.updateStatement("INSERT INTO persons (name, age) VALUES (?, ?)", bindings: ["Arthur", 36])
                try statement.execute()
                let rowID = statement.lastInsertedRowID
                
                try db.execute("INSERT INTO persons (name, age) VALUES (?, ?)", bindings: ["Arthur", 36])
                try db.execute("INSERT INTO persons (name, age) VALUES (:name, :age)", bindings: [":name": "Arthur", ":age": 36])
                
                let insert1Stmt = try db.updateStatement("INSERT INTO persons (name, age) VALUES (?, ?)")
                insert1Stmt.bind("Arthur", atIndex: 1)
                insert1Stmt.bind(36, atIndex: 2)
                try insert1Stmt.execute()
                try insert1Stmt.reset()
                insert1Stmt.bind("Arthur no age", atIndex: 1)
                insert1Stmt.bind(nil, atIndex: 2)
                try insert1Stmt.execute()
                
                let insert2Stmt = try db.updateStatement("INSERT INTO persons (name, age) VALUES (?, ?)")
                insert2Stmt.bind(["Zoe", 65])
                try insert2Stmt.execute()
                try insert2Stmt.reset()
                insert2Stmt.bind(["Zoe no age", nil])
                try insert2Stmt.execute()
                
                let insert3Stmt = try db.updateStatement("INSERT INTO persons (name, age) VALUES (:name, :age)")
                insert3Stmt.bind("Beate", forKey: ":name")
                insert3Stmt.bind(37, forKey: ":age")
                try insert3Stmt.execute()
                try insert3Stmt.reset()
                insert3Stmt.bind("Beate no age", forKey: ":name")
                insert3Stmt.bind(nil, forKey: ":age")
                try insert3Stmt.execute()
                
                let insert4Stmt = try db.updateStatement("INSERT INTO persons (name, age) VALUES (:name, :age)")
                insert4Stmt.bind([":name": "Crystel", ":age": 16])
                try insert4Stmt.execute()
                try insert4Stmt.reset()
                insert4Stmt.bind([":name": "Crystel no age", ":age": nil])
                try insert4Stmt.execute()
            }
            
            try dbQueue.inDatabase { db -> Void in
                for row in try db.fetchRows("SELECT * FROM persons") {
                    let id: Int64 = row.value(atIndex: 0)!
                    let name: String? = row.value(atIndex: 1)
                    let age: Int? = row.value(atIndex: 2)
                    print("id: \(id), name: \(name), age: \(age)")
                }
                
                for name in try db.fetchValues("SELECT name FROM persons", type: String.self) {
                    print(name)
                }
                
                let names = try db.fetchValues("SELECT name FROM persons", type: String.self).map { $0! }
                print("names: \(names)")
                
                let selectStmt = try db.selectStatement("SELECT * FROM persons")
                
                for name: String? in selectStmt.fetchValues(type: String.self) {
                    print(name)
                }
                
                let uncachedRows = Array(selectStmt.fetchRows(unsafe: true)).map { $0.dictionary }
                NSLog("%@", "\(uncachedRows)")
                
                let cachedRows = Array(selectStmt.fetchRows()).map { $0.dictionary }
                NSLog("%@", "\(cachedRows)")
                
                for row in selectStmt.fetchRows() {
                    let name: String? = row.value(atIndex: 0)
                    let age: Int? = row.value(atIndex: 1)
                    print("\(name): \(age)")
                    print("\(row.dictionary)")
                }
                for row in selectStmt.fetchRows() {
                    let name: String? = row.value(atIndex: 0)
                    let age: Int? = row.value(atIndex: 1)
                    print("\(name): \(age)")
                    print("\(row.dictionary)")
                }
            }

            let names = try dbQueue.inDatabase { db in
                try db.fetchValues("SELECT name FROM persons", type: String.self).map { $0! }
            }
            print("names: \(names)")

        } catch let error as GRDB.Error {
            print("Error \(error._code), \(error.message)")
        } catch {
            
        }
    }
}
