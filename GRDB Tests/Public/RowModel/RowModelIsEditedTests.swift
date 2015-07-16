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

class RowModelIsEditedTests: RowModelTestCase {
    
    func testRowModelIsEditedAfterInit() {
        // Create a RowModel. No fetch has happen, so we don't know if it is
        // identical to its eventual row in the database. So it is edited.
        let person = Person(name: "Arthur", age: 41)
        XCTAssertTrue(person.isEdited)
    }
    
    func testRowModelIsNotEditedAfterFullFetch() {
        // Fetch a model from a row that contains all the columns in
        // storedDatabaseDictionary: An update statement, which only saves the
        // columns in storedDatabaseDictionary would perform no change. So the
        // model is not edited.
        assertNoError {
            try dbQueue.inDatabase { db in
                try Person(name: "Arthur", age: 41).insert(db)
                let person = db.fetchOne(Person.self, "SELECT * FROM persons")!
                XCTAssertFalse(person.isEdited)
            }
        }
    }
    
    func testRowModelIsNotEditedAfterWiderThanFullFetch() {
        // Fetch a model from a row that contains all the columns in
        // storedDatabaseDictionary, plus extra ones: An update statement, which
        // only saves the columns in storedDatabaseDictionary would perform no
        // change. So the model is not edited.
        assertNoError {
            try dbQueue.inDatabase { db in
                try Person(name: "Arthur", age: 41).insert(db)
                let person = db.fetchOne(Person.self, "SELECT *, 1 AS foo FROM persons")!
                XCTAssertFalse(person.isEdited)
            }
        }
    }
    
    func testRowModelIsEditedAfterPartialFetch() {
        // Fetch a model from a row that does not contain all the columns in
        // storedDatabaseDictionary: An update statement saves the columns in
        // storedDatabaseDictionary, so it may perform unpredictable change.
        // So the model is edited.
        assertNoError {
            try dbQueue.inDatabase { db in
                try Person(name: "Arthur", age: 41).insert(db)
                let person =  db.fetchOne(Person.self, "SELECT name FROM persons")!
                XCTAssertTrue(person.isEdited)
            }
        }
    }
    
    func testRowModelIsNotEditedAfterInsert() {
        // After insertion, a model is not edited.
        assertNoError {
            try dbQueue.inDatabase { db in
                let person = Person(name: "Arthur", age: 41)
                try person.insert(db)
                XCTAssertFalse(person.isEdited)
            }
        }
    }
    
    func testRowModelIsEditedAfterValueChange() {
        // Any change in a value exposed in storedDatabaseDictionary yields a
        // row model that is edited.
        assertNoError {
            try dbQueue.inDatabase { db in
                let person = Person(name: "Arthur", age: 41)
                try person.insert(db)
                
                person.name = "Bobby"           // non-nil vs. non-nil
                XCTAssertTrue(person.isEdited)
                try person.reload(db)
                
                person.name = nil               // non-nil vs. nil
                XCTAssertTrue(person.isEdited)
                try person.reload(db)
                
                person.creationDate = NSDate()  // nil vs. non-nil
                XCTAssertTrue(person.isEdited)
                try person.reload(db)
            }
        }
    }
    
    func testRowModelIsNotEditedAfterUpdate() {
        // After update, a model is not edited.
        assertNoError {
            try dbQueue.inDatabase { db in
                let person = Person(name: "Arthur", age: 41)
                try person.insert(db)
                person.name = "Bobby"
                try person.update(db)
                XCTAssertFalse(person.isEdited)
            }
        }
    }
    
    func testRowModelIsNotEditedAfterSave() {
        // After save, a model is not edited.
        assertNoError {
            try dbQueue.inDatabase { db in
                let person = Person(name: "Arthur", age: 41)
                try person.save(db)
                XCTAssertFalse(person.isEdited)
                person.name = "Bobby"
                XCTAssertTrue(person.isEdited)
                try person.save(db)
                XCTAssertFalse(person.isEdited)
            }
        }
    }
    
    func testRowModelIsNotEditedAfterReload() {
        // After reload, a model is not edited.
        assertNoError {
            try dbQueue.inDatabase { db in
                let person = Person(name: "Arthur", age: 41)
                try person.insert(db)
                
                person.name = "Bobby"
                XCTAssertTrue(person.isEdited)
                
                try person.reload(db)
                XCTAssertFalse(person.isEdited)
            }
        }
    }
}
