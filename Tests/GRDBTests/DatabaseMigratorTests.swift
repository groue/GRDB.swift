import XCTest
#if GRDBCIPHER
    import GRDBCipher
#elseif GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class DatabaseMigratorTests : GRDBTestCase {
    
    func testMigratorDatabaseQueue() throws {
        let dbQueue = try makeDatabaseQueue()
        
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createPersons") { db in
            try db.execute("""
                CREATE TABLE persons (
                    id INTEGER PRIMARY KEY,
                    name TEXT)
                """)
        }
        migrator.registerMigration("createPets") { db in
            try db.execute("""
                CREATE TABLE pets (
                    id INTEGER PRIMARY KEY,
                    masterID INTEGER NOT NULL
                             REFERENCES persons(id)
                             ON DELETE CASCADE ON UPDATE CASCADE,
                    name TEXT)
                """)
        }
        
        try migrator.migrate(dbQueue)
        try dbQueue.inDatabase { db in
            XCTAssertTrue(try db.tableExists("persons"))
            XCTAssertTrue(try db.tableExists("pets"))
        }
        
        migrator.registerMigration("destroyPersons") { db in
            try db.execute("DROP TABLE pets")
        }
        
        try migrator.migrate(dbQueue)
        try dbQueue.inDatabase { db in
            XCTAssertTrue(try db.tableExists("persons"))
            XCTAssertFalse(try db.tableExists("pets"))
        }
    }

    func testMigratorDatabasePool() throws {
        let dbPool = try makeDatabasePool()
        
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createPersons") { db in
            try db.execute("""
                CREATE TABLE persons (
                    id INTEGER PRIMARY KEY,
                    name TEXT)
                """)
        }
        migrator.registerMigration("createPets") { db in
            try db.execute("""
                CREATE TABLE pets (
                    id INTEGER PRIMARY KEY,
                    masterID INTEGER NOT NULL
                             REFERENCES persons(id)
                             ON DELETE CASCADE ON UPDATE CASCADE,
                    name TEXT)
                """)
        }
        
        try migrator.migrate(dbPool)
        try dbPool.read { db in
            XCTAssertTrue(try db.tableExists("persons"))
            XCTAssertTrue(try db.tableExists("pets"))
        }
        
        migrator.registerMigration("destroyPersons") { db in
            try db.execute("DROP TABLE pets")
        }
        
        try migrator.migrate(dbPool)
        try dbPool.read { db in
            XCTAssertTrue(try db.tableExists("persons"))
            XCTAssertFalse(try db.tableExists("pets"))
        }
    }

    func testMigrateUpTo() throws {
        let dbQueue = try makeDatabaseQueue()
        
        var migrator = DatabaseMigrator()
        migrator.registerMigration("a") { db in
            try db.execute("CREATE TABLE a (id INTEGER PRIMARY KEY)")
        }
        migrator.registerMigration("b") { db in
            try db.execute("CREATE TABLE b (id INTEGER PRIMARY KEY)")
        }
        migrator.registerMigration("c") { db in
            try db.execute("CREATE TABLE c (id INTEGER PRIMARY KEY)")
        }
        
        // one step
        try migrator.migrate(dbQueue, upTo: "a")
        try dbQueue.inDatabase { db in
            XCTAssertTrue(try db.tableExists("a"))
            XCTAssertFalse(try db.tableExists("b"))
        }
        
        // zero step
        try migrator.migrate(dbQueue, upTo: "a")
        try dbQueue.inDatabase { db in
            XCTAssertTrue(try db.tableExists("a"))
            XCTAssertFalse(try db.tableExists("b"))
        }
        
        // two steps
        try migrator.migrate(dbQueue, upTo: "c")
        try dbQueue.inDatabase { db in
            XCTAssertTrue(try db.tableExists("a"))
            XCTAssertTrue(try db.tableExists("b"))
            XCTAssertTrue(try db.tableExists("c"))
        }
        
        // zero step
        try migrator.migrate(dbQueue, upTo: "c")
        try migrator.migrate(dbQueue)
        
        // fatal error: undefined migration: "missing"
        // try migrator.migrate(dbQueue, upTo: "missing")
        
        // fatal error: database is already migrated beyond migration "b"
        // try migrator.migrate(dbQueue, upTo: "b")
    }
    
    func testMigrationFailureTriggersRollback() throws {
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
        
        let dbQueue = try makeDatabaseQueue()
        do {
            try migrator.migrate(dbQueue)
            XCTFail("Expected error")
        } catch let error as DatabaseError {
            // The first migration should be committed.
            // The second migration should be rollbacked.
            
            XCTAssertEqual(error.resultCode, .SQLITE_CONSTRAINT)
            XCTAssertEqual(error.message!.lowercased(), "foreign key constraint failed") // lowercased: accept multiple SQLite version
            XCTAssertEqual(error.sql!, "INSERT INTO pets (masterId, name) VALUES (?, ?)")
            // SQLITE_CONSTRAINT_FOREIGNKEY was added in SQLite 3.7.16 http://www.sqlite.org/changes.html#version_3_7_16
            // It is available from iOS 8.2 and OS X 10.10 https://github.com/yapstudios/YapDatabase/wiki/SQLite-version-(bundled-with-OS)
            if error.resultCode == error.extendedResultCode {
                XCTAssertEqual(error.description.lowercased(), "sqlite error 19 with statement `insert into pets (masterid, name) values (?, ?)` arguments [123, \"bobby\"]: foreign key constraint failed")
            } else {
                XCTAssertEqual(error.extendedResultCode, .SQLITE_CONSTRAINT_FOREIGNKEY)
                XCTAssertEqual(error.description.lowercased(), "sqlite error 787 with statement `insert into pets (masterid, name) values (?, ?)` arguments [123, \"bobby\"]: foreign key constraint failed")
            }
            
            let names = try dbQueue.inDatabase { db in
                try String.fetchAll(db, "SELECT name FROM persons")
            }
            XCTAssertEqual(names, ["Arthur"])
        }
    }
    
    func testMigrationWithoutForeignKeyChecks() throws {
        #if !GRDBCUSTOMSQLITE && !GRDBCIPHER
            guard #available(iOS 8.2, OSX 10.10, *) else {
                return
            }
        #endif
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createPersons") { db in
            try db.execute("CREATE TABLE persons (id INTEGER PRIMARY KEY, name TEXT, tmp TEXT)")
            try db.execute("CREATE TABLE pets (masterId INTEGER NOT NULL REFERENCES persons(id), name TEXT)")
            try db.execute("INSERT INTO persons (name) VALUES ('Arthur')")
            let personId = db.lastInsertedRowID
            try db.execute("INSERT INTO pets (masterId, name) VALUES (?, 'Bobby')", arguments:[personId])
        }
        migrator.registerMigrationWithDeferredForeignKeyCheck("removePersonTmpColumn") { db in
            // Test the technique described at https://www.sqlite.org/lang_altertable.html#otheralter
            try db.execute("CREATE TABLE new_persons (id INTEGER PRIMARY KEY, name TEXT)")
            try db.execute("INSERT INTO new_persons SELECT id, name FROM persons")
            try db.execute("DROP TABLE persons")
            try db.execute("ALTER TABLE new_persons RENAME TO persons")
        }
        migrator.registerMigrationWithDeferredForeignKeyCheck("foreignKeyError") { db in
            // Make sure foreign keys are checked at the end.
            try db.execute("INSERT INTO persons (name) VALUES ('Barbara')")
            do {
                // triggers foreign key error, but not now.
                try db.execute("INSERT INTO pets (masterId, name) VALUES (?, ?)", arguments: [123, "Bobby"])
            } catch {
                XCTFail("Error not expected at this point")
            }
        }
        
        let dbQueue = try makeDatabaseQueue()
        do {
            try migrator.migrate(dbQueue)
            XCTFail("Expected error")
        } catch let error as DatabaseError {
            // Migration 1 and 2 should be committed.
            // Migration 3 should not be committed.
            
            XCTAssertEqual(error.resultCode, .SQLITE_CONSTRAINT)
            XCTAssertEqual(error.message!, "FOREIGN KEY constraint failed")
            XCTAssertTrue(error.sql == nil)
            XCTAssertEqual(error.description, "SQLite error 19: FOREIGN KEY constraint failed")
            
            try dbQueue.inDatabase { db in
                // Arthur inserted (migration 1), Barbara (migration 3) not inserted.
                var rows = try Row.fetchAll(db, "SELECT * FROM persons")
                XCTAssertEqual(rows.count, 1)
                var row = rows.first!
                XCTAssertEqual(row["name"] as String, "Arthur")
                
                // persons table has no "tmp" column (migration 2)
                XCTAssertEqual(Array(row.columnNames), ["id", "name"])
                
                // Bobby inserted (migration 1), not deleted by migration 2.
                rows = try Row.fetchAll(db, "SELECT * FROM pets")
                XCTAssertEqual(rows.count, 1)
                row = rows.first!
                XCTAssertEqual(row["name"] as String, "Bobby")
            }
        }
    }
}
