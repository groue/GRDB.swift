//
//  DatabaseMigratorTests.swift
//  GRDB
//
//  Created by Gwendal Roué on 01/07/2015.
//  Copyright © 2015 Gwendal Roué. All rights reserved.
//

import XCTest
import GRDB

class DatabaseMigratorTests: GRDBTests {
    
    func testMigrator() {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createPersons") { db in
            try db.execute(
                "CREATE TABLE persons (" +
                "id INTEGER PRIMARY KEY, " +
                "name TEXT)")
        }
        migrator.registerMigration("createPets") { db in
            try db.execute(
                "CREATE TABLE pets (" +
                "id INTEGER PRIMARY KEY, " +
                "masterID INTEGER NOT NULL " +
                "         REFERENCES persons(id) " +
                "         ON DELETE CASCADE ON UPDATE CASCADE, " +
                "name TEXT)")
        }
        
        assertNoError {
            try migrator.migrate(dbQueue)
            dbQueue.inDatabase { db in
                XCTAssertTrue(db.tableExists("persons"))
                XCTAssertTrue(db.tableExists("pets"))
            }
        }
        
        migrator.registerMigration("destroyPersons") { db in
            try db.execute("DROP TABLE pets")
        }
        
        assertNoError {
            try migrator.migrate(dbQueue)
            dbQueue.inDatabase { db in
                XCTAssertTrue(db.tableExists("persons"))
                XCTAssertFalse(db.tableExists("pets"))
            }
        }
    }
    
    func testMigrationFailureTriggersRollback() {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createPersons") { db in
            try db.execute("CREATE TABLE persons (name TEXT)")
            try db.execute("INSERT INTO persons (name) VALUES ('Arthur')")
        }
        migrator.registerMigration("destroyPersonErroneous") { db in
            try db.execute("DELETE FROM persons")
            try db.execute("I like cookies.")
        }
        
        do {
            try migrator.migrate(dbQueue)
        } catch {
            // The first migration should be committed.
            // The second migration should be rollbacked.
            let names = dbQueue.inDatabase { db in
                db.fetch("SELECT * FROM persons", type: String.self).map { $0! }
            }
            XCTAssertEqual(names, ["Arthur"])
        }
    }
}
