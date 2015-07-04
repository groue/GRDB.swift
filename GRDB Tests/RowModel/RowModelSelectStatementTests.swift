//
//  RowModelSelectStatementTests.swift
//  GRDB
//
//  Created by Gwendal Roué on 04/07/2015.
//  Copyright © 2015 Gwendal Roué. All rights reserved.
//

import XCTest

class RowModelSelectStatementTests: RowModelTests {
    
    func testBlah() {
        assertNoError {
            try dbQueue.inTransaction { db in
                try Person(name: "Arthur", age: 41).insert(db)
                try Person(name: "Barbara", age: 37).insert(db)
                return .Commit
            }
            
            try dbQueue.inDatabase { db in
                let statement = try db.selectStatement("SELECT * FROM persons WHERE name = ?")
                
                for name in ["Arthur", "Barbara"] {
                    let person = statement.fetchOne(Person.self, bindings: [name])!
                    XCTAssertEqual(person.name!, name)
                }
            }
        }
    }
}
