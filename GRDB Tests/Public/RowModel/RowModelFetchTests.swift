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

class RowModelFetchTests: RowModelTestCase {
    
    func testSelectStatement() {
        assertNoError {
            try dbQueue.inTransaction { db in
                try Person(name: "Arthur", age: 41).insert(db)
                try Person(name: "Barbara", age: 37).insert(db)
                return .Commit
            }
            
            dbQueue.inDatabase { db in
                let statement = db.selectStatement("SELECT * FROM persons WHERE name = ?")
                
                for name in ["Arthur", "Barbara"] {
                    let person = statement.fetchOne(Person.self, arguments: [name])!
                    XCTAssertEqual(person.name!, name)
                }
            }
        }
    }
    
    func testDatabaseRowModelSequenceCanBeIteratedTwice() {
        assertNoError {
            try dbQueue.inTransaction { db in
                try Person(name: "Arthur", age: 41).insert(db)
                try Person(name: "Barbara", age: 37).insert(db)
                
                let personSequence = db.fetch(Person.self, "SELECT * FROM persons ORDER BY name")
                var names1: [String?] = personSequence.map { $0.name }
                var names2: [String?] = personSequence.map { $0.name }
                
                XCTAssertEqual(names1[0]!, "Arthur")
                XCTAssertEqual(names1[1]!, "Barbara")
                XCTAssertEqual(names2[0]!, "Arthur")
                XCTAssertEqual(names2[1]!, "Barbara")
                
                return .Commit
            }
        }
    }
    
    func testSelectStatementRowModelSequenceCanBeIteratedTwice() {
        assertNoError {
            try dbQueue.inTransaction { db in
                try Person(name: "Arthur", age: 41).insert(db)
                try Person(name: "Barbara", age: 37).insert(db)

                let statement = db.selectStatement("SELECT * FROM persons ORDER BY name")
                let personSequence = statement.fetch(Person.self)
                var names1: [String?] = personSequence.map { $0.name }
                var names2: [String?] = personSequence.map { $0.name }
                
                XCTAssertEqual(names1[0]!, "Arthur")
                XCTAssertEqual(names1[1]!, "Barbara")
                XCTAssertEqual(names2[0]!, "Arthur")
                XCTAssertEqual(names2[1]!, "Barbara")
                
                return .Commit
            }
        }
    }
}
