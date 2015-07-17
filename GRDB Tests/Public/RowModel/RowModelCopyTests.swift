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
        let person1 = Person(id: 123, name: "Arthur", age: 41, creationDate: NSDate())
        let person2 = Person(id: 456, name: "Bobby")
        
        // Persons are different
        XCTAssertFalse(person2.id == person1.id)
        XCTAssertFalse(person2.name == person1.name)
        XCTAssertFalse((person1.age == nil) == (person2.age == nil))
        XCTAssertFalse((person1.creationDate == nil) == (person2.creationDate == nil))
        
        // And then identical
        person2.copyDatabaseValuesFrom(person1)
        XCTAssertTrue(person2.id == person1.id)
        XCTAssertTrue(person2.name == person1.name)
        XCTAssertTrue(person2.age == person1.age)
        XCTAssertTrue(abs(person2.creationDate.timeIntervalSinceDate(person1.creationDate)) < 1e-3)    // ISO-8601 is precise to the millisecond.
    }
}
