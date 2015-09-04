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

class PersonWithOverrides: Person {
    enum SavingMethod {
        case Insert
        case Update
    }
    
    var extra: Int!
    var lastSavingMethod: SavingMethod?
    
    override func setDatabaseValue(dbv: DatabaseValue, forColumn column: String) {
        switch column {
        case "extra": extra = dbv.value()
        default:      super.setDatabaseValue(dbv, forColumn: column)
        }
    }
    
    override func insert(db: Database) throws {
        lastSavingMethod = .Insert
        try super.insert(db)
    }
    
    override func update(db: Database) throws {
        lastSavingMethod = .Update
        try super.update(db)
    }
}

class RowModelSubClassTests: RowModelTestCase {
    
    
    // MARK: - Save
    
    func testSaveWithNilPrimaryKeyCallsInsertMethod() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let rowModel = PersonWithOverrides(name: "Arthur")
                try rowModel.save(db)
                XCTAssertEqual(rowModel.lastSavingMethod!, PersonWithOverrides.SavingMethod.Insert)
            }
        }
    }
    
    func testSaveWithNotNilPrimaryKeyThatDoesNotMatchAnyRowCallsInsertMethod() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let rowModel = PersonWithOverrides(id: 123456, name: "Arthur")
                try rowModel.save(db)
                XCTAssertEqual(rowModel.lastSavingMethod!, PersonWithOverrides.SavingMethod.Insert)
            }
        }
    }
    
    
    func testSaveWithNotNilPrimaryKeyThatMatchesARowCallsUpdateMethod() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let rowModel = PersonWithOverrides(name: "Arthur", age: 41)
                try rowModel.insert(db)
                rowModel.age = rowModel.age! + 1
                try rowModel.save(db)
                XCTAssertEqual(rowModel.lastSavingMethod!, PersonWithOverrides.SavingMethod.Update)
            }
        }
    }
    
    func testSaveAfterDeleteCallsInsertMethod() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let rowModel = PersonWithOverrides(name: "Arthur")
                try rowModel.insert(db)
                try rowModel.delete(db)
                try rowModel.save(db)
                XCTAssertEqual(rowModel.lastSavingMethod!, PersonWithOverrides.SavingMethod.Insert)
            }
        }
    }
    
    
    // MARK: - Select
    
    func testSelect() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let rowModel = Person(name: "Arthur", age: 41)
                try rowModel.insert(db)
                
                let fetchedRowModel = PersonWithOverrides.fetchOne(db, "SELECT *, 123 as extra FROM persons")!
                XCTAssertTrue(fetchedRowModel.id == rowModel.id)
                XCTAssertTrue(fetchedRowModel.name == rowModel.name)
                XCTAssertTrue(fetchedRowModel.age == rowModel.age)
                XCTAssertTrue(abs(fetchedRowModel.creationDate.timeIntervalSinceDate(rowModel.creationDate)) < 1e-3)    // ISO-8601 is precise to the millisecond.
                XCTAssertTrue(fetchedRowModel.extra == 123)
            }
        }
    }
    
}
