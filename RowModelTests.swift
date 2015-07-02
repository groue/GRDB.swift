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

    override var tableName: String? {
        return "persons"
    }
    
    override var databaseDictionary : [String: DatabaseValue?] {
        return ["name": name, "age": age]
    }
    
    override var databasePrimaryKey : [String: DatabaseValue?] {
        return ["ID": ID]
    }
    
    override func updateFromDatabaseRow(row: Row) {
        if row.hasColumn("ID") { ID = row.value(named: "ID") }
        if row.hasColumn("name") { name = row.value(named: "name") }
        if row.hasColumn("age") { age = row.value(named: "age") }
    }
}

class Pet: RowModel {
    var ID: Int64?
    var masterID: Int64?
    var name: String?
    
    override var tableName: String? {
        return "pets"
    }
    
    override var databaseDictionary : [String: DatabaseValue?] {
        return ["name": name, "masterID": masterID]
    }
    
    override var databasePrimaryKey : [String: DatabaseValue?] {
        return ["ID": ID]
    }
    
    override func updateFromDatabaseRow(row: Row) {
        if row.hasColumn("ID") { ID = row.value(named: "ID") }
        if row.hasColumn("name") { name = row.value(named: "name") }
        if row.hasColumn("masterID") { masterID = row.value(named: "masterID") }
    }
}

class PersonWithPet: Person {
    var petCount: Int?
    
    override func updateFromDatabaseRow(row: Row) {
        super.updateFromDatabaseRow(row)
        if row.hasColumn("petCount") { petCount = row.value(named: "petCount") }
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
                "age INT)")
        }
        migrator.registerMigration("createPets") { db in
            try db.execute(
                "CREATE TABLE pets (" +
                    "ID INTEGER PRIMARY KEY, " +
                    "masterID INTEGER NOT NULL " +
                    "         REFERENCES persons(ID) " +
                    "         ON DELETE CASCADE ON UPDATE CASCADE, " +
                "name TEXT)")
        }
        try! migrator.migrate(dbQueue)
    }
    
    func testInsert() {
        assertNoError {
            let arthur = Person()
            arthur.name = "Arthur"
            arthur.age = 41
            
            XCTAssertTrue(arthur.ID == nil)
            try dbQueue.inTransaction { db in
                try arthur.insert(db)
                return .Commit
            }
            XCTAssertTrue(arthur.ID != nil)
        }
    }
    
    func testInsertTwiceBreaksUniqueIndex() {
        assertNoError {
            let arthur = Person()
            arthur.name = "Arthur"
            arthur.age = 41
            
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
}
