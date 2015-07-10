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

class RowModelDirtyTests: RowModelTestCase {
    
    func testRowModelIsDirtyAfterInit() {
        // Create a RowModel. No fetch has happen, so we don't know if it is
        // identical to its eventual row in the database. So it is dirty.
        let person = Person(name: "Arthur", age: 41)
        XCTAssertTrue(person.isDirty)
    }
    
    func testRowModelIsNotDirtyAfterFullFetch() {
        // Fetch a model from a row that contains all the columns in
        // storedDatabaseDictionary: An update statement, which only saves the
        // columns in storedDatabaseDictionary would perform no change. So the
        // model is not dirty.
        assertNoError {
            try dbQueue.inDatabase { db in
                try Person(name: "Arthur", age: 41).insert(db)
                let person = db.fetchOne(Person.self, "SELECT * FROM persons")!
                XCTAssertFalse(person.isDirty)
            }
        }
    }
    
    func testRowModelIsDirtyAfterPartialFetch() {
        // Fetch a model from a row that does not contain all the columns in
        // storedDatabaseDictionary: An update statement, which only saves the
        // columns in storedDatabaseDictionary may perform unpredictable change.
        // So the model is dirty.
        assertNoError {
            try dbQueue.inDatabase { db in
                try Person(name: "Arthur", age: 41).insert(db)
                let person =  db.fetchOne(Person.self, "SELECT name FROM persons")!
                XCTAssertTrue(person.isDirty)
            }
        }
    }
    
    func testRowModelIsNotDirtyAfterInsert() {
        // After insertion, a model is not dirty since an update would update
        // nothing.
        assertNoError {
            try dbQueue.inDatabase { db in
                let person = Person(name: "Arthur", age: 41)
                try person.insert(db)
                XCTAssertFalse(person.isDirty)
            }
        }
    }
    
    func testRowModelIsDirtyAfterValueChange() {
        // Any change in a value exposed in storedDatabaseDictionary yields a
        // dirty row model.
        assertNoError {
            try dbQueue.inDatabase { db in
                let person = Person(name: "Arthur", age: 41)
                try person.insert(db)
                
                person.name = "Bobby"           // non-nil vs. non-nil
                XCTAssertTrue(person.isDirty)
                try person.reload(db)
                
                person.name = nil               // non-nil vs. nil
                XCTAssertTrue(person.isDirty)
                try person.reload(db)
                
                person.creationDate = NSDate()  // nil vs. non-nil
                XCTAssertTrue(person.isDirty)
                try person.reload(db)
            }
        }
    }
    
    func testRowModelIsNotDirtyAfterUpdate() {
        // After update, a model is not dirty since another update would update
        // nothing.
        assertNoError {
            try dbQueue.inDatabase { db in
                let person = Person(name: "Arthur", age: 41)
                try person.insert(db)
                person.name = "Bobby"
                try person.update(db)
                XCTAssertFalse(person.isDirty)
            }
        }
    }
    
    func testNotDirtyModelPreventsSQLUpdateFromBothUpdateAndSaveMethods() {
        // Updating a non-dirty model is a no-op
        
        assertNoError {
            try dbQueue.inDatabase { db in
                let person = Person(name: "Arthur", age: 41)
                try person.insert(db)
                try person.update(db)
                try person.save(db)
                try person.delete(db)
                
                let insertQueries = self.sqlQueries.filter { sql in sql.rangeOfString("INSERT INTO .*persons", options: [.CaseInsensitiveSearch, .RegularExpressionSearch]) != nil }
                XCTAssertEqual(insertQueries.count, 1)
                
                let updateQueries = self.sqlQueries.filter { sql in sql.rangeOfString("UPDATE .*persons", options: [.CaseInsensitiveSearch, .RegularExpressionSearch]) != nil }
                XCTAssertEqual(updateQueries.count, 0)
                
                // This is the only use of self.sqlQueries. So let's test it as well by making sure the DELETE has been recorded.
                let deleteQueries = self.sqlQueries.filter { sql in sql.rangeOfString("DELETE FROM .*persons", options: [.CaseInsensitiveSearch, .RegularExpressionSearch]) != nil }
                XCTAssertEqual(deleteQueries.count, 1)
            }
        }
    }
    
    func testRowModelIsDirtyAfterReload() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let person = Person(name: "Arthur", age: 41)
                try person.insert(db)
                
                person.name = "Bobby"
                XCTAssertTrue(person.isDirty)
                
                try person.reload(db)
                XCTAssertFalse(person.isDirty)
            }
        }
    }
}
