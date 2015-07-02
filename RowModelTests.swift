//
//  RowModelTests.swift
//  GRDB
//
//  Created by Gwendal Roué on 01/07/2015.
//  Copyright © 2015 Gwendal Roué. All rights reserved.
//

import XCTest
import GRDB

class Person: RowModel {
    var ID: Int64?
    var name: String?
    var age: Int?
    
    override class var databaseTableName: String? {
        return "persons"
    }
    
    override class var databasePrimaryKey: PrimaryKey {
        return .SQLiteRowID("ID")
    }
    
    override var databaseDictionary: [String: DatabaseValue?] {
        return ["ID": ID, "name": name, "age": age]
    }
    
    override func updateFromDatabaseRow(row: Row) {
        if row.hasColumn("ID") { ID = row.value(named: "ID") }
        if row.hasColumn("name") { name = row.value(named: "name") }
        if row.hasColumn("age") { age = row.value(named: "age") }
    }
    
    init (name: String? = nil, age: Int? = nil) {
        self.name = name
        self.age = age
        super.init()
    }
    
    required init(row: Row) {
        super.init(row: row)
    }
}

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
    
    override var databaseDictionary: [String: DatabaseValue?] {
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
}

class PersonWithPet: Person {
    var petCount: Int?
    
    override func updateFromDatabaseRow(row: Row) {
        super.updateFromDatabaseRow(row)
        if row.hasColumn("petCount") { petCount = row.value(named: "petCount") }
    }
}

class Stuff: RowModel {
    var name: String?
    
    override class var databaseTableName: String? {
        return "stuffs"
    }
    
    override var databaseDictionary: [String: DatabaseValue?] {
        return ["name": name]
    }
    
    override func updateFromDatabaseRow(row: Row) {
        if row.hasColumn("name") { name = row.value(named: "name") }
    }
}

class Citizenship: RowModel {
    var personID: Int64?
    var countryName: String?
    
    override class var databaseTableName: String? {
        return "citizenships"
    }
    
    override class var databasePrimaryKey: PrimaryKey {
        return .Multiple(["personID", "countryName"])
    }
    
    override var databaseDictionary: [String: DatabaseValue?] {
        return ["personID": personID, "countryName": countryName]
    }
    
    override func updateFromDatabaseRow(row: Row) {
        if row.hasColumn("personID") { personID = row.value(named: "personID") }
        if row.hasColumn("countryName") { countryName = row.value(named: "countryName") }
    }
}

class RowModelTests: GRDBTests {
    override func setUp() {
        super.setUp()
        
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createPersons") { db in
            try db.execute(
                "CREATE TABLE persons (" +
                    "ID INTEGER PRIMARY KEY, " +
                    "name TEXT NOT NULL, " +
                    "age INT" +
                ")")
        }
        migrator.registerMigration("createPets") { db in
            try db.execute(
                "CREATE TABLE pets (" +
                    "UUID TEXT NOT NULL PRIMARY KEY, " +
                    "masterID INTEGER NOT NULL " +
                    "         REFERENCES persons(ID) " +
                    "         ON DELETE CASCADE ON UPDATE CASCADE, " +
                    "name TEXT" +
                ")")
        }
        migrator.registerMigration("createStuffs") { db in
            try db.execute(
                "CREATE TABLE stuffs (" +
                    "name NOT NULL" +
                ")")
        }
        migrator.registerMigration("createCitizenships") { db in
            try db.execute(
                "CREATE TABLE citizenships (" +
                    "personID INTEGER NOT NULL " +
                    "         REFERENCES persons(ID) " +
                    "         ON DELETE CASCADE ON UPDATE CASCADE, " +
                    "countryName TEXT NOT NULL, " +
                    "PRIMARY KEY (personID, countryName)" +
                ")")
        }
        assertNoError {
            try migrator.migrate(dbQueue)
        }
    }
    
    func testInsertRowModelWithSQLiteRowIDPrimaryKey() {
        // Models with SQLiteRowID primary key should be able to be inserted
        // with a nil primary key. After the insertion, they have their primary
        // key set.
        
        assertNoError {
            let arthur = Person(name: "Arthur", age: 41)
            
            XCTAssertTrue(arthur.ID == nil)
            try dbQueue.inTransaction { db in
                // The tested method
                try arthur.insert(db)

                // After insertion, ID should be set
                XCTAssertTrue(arthur.ID != nil)
                
                return .Commit
            }
            
            // After insertion, model should be present in the database
            dbQueue.inDatabase { db in
                let persons = db.fetchAllModels("SELECT * FROM persons ORDER BY name", type: Person.self)
                XCTAssertEqual(persons.count, 1)
                XCTAssertEqual(persons.first!.name!, "Arthur")
            }
        }
    }
    
    func testInsertTwiceRowModelWithSQLiteRowIDPrimaryKey() {
        // Models with SQLiteRowID primary key should be able to be inserted
        // with a nil primary key. After the insertion, they have their primary
        // key set.
        //
        // The second insertion should fail because the primary key is already
        // taken.
        
        assertNoError {
            let arthur = Person(name: "Arthur", age: 41)
            
            XCTAssertTrue(arthur.ID == nil)
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
    
    func testInsertRowModelWithNonePrimaryKey() {
        // Models with None primary key should be able to be inserted.
        
        assertNoError {
            let stuff = Stuff()
            stuff.name = "foo"
            
            try dbQueue.inTransaction { db in
                // The tested method
                try stuff.insert(db)
                
                return .Commit
            }
            
            // After insertion, model should be present in the database
            dbQueue.inDatabase { db in
                let stuffs = db.fetchAllModels("SELECT * FROM stuffs ORDER BY name", type: Stuff.self)
                XCTAssertEqual(stuffs.count, 1)
                XCTAssertEqual(stuffs.first!.name!, "foo")
            }
        }
    }
    
    func testInsertTwiceRowModelWithNonePrimaryKey() {
        // Models with None primary key should be able to be inserted.
        //
        // The second insertion simply inserts a second row.
        
        assertNoError {
            let stuff = Stuff()
            stuff.name = "foo"
            
            try dbQueue.inTransaction { db in
                // The tested method
                try stuff.insert(db)
                try stuff.insert(db)
                
                return .Commit
            }
            
            // After insertion, model should be present in the database
            dbQueue.inDatabase { db in
                let stuffs = db.fetchAllModels("SELECT * FROM stuffs ORDER BY name", type: Stuff.self)
                XCTAssertEqual(stuffs.count, 2)
                XCTAssertEqual(stuffs.first!.name!, "foo")
                XCTAssertEqual(stuffs.last!.name!, "foo")
            }
        }
    }
    
    func testInsertRowModelWithNonNilSinglePrimaryKey() {
        // Models with Single primary key should be able to be inserted when
        // their primary key is not nil.
        
        assertNoError {
            let arthur = Person(name: "Arthur", age: 41)
            
            try dbQueue.inTransaction { db in
                try arthur.insert(db)
                return .Commit
            }
            
            let pet = Pet(UUID: "BobbyID", name: "Bobby", masterID: arthur.ID)
            
            try dbQueue.inTransaction { db in
                // The tested method
                try pet.insert(db)
                
                // After insertion, primary key is still set
                XCTAssertEqual(pet.UUID!, "BobbyID")
                
                return .Commit
            }
            
            // After insertion, model should be present in the database
            dbQueue.inDatabase { db in
                let pets = db.fetchAllModels("SELECT * FROM pets ORDER BY name", type: Pet.self)
                XCTAssertEqual(pets.count, 1)
                XCTAssertEqual(pets.first!.UUID!, "BobbyID")
                XCTAssertEqual(pets.first!.name!, "Bobby")
            }
        }
    }
    
    func testInsertRowModelWithNilSinglePrimaryKey() {
        // Models with Single primary key should not be able to be inserted when
        // their primary key is nil.
        
        assertNoError {
            let arthur = Person(name: "Arthur", age: 41)
            
            try dbQueue.inTransaction { db in
                try arthur.insert(db)
                return .Commit
            }
            
            let pet = Pet(name: "Bobby", masterID: arthur.ID)
            
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
    
    func testInsertTwiceRowModelWithNonNilSinglePrimaryKey() {
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
            
            let pet = Pet(UUID: "BobbyID", name: "Bobby", masterID: arthur.ID)
            
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
    
    func testInsertRowModelWithMultiplePrimaryKey() {
        // Models with Multiple primary key should be able to be inserted when
        // their primary key is set.
        
        assertNoError {
            let arthur = Person(name: "Arthur", age: 41)
            
            try dbQueue.inTransaction { db in
                try arthur.insert(db)
                return .Commit
            }
            
            let citizenship = Citizenship()
            citizenship.personID = arthur.ID
            citizenship.countryName = "France"
            
            try dbQueue.inTransaction { db in
                // The tested method
                try citizenship.insert(db)
                
                // After insertion, primary key is still set
                XCTAssertEqual(citizenship.personID!, arthur.ID!)
                XCTAssertEqual(citizenship.countryName!, "France")
                
                return .Commit
            }
            
            // After insertion, model should be present in the database
            dbQueue.inDatabase { db in
                let citizenships = db.fetchAllModels("SELECT * FROM citizenships", type: Citizenship.self)
                XCTAssertEqual(citizenships.count, 1)
                XCTAssertEqual(citizenships.first!.personID!, arthur.ID!)
                XCTAssertEqual(citizenships.first!.countryName!, "France")
            }
        }
    }
    
    func testInsertTwiceRowModelWithMultiplePrimaryKey() {
        assertNoError {
            let arthur = Person(name: "Arthur", age: 41)
            
            try dbQueue.inTransaction { db in
                try arthur.insert(db)
                return .Commit
            }
            
            let citizenship = Citizenship()
            citizenship.personID = arthur.ID
            citizenship.countryName = "France"
            
            do {
                try dbQueue.inTransaction { db in
                    // The tested method
                    try citizenship.insert(db)
                    try citizenship.insert(db)
                    
                    return .Commit
                }
                XCTFail("Expected error")
            } catch is SQLiteError {
                // OK, this is expected
            }
        }
    }

    func testUpdateRowModelWithSQLiteRowIDPrimaryKey() {
        assertNoError {
            let arthur = Person(name: "Arthur", age: 41)
            
            XCTAssertTrue(arthur.ID == nil)
            try dbQueue.inTransaction { db in
                try arthur.insert(db)
                arthur.age = 42
                try arthur.update(db)   // The tested method
                return .Commit
            }
            
            dbQueue.inDatabase { db in
                let persons = db.fetchAllModels("SELECT * FROM persons ORDER BY name", type: Person.self)
                XCTAssertEqual(persons.count, 1)
                XCTAssertEqual(persons.first!.name!, "Arthur")
                XCTAssertEqual(persons.first!.age!, 42)
            }
        }
    }
    
    func testUpdateRowModelWithSinglePrimaryKey() {
        assertNoError {
            try dbQueue.inTransaction { db in
                let arthur = Person(name: "Arthur", age: 41)
                try arthur.insert(db)
                let pet = Pet(UUID: "BobbyID", name: "Bobby", masterID: arthur.ID)
                try pet.insert(db)
                
                pet.name = "Karl"
                try pet.update(db)  // The tested method
                return .Commit
            }
            
            // After insertion, model should be present in the database
            dbQueue.inDatabase { db in
                let pets = db.fetchAllModels("SELECT * FROM pets ORDER BY name", type: Pet.self)
                XCTAssertEqual(pets.count, 1)
                XCTAssertEqual(pets.first!.UUID!, "BobbyID")
                XCTAssertEqual(pets.first!.name!, "Karl")
            }
        }
    }
    
    func testSelect() {
        assertNoError {
            try dbQueue.inTransaction { db in
                try Person(name: "Arthur", age: 41).insert(db)
                try Person(name: "Barbara", age: 36).insert(db)
                return .Commit
            }
            
            dbQueue.inDatabase { db in
                let persons = db.fetchAllModels("SELECT * FROM persons ORDER BY name", type: Person.self)
                let arthur = db.fetchOneModel("SELECT * FROM persons ORDER BY age DESC", type: Person.self)!
                
                XCTAssertEqual(persons.map { $0.name! }, ["Arthur", "Barbara"])
                XCTAssertEqual(persons.map { $0.age! }, [41, 36])
                XCTAssertEqual(arthur.name!, "Arthur")
                XCTAssertEqual(arthur.age!, 41)
            }
        }
    }
    
    func testSelectOneRowModelWithSQLiteRowIDPrimaryKey() {
        assertNoError {
            var arthurID: Int64? = nil
            try dbQueue.inTransaction { db in
                let arthur = Person(name: "Arthur", age: 41)
                try arthur.insert(db)
                arthurID = arthur.ID
                return .Commit
            }
            
            dbQueue.inDatabase { db in
                let arthur = db.fetchOneModel(primaryKey: arthurID!, type: Person.self)!
                
                XCTAssertEqual(arthur.ID!, arthurID!)
                XCTAssertEqual(arthur.name!, "Arthur")
                XCTAssertEqual(arthur.age!, 41)
            }
        }
    }
    
    func testSelectOneRowModelWithSinglePrimaryKey() {
        assertNoError {
            let petUUID = "BobbyID"
            
            try dbQueue.inTransaction { db in
                let arthur = Person(name: "Arthur", age: 41)
                try arthur.insert(db)

                let pet = Pet(UUID: "BobbyID", name: "Bobby", masterID: arthur.ID)
                try pet.insert(db)
                
                return .Commit
            }
            
            
            dbQueue.inDatabase { db in
                let pet = db.fetchOneModel(primaryKey: petUUID, type: Pet.self)!
                
                XCTAssertEqual(pet.UUID!, petUUID)
                XCTAssertEqual(pet.name!, "Bobby")
            }
        }
    }
}
