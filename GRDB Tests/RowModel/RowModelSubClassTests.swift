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

class PersonWithPet: Person {
    var petCount: Int?
    
    override func updateFromDatabaseRow(row: Row) {
        super.updateFromDatabaseRow(row)
        if let v = row.sqliteValue(named: "petCount") { petCount = v.value() }
    }
}

class RowModelSubClassTests: RowModelTests {
    
    func testSelect() {
        assertNoError {
            try dbQueue.inTransaction { db in
                try Person(name: "Arthur", age: 41).insert(db)
                try Person(name: "Barbara", age: 36).insert(db)
                return .Commit
            }
            
            dbQueue.inDatabase { db in
                let persons = db.fetchAll(Person.self, "SELECT * FROM persons ORDER BY name")
                let arthur = db.fetchOne(Person.self, "SELECT * FROM persons ORDER BY age DESC")!
                
                XCTAssertEqual(persons.map { $0.name! }, ["Arthur", "Barbara"])
                XCTAssertEqual(persons.map { $0.age! }, [41, 36])
                XCTAssertEqual(arthur.name!, "Arthur")
                XCTAssertEqual(arthur.age!, 41)
            }
        }
    }
    
}
