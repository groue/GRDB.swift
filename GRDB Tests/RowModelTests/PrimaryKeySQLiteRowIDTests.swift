//
//  PrimaryKeySQLiteRowIDTests.swift
//  GRDB
//
//  Created by Gwendal Roué on 03/07/2015.
//  Copyright © 2015 Gwendal Roué. All rights reserved.
//

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
        return .SQLiteRowID("id")
    }
    
    override var databaseDictionary: [String: DatabaseValue?] {
        return [
            "id": id,
            "name": name,
            "age": age,
            "creationTimestamp": DatabaseDate(creationDate),
        ]
    }
    
    override func updateFromDatabaseRow(row: Row) {
        if row.hasColumn("id") { id = row.value(named: "id") }
        if row.hasColumn("name") { name = row.value(named: "name") }
        if row.hasColumn("age") { age = row.value(named: "age") }
        if row.hasColumn("creationTimestamp") {
            let dbDate: DatabaseDate? = row.value(named: "creationTimestamp")
            creationDate = dbDate?.date
        }
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

class PrimaryKeySQLiteRowIDTests: RowModelTests {

    func testInsert() {
        // Models with SQLiteRowID primary key should be able to be inserted
        // with a nil primary key. After the insertion, they have their primary
        // key set.
        
        assertNoError {
            let arthur = Person(name: "Arthur", age: 41)
            
            XCTAssertTrue(arthur.id == nil)
            try dbQueue.inTransaction { db in
                // The tested method
                try arthur.insert(db)
                
                // After insertion, ID should be set
                XCTAssertTrue(arthur.id != nil)
                
                return .Commit
            }
            
            // After insertion, model should be present in the database
            dbQueue.inDatabase { db in
                let persons = db.fetchAll(Person.self, "SELECT * FROM persons ORDER BY name")
                XCTAssertEqual(persons.count, 1)
                XCTAssertEqual(persons.first!.name!, "Arthur")
            }
        }
    }
    
    func testInsertTwice() {
        // Models with SQLiteRowID primary key should be able to be inserted
        // with a nil primary key. After the insertion, they have their primary
        // key set.
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
                let arthur = db.fetchOne(Person.self, primaryKey: arthurID!)!
                
                XCTAssertEqual(arthur.id!, arthurID!)
                XCTAssertEqual(arthur.name!, "Arthur")
                XCTAssertEqual(arthur.age!, 41)
            }
        }
    }
    
}
