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

class SelectStatementTests : GRDBTestCase {
    
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
            
            try db.execute("INSERT INTO persons (name, age) VALUES (?,?)", arguments: ["Arthur", 41])
            try db.execute("INSERT INTO persons (name, age) VALUES (?,?)", arguments: ["Barbara", 26])
            try db.execute("INSERT INTO persons (name, age) VALUES (?,?)", arguments: ["Craig", 13])
        }
        
        assertNoError {
            try migrator.migrate(dbQueue)
        }
    }
    
    func testArrayStatementArguments() {
        assertNoError {
            dbQueue.inDatabase { db in
                let statement = db.selectStatement("SELECT COUNT(*) FROM persons WHERE age < ?")
                let ages = [20, 30, 40, 50]
                let counts = ages.map { statement.fetchOne(Int.self, arguments: [$0])! }
                XCTAssertEqual(counts, [1,2,2,3])
            }
        }
    }
    
    func testStatementArgumentsSetterWithArray() {
        assertNoError {
            dbQueue.inDatabase { db in
                let statement = db.selectStatement("SELECT COUNT(*) FROM persons WHERE age < ?")
                let ages = [20, 30, 40, 50]
                let counts = ages.map { (age: Int) -> Int in
                    statement.arguments = [age]
                    return statement.fetchOne(Int.self)!
                }
                XCTAssertEqual(counts, [1,2,2,3])
            }
        }
    }
    
    func testDictionaryStatementArguments() {
        assertNoError {
            dbQueue.inDatabase { db in
                let statement = db.selectStatement("SELECT COUNT(*) FROM persons WHERE age < :age")
                // TODO: why is this explicit type declaration required?
                let ageDicts: [[String: DatabaseValueConvertible?]] = [["age": 20], ["age": 30], ["age": 40], ["age": 50]]
                let counts = ageDicts.map { statement.fetchOne(Int.self, arguments: StatementArguments($0))! }
                XCTAssertEqual(counts, [1,2,2,3])
            }
        }
    }
    
    func testStatementArgumentsSetterWithDictionary() {
        assertNoError {
            dbQueue.inDatabase { db in
                let statement = db.selectStatement("SELECT COUNT(*) FROM persons WHERE age < :age")
                // TODO: why is this explicit type declaration required?
                let ageDicts: [[String: DatabaseValueConvertible?]] = [["age": 20], ["age": 30], ["age": 40], ["age": 50]]
                let counts = ageDicts.map { (ageDict: [String: DatabaseValueConvertible?]) -> Int in
                    statement.arguments = StatementArguments(ageDict)
                    return statement.fetchOne(Int.self)!
                }
                XCTAssertEqual(counts, [1,2,2,3])
            }
        }
    }
    
    func testRowSequenceCanBeFetchedTwice() {
        assertNoError {
            dbQueue.inDatabase { db in
                let statement = db.selectStatement("SELECT * FROM persons ORDER BY name")
                var names1: [String?] = statement.fetchRows().map { $0.value(named: "name") as String? }
                var names2: [String?] = statement.fetchRows().map { $0.value(named: "name") as String? }
                
                XCTAssertEqual(names1[0]!, "Arthur")
                XCTAssertEqual(names1[1]!, "Barbara")
                XCTAssertEqual(names1[2]!, "Craig")
                XCTAssertEqual(names2[0]!, "Arthur")
                XCTAssertEqual(names2[1]!, "Barbara")
                XCTAssertEqual(names2[2]!, "Craig")
            }
        }
    }

    func testRowSequenceCanBeIteratedTwice() {
        assertNoError {
            dbQueue.inDatabase { db in
                let statement = db.selectStatement("SELECT * FROM persons ORDER BY name")
                let rows = statement.fetchRows()
                var names1: [String?] = rows.map { $0.value(named: "name") as String? }
                var names2: [String?] = rows.map { $0.value(named: "name") as String? }
                
                XCTAssertEqual(names1[0]!, "Arthur")
                XCTAssertEqual(names1[1]!, "Barbara")
                XCTAssertEqual(names1[2]!, "Craig")
                XCTAssertEqual(names2[0]!, "Arthur")
                XCTAssertEqual(names2[1]!, "Barbara")
                XCTAssertEqual(names2[2]!, "Craig")
            }
        }
    }
    
    func testValueSequenceCanBeFetchedTwice() {
        assertNoError {
            dbQueue.inDatabase { db in
                let statement = db.selectStatement("SELECT name FROM persons ORDER BY name")
                var names1: [String?] = Array(statement.fetch(String.self))
                var names2: [String?] = Array(statement.fetch(String.self))
                
                XCTAssertEqual(names1[0]!, "Arthur")
                XCTAssertEqual(names1[1]!, "Barbara")
                XCTAssertEqual(names1[2]!, "Craig")
                XCTAssertEqual(names2[0]!, "Arthur")
                XCTAssertEqual(names2[1]!, "Barbara")
                XCTAssertEqual(names2[2]!, "Craig")
            }
        }
    }
    
    func testValueSequenceCanBeIteratedTwice() {
        assertNoError {
            dbQueue.inDatabase { db in
                let statement = db.selectStatement("SELECT name FROM persons ORDER BY name")
                let nameSequence = statement.fetch(String.self)
                var names1: [String?] = Array(nameSequence)
                var names2: [String?] = Array(nameSequence)
                
                XCTAssertEqual(names1[0]!, "Arthur")
                XCTAssertEqual(names1[1]!, "Barbara")
                XCTAssertEqual(names1[2]!, "Craig")
                XCTAssertEqual(names2[0]!, "Arthur")
                XCTAssertEqual(names2[1]!, "Barbara")
                XCTAssertEqual(names2[2]!, "Craig")
            }
        }
    }
}
