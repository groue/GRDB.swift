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

class DatabaseMigratorTests : GRDBTestCase {
    
    func testMigrator() {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createPersons") { db in
            try db.execute(
                "CREATE TABLE persons (" +
                    "id INTEGER PRIMARY KEY, " +
                    "name TEXT" +
                ")")
        }
        migrator.registerMigration("createPets") { db in
            try db.execute(
                "CREATE TABLE pets (" +
                    "id INTEGER PRIMARY KEY, " +
                    "masterID INTEGER NOT NULL " +
                    "         REFERENCES persons(id) " +
                    "         ON DELETE CASCADE ON UPDATE CASCADE, " +
                    "name TEXT" +
                ")")
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
                String.fetch(db, "SELECT * FROM persons").map { $0! }
            }
            XCTAssertEqual(names, ["Arthur"])
        }
    }
}
