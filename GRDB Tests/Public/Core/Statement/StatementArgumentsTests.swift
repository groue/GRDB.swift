//
//  StatementTests.swift
//  GRDB
//
//  Created by Gwendal Roué on 06/01/2016.
//  Copyright © 2016 Gwendal Roué. All rights reserved.
//

import XCTest
import GRDB

class StatementArgumentsTests: GRDBTestCase {

    override func setUp() {
        super.setUp()
        
        var migrator = DatabaseMigrator()
        
        migrator.registerMigration("createPersons") { db in
            try db.execute(
                "CREATE TABLE persons (" +
                    "id INTEGER PRIMARY KEY, " +
                    "firstName TEXT, " +
                    "lastName TEXT, " +
                    "age INT" +
                ")")
        }
        
        assertNoError {
            try migrator.migrate(dbQueue)
        }
    }
    
    func testPositionalStatementArgumentsValidation() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let statement = try db.updateStatement("INSERT INTO persons (firstName, age) VALUES (?, ?)")
                
                do {
                    // Correct number of arguments
                    try statement.validateArguments(["foo", 1])
                } catch {
                    XCTFail("Unexpected error: \(error)")
                }
                
                do {
                    // Missing arguments
                    try statement.validateArguments([])
                    XCTFail("Expected error")
                } catch let error as DatabaseError {
                    print(error)
                } catch {
                    XCTFail("Unexpected error: \(error)")
                }
                
                do {
                    // Two few arguments
                    try statement.validateArguments(["foo"])
                    XCTFail("Expected error")
                } catch let error as DatabaseError {
                    print(error)
                } catch {
                    XCTFail("Unexpected error: \(error)")
                }
                
                do {
                    // Two many arguments
                    try statement.validateArguments(["foo", 1, "bar"])
                    XCTFail("Expected error")
                } catch let error as DatabaseError {
                    print(error)
                } catch {
                    XCTFail("Unexpected error: \(error)")
                }
                
                do {
                    // Missing arguments
                    try statement.validateArguments([:])
                    XCTFail("Expected error")
                } catch let error as DatabaseError {
                    print(error)
                } catch {
                    XCTFail("Unexpected error: \(error)")
                }
                
                do {
                    // Unmappable arguments
                    try statement.validateArguments(["firstName": "foo", "age": 1])
                    XCTFail("Expected error")
                } catch let error as DatabaseError {
                    print(error)
                } catch {
                    XCTFail("Unexpected error: \(error)")
                }
            }
        }
    }
    
    func testNamedStatementArgumentsValidation() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let statement = try db.updateStatement("INSERT INTO persons (firstName, age) VALUES (:firstName, :age)")
                
                do {
                    // Correct number of arguments
                    try statement.validateArguments(["foo", 1])
                } catch {
                    XCTFail("Unexpected error: \(error)")
                }
                
                do {
                    // All arguments are mapped
                    try statement.validateArguments(["firstName": "foo", "age": 1])
                } catch {
                    XCTFail("Unexpected error: \(error)")
                }
                
                do {
                    // All arguments are mapped
                    try statement.validateArguments(["firstName": "foo", "age": 1, "bar": "baz"])
                } catch {
                    XCTFail("Unexpected error: \(error)")
                }
                
                do {
                    // Missing arguments
                    try statement.validateArguments([])
                    XCTFail("Expected error")
                } catch let error as DatabaseError {
                    print(error)
                } catch {
                    XCTFail("Unexpected error: \(error)")
                }
                
                do {
                    // Missing arguments
                    try statement.validateArguments(["foo"])
                    XCTFail("Expected error")
                } catch let error as DatabaseError {
                    print(error)
                } catch {
                    XCTFail("Unexpected error: \(error)")
                }
                
                do {
                    // Too many arguments
                    try statement.validateArguments(["foo", 1, "baz"])
                    XCTFail("Expected error")
                } catch let error as DatabaseError {
                    print(error)
                } catch {
                    XCTFail("Unexpected error: \(error)")
                }
                
                do {
                    // Missing arguments
                    try statement.validateArguments([:])
                    XCTFail("Expected error")
                } catch let error as DatabaseError {
                    print(error)
                } catch {
                    XCTFail("Unexpected error: \(error)")
                }
                
                do {
                    // Missing arguments
                    try statement.validateArguments(["firstName": "foo"])
                    XCTFail("Expected error")
                } catch let error as DatabaseError {
                    print(error)
                } catch {
                    XCTFail("Unexpected error: \(error)")
                }
            }
        }
    }
    
    func testReusedNamedStatementArgumentsValidation() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let statement = try db.updateStatement("INSERT INTO persons (firstName, lastName, age) VALUES (:name, :name, :age)")
                
                do {
                    try statement.execute(arguments: ["name": "foo", "age": 1])
                    let row = Row.fetchOne(db, "SELECT * FROM persons")!
                    XCTAssertEqual(row.value(named: "firstName") as String, "foo")
                    XCTAssertEqual(row.value(named: "lastName") as String, "foo")
                    XCTAssertEqual(row.value(named: "age") as Int, 1)
                }
                
                do {
                    // Correct number of arguments
                    try statement.validateArguments(["foo", 1])
                } catch {
                    XCTFail("Unexpected error: \(error)")
                }
                
                do {
                    // All arguments are mapped
                    try statement.validateArguments(["name": "foo", "age": 1])
                } catch {
                    XCTFail("Unexpected error: \(error)")
                }
                
                do {
                    // All arguments are mapped
                    try statement.validateArguments(["name": "foo", "age": 1, "bar": "baz"])
                } catch {
                    XCTFail("Unexpected error: \(error)")
                }
                
                do {
                    // Missing arguments
                    try statement.validateArguments([])
                    XCTFail("Expected error")
                } catch let error as DatabaseError {
                    print(error)
                } catch {
                    XCTFail("Unexpected error: \(error)")
                }
                
                do {
                    // Missing arguments
                    try statement.validateArguments(["foo"])
                    XCTFail("Expected error")
                } catch let error as DatabaseError {
                    print(error)
                } catch {
                    XCTFail("Unexpected error: \(error)")
                }
                
                do {
                    // Too many arguments
                    try statement.validateArguments(["foo", 1, "baz"])
                    XCTFail("Expected error")
                } catch let error as DatabaseError {
                    print(error)
                } catch {
                    XCTFail("Unexpected error: \(error)")
                }
                
                do {
                    // Missing arguments
                    try statement.validateArguments([:])
                    XCTFail("Expected error")
                } catch let error as DatabaseError {
                    print(error)
                } catch {
                    XCTFail("Unexpected error: \(error)")
                }
                
                do {
                    // Missing arguments
                    try statement.validateArguments(["name": "foo"])
                    XCTFail("Expected error")
                } catch let error as DatabaseError {
                    print(error)
                } catch {
                    XCTFail("Unexpected error: \(error)")
                }
            }
        }
    }
}
