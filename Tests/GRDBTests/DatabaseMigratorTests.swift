import XCTest
#if GRDBCUSTOMSQLITE
import GRDBCustomSQLite
#else
import GRDB
#endif

class DatabaseMigratorTests : GRDBTestCase {
    
    func testEmptyMigrator() throws {
        let migrator = DatabaseMigrator()
        let dbQueue = try makeDatabaseQueue()
        try migrator.migrate(dbQueue)
    }
    
    func testMigratorDatabaseQueue() throws {
        let dbQueue = try makeDatabaseQueue()
        
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createPersons") { db in
            try db.execute(sql: """
                CREATE TABLE persons (
                    id INTEGER PRIMARY KEY,
                    name TEXT)
                """)
        }
        migrator.registerMigration("createPets") { db in
            try db.execute(sql: """
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
            try db.execute(sql: "DROP TABLE pets")
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
            try db.execute(sql: """
                CREATE TABLE persons (
                    id INTEGER PRIMARY KEY,
                    name TEXT)
                """)
        }
        migrator.registerMigration("createPets") { db in
            try db.execute(sql: """
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
            try db.execute(sql: "DROP TABLE pets")
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
            try db.execute(sql: "CREATE TABLE a (id INTEGER PRIMARY KEY)")
        }
        migrator.registerMigration("b") { db in
            try db.execute(sql: "CREATE TABLE b (id INTEGER PRIMARY KEY)")
        }
        migrator.registerMigration("c") { db in
            try db.execute(sql: "CREATE TABLE c (id INTEGER PRIMARY KEY)")
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
            try db.execute(sql: "CREATE TABLE persons (id INTEGER PRIMARY KEY, name TEXT)")
            try db.execute(sql: "CREATE TABLE pets (masterId INTEGER NOT NULL REFERENCES persons(id), name TEXT)")
            try db.execute(sql: "INSERT INTO persons (name) VALUES ('Arthur')")
        }
        migrator.registerMigration("foreignKeyError") { db in
            try db.execute(sql: "INSERT INTO persons (name) VALUES ('Barbara')")
            // triggers foreign key error:
            try db.execute(sql: "INSERT INTO pets (masterId, name) VALUES (?, ?)", arguments: [123, "Bobby"])
        }
        
        let dbQueue = try makeDatabaseQueue()
        do {
            try migrator.migrate(dbQueue)
            XCTFail("Expected error")
        } catch let error as DatabaseError {
            // The first migration should be committed.
            // The second migration should be rollbacked.
            
            // SQLITE_CONSTRAINT_FOREIGNKEY was added in SQLite 3.7.16 http://www.sqlite.org/changes.html#version_3_7_16
            // It is available from iOS 8.2 and OS X 10.10 https://github.com/yapstudios/YapDatabase/wiki/SQLite-version-(bundled-with-OS)
            XCTAssert((error.resultCode == error.extendedResultCode) || error.extendedResultCode == .SQLITE_CONSTRAINT_FOREIGNKEY)
            XCTAssertEqual(error.resultCode, .SQLITE_CONSTRAINT)
            XCTAssertEqual(error.message!.lowercased(), "foreign key constraint failed") // lowercased: accept multiple SQLite version
            
            let names = try dbQueue.inDatabase { db in
                try String.fetchAll(db, sql: "SELECT name FROM persons")
            }
            XCTAssertEqual(names, ["Arthur"])
        }
    }
    
    func testForeignKeyViolation() throws {
        #if !GRDBCUSTOMSQLITE && !GRDBCIPHER
        guard #available(iOS 8.2, OSX 10.10, *) else {
            return
        }
        #endif
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createPersons") { db in
            try db.execute(sql: "CREATE TABLE persons (id INTEGER PRIMARY KEY, name TEXT, tmp TEXT)")
            try db.execute(sql: "CREATE TABLE pets (masterId INTEGER NOT NULL REFERENCES persons(id), name TEXT)")
            try db.execute(sql: "INSERT INTO persons (name) VALUES ('Arthur')")
            let personId = db.lastInsertedRowID
            try db.execute(sql: "INSERT INTO pets (masterId, name) VALUES (?, 'Bobby')", arguments:[personId])
        }
        migrator.registerMigration("removePersonTmpColumn") { db in
            // Test the technique described at https://www.sqlite.org/lang_altertable.html#otheralter
            try db.execute(sql: "CREATE TABLE new_persons (id INTEGER PRIMARY KEY, name TEXT)")
            try db.execute(sql: "INSERT INTO new_persons SELECT id, name FROM persons")
            try db.execute(sql: "DROP TABLE persons")
            try db.execute(sql: "ALTER TABLE new_persons RENAME TO persons")
        }
        migrator.registerMigration("foreignKeyError") { db in
            try db.execute(sql: "INSERT INTO persons (name) VALUES ('Barbara')")
            // triggers foreign key error:
            try db.execute(sql: "INSERT INTO pets (masterId, name) VALUES (?, ?)", arguments: [123, "Bobby"])
        }
        
        let dbQueue = try makeDatabaseQueue()
        do {
            try migrator.migrate(dbQueue)
            XCTFail("Expected error")
        } catch let error as DatabaseError {
            // Migration 1 and 2 should be committed.
            // Migration 3 should not be committed.
            
            XCTAssert((error.resultCode == error.extendedResultCode) || error.extendedResultCode == .SQLITE_CONSTRAINT_FOREIGNKEY)
            XCTAssertEqual(error.resultCode, .SQLITE_CONSTRAINT)
            XCTAssertEqual(error.message!.lowercased(), "foreign key constraint failed") // lowercased: accept multiple SQLite version
            
            try dbQueue.inDatabase { db in
                // Arthur inserted (migration 1), Barbara (migration 3) not inserted.
                var rows = try Row.fetchAll(db, sql: "SELECT * FROM persons")
                XCTAssertEqual(rows.count, 1)
                var row = rows.first!
                XCTAssertEqual(row["name"] as String, "Arthur")
                
                // persons table has no "tmp" column (migration 2)
                XCTAssertEqual(Array(row.columnNames), ["id", "name"])
                
                // Bobby inserted (migration 1), not deleted by migration 2.
                rows = try Row.fetchAll(db, sql: "SELECT * FROM pets")
                XCTAssertEqual(rows.count, 1)
                row = rows.first!
                XCTAssertEqual(row["name"] as String, "Bobby")
            }
        }
    }
    
    func testMigrationWithDeferredForeignKeyChecksDeprecated() throws {
        #if !GRDBCUSTOMSQLITE && !GRDBCIPHER
        guard #available(iOS 8.2, OSX 10.10, *) else {
            return
        }
        #endif
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createPersons") { db in
            try db.execute(sql: "CREATE TABLE persons (id INTEGER PRIMARY KEY, name TEXT, tmp TEXT)")
            try db.execute(sql: "CREATE TABLE pets (masterId INTEGER NOT NULL REFERENCES persons(id), name TEXT)")
            try db.execute(sql: "INSERT INTO persons (name) VALUES ('Arthur')")
            let personId = db.lastInsertedRowID
            try db.execute(sql: "INSERT INTO pets (masterId, name) VALUES (?, 'Bobby')", arguments:[personId])
        }
        migrator.registerMigrationWithDeferredForeignKeyCheck("removePersonTmpColumn") { db in
            // Test the technique described at https://www.sqlite.org/lang_altertable.html#otheralter
            try db.execute(sql: "CREATE TABLE new_persons (id INTEGER PRIMARY KEY, name TEXT)")
            try db.execute(sql: "INSERT INTO new_persons SELECT id, name FROM persons")
            try db.execute(sql: "DROP TABLE persons")
            try db.execute(sql: "ALTER TABLE new_persons RENAME TO persons")
        }
        migrator.registerMigrationWithDeferredForeignKeyCheck("foreignKeyError") { db in
            // Make sure foreign keys are checked at the end.
            try db.execute(sql: "INSERT INTO persons (name) VALUES ('Barbara')")
            do {
                // triggers foreign key error, but not now.
                try db.execute(sql: "INSERT INTO pets (masterId, name) VALUES (?, ?)", arguments: [123, "Bobby"])
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
                var rows = try Row.fetchAll(db, sql: "SELECT * FROM persons")
                XCTAssertEqual(rows.count, 1)
                var row = rows.first!
                XCTAssertEqual(row["name"] as String, "Arthur")
                
                // persons table has no "tmp" column (migration 2)
                XCTAssertEqual(Array(row.columnNames), ["id", "name"])
                
                // Bobby inserted (migration 1), not deleted by migration 2.
                rows = try Row.fetchAll(db, sql: "SELECT * FROM pets")
                XCTAssertEqual(rows.count, 1)
                row = rows.first!
                XCTAssertEqual(row["name"] as String, "Bobby")
            }
        }
    }
    
    func testAppliedMigrationsDeprecated() throws {
        var migrator = DatabaseMigrator()
        
        // No migration
        do {
            let dbQueue = try makeDatabaseQueue()
            try XCTAssertEqual(migrator.appliedMigrations(in: dbQueue), [])
        }
        
        // One migration
        
        migrator.registerMigration("1") { db in
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text)
                t.column("score", .integer)
            }
        }
        
        do {
            let dbQueue = try makeDatabaseQueue()
            try XCTAssertEqual(migrator.appliedMigrations(in: dbQueue), [])
            try migrator.migrate(dbQueue, upTo: "1")
            try XCTAssertEqual(migrator.appliedMigrations(in: dbQueue), ["1"])
        }
        
        // Two migrations
        
        migrator.registerMigration("2") { db in
            try db.execute(sql: "INSERT INTO player (id, name, score) VALUES (NULL, 'Arthur', 1000)")
        }
        
        do {
            let dbQueue = try makeDatabaseQueue()
            try XCTAssertEqual(migrator.appliedMigrations(in: dbQueue), [])
            try migrator.migrate(dbQueue, upTo: "1")
            try XCTAssertEqual(migrator.appliedMigrations(in: dbQueue), ["1"])
            try migrator.migrate(dbQueue, upTo: "2")
            try XCTAssertEqual(migrator.appliedMigrations(in: dbQueue), ["1", "2"])
        }
    }
    
    func testAppliedMigrations() throws {
        var migrator = DatabaseMigrator()
        
        // No migration
        do {
            let dbQueue = try makeDatabaseQueue()
            try XCTAssertEqual(dbQueue.read(migrator.appliedMigrations), [])
        }
        
        // One migration
        
        migrator.registerMigration("1") { db in
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text)
                t.column("score", .integer)
            }
        }
        
        do {
            let dbQueue = try makeDatabaseQueue()
            try XCTAssertEqual(dbQueue.read(migrator.appliedMigrations), [])
            try migrator.migrate(dbQueue, upTo: "1")
            try XCTAssertEqual(dbQueue.read(migrator.appliedMigrations), ["1"])
        }
        
        // Two migrations
        
        migrator.registerMigration("2") { db in
            try db.execute(sql: "INSERT INTO player (id, name, score) VALUES (NULL, 'Arthur', 1000)")
        }
        
        do {
            let dbQueue = try makeDatabaseQueue()
            try XCTAssertEqual(dbQueue.read(migrator.appliedMigrations), [])
            try migrator.migrate(dbQueue, upTo: "1")
            try XCTAssertEqual(dbQueue.read(migrator.appliedMigrations), ["1"])
            try migrator.migrate(dbQueue, upTo: "2")
            try XCTAssertEqual(dbQueue.read(migrator.appliedMigrations), ["1", "2"])
        }
    }
    
    func testHasCompletedMigrationsDeprecated() throws {
        var migrator = DatabaseMigrator()
        
        // No migration
        do {
            let dbQueue = try makeDatabaseQueue()
            try XCTAssertTrue(migrator.hasCompletedMigrations(in: dbQueue))
        }
        
        // One migration
        
        migrator.registerMigration("1") { db in
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text)
                t.column("score", .integer)
            }
        }
        
        do {
            let dbQueue = try makeDatabaseQueue()
            try XCTAssertFalse(migrator.hasCompletedMigrations(in: dbQueue, through: "1"))
            try XCTAssertFalse(migrator.hasCompletedMigrations(in: dbQueue))
            try migrator.migrate(dbQueue, upTo: "1")
            try XCTAssertTrue(migrator.hasCompletedMigrations(in: dbQueue, through: "1"))
            try XCTAssertTrue(migrator.hasCompletedMigrations(in: dbQueue))
        }
        
        // Two migrations
        
        migrator.registerMigration("2") { db in
            try db.execute(sql: "INSERT INTO player (id, name, score) VALUES (NULL, 'Arthur', 1000)")
        }
        
        do {
            let dbQueue = try makeDatabaseQueue()
            try XCTAssertFalse(migrator.hasCompletedMigrations(in: dbQueue, through: "1"))
            try XCTAssertFalse(migrator.hasCompletedMigrations(in: dbQueue, through: "2"))
            try XCTAssertFalse(migrator.hasCompletedMigrations(in: dbQueue))
            try migrator.migrate(dbQueue, upTo: "1")
            try XCTAssertTrue(migrator.hasCompletedMigrations(in: dbQueue, through: "1"))
            try XCTAssertFalse(migrator.hasCompletedMigrations(in: dbQueue, through: "2"))
            try XCTAssertFalse(migrator.hasCompletedMigrations(in: dbQueue))
            try migrator.migrate(dbQueue, upTo: "2")
            try XCTAssertTrue(migrator.hasCompletedMigrations(in: dbQueue, through: "1"))
            try XCTAssertTrue(migrator.hasCompletedMigrations(in: dbQueue, through: "2"))
            try XCTAssertTrue(migrator.hasCompletedMigrations(in: dbQueue))
        }
    }
    
    func testLastCompletedMigrationDeprecated() throws {
        var migrator = DatabaseMigrator()
        
        // No migration
        do {
            let dbQueue = try makeDatabaseQueue()
            try XCTAssertNil(migrator.lastCompletedMigration(in: dbQueue))
        }
        
        // One migration
        
        migrator.registerMigration("1") { db in
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text)
                t.column("score", .integer)
            }
        }
        
        do {
            let dbQueue = try makeDatabaseQueue()
            try XCTAssertNil(migrator.lastCompletedMigration(in: dbQueue))
            try migrator.migrate(dbQueue, upTo: "1")
            try XCTAssertEqual(migrator.lastCompletedMigration(in: dbQueue), "1")
        }
        
        // Two migrations
        
        migrator.registerMigration("2") { db in
            try db.execute(sql: "INSERT INTO player (id, name, score) VALUES (NULL, 'Arthur', 1000)")
        }
        
        do {
            let dbQueue = try makeDatabaseQueue()
            try XCTAssertNil(migrator.lastCompletedMigration(in: dbQueue))
            try migrator.migrate(dbQueue, upTo: "1")
            try XCTAssertEqual(migrator.lastCompletedMigration(in: dbQueue), "1")
            try migrator.migrate(dbQueue, upTo: "2")
            try XCTAssertEqual(migrator.lastCompletedMigration(in: dbQueue), "2")
        }
    }
    
    func testCompletedMigrations() throws {
        var migrator = DatabaseMigrator()
        
        // No migration
        do {
            let dbQueue = try makeDatabaseQueue()
            try XCTAssertEqual(dbQueue.read(migrator.completedMigrations), [])
            try XCTAssertTrue(dbQueue.read(migrator.hasCompletedMigrations))
        }
        
        // One migration
        
        migrator.registerMigration("1") { db in
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text)
                t.column("score", .integer)
            }
        }
        
        do {
            let dbQueue = try makeDatabaseQueue()
            try XCTAssertEqual(dbQueue.read(migrator.completedMigrations), [])
            try XCTAssertFalse(dbQueue.read(migrator.hasCompletedMigrations))
            try migrator.migrate(dbQueue, upTo: "1")
            try XCTAssertEqual(dbQueue.read(migrator.completedMigrations), ["1"])
            try XCTAssertTrue(dbQueue.read(migrator.hasCompletedMigrations))
        }
        
        // Two migrations
        
        migrator.registerMigration("2") { db in
            try db.execute(sql: "INSERT INTO player (id, name, score) VALUES (NULL, 'Arthur', 1000)")
        }
        
        do {
            let dbQueue = try makeDatabaseQueue()
            try XCTAssertEqual(dbQueue.read(migrator.completedMigrations), [])
            try XCTAssertFalse(dbQueue.read(migrator.hasCompletedMigrations))
            try migrator.migrate(dbQueue, upTo: "1")
            try XCTAssertEqual(dbQueue.read(migrator.completedMigrations), ["1"])
            try XCTAssertFalse(dbQueue.read(migrator.hasCompletedMigrations))
            try migrator.migrate(dbQueue, upTo: "2")
            try XCTAssertEqual(dbQueue.read(migrator.completedMigrations), ["1", "2"])
            try XCTAssertTrue(dbQueue.read(migrator.hasCompletedMigrations))
        }
    }
    
    func testMergedMigrators() throws {
        // Migrate a database
        var oldMigrator = DatabaseMigrator()
        oldMigrator.registerMigration("1", migrate: { _ in })
        oldMigrator.registerMigration("3", migrate: { _ in })
        
        let dbQueue = try makeDatabaseQueue()
        try oldMigrator.migrate(dbQueue)
        
        try XCTAssertEqual(dbQueue.read(oldMigrator.appliedMigrations), ["1", "3"])
        try XCTAssertEqual(dbQueue.read(oldMigrator.completedMigrations), ["1", "3"])
        try XCTAssertTrue(dbQueue.read(oldMigrator.hasCompletedMigrations))
        
        // A source code merge inserts a migration between "1" and "3"
        var newMigrator = DatabaseMigrator()
        newMigrator.registerMigration("1", migrate: { _ in })
        newMigrator.registerMigration("2", migrate: { _ in })
        newMigrator.registerMigration("3", migrate: { _ in })
        
        try XCTAssertEqual(dbQueue.read(newMigrator.appliedMigrations), ["1", "3"])
        try XCTAssertEqual(dbQueue.read(newMigrator.completedMigrations), ["1"])
        try XCTAssertFalse(dbQueue.read(newMigrator.hasCompletedMigrations))
        
        // The new source code migrates the database
        try newMigrator.migrate(dbQueue)
        
        try XCTAssertEqual(dbQueue.read(oldMigrator.appliedMigrations), ["1", "3"])
        try XCTAssertEqual(dbQueue.read(oldMigrator.completedMigrations), ["1", "3"])
        try XCTAssertTrue(dbQueue.read(oldMigrator.hasCompletedMigrations))
        
        try XCTAssertEqual(dbQueue.read(newMigrator.appliedMigrations), ["1", "2", "3"])
        try XCTAssertEqual(dbQueue.read(newMigrator.completedMigrations), ["1", "2", "3"])
        try XCTAssertTrue(dbQueue.read(newMigrator.hasCompletedMigrations))
    }
    
    // Regression test for https://github.com/groue/GRDB.swift/issues/741
    func testEraseDatabaseOnSchemaChangeDoesNotDeadLock() throws {
        dbConfiguration.targetQueue = DispatchQueue(label: "target")
        let dbQueue = try makeDatabaseQueue()
        
        var migrator = DatabaseMigrator()
        migrator.eraseDatabaseOnSchemaChange = true
        migrator.registerMigration("1", migrate: { _ in })
        try migrator.migrate(dbQueue)
        
        migrator.registerMigration("2", migrate: { _ in })
        try migrator.migrate(dbQueue)
    }
    
    func testEraseDatabaseOnSchemaChange() throws {
        // 1st version of the migrator
        var migrator1 = DatabaseMigrator()
        migrator1.registerMigration("1") { db in
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text)
            }
        }
        
        // 2nd version of the migrator
        var migrator2 = DatabaseMigrator()
        migrator2.registerMigration("1") { db in
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text)
                t.column("score", .integer) // <- schema change, because reasons (development)
            }
        }
        migrator2.registerMigration("2") { db in
            try db.execute(sql: "INSERT INTO player (id, name, score) VALUES (NULL, 'Arthur', 1000)")
        }
        
        // Apply 1st migrator
        let dbQueue = try makeDatabaseQueue()
        try migrator1.migrate(dbQueue)
        
        // Test than 2nd migrator can't run...
        do {
            try migrator2.migrate(dbQueue)
            XCTFail("Expected DatabaseError")
        } catch let error as DatabaseError {
            XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
            XCTAssertEqual(error.message, "table player has no column named score")
        }
        try XCTAssertEqual(dbQueue.read(migrator2.appliedMigrations), ["1"])
        
        // ... unless databaase gets erased
        migrator2.eraseDatabaseOnSchemaChange = true
        try migrator2.migrate(dbQueue)
        try XCTAssertEqual(dbQueue.read(migrator2.appliedMigrations), ["1", "2"])
    }
    
    func testEraseDatabaseOnSchemaChangeWithConfiguration() throws {
        // 1st version of the migrator
        var migrator1 = DatabaseMigrator()
        migrator1.registerMigration("1") { db in
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text)
            }
            try db.execute(sql: "INSERT INTO player (id, name) VALUES (NULL, testFunction())")
        }
        
        // 2nd version of the migrator
        var migrator2 = DatabaseMigrator()
        migrator2.registerMigration("1") { db in
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text)
                t.column("score", .integer) // <- schema change, because reasons (development)
            }
            try db.execute(sql: "INSERT INTO player (id, name, score) VALUES (NULL, testFunction(), 1000)")
        }
        migrator2.registerMigration("2") { db in
            try db.execute(sql: "INSERT INTO player (id, name, score) VALUES (NULL, testFunction(), 2000)")
        }
        
        // Apply 1st migrator
        dbConfiguration.prepareDatabase = { db in
            let function = DatabaseFunction("testFunction", argumentCount: 0, pure: true) { _ in "Arthur" }
            db.add(function: function)
        }
        let dbQueue = try makeDatabaseQueue()
        try migrator1.migrate(dbQueue)
        
        // Test than 2nd migrator can't run...
        do {
            try migrator2.migrate(dbQueue)
            XCTFail("Expected DatabaseError")
        } catch let error as DatabaseError {
            XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
            XCTAssertEqual(error.message, "table player has no column named score")
        }
        try XCTAssertEqual(dbQueue.read(migrator2.appliedMigrations), ["1"])
        
        // ... unless databaase gets erased
        migrator2.eraseDatabaseOnSchemaChange = true
        try migrator2.migrate(dbQueue)
        try XCTAssertEqual(dbQueue.read(migrator2.appliedMigrations), ["1", "2"])
    }
    
    func testEraseDatabaseOnSchemaChangeDoesNotEraseDatabaseOnAddedMigration() throws {
        var migrator = DatabaseMigrator()
        migrator.eraseDatabaseOnSchemaChange = true
        
        var witness = 1
        migrator.registerMigration("1") { db in
            try db.execute(sql: """
                CREATE TABLE t1(id INTEGER PRIMARY KEY);
                INSERT INTO t1(id) VALUES (?)
                """, arguments: [witness])
            witness += 1
        }
        
        let dbQueue = try makeDatabaseQueue()
        
        // 1st migration
        try migrator.migrate(dbQueue)
        try XCTAssertEqual(dbQueue.read { try Int.fetchOne($0, sql: "SELECT id FROM t1") }, 1)
        
        // 2nd migration does not erase database
        migrator.registerMigration("2") { db in
            try db.execute(sql: """
                CREATE TABLE t2(id INTEGER PRIMARY KEY);
                """)
        }
        try migrator.migrate(dbQueue)
        try XCTAssertEqual(dbQueue.read { try Int.fetchOne($0, sql: "SELECT id FROM t1") }, 1)
        try XCTAssertTrue(dbQueue.read { try $0.tableExists("t2") })
    }
    
    func testEraseDatabaseOnSchemaChangeWithRenamedMigration() throws {
        let dbQueue = try makeDatabaseQueue()
        
        // 1st migration
        var migrator1 = DatabaseMigrator()
        migrator1.registerMigration("1") { db in
            try db.execute(sql: """
                CREATE TABLE t1(id INTEGER PRIMARY KEY);
                INSERT INTO t1(id) VALUES (1)
                """)
        }
        try migrator1.migrate(dbQueue)
        try XCTAssertEqual(dbQueue.read { try Int.fetchOne($0, sql: "SELECT id FROM t1") }, 1)
        
        // 2nd migration does not erase database
        var migrator2 = DatabaseMigrator()
        migrator2.eraseDatabaseOnSchemaChange = true
        migrator2.registerMigration("2") { db in
            try db.execute(sql: """
                CREATE TABLE t1(id INTEGER PRIMARY KEY);
                INSERT INTO t1(id) VALUES (2)
                """)
        }
        try migrator2.migrate(dbQueue)
        try XCTAssertEqual(dbQueue.read { try Int.fetchOne($0, sql: "SELECT id FROM t1") }, 2)
    }
}
