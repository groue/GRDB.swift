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

// Person has a RowID primary key, and a overriden insert() method.
class Person: RowModel {
    var id: Int64!
    var name: String!
    var age: Int?
    var creationDate: NSDate!
    
    override class var databaseTable: Table? {
        return Table(named: "persons", primaryKey: .RowID("id"))
    }
    
    override var storedDatabaseDictionary: [String: DatabaseValueConvertible?] {
        return [
            "id": id,
            "name": name,
            "age": age,
            "creationDate": DBDate(creationDate),
        ]
    }
    
    override func setDatabaseValue(dbv: DatabaseValue, forColumn column: String) {
        switch column {
        case "id":              id = dbv.value()
        case "name":            name = dbv.value()
        case "age":             age = dbv.value()
        case "creationDate":    creationDate = (dbv.value() as DBDate?)?.date
        default:                super.setDatabaseValue(dbv, forColumn: column)
        }
    }
    
    init (id: Int64? = nil, name: String? = nil, age: Int? = nil) {
        self.id = id
        self.name = name
        self.age = age
        super.init()
    }
    
    required init(row: Row) {
        super.init(row: row)
    }
    
    override func insert(db: Database) throws {
        // This is implicitely tested with the NOT NULL constraint on creationDate
        if creationDate == nil {
            creationDate = NSDate()
        }
        
        try super.insert(db)
    }
    
    static func setupInDatabase(db: Database) throws {
        try db.execute(
            "CREATE TABLE persons (" +
                "id INTEGER PRIMARY KEY, " +
                "creationDate TEXT NOT NULL, " +
                "name TEXT NOT NULL, " +
                "age INT" +
            ")")
    }
}

class PrimaryKeyRowIDTests: RowModelTestCase {
    
    
    // MARK:- Insert
    
    func testInsertWithNilPrimaryKeyInsertsARowAndSetsPrimaryKey() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let rowModel = Person(name: "Arthur")
                XCTAssertTrue(rowModel.id == nil)
                try rowModel.insert(db)
                XCTAssertTrue(rowModel.id != nil)
                
                let row = db.fetchOneRow("SELECT * FROM persons WHERE id = ?", bindings: [rowModel.id])!
                for (key, value) in rowModel.storedDatabaseDictionary {
                    if let dbv = row[key] {
                        XCTAssertEqual(dbv, value?.databaseValue ?? .Null)
                    } else {
                        XCTFail("Missing column \(key) in fetched row")
                    }
                }
            }
        }
    }
    
    func testInsertWithNotNilPrimaryKeyThatDoesNotMatchAnyRowInsertsARow() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let rowModel = Person(id: 123456, name: "Arthur")
                try rowModel.insert(db)
                
                let row = db.fetchOneRow("SELECT * FROM persons WHERE id = ?", bindings: [rowModel.id])!
                for (key, value) in rowModel.storedDatabaseDictionary {
                    if let dbv = row[key] {
                        XCTAssertEqual(dbv, value?.databaseValue ?? .Null)
                    } else {
                        XCTFail("Missing column \(key) in fetched row")
                    }
                }
            }
        }
    }
    
    func testInsertWithNotNilPrimaryKeyThatMatchesARowThrowsDatabaseError() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let rowModel = Person(name: "Arthur")
                try rowModel.insert(db)
                do {
                    try rowModel.insert(db)
                    XCTFail("Expected DatabaseError")
                } catch is DatabaseError {
                    // Expected DatabaseError
                }
            }
        }
    }
    
    func testInsertAfterDeleteInsertsARow() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let rowModel = Person(name: "Arthur")
                try rowModel.insert(db)
                try rowModel.delete(db)
                try rowModel.insert(db)
                
                let row = db.fetchOneRow("SELECT * FROM persons WHERE id = ?", bindings: [rowModel.id])!
                for (key, value) in rowModel.storedDatabaseDictionary {
                    if let dbv = row[key] {
                        XCTAssertEqual(dbv, value?.databaseValue ?? .Null)
                    } else {
                        XCTFail("Missing column \(key) in fetched row")
                    }
                }
            }
        }
    }
    
    
    // MARK:- Update
    
    func testUpdateWithNilPrimaryKeyThrowsInvalidPrimaryKey() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let rowModel = Person(name: "Arthur")
                XCTAssertTrue(rowModel.id == nil)
                do {
                    try rowModel.update(db)
                    XCTFail("Expected RowModelError.InvalidPrimaryKey")
                } catch RowModelError.InvalidPrimaryKey {
                    // Expected RowModelError.InvalidPrimaryKey
                }
            }
        }
    }
    
    func testUpdateWithNotNilPrimaryKeyThatDoesNotMatchAnyRowThrowsRowModelNotFound() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let rowModel = Person(id: 123456, name: "Arthur")
                do {
                    try rowModel.update(db)
                    XCTFail("Expected RowModelError.RowModelNotFound")
                } catch RowModelError.RowModelNotFound {
                    // Expected RowModelError.RowModelNotFound
                }
            }
        }
    }
    
    func testUpdateWithNotNilPrimaryKeyThatMatchesARowUpdatesThatRow() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let rowModel = Person(name: "Arthur", age: 41)
                try rowModel.insert(db)
                rowModel.age = rowModel.age! + 1
                try rowModel.update(db)

                let row = db.fetchOneRow("SELECT * FROM persons WHERE id = ?", bindings: [rowModel.id])!
                for (key, value) in rowModel.storedDatabaseDictionary {
                    if let dbv = row[key] {
                        XCTAssertEqual(dbv, value?.databaseValue ?? .Null)
                    } else {
                        XCTFail("Missing column \(key) in fetched row")
                    }
                }
            }
        }
    }
    
    func testUpdateAfterDeleteThrowsRowModelNotFound() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let rowModel = Person(name: "Arthur")
                try rowModel.insert(db)
                try rowModel.delete(db)
                do {
                    try rowModel.update(db)
                    XCTFail("Expected RowModelError.RowModelNotFound")
                } catch RowModelError.RowModelNotFound {
                    // Expected RowModelError.RowModelNotFound
                }
            }
        }
    }
    
    
    // MARK:- Save
    
    func testSaveWithNilPrimaryKeyInsertsARowAndSetsPrimaryKey() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let rowModel = Person(name: "Arthur")
                XCTAssertTrue(rowModel.id == nil)
                try rowModel.save(db)
                XCTAssertTrue(rowModel.id != nil)
                
                let row = db.fetchOneRow("SELECT * FROM persons WHERE id = ?", bindings: [rowModel.id])!
                for (key, value) in rowModel.storedDatabaseDictionary {
                    if let dbv = row[key] {
                        XCTAssertEqual(dbv, value?.databaseValue ?? .Null)
                    } else {
                        XCTFail("Missing column \(key) in fetched row")
                    }
                }
            }
        }
    }
    
    func testSaveWithNotNilPrimaryKeyThatDoesNotMatchAnyRowInsertsARow() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let rowModel = Person(id: 123456, name: "Arthur")
                try rowModel.save(db)
                
                let row = db.fetchOneRow("SELECT * FROM persons WHERE id = ?", bindings: [rowModel.id])!
                for (key, value) in rowModel.storedDatabaseDictionary {
                    if let dbv = row[key] {
                        XCTAssertEqual(dbv, value?.databaseValue ?? .Null)
                    } else {
                        XCTFail("Missing column \(key) in fetched row")
                    }
                }
            }
        }
    }

    
    func testSaveWithNotNilPrimaryKeyThatMatchesARowUpdatesThatRow() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let rowModel = Person(name: "Arthur", age: 41)
                try rowModel.insert(db)
                rowModel.age = rowModel.age! + 1
                try rowModel.save(db)
                
                let row = db.fetchOneRow("SELECT * FROM persons WHERE id = ?", bindings: [rowModel.id])!
                for (key, value) in rowModel.storedDatabaseDictionary {
                    if let dbv = row[key] {
                        XCTAssertEqual(dbv, value?.databaseValue ?? .Null)
                    } else {
                        XCTFail("Missing column \(key) in fetched row")
                    }
                }
            }
        }
    }
    
    func testSaveAfterDeleteInsertsARow() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let rowModel = Person(name: "Arthur")
                try rowModel.insert(db)
                try rowModel.delete(db)
                try rowModel.save(db)
                
                let row = db.fetchOneRow("SELECT * FROM persons WHERE id = ?", bindings: [rowModel.id])!
                for (key, value) in rowModel.storedDatabaseDictionary {
                    if let dbv = row[key] {
                        XCTAssertEqual(dbv, value?.databaseValue ?? .Null)
                    } else {
                        XCTFail("Missing column \(key) in fetched row")
                    }
                }
            }
        }
    }
    
    
    // MARK:- Delete
    
    func testDeleteWithNilPrimaryKeyThrowsInvalidPrimaryKey() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let rowModel = Person(name: "Arthur")
                XCTAssertTrue(rowModel.id == nil)
                do {
                    try rowModel.delete(db)
                    XCTFail("Expected RowModelError.InvalidPrimaryKey")
                } catch RowModelError.InvalidPrimaryKey {
                    // Expected RowModelError.InvalidPrimaryKey
                }
            }
        }
    }
    
    func testDeleteWithNotNilPrimaryKeyThatDoesNotMatchAnyRowDoesNothing() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let rowModel = Person(id: 123456, name: "Arthur")
                try rowModel.delete(db)
            }
        }
    }
    
    func testDeleteWithNotNilPrimaryKeyThatMatchesARowDeletesThatRow() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let rowModel = Person(name: "Arthur")
                try rowModel.insert(db)
                try rowModel.delete(db)
                
                let row = db.fetchOneRow("SELECT * FROM persons WHERE id = ?", bindings: [rowModel.id])
                XCTAssertTrue(row == nil)
            }
        }
    }
    
    func testDeleteAfterDeleteDoesNothing() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let rowModel = Person(name: "Arthur")
                try rowModel.insert(db)
                try rowModel.delete(db)
                try rowModel.delete(db)
            }
        }
    }
    
    
    // MARK:- Reload
    
    func testReloadWithNilPrimaryKeyThrowsInvalidPrimaryKey() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let rowModel = Person(name: "Arthur")
                XCTAssertTrue(rowModel.id == nil)
                do {
                    try rowModel.reload(db)
                    XCTFail("Expected RowModelError.InvalidPrimaryKey")
                } catch RowModelError.InvalidPrimaryKey {
                    // Expected RowModelError.InvalidPrimaryKey
                }
            }
        }
    }
    
    func testReloadWithNotNilPrimaryKeyThatDoesNotMatchAnyRowThrowsRowModelNotFound() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let rowModel = Person(id: 123456, name: "Arthur")
                do {
                    try rowModel.reload(db)
                    XCTFail("Expected RowModelError.RowModelNotFound")
                } catch RowModelError.RowModelNotFound {
                    // Expected RowModelError.RowModelNotFound
                }
            }
        }
    }
    
    func testReloadWithNotNilPrimaryKeyThatMatchesARowFetchesThatRow() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let rowModel = Person(name: "Arthur", age: 41)
                try rowModel.insert(db)
                rowModel.age = rowModel.age! + 1
                try rowModel.reload(db)
                
                let row = db.fetchOneRow("SELECT * FROM persons WHERE id = ?", bindings: [rowModel.id])!
                for (key, value) in rowModel.storedDatabaseDictionary {
                    if let dbv = row[key] {
                        XCTAssertEqual(dbv, value?.databaseValue ?? .Null)
                    } else {
                        XCTFail("Missing column \(key) in fetched row")
                    }
                }
            }
        }
    }
    
    func testReloadAfterDeleteThrowsRowModelNotFound() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let rowModel = Person(name: "Arthur")
                try rowModel.insert(db)
                try rowModel.delete(db)
                do {
                    try rowModel.reload(db)
                    XCTFail("Expected RowModelError.RowModelNotFound")
                } catch RowModelError.RowModelNotFound {
                    // Expected RowModelError.RowModelNotFound
                }
            }
        }
    }
    
    
    // MARK: - Select
    
    func testSelectWithPrimaryKey() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let rowModel = Person(name: "Arthur")
                try rowModel.insert(db)
                
                let fetchedRowModel = db.fetchOne(Person.self, primaryKey: rowModel.id)!
                XCTAssertTrue(fetchedRowModel.id == rowModel.id)
                XCTAssertTrue(fetchedRowModel.name == rowModel.name)
                XCTAssertTrue(fetchedRowModel.age == rowModel.age)
                XCTAssertTrue(abs(fetchedRowModel.creationDate.timeIntervalSinceDate(rowModel.creationDate)) < 1e-3)    // ISO-8601 is precise to the millisecond.
            }
        }
    }
    
    func testSelectWithKey() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let rowModel = Person(name: "Arthur")
                try rowModel.insert(db)
                
                let fetchedRowModel = db.fetchOne(Person.self, key: ["name": "Arthur"])!
                XCTAssertTrue(fetchedRowModel.id == rowModel.id)
                XCTAssertTrue(fetchedRowModel.name == rowModel.name)
                XCTAssertTrue(fetchedRowModel.age == rowModel.age)
                XCTAssertTrue(abs(fetchedRowModel.creationDate.timeIntervalSinceDate(rowModel.creationDate)) < 1e-3)    // ISO-8601 is precise to the millisecond.
            }
        }
    }
    
    // TODO: fetch sequence & fetch array
}
