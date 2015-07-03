//
//  RowModelSubClassTests.swift
//  GRDB
//
//  Created by Gwendal Roué on 03/07/2015.
//  Copyright © 2015 Gwendal Roué. All rights reserved.
//

import XCTest
import GRDB

class PersonWithPet: Person {
    var petCount: Int?
    
    override func updateFromDatabaseRow(row: Row) {
        super.updateFromDatabaseRow(row)
        if row.hasColumn("petCount") { petCount = row.value(named: "petCount") }
    }
}

class RowModelSubClassTests: RowModelTests {
    
    func testSelect() {
        assertNoError {
            try dbQueue.inTransaction { db in
                try Person(name: "Arthur", age: 41).insert(db)
                try Person(name: "Barbara", age: 36).insert(db)
                return .Commit
            }
            
            dbQueue.inDatabase { db in
                let persons = db.fetchAll(Person.self, "SELECT * FROM persons ORDER BY name")
                let arthur = db.fetchOne(Person.self, "SELECT * FROM persons ORDER BY age DESC")!
                
                XCTAssertEqual(persons.map { $0.name! }, ["Arthur", "Barbara"])
                XCTAssertEqual(persons.map { $0.age! }, [41, 36])
                XCTAssertEqual(arthur.name!, "Arthur")
                XCTAssertEqual(arthur.age!, 41)
            }
        }
    }
    
}
