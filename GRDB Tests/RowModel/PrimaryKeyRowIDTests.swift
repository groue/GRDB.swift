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

class Person: RowModel {
    var id: Int64?
    var name: String?
    var age: Int?
    var creationDate: NSDate?
    
    override class var databaseTableName: String? {
        return "persons"
    }
    
    override class var databasePrimaryKey: PrimaryKey {
        return .RowID("id")
    }
    
    override var databaseDictionary: [String: SQLiteValueConvertible?] {
        return [
            "id": id,
            "name": name,
            "age": age,
            "creationTimestamp": DBDate(creationDate),
        ]
    }
    
    override func updateFromDatabaseRow(row: Row) {
        if let v = row.sqliteValue(named: "id") { id = v.value() }
        if let v = row.sqliteValue(named: "name") { name = v.value() }
        if let v = row.sqliteValue(named: "age") { age = v.value() }
        if let v = row.sqliteValue(named: "creationTimestamp") { creationDate = (v.value() as DBDate?)?.date }
    }
    
    override func insert(db: Database) throws {
        // TODO: test
        if creationDate == nil {
            creationDate = NSDate()
        }
        
        try super.insert(db)
    }
    
    init (name: String? = nil, age: Int? = nil) {
        self.name = name
        self.age = age
        super.init()
    }
    
    required init(row: Row) {
        super.init(row: row)
    }
    
    static func setupInDatabase(db: Database) throws {
        try db.execute(
            "CREATE TABLE persons (" +
                "id INTEGER PRIMARY KEY, " +
                "creationTimestamp DOUBLE, " +
                "name TEXT NOT NULL, " +
                "age INT" +
            ")")
    }
}

class PrimaryKeyRowIDTests: RowModelTestCase {

    func testInsert() {
        // Models with RowID primary key should be able to be inserted with a
        // nil primary key. After the insertion, they have their primary key
        // set.
        
        assertNoError {
            let arthur = Person(name: "Arthur", age: 41)
            
            XCTAssertTrue(arthur.id == nil)
            try dbQueue.inTransaction { db in
                // The tested method
                try arthur.insert(db)
                
                // After insertion, ID should be set
                XCTAssertTrue(arthur.id != nil)
                
                // After insertion, creationDate should be set
                XCTAssertTrue(arthur.creationDate != nil)
                
                return .Commit
            }
            
            // After insertion, model should be present in the database
            dbQueue.inDatabase { db in
                let persons = db.fetchAll(Person.self, "SELECT * FROM persons ORDER BY name")
                XCTAssertEqual(persons.count, 1)
                let person = persons.first!
                XCTAssertEqual(person.name!, "Arthur")
                XCTAssertEqual(person.age!, 41)
                XCTAssertTrue(abs(person.creationDate!.timeIntervalSinceDate(NSDate())) < 1)
            }
        }
    }
    
    func testInsertTwice() {
        // Models with RowID primary key should be able to be inserted with a
        // nil primary key. After the insertion, they have their primary key
        // set.
        //
        // The second insertion should fail because the primary key is already
        // taken.
        
        assertNoError {
            let arthur = Person(name: "Arthur", age: 41)
            
            XCTAssertTrue(arthur.id == nil)
            do {
                try dbQueue.inTransaction { db in
                    try arthur.insert(db)
                    try arthur.insert(db)
                    return .Commit
                }
                XCTFail("Expected error")
            } catch is SQLiteError {
                // OK, this is expected
            }
        }
    }
    
    func testUpdate() {
        assertNoError {
            let arthur = Person(name: "Arthur", age: 41)
            
            XCTAssertTrue(arthur.id == nil)
            try dbQueue.inTransaction { db in
                try arthur.insert(db)
                arthur.age = 42
                try arthur.update(db)   // The tested method
                return .Commit
            }
            
            dbQueue.inDatabase { db in
                let persons = db.fetchAll(Person.self, "SELECT * FROM persons ORDER BY name")
                XCTAssertEqual(persons.count, 1)
                XCTAssertEqual(persons.first!.name!, "Arthur")
                XCTAssertEqual(persons.first!.age!, 42)
            }
        }
    }
    
    func testSave() {
        assertNoError {
            let arthur = Person(name: "Arthur", age: 41)
            
            XCTAssertTrue(arthur.id == nil)
            try dbQueue.inTransaction { db in
                // Initial save should insert
                try arthur.save(db)
                return .Commit
            }
            XCTAssertTrue(arthur.id != nil)
            arthur.age = 42
            try dbQueue.inTransaction { db in
                // Initial save should update
                try arthur.save(db)
                return .Commit
            }
            
            dbQueue.inDatabase { db in
                let arthur2 = db.fetchOne(Person.self, primaryKey: arthur.id!)!
                XCTAssertEqual(arthur2.age!, 42)
            }
        }
    }
    
    func testSelectWithPrimaryKey() {
        assertNoError {
            var arthurID: Int64? = nil
            try dbQueue.inTransaction { db in
                let arthur = Person(name: "Arthur", age: 41)
                try arthur.insert(db)
                arthurID = arthur.id
                return .Commit
            }
            
            dbQueue.inDatabase { db in
                let arthur = db.fetchOne(Person.self, primaryKey: arthurID!)! // The tested method
                
                XCTAssertEqual(arthur.id!, arthurID!)
                XCTAssertEqual(arthur.name!, "Arthur")
                XCTAssertEqual(arthur.age!, 41)
            }
        }
    }
    
    func testSelectWithDictionaryPrimaryKey() {
        assertNoError {
            var arthurID: Int64? = nil
            try dbQueue.inTransaction { db in
                let arthur = Person(name: "Arthur", age: 41)
                try arthur.insert(db)
                arthurID = arthur.id
                return .Commit
            }
            
            dbQueue.inDatabase { db in
                let arthur = db.fetchOne(Person.self, primaryKey: ["id": arthurID])! // The tested method
                
                XCTAssertEqual(arthur.id!, arthurID!)
                XCTAssertEqual(arthur.name!, "Arthur")
                XCTAssertEqual(arthur.age!, 41)
            }
        }
    }
    
    func testSelectWithArrayPrimaryKey() {
        assertNoError {
            var arthurID: Int64? = nil
            try dbQueue.inTransaction { db in
                let arthur = Person(name: "Arthur", age: 41)
                try arthur.insert(db)
                arthurID = arthur.id
                return .Commit
            }
            
            dbQueue.inDatabase { db in
                let arthur = db.fetchOne(Person.self, primaryKey: [arthurID])! // The tested method
                XCTAssertEqual(arthur.id!, arthurID!)
                XCTAssertEqual(arthur.name!, "Arthur")
                XCTAssertEqual(arthur.age!, 41)
            }
        }
    }
    
    func testDelete() {
        assertNoError {
            try dbQueue.inTransaction { db in
                let arthur = Person(name: "Arthur")
                try arthur.insert(db)
                
                let barbara = Person(name: "Barbara")
                try barbara.insert(db)
                
                try arthur.delete(db)   // The tested method
                
                return .Commit
            }
            
            dbQueue.inDatabase { db in
                let persons = db.fetchAll(Person.self, "SELECT * FROM persons ORDER BY name")
                XCTAssertEqual(persons.count, 1)
                XCTAssertEqual(persons.first!.name!, "Barbara")
            }
        }
    }
}
