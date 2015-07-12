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

// Pet has a non-RowID primary key, and a reference to Person.
class Pet: RowModel {
    var UUID: String?
    var masterID: Int64?
    var name: String?
    
    override class var databaseTable: Table? {
        return Table(named: "pets", primaryKey: .Column("UUID"))
    }
    
    override var storedDatabaseDictionary: [String: DatabaseValueConvertible?] {
        return [
            "UUID": UUID,
            "name": name,
            "masterID": masterID]
    }
    
    override func setDatabaseValue(dbv: DatabaseValue, forColumn column: String) {
        switch column {
        case "UUID":        UUID = dbv.value()
        case "name":        name = dbv.value()
        case "masterID":    masterID = dbv.value()
        default:            super.setDatabaseValue(dbv, forColumn: column)
        }
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

class PrimaryKeySingleTests: RowModelTestCase {
    
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
            } catch is DatabaseError {
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
            } catch is DatabaseError {
                // OK, this is expected
            }
        }
    }
    
    func testUpdate() {
        assertNoError {
            try dbQueue.inTransaction { db in
                let arthur = Person(name: "Arthur", age: 41)
                try arthur.insert(db)
                
                var pet = Pet(UUID: "BobbyID", name: "Bobby", masterID: arthur.id)
                try pet.insert(db)
                
                pet.name = "Karl"
                try pet.update(db)          // object still in database
                
                pet = db.fetchOne(Pet.self, primaryKey: pet.UUID!)!
                XCTAssertEqual(pet.name!, "Karl")
                
                try pet.delete(db)
                do {
                    try pet.update(db)      // object no longer in database
                    XCTFail("Expected RowModelError.RowModelNotFound")
                } catch RowModelError.RowModelNotFound {
                } catch {
                    XCTFail("Expected RowModelError.RowModelNotFound, not \(error)")
                }
                
                return .Commit
            }
        }
    }
    
    func testSave() {
        assertNoError {
            let person = Person(name: "Arthur", age: 41)
            try dbQueue.inTransaction { db in
                try person.insert(db)
                return .Commit
            }
            
            let pet = Pet(UUID: "BobbyID", name: "Bobby", masterID: person.id)
            
            try dbQueue.inTransaction { db in
                try pet.save(db)       // insert
                let petCount = db.fetchOne(Int.self, "SELECT COUNT(*) FROM pets")!
                XCTAssertEqual(petCount, 1)
                return .Commit
            }
            
            try dbQueue.inTransaction { db in
                try pet.save(db)       // update
                let petCount = db.fetchOne(Int.self, "SELECT COUNT(*) FROM pets")!
                XCTAssertEqual(petCount, 1)
                return .Commit
            }
            
            try dbQueue.inDatabase { db in
                try pet.delete(db)
                try pet.save(db)       // inserts
                let petCount = db.fetchOne(Int.self, "SELECT COUNT(*) FROM pets")!
                XCTAssertEqual(petCount, 1)
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
    
    func testSelectWithKey() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let arthur = Person(name: "Arthur", age: 41)
                try arthur.insert(db)
                
                let uuid = "BobbyID"
                var pet = Pet(UUID: uuid, name: "Bobby", masterID: arthur.id)
                try pet.insert(db)

                pet = db.fetchOne(Pet.self, key: ["name": "Bobby"])!   // The tested method
                XCTAssertEqual(pet.UUID!, uuid)
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
    
    func testReload() {
        assertNoError {
            try dbQueue.inTransaction { db in
                let arthur = Person(name: "Arthur", age: 41)
                try arthur.insert(db)
                
                let bobby = Pet(UUID: "BobbyID", name: "Bobby", masterID: arthur.id)
                try bobby.insert(db)
                
                bobby.name = "Karl"
                XCTAssertEqual(bobby.name!, "Karl")
                try bobby.reload(db)                    // object still in database
                XCTAssertEqual(bobby.name!, "Bobby")
                
                try bobby.delete(db)
                
                bobby.name = "Karl"
                XCTAssertEqual(bobby.name!, "Karl")
                do {
                    try bobby.reload(db)                // object no longer in database
                    XCTFail("Expected RowModelError.RowModelNotFound")
                } catch RowModelError.RowModelNotFound {
                } catch {
                    XCTFail("Expected RowModelError.RowModelNotFound, not \(error)")
                }
                XCTAssertEqual(bobby.name!, "Karl")
                
                return .Commit
            }
        }
    }
}
