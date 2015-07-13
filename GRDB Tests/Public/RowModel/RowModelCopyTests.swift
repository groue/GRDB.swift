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

class RowModelCopyTests: RowModelTestCase {
    
    func testRowModelCopyDatabaseValuesFrom() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let person = Person(name: "Arthur", age: 41)
                try person.insert(db)
                
                let clone = Person()
                clone.copyDatabaseValuesFrom(person)
                XCTAssertEqual(clone.id, person.id)
                XCTAssertEqual(clone.name, person.name)
                XCTAssertEqual(clone.age, person.age)
                XCTAssertTrue(abs(clone.creationDate.timeIntervalSinceDate(person.creationDate)) < 1)
            }
        }
    }
}
