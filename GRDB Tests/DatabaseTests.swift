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
                
                let statement = try db.updateStatement("INSERT INTO persons (name, age) VALUES (?, ?)", arguments: ["Arthur", 36])
                try statement.execute()
                let rowID = statement.lastInsertedRowID
                
                try db.execute("INSERT INTO persons (name, age) VALUES (?, ?)", arguments: ["Arthur", 36])
                try db.execute("INSERT INTO persons (name, age) VALUES (:name, :age)", arguments: [":name": "Arthur", ":age": 36])
                
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
                    let id: Int64 = row.valueAtIndex(0)!
                    let name: String? = row.valueAtIndex(1)
                    let age: Int? = row.valueAtIndex(2)
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
                    let value = row.valueAtIndex(0)
                    let name: String? = row.valueAtIndex(0)
                    let age: Int? = row.valueAtIndex(1)
                    print("value: \(value)")
                    print("\(name): \(age)")
                    print("\(row.dictionary)")
                }
                for row in selectStmt.fetchRows() {
                    let name: String? = row.valueAtIndex(0)
                    let age: Int? = row.valueAtIndex(1)
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
