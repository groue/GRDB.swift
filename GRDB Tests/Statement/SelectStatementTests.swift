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
    
    func testArrayBindingsWithSetter() {
        assertNoError {
            
            try dbQueue.inDatabase { db in
                
                let statement = try db.selectStatement("SELECT COUNT(*) FROM persons WHERE age < ?")
                let ages = [20, 30, 40, 50]
                let counts = ages.map { age -> Int in
                    statement.bindings = [age]
                    return statement.fetchOne(Int.self)!
                }
                XCTAssertEqual(counts, [1,2,2,3])
            }
        }
    }
    
    func testArrayBindingsInFetch() {
        assertNoError {
            
            try dbQueue.inDatabase { db in
                
                let statement = try db.selectStatement("SELECT COUNT(*) FROM persons WHERE age < ?")
                let ages = [20, 30, 40, 50]
                let counts = ages.map { statement.fetchOne(Int.self, bindings: [$0])! }
                XCTAssertEqual(counts, [1,2,2,3])
            }
        }
    }
    
    func testDictionaryBindingsWithSetter() {
        assertNoError {
            
            try dbQueue.inDatabase { db in
                
                let statement = try db.selectStatement("SELECT COUNT(*) FROM persons WHERE age < :age")
                // TODO: why is this explicit type declaration required?
                let ageDicts: [[String: DatabaseValueType?]] = [["age": 20], ["age": 30], ["age": 40], ["age": 50]]
                let counts = ageDicts.map { ageDict -> Int in
                    statement.bindings = Bindings(ageDict)
                    return statement.fetchOne(Int.self)!
                }
                XCTAssertEqual(counts, [1,2,2,3])
            }
        }
    }
    
    func testDictionaryBindingsInFetch() {
        assertNoError {
            
            try dbQueue.inDatabase { db in
                
                let statement = try db.selectStatement("SELECT COUNT(*) FROM persons WHERE age < :age")
                // TODO: why is this explicit type declaration required?
                let ageDicts: [[String: DatabaseValueType?]] = [["age": 20], ["age": 30], ["age": 40], ["age": 50]]
                let counts = ageDicts.map { statement.fetchOne(Int.self, bindings: Bindings($0))! }
                XCTAssertEqual(counts, [1,2,2,3])
            }
        }
    }
}
