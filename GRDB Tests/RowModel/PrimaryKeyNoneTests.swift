//
//  PrimaryKeyNoneTests.swift
//  GRDB
//
//  Created by Gwendal Roué on 03/07/2015.
//  Copyright © 2015 Gwendal Roué. All rights reserved.
//

import XCTest
import GRDB

class Item: RowModel {
    var name: String?
    
    override class var databaseTableName: String? {
        return "items"
    }
    
    override var databaseDictionary: [String: DatabaseValue?] {
        return ["name": name]
    }
    
    override func updateFromDatabaseRow(row: Row) {
        if row.hasColumn("name") { name = row.value(named: "name") }
    }
    
    static func setupInDatabase(db: Database) throws {
        try db.execute(
            "CREATE TABLE items (" +
                "name NOT NULL" +
            ")")
    }
}

class PrimaryKeyNoneTests: RowModelTests {

    func testInsert() {
        // Models with None primary key should be able to be inserted.
        
        assertNoError {
            let item = Item()
            item.name = "foo"
            
            try dbQueue.inTransaction { db in
                // The tested method
                try item.insert(db)
                
                return .Commit
            }
            
            // After insertion, model should be present in the database
            dbQueue.inDatabase { db in
                let items = db.fetchAll(Item.self, "SELECT * FROM items ORDER BY name")
                XCTAssertEqual(items.count, 1)
                XCTAssertEqual(items.first!.name!, "foo")
            }
        }
    }
    
    func testInsertTwice() {
        // Models with None primary key should be able to be inserted.
        //
        // The second insertion simply inserts a second row.
        
        assertNoError {
            let item = Item()
            item.name = "foo"
            
            try dbQueue.inTransaction { db in
                // The tested method
                try item.insert(db)
                try item.insert(db)
                
                return .Commit
            }
            
            // After insertion, model should be present in the database
            dbQueue.inDatabase { db in
                let items = db.fetchAll(Item.self, "SELECT * FROM items ORDER BY name")
                XCTAssertEqual(items.count, 2)
                XCTAssertEqual(items.first!.name!, "foo")
                XCTAssertEqual(items.last!.name!, "foo")
            }
        }
    }
    
}
