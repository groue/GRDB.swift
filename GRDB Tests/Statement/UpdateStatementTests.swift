//
//  UpdateStatementTests.swift
//  GRDB
//
//  Created by Gwendal Roué on 03/07/2015.
//  Copyright © 2015 Gwendal Roué. All rights reserved.
//

import XCTest
import GRDB

class UpdateStatementTests: GRDBTests {
    
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
        }
        
        assertNoError {
            try migrator.migrate(dbQueue)
        }
    }
    
    func testArrayBindings() {
        assertNoError {
            
            try dbQueue.inTransaction { db in
                
                let statement = try db.updateStatement("INSERT INTO persons (name, age) VALUES (?, ?)")
                let persons = [
                    ["Arthur", 41],
                    ["Barbara"],
                ]
                for person in persons {
                    statement.reset()
                    statement.clearBindings()
                    statement.bind(Bindings(person))
                    try statement.execute()
                }
                
                return .Commit
            }
            
            dbQueue.inDatabase { db in
                let rows = db.fetchAllRows("SELECT * FROM persons ORDER BY name")
                XCTAssertEqual(rows.count, 2)
                XCTAssertEqual(rows[0].value(named: "name")! as String, "Arthur")
                XCTAssertEqual(rows[0].value(named: "age")! as Int, 41)
                XCTAssertEqual(rows[1].value(named: "name")! as String, "Barbara")
                XCTAssertTrue(rows[1].value(named: "age") == nil)
            }
        }
    }
    
    func testDictionaryBindings() {
        assertNoError {
            
            try dbQueue.inTransaction { db in
                
                let statement = try db.updateStatement("INSERT INTO persons (name, age) VALUES (:name, :age)")
                let persons = [
                    ["name": "Arthur", "age": 41],
                    ["name": "Barbara"],
                ]
                for person in persons {
                    statement.reset()
                    statement.clearBindings()
                    statement.bind(Bindings(person))
                    try statement.execute()
                }
                
                return .Commit
            }
            
            dbQueue.inDatabase { db in
                let rows = db.fetchAllRows("SELECT * FROM persons ORDER BY name")
                XCTAssertEqual(rows.count, 2)
                XCTAssertEqual(rows[0].value(named: "name")! as String, "Arthur")
                XCTAssertEqual(rows[0].value(named: "age")! as Int, 41)
                XCTAssertEqual(rows[1].value(named: "name")! as String, "Barbara")
                XCTAssertTrue(rows[1].value(named: "age") == nil)
            }
        }
    }
}
