//
//  SelectStatementTests.swift
//  GRDB
//
//  Created by Gwendal Roué on 03/07/2015.
//  Copyright © 2015 Gwendal Roué. All rights reserved.
//

import XCTest
import GRDB

class SelectStatementTests: GRDBTests {
    
    override func setUp() {
        super.setUp()
        
        var migrator = DatabaseMigrator()
        
        migrator.registerMigration("createPersons") { db in
            try db.execute(
                "CREATE TABLE persons (" +
                    "id INTEGER PRIMARY KEY, " +
                    "creationTimestamp DOUBLE, " +
                    "name TEXT NOT NULL, " +
                    "age INT" +
                ")")
            
            try db.execute("INSERT INTO persons (name, age) VALUES (?,?)", bindings: ["Arthur", 41])
            try db.execute("INSERT INTO persons (name, age) VALUES (?,?)", bindings: ["Barbara", 26])
            try db.execute("INSERT INTO persons (name, age) VALUES (?,?)", bindings: ["Craig", 13])
        }
        
        assertNoError {
            try migrator.migrate(dbQueue)
        }
    }
    
    func testArrayBindings() {
        assertNoError {
            
            try dbQueue.inDatabase { db in
                
                let statement = try db.selectStatement("SELECT COUNT(*) FROM persons WHERE age < ?")
                let ages = [20, 30, 40, 50]
                let counts = ages.map { age -> Int in
                    statement.reset()
                    statement.clearBindings()
                    statement.bind([age])
                    return statement.fetchOne(Int.self)!
                }
                XCTAssertEqual(counts, [1,2,2,3])
            }
        }
    }
    
    func testDictionaryBindings() {
        assertNoError {
            
            try dbQueue.inDatabase { db in
                
                let statement = try db.selectStatement("SELECT COUNT(*) FROM persons WHERE age < :age")
                // TODO: why is this explicit type declaration required?
                let ages: [[String: DatabaseValue?]] = [["age": 20], ["age": 30], ["age": 40], ["age": 50]]
                let counts = ages.map { age -> Int in
                    statement.reset()
                    statement.clearBindings()
                    statement.bind(Bindings(age))
                    return statement.fetchOne(Int.self)!
                }
                XCTAssertEqual(counts, [1,2,2,3])
            }
        }
    }
}
