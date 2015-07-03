//
//  DatabaseEnumTests.swift
//  GRDB
//
//  Created by Gwendal Roué on 03/07/2015.
//  Copyright © 2015 Gwendal Roué. All rights reserved.
//

import XCTest
import GRDB

enum Color: Int {   // A raw underlying type is required
    case Red
    case White
    case Rose
}

class DatabaseEnumTests: GRDBTests {
    
    override func setUp() {
        super.setUp()
        
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createWines") { db in
            try db.execute(
                "CREATE TABLE wines (color INTEGER)")
        }
        assertNoError {
            try migrator.migrate(dbQueue)
        }
    }
    
    func testDatabaseEnum() {
        assertNoError {
            try dbQueue.inTransaction { db in
                
                try db.execute("INSERT INTO wines (color) VALUES (?)", bindings: [DatabaseEnum(Color.Red)])
                try db.execute("INSERT INTO wines (color) VALUES (?)", bindings: [DatabaseEnum(Color.White)])
                try db.execute("INSERT INTO wines (color) VALUES (?)", bindings: [DatabaseEnum(Color.Rose)])
                try db.execute("INSERT INTO wines (color) VALUES (?)", bindings: [3])
                
                return .Commit
            }
            
            dbQueue.inDatabase { db in
                let row = db.fetchOneRow("SELECT color FROM wines ORDER BY color LIMIT 1")!
                let dbColor: DatabaseEnum<Color> = row.value(named: "color")!
                let color = dbColor.value
                XCTAssertEqual(color, Color.Red)
                
                let colors = db.fetchAll(DatabaseEnum<Color>.self, "SELECT color FROM wines ORDER BY color").map { $0?.value }
                XCTAssertEqual(colors.count, 4)
                XCTAssertEqual(colors[0]!, Color.Red)
                XCTAssertEqual(colors[1]!, Color.White)
                XCTAssertEqual(colors[2]!, Color.Rose)
                XCTAssertTrue(colors[3] == nil)
            }
        }
    }
}

