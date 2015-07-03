//
//  PrimaryKeySingleTests.swift
//  GRDB
//
//  Created by Gwendal Roué on 03/07/2015.
//  Copyright © 2015 Gwendal Roué. All rights reserved.
//

import XCTest
import GRDB

class Pet: RowModel {
    var UUID: String?
    var masterID: Int64?
    var name: String?
    
    override class var databaseTableName: String? {
        return "pets"
    }
    
    override class var databasePrimaryKey: PrimaryKey {
        return .Single("UUID")
    }
    
    override var databaseDictionary: [String: DatabaseValueType?] {
        return ["UUID": UUID, "name": name, "masterID": masterID]
    }
    
    override func updateFromDatabaseRow(row: Row) {
        if row.hasColumn("UUID") { UUID = row.value(named: "UUID") }
        if row.hasColumn("name") { name = row.value(named: "name") }
        if row.hasColumn("masterID") { masterID = row.value(named: "masterID") }
    }
    
    init (UUID: String? = nil, name: String? = nil, masterID: Int64? = nil) {
        self.UUID = UUID
        self.name = name
        self.masterID = masterID
        super.init()
    }
    
    required init(row: Row) {
        super.init(row: row)
    }
    
    static func setupInDatabase(db: Database) throws {
        try db.execute(
            "CREATE TABLE pets (" +
                "UUID TEXT NOT NULL PRIMARY KEY, " +
                "masterID INTEGER NOT NULL " +
                "         REFERENCES persons(ID) " +
                "         ON DELETE CASCADE ON UPDATE CASCADE, " +
                "name TEXT" +
            ")")
    }
}

class PrimaryKeySingleTests: RowModelTests {
    
    func testInsertWithNonNilPrimaryKey() {
        // Models with Single primary key should be able to be inserted when
        // their primary key is not nil.
        
        assertNoError {
            let arthur = Person(name: "Arthur", age: 41)
            
            try dbQueue.inTransaction { db in
                try arthur.insert(db)
                return .Commit
            }
            
            let pet = Pet(UUID: "BobbyID", name: "Bobby", masterID: arthur.id)
            
            try dbQueue.inTransaction { db in
                // The tested method
                try pet.insert(db)
                
                // After insertion, primary key is still set
                XCTAssertEqual(pet.UUID!, "BobbyID")
                
                return .Commit
            }
            
            // After insertion, model should be present in the database
            dbQueue.inDatabase { db in
                let pets = db.fetchAll(Pet.self, "SELECT * FROM pets ORDER BY name")
                XCTAssertEqual(pets.count, 1)
                XCTAssertEqual(pets.first!.UUID!, "BobbyID")
                XCTAssertEqual(pets.first!.name!, "Bobby")
            }
        }
    }
    
    func testInsertWithNilPrimaryKey() {
        // Models with Single primary key should not be able to be inserted when
        // their primary key is nil.
        
        assertNoError {
            let arthur = Person(name: "Arthur", age: 41)
            
            try dbQueue.inTransaction { db in
                try arthur.insert(db)
                return .Commit
            }
            
            let pet = Pet(name: "Bobby", masterID: arthur.id)
            
            do {
                try dbQueue.inTransaction { db in
                    // The tested method
                    try pet.insert(db)
                    return .Commit
                }
                XCTFail("Expected error")
            } catch is SQLiteError {
                // OK, this is expected
            }
        }
    }
    
    func testInsertTwice() {
        // Models with Single primary key should be able to be inserted when
        // their primary key is not nil.
        //
        // The second insertion should fail because the primary key is already
        // taken.
        
        assertNoError {
            let arthur = Person(name: "Arthur", age: 41)
            
            try dbQueue.inTransaction { db in
                try arthur.insert(db)
                return .Commit
            }
            
            let pet = Pet(UUID: "BobbyID", name: "Bobby", masterID: arthur.id)
            
            do {
                try dbQueue.inTransaction { db in
                    // The tested method
                    try pet.insert(db)
                    try pet.insert(db)
                    
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
            try dbQueue.inTransaction { db in
                let arthur = Person(name: "Arthur", age: 41)
                try arthur.insert(db)
                let pet = Pet(UUID: "BobbyID", name: "Bobby", masterID: arthur.id)
                try pet.insert(db)
                
                pet.name = "Karl"
                try pet.update(db)  // The tested method
                return .Commit
            }
            
            // After insertion, model should be present in the database
            dbQueue.inDatabase { db in
                let pets = db.fetchAll(Pet.self, "SELECT * FROM pets ORDER BY name")
                XCTAssertEqual(pets.count, 1)
                XCTAssertEqual(pets.first!.UUID!, "BobbyID")
                XCTAssertEqual(pets.first!.name!, "Karl")
            }
        }
    }
    
    func testSelectWithPrimaryKey() {
        assertNoError {
            let petUUID = "BobbyID"
            
            try dbQueue.inTransaction { db in
                let arthur = Person(name: "Arthur", age: 41)
                try arthur.insert(db)
                
                let pet = Pet(UUID: "BobbyID", name: "Bobby", masterID: arthur.id)
                try pet.insert(db)
                
                return .Commit
            }
            
            
            dbQueue.inDatabase { db in
                let pet = db.fetchOne(Pet.self, primaryKey: petUUID)!   // The tested method
                
                XCTAssertEqual(pet.UUID!, petUUID)
                XCTAssertEqual(pet.name!, "Bobby")
            }
        }
    }
    
    func testSelectWithDictionaryBindings() {
        assertNoError {
            let petUUID = "BobbyID"
            
            try dbQueue.inTransaction { db in
                let arthur = Person(name: "Arthur", age: 41)
                try arthur.insert(db)
                
                let pet = Pet(UUID: "BobbyID", name: "Bobby", masterID: arthur.id)
                try pet.insert(db)
                
                return .Commit
            }
            
            
            dbQueue.inDatabase { db in
                let pet = db.fetchOne(Pet.self, bindings: ["UUID": petUUID])!   // The tested method
                
                XCTAssertEqual(pet.UUID!, petUUID)
                XCTAssertEqual(pet.name!, "Bobby")
            }
        }
    }
    
    func testSelectWithArrayBindings() {
        assertNoError {
            let petUUID = "BobbyID"
            
            try dbQueue.inTransaction { db in
                let arthur = Person(name: "Arthur", age: 41)
                try arthur.insert(db)
                
                let pet = Pet(UUID: "BobbyID", name: "Bobby", masterID: arthur.id)
                try pet.insert(db)
                
                return .Commit
            }
            
            
            dbQueue.inDatabase { db in
                let pet = db.fetchOne(Pet.self, bindings: [petUUID])!   // The tested method
                
                XCTAssertEqual(pet.UUID!, petUUID)
                XCTAssertEqual(pet.name!, "Bobby")
            }
        }
    }
    
    func testDelete() {
        assertNoError {
            try dbQueue.inTransaction { db in
                let arthur = Person(name: "Arthur", age: 41)
                try arthur.insert(db)
                
                let bobby = Pet(UUID: "BobbyID", name: "Bobby", masterID: arthur.id)
                try bobby.insert(db)
                
                let karl = Pet(UUID: "KarlID", name: "Karl", masterID: arthur.id)
                try karl.insert(db)
                
                try bobby.delete(db)   // The tested method
                
                return .Commit
            }
            
            dbQueue.inDatabase { db in
                let pets = db.fetchAll(Pet.self, "SELECT * FROM pets ORDER BY name")
                XCTAssertEqual(pets.count, 1)
                XCTAssertEqual(pets.first!.name!, "Karl")
            }
        }
    }
}
