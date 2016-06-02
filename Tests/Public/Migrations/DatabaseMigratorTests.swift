import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class DatabaseMigratorTests : GRDBTestCase {
    
    func testMigratorDatabaseQueue() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            
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
            
            try migrator.migrate(dbQueue)
            dbQueue.inDatabase { db in
                XCTAssertTrue(db.tableExists("persons"))
                XCTAssertTrue(db.tableExists("pets"))
            }
            
            migrator.registerMigration("destroyPersons") { db in
                try db.execute("DROP TABLE pets")
            }
            
            try migrator.migrate(dbQueue)
            dbQueue.inDatabase { db in
                XCTAssertTrue(db.tableExists("persons"))
                XCTAssertFalse(db.tableExists("pets"))
            }
        }
    }
    
    func testMigratorDatabasePool() {
        assertNoError {
            let dbPool = try makeDatabasePool()
            
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
            
            try migrator.migrate(dbPool)
            dbPool.read { db in
                XCTAssertTrue(db.tableExists("persons"))
                XCTAssertTrue(db.tableExists("pets"))
            }
            
            migrator.registerMigration("destroyPersons") { db in
                try db.execute("DROP TABLE pets")
            }
            
            try migrator.migrate(dbPool)
            dbPool.read { db in
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
        
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            do {
                try migrator.migrate(dbQueue)
                XCTFail("Expected error")
            } catch let error as DatabaseError {
                // The first migration should be committed.
                // The second migration should be rollbacked.
                
                XCTAssertEqual(error.code, 19) // SQLITE_CONSTRAINT
                XCTAssertEqual(error.message!.lowercased(), "foreign key constraint failed") // lowercased: accept multiple SQLite version
                XCTAssertEqual(error.sql!, "INSERT INTO pets (masterId, name) VALUES (?, ?)")
                XCTAssertEqual(error.description.lowercased(), "sqlite error 19 with statement `insert into pets (masterid, name) values (?, ?)` arguments [123, \"bobby\"]: foreign key constraint failed")

                let names = dbQueue.inDatabase { db in
                    String.fetchAll(db, "SELECT name FROM persons")
                }
                XCTAssertEqual(names, ["Arthur"])
            }
        }
    }
    
    func testMigrationWithoutForeignKeyChecks() {
        // Advanced migration are not available until iOS 8.2 and OSX 10.10
        guard #available(iOS 8.2, OSX 10.10, *) else {
            return
        }
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createPersons") { db in
            try db.execute("CREATE TABLE persons (id INTEGER PRIMARY KEY, name TEXT, tmp TEXT)")
            try db.execute("CREATE TABLE pets (masterId INTEGER NOT NULL REFERENCES persons(id), name TEXT)")
            try db.execute("INSERT INTO persons (name) VALUES ('Arthur')")
            let personId = db.lastInsertedRowID
            try db.execute("INSERT INTO pets (masterId, name) VALUES (?, 'Bobby')", arguments:[personId])
        }
        migrator.registerMigrationWithDisabledForeignKeyChecks("removePersonTmpColumn") { db in
            // Test the technique described at https://www.sqlite.org/lang_altertable.html#otheralter
            try db.execute("CREATE TABLE new_persons (id INTEGER PRIMARY KEY, name TEXT)")
            try db.execute("INSERT INTO new_persons SELECT id, name FROM persons")
            try db.execute("DROP TABLE persons")
            try db.execute("ALTER TABLE new_persons RENAME TO persons")
        }
        migrator.registerMigrationWithDisabledForeignKeyChecks("foreignKeyError") { db in
            // Make sure foreign keys are checked at the end.
            try db.execute("INSERT INTO persons (name) VALUES ('Barbara')")
            do {
                // triggers foreign key error, but not now.
                try db.execute("INSERT INTO pets (masterId, name) VALUES (?, ?)", arguments: [123, "Bobby"])
            } catch {
                XCTFail("Error not expected at this point")
            }
        }
        
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            do {
                try migrator.migrate(dbQueue)
                XCTFail("Expected error")
            } catch let error as DatabaseError {
                // Migration 1 and 2 should be committed.
                // Migration 3 should not be committed.
                
                XCTAssertEqual(error.code, 19) // SQLITE_CONSTRAINT
                XCTAssertEqual(error.message!, "FOREIGN KEY constraint failed")
                XCTAssertTrue(error.sql == nil)
                XCTAssertEqual(error.description, "SQLite error 19: FOREIGN KEY constraint failed")
                
                dbQueue.inDatabase { db in
                    // Arthur inserted (migration 1), Barbara (migration 3) not inserted.
                    var rows = Row.fetchAll(db, "SELECT * FROM persons")
                    XCTAssertEqual(rows.count, 1)
                    var row = rows.first!
                    XCTAssertEqual(row.value(named: "name") as String, "Arthur")
                    
                    // persons table has no "tmp" column (migration 2)
                    XCTAssertEqual(Array(row.columnNames), ["id", "name"])
                    
                    // Bobby inserted (migration 1), not deleted by migration 2.
                    rows = Row.fetchAll(db, "SELECT * FROM pets")
                    XCTAssertEqual(rows.count, 1)
                    row = rows.first!
                    XCTAssertEqual(row.value(named: "name") as String, "Bobby")
                }
            }
        }
    }
}
