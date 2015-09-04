//
// GRDB.swift
// https://github.com/groue/GRDB.swift
// Copyright (c) 2015 Gwendal Roué
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.


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
