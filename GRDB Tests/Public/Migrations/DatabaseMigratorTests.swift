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
            try db.execute("CREATE TABLE persons (id INTEGER PRIMARY KEY, name TEXT)")
            try db.execute("CREATE TABLE pets (masterId INTEGER NOT NULL REFERENCES persons(id), name TEXT)")
            try db.execute("INSERT INTO persons (name) VALUES ('Arthur')")
        }
        migrator.registerMigration("foreignKeyError") { db in
            try db.execute("INSERT INTO persons (name) VALUES ('Barbara')")
            do {
                // triggers immediate foreign key error:
                try db.execute("INSERT INTO pets (masterId, name) VALUES (?, ?)", arguments: [123, "Bobby"])
                XCTFail("Expected error")
            } catch {
                throw error
            }
        }
        
        do {
            try migrator.migrate(dbQueue)
            XCTFail("Expected error")
        } catch {
            // The first migration should be committed.
            // The second migration should be rollbacked.
            let names = dbQueue.inDatabase { db in
                String.fetchAll(db, "SELECT name FROM persons")
            }
            XCTAssertEqual(names, ["Arthur"])
        }
    }
    
    func testMigrationWithoutForeignKeyChecks() {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createPersons") { db in
            try db.execute("CREATE TABLE persons (id INTEGER PRIMARY KEY, name TEXT, tmp TEXT)")
            try db.execute("CREATE TABLE pets (masterId INTEGER NOT NULL REFERENCES persons(id), name TEXT)")
            let personId = try db.execute("INSERT INTO persons (name) VALUES ('Arthur')").insertedRowID
            try db.execute("INSERT INTO pets (masterId, name) VALUES (?, 'Bobby')", arguments:[personId])
        }
        migrator.registerMigrationWithoutForeignKeyChecks("removePersonTmpColumn") { db in
            // Test the technique described at https://www.sqlite.org/lang_altertable.html#otheralter
            try db.execute("CREATE TABLE new_persons (id INTEGER PRIMARY KEY, name TEXT)")
            try db.execute("INSERT INTO new_persons SELECT id, name FROM persons")
            try db.execute("DROP TABLE persons")
            try db.execute("ALTER TABLE new_persons RENAME TO persons")
        }
        migrator.registerMigrationWithoutForeignKeyChecks("foreignKeyError") { db in
            // Make sure foreign keys are checked at the end.
            try db.execute("INSERT INTO persons (name) VALUES ('Barbara')")
            do {
                // triggers foreign key error, but not now.
                try db.execute("INSERT INTO pets (masterId, name) VALUES (?, ?)", arguments: [123, "Bobby"])
            } catch {
                XCTFail("Error not expected at this point")
            }
        }
        
        do {
            try migrator.migrate(dbQueue)
            XCTFail("Expected error")
        } catch {
            // Migration 1 and 2 should be committed.
            // Migration 3 should not be committed.
            
            // Arthur inserted (migration 1), Barbara (migration 3) not inserted.
            let rows = dbQueue.inDatabase { db in
                Row.fetchAll(db, "SELECT * FROM persons")
            }
            XCTAssertEqual(rows.count, 1)
            let row = rows.first!
            XCTAssertEqual(row.value(named: "name") as String, "Arthur")
            
            // persons table has no "tmp" column (migration 2)
            XCTAssertEqual(Array(row.columnNames), ["id", "name"])
        }
    }
}
