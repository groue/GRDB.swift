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
        migrator.registerMigration("destroyPersonErroneous") { db in
            try db.execute("INSERT INTO persons (name) VALUES ('Barbara')")
            try db.execute("INSERT INTO pets (masterId, name) VALUES (?, ?)", arguments: [123, "Bobby"])
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
}
