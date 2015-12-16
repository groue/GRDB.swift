//
//  FetchedRecordsControllerTests.swift
//  GRDB
//
//  Created by Pascal Edmond on 16/12/2015.
//  Copyright © 2015 Gwendal Roué. All rights reserved.
//

import XCTest

class FetchedRecordsControllerTests: GRDBTestCase {
    
    override func setUp() {
        super.setUp()
        
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createPersons") { db in
            try db.execute(
                "CREATE TABLE persons (" +
                    "id INTEGER PRIMARY KEY, " +
                    "firstName TEXT, " +
                    "lastName TEXT " +
                ")")
        }
        migrator.registerMigration("addPersons") { db in
            try Person(firstName: "Arthur", lastName: "Miller").insert(db)
            try Person(firstName: "Barbara", lastName: "Streisand").insert(db)
            try Person(firstName: "Cinderella").insert(db)
        }
        try! migrator.migrate(dbQueue)
    }
    
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measureBlock {
            // Put the code you want to measure the time of here.
        }
    }
    
}
