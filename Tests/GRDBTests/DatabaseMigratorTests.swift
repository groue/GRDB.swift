import XCTest
import GRDB

class DatabaseMigratorTests : GRDBTestCase {
    
    func testEmptyMigratorSync() throws {
        func test(writer: DatabaseWriter) throws {
            let migrator = DatabaseMigrator()
            try migrator.migrate(writer)
        }
        
        try Test(test)
            .run { try DatabaseQueue() }
            .runAtTemporaryDatabasePath { try DatabaseQueue(path: $0) }
            .runAtTemporaryDatabasePath { try DatabasePool(path: $0) }
    }
    
    func testEmptyMigratorAsync() throws {
        func test(writer: DatabaseWriter) throws {
            let expectation = self.expectation(description: "")
            let migrator = DatabaseMigrator()
            migrator.asyncMigrate(writer, completion: { dbResult in
                // No migration error
                let db = try! dbResult.get()
                
                // Write access
                try! db.execute(sql: "CREATE TABLE t(a)")
                expectation.fulfill()
            })
            waitForExpectations(timeout: 1, handler: nil)
        }
        
        try Test(test)
            .run { try DatabaseQueue() }
            .runAtTemporaryDatabasePath { try DatabaseQueue(path: $0) }
            .runAtTemporaryDatabasePath { try DatabasePool(path: $0) }
    }
    
    func testEmptyMigratorPublisher() throws {
        guard #available(OSX 10.15, iOS 13, tvOS 13, watchOS 6, *) else {
            throw XCTSkip("Combine is not available")
        }
        
        func test(writer: DatabaseWriter) throws {
            let migrator = DatabaseMigrator()
            let publisher = migrator.migratePublisher(writer)
            let recorder = publisher.record()
            try wait(for: recorder.single, timeout: 1)
        }
        
        try Test(test)
            .run { try DatabaseQueue() }
            .runAtTemporaryDatabasePath { try DatabaseQueue(path: $0) }
            .runAtTemporaryDatabasePath { try DatabasePool(path: $0) }
    }
    
    func testNonEmptyMigratorSync() throws {
        func test(writer: DatabaseWriter) throws {
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
            
            var migrator2 = migrator
            migrator2.registerMigration("destroyPersons") { db in
                try db.execute(sql: "DROP TABLE pets")
            }
            
            try migrator.migrate(writer)
            try writer.read { db in
                XCTAssertTrue(try db.tableExists("persons"))
                XCTAssertTrue(try db.tableExists("pets"))
            }
            
            try migrator2.migrate(writer)
            try writer.read { db in
                XCTAssertTrue(try db.tableExists("persons"))
                XCTAssertFalse(try db.tableExists("pets"))
            }
        }
        
        try Test(test)
            .run { try DatabaseQueue() }
            .runAtTemporaryDatabasePath { try DatabaseQueue(path: $0) }
            .runAtTemporaryDatabasePath { try DatabasePool(path: $0) }
    }
    
    func testNonEmptyMigratorAsync() throws {
        func test(writer: DatabaseWriter) throws {
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
            
            var migrator2 = migrator
            migrator2.registerMigration("destroyPersons") { db in
                try db.execute(sql: "DROP TABLE pets")
            }
            
            let expectation = self.expectation(description: "")
            migrator.asyncMigrate(writer, completion: { dbResult in
                // No migration error
                let db = try! dbResult.get()
                
                XCTAssertTrue(try! db.tableExists("persons"))
                XCTAssertTrue(try! db.tableExists("pets"))
                
                migrator2.asyncMigrate(writer, completion: { dbResult in
                    // No migration error
                    let db = try! dbResult.get()
                    
                    XCTAssertTrue(try! db.tableExists("persons"))
                    XCTAssertFalse(try! db.tableExists("pets"))
                    expectation.fulfill()
                })
            })
            waitForExpectations(timeout: 1, handler: nil)
        }
        
        try Test(test)
            .run { try DatabaseQueue() }
            .runAtTemporaryDatabasePath { try DatabaseQueue(path: $0) }
            .runAtTemporaryDatabasePath { try DatabasePool(path: $0) }
    }
    
    func testNonEmptyMigratorPublisher() throws {
        guard #available(OSX 10.15, iOS 13, tvOS 13, watchOS 6, *) else {
            throw XCTSkip("Combine is not available")
        }
        
        func test(writer: DatabaseWriter) throws {
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
            
            var migrator2 = migrator
            migrator2.registerMigration("destroyPersons") { db in
                try db.execute(sql: "DROP TABLE pets")
            }
            
            do {
                let publisher = migrator.migratePublisher(writer)
                let recorder = publisher.record()
                try wait(for: recorder.single, timeout: 1)
                try writer.read { db in
                    XCTAssertTrue(try db.tableExists("persons"))
                    XCTAssertTrue(try db.tableExists("pets"))
                }
            }
            
            do {
                let publisher = migrator2.migratePublisher(writer)
                let recorder = publisher.record()
                try wait(for: recorder.single, timeout: 1)
                try writer.read { db in
                    XCTAssertTrue(try db.tableExists("persons"))
                    XCTAssertFalse(try db.tableExists("pets"))
                }
            }
        }
        
        try Test(test)
            .run { try DatabaseQueue() }
            .runAtTemporaryDatabasePath { try DatabaseQueue(path: $0) }
            .runAtTemporaryDatabasePath { try DatabasePool(path: $0) }
    }

    func testEmptyMigratorPublisherIsAsynchronous() throws {
        guard #available(OSX 10.15, iOS 13, tvOS 13, watchOS 6, *) else {
            throw XCTSkip("Combine is not available")
        }
        
        func test(writer: DatabaseWriter) throws {
            let migrator = DatabaseMigrator()
            let expectation = self.expectation(description: "")
            let semaphore = DispatchSemaphore(value: 0)
            let cancellable = migrator.migratePublisher(writer).sink(
                receiveCompletion: { _ in },
                receiveValue: { _ in
                    semaphore.wait()
                    expectation.fulfill()
                })
            
            semaphore.signal()
            waitForExpectations(timeout: 1, handler: nil)
            cancellable.cancel()
        }
        
        try Test(test)
            .run { try DatabaseQueue() }
            .runAtTemporaryDatabasePath { try DatabaseQueue(path: $0) }
            .runAtTemporaryDatabasePath { try DatabasePool(path: $0) }
    }
    
    func testNonEmptyMigratorPublisherIsAsynchronous() throws {
        guard #available(OSX 10.15, iOS 13, tvOS 13, watchOS 6, *) else {
            throw XCTSkip("Combine is not available")
        }
        
        func test(writer: DatabaseWriter) throws {
            var migrator = DatabaseMigrator()
            migrator.registerMigration("first", migrate: { _ in })
            let expectation = self.expectation(description: "")
            let semaphore = DispatchSemaphore(value: 0)
            let cancellable = migrator.migratePublisher(writer).sink(
                receiveCompletion: { _ in },
                receiveValue: { _ in
                    semaphore.wait()
                    expectation.fulfill()
                })
            
            semaphore.signal()
            waitForExpectations(timeout: 1, handler: nil)
            cancellable.cancel()
        }
        
        try Test(test)
            .run { try DatabaseQueue() }
            .runAtTemporaryDatabasePath { try DatabaseQueue(path: $0) }
            .runAtTemporaryDatabasePath { try DatabasePool(path: $0) }
    }
    
    func testMigratorPublisherDefaultScheduler() throws {
        guard #available(OSX 10.15, iOS 13, tvOS 13, watchOS 6, *) else {
            throw XCTSkip("Combine is not available")
        }
        
        func test(writer: DatabaseWriter) {
            var migrator = DatabaseMigrator()
            migrator.registerMigration("first", migrate: { _ in })
            let expectation = self.expectation(description: "")
            expectation.expectedFulfillmentCount = 2 // value + completion
            let cancellable = migrator.migratePublisher(writer).sink(
                receiveCompletion: { completion in
                    dispatchPrecondition(condition: .onQueue(.main))
                    expectation.fulfill()
                },
                receiveValue: { _ in
                    dispatchPrecondition(condition: .onQueue(.main))
                    expectation.fulfill()
                })
            
            waitForExpectations(timeout: 1, handler: nil)
            cancellable.cancel()
        }
        
        try Test(test)
            .run { try DatabaseQueue() }
            .runAtTemporaryDatabasePath { try DatabaseQueue(path: $0) }
            .runAtTemporaryDatabasePath { try DatabasePool(path: $0) }
    }
    
    func testMigratorPublisherCustomScheduler() throws {
        guard #available(OSX 10.15, iOS 13, tvOS 13, watchOS 6, *) else {
            throw XCTSkip("Combine is not available")
        }
        
        func test(writer: DatabaseWriter) {
            var migrator = DatabaseMigrator()
            migrator.registerMigration("first", migrate: { _ in })
            let queue = DispatchQueue(label: "test")
            let expectation = self.expectation(description: "")
            expectation.expectedFulfillmentCount = 2 // value + completion
            let cancellable = migrator.migratePublisher(writer, receiveOn: queue).sink(
                receiveCompletion: { completion in
                    dispatchPrecondition(condition: .onQueue(queue))
                    expectation.fulfill()
                },
                receiveValue: { _ in
                    dispatchPrecondition(condition: .onQueue(queue))
                    expectation.fulfill()
                })
            
            waitForExpectations(timeout: 1, handler: nil)
            cancellable.cancel()
        }
        
        try Test(test)
            .run { try DatabaseQueue() }
            .runAtTemporaryDatabasePath { try DatabaseQueue(path: $0) }
            .runAtTemporaryDatabasePath { try DatabasePool(path: $0) }
    }

    func testMigrateUpTo() throws {
        func test(writer: DatabaseWriter) throws {
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
            try migrator.migrate(writer, upTo: "a")
            try writer.read { db in
                XCTAssertTrue(try db.tableExists("a"))
                XCTAssertFalse(try db.tableExists("b"))
            }
            
            // zero step
            try migrator.migrate(writer, upTo: "a")
            try writer.read { db in
                XCTAssertTrue(try db.tableExists("a"))
                XCTAssertFalse(try db.tableExists("b"))
            }
            
            // two steps
            try migrator.migrate(writer, upTo: "c")
            try writer.read { db in
                XCTAssertTrue(try db.tableExists("a"))
                XCTAssertTrue(try db.tableExists("b"))
                XCTAssertTrue(try db.tableExists("c"))
            }
            
            // zero step
            try migrator.migrate(writer, upTo: "c")
            try migrator.migrate(writer)
            
            // fatal error: undefined migration: "missing"
            // try migrator.migrate(writer, upTo: "missing")
            
            // fatal error: database is already migrated beyond migration "b"
            // try migrator.migrate(writer, upTo: "b")
        }
        
        try Test(test)
            .run { try DatabaseQueue() }
            .runAtTemporaryDatabasePath { try DatabaseQueue(path: $0) }
            .runAtTemporaryDatabasePath { try DatabasePool(path: $0) }
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
        
        // Sync
        do {
            let dbQueue = try makeDatabaseQueue()
            do {
                try migrator.migrate(dbQueue)
                XCTFail("Expected error")
            } catch let error as DatabaseError {
                // The first migration should be committed.
                // The second migration should be rollbacked.
                
                XCTAssertEqual(error.extendedResultCode, .SQLITE_CONSTRAINT_FOREIGNKEY)
                XCTAssertEqual(error.resultCode, .SQLITE_CONSTRAINT)
                XCTAssertEqual(error.message, #"FOREIGN KEY constraint violation - from pets(masterId) to persons(id), in [masterId:123 name:"Bobby"]"#)
                
                let names = try dbQueue.inDatabase { db in
                    try String.fetchAll(db, sql: "SELECT name FROM persons")
                }
                XCTAssertEqual(names, ["Arthur"])
            }
        }
        
        // Async
        do {
            let expectation = self.expectation(description: "")
            let dbQueue = try makeDatabaseQueue()
            migrator.asyncMigrate(dbQueue, completion: { dbResult in
                // The first migration should be committed.
                // The second migration should be rollbacked.
                
                guard case let .failure(error as DatabaseError) = dbResult else {
                    XCTFail("Expected DatabaseError")
                    expectation.fulfill()
                    return
                }
                
                XCTAssertEqual(error.extendedResultCode, .SQLITE_CONSTRAINT_FOREIGNKEY)
                XCTAssertEqual(error.resultCode, .SQLITE_CONSTRAINT)
                XCTAssertEqual(error.message, #"FOREIGN KEY constraint violation - from pets(masterId) to persons(id), in [masterId:123 name:"Bobby"]"#)
                
                dbQueue.asyncRead { dbResult in
                    let names = try! String.fetchAll(dbResult.get(), sql: "SELECT name FROM persons")
                    XCTAssertEqual(names, ["Arthur"])
                    
                    expectation.fulfill()
                }
            })
            waitForExpectations(timeout: 1, handler: nil)
        }
    }
    
    func testForeignKeyViolation() throws {
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
            
            XCTAssertEqual(error.extendedResultCode, .SQLITE_CONSTRAINT_FOREIGNKEY)
            XCTAssertEqual(error.resultCode, .SQLITE_CONSTRAINT)
            XCTAssertEqual(error.message, #"FOREIGN KEY constraint violation - from pets(masterId) to persons(id), in [masterId:123 name:"Bobby"]"#)
            
            try dbQueue.inDatabase { db in
                // Arthur inserted (migration 1), Barbara (migration 3) not inserted.
                var rows = try Row.fetchAll(db, sql: "SELECT * FROM persons")
                XCTAssertEqual(rows.count, 1)
                var row = rows.first!
                try XCTAssertEqual(row["name"] as String, "Arthur")
                
                // persons table has no "tmp" column (migration 2)
                XCTAssertEqual(Array(row.columnNames), ["id", "name"])
                
                // Bobby inserted (migration 1), not deleted by migration 2.
                rows = try Row.fetchAll(db, sql: "SELECT * FROM pets")
                XCTAssertEqual(rows.count, 1)
                row = rows.first!
                try XCTAssertEqual(row["name"] as String, "Bobby")
            }
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
        
        migrator.registerMigration("1", migrate: { _ in })
        
        do {
            let dbQueue = try makeDatabaseQueue()
            try XCTAssertEqual(dbQueue.read(migrator.appliedMigrations), [])
            try migrator.migrate(dbQueue, upTo: "1")
            try XCTAssertEqual(dbQueue.read(migrator.appliedMigrations), ["1"])
        }
        
        // Two migrations
        
        migrator.registerMigration("2", migrate: { _ in })
        
        do {
            let dbQueue = try makeDatabaseQueue()
            try XCTAssertEqual(dbQueue.read(migrator.appliedMigrations), [])
            try migrator.migrate(dbQueue, upTo: "1")
            try XCTAssertEqual(dbQueue.read(migrator.appliedMigrations), ["1"])
            try migrator.migrate(dbQueue, upTo: "2")
            try XCTAssertEqual(dbQueue.read(migrator.appliedMigrations), ["1", "2"])
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
        
        migrator.registerMigration("1", migrate: { _ in })
        
        do {
            let dbQueue = try makeDatabaseQueue()
            try XCTAssertEqual(dbQueue.read(migrator.completedMigrations), [])
            try XCTAssertFalse(dbQueue.read(migrator.hasCompletedMigrations))
            try migrator.migrate(dbQueue, upTo: "1")
            try XCTAssertEqual(dbQueue.read(migrator.completedMigrations), ["1"])
            try XCTAssertTrue(dbQueue.read(migrator.hasCompletedMigrations))
        }
        
        // Two migrations
        
        migrator.registerMigration("2", migrate: { _ in })
        
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
    
    func testSuperseded() throws {
        var migrator = DatabaseMigrator()
        
        // No migration
        do {
            let dbQueue = try makeDatabaseQueue()
            try XCTAssertFalse(dbQueue.read(migrator.hasBeenSuperseded))
        }
        
        // One migration
        
        migrator.registerMigration("1", migrate: { _ in })
        
        do {
            let dbQueue = try makeDatabaseQueue()
            try XCTAssertFalse(dbQueue.read(migrator.hasBeenSuperseded))
            try migrator.migrate(dbQueue, upTo: "1")
            try XCTAssertFalse(dbQueue.read(migrator.hasBeenSuperseded))
        }
        
        // Two migrations
        
        migrator.registerMigration("2", migrate: { _ in })
        
        do {
            let dbQueue = try makeDatabaseQueue()
            try XCTAssertFalse(dbQueue.read(migrator.hasBeenSuperseded))
            try migrator.migrate(dbQueue, upTo: "1")
            try XCTAssertFalse(dbQueue.read(migrator.hasBeenSuperseded))
            try migrator.migrate(dbQueue, upTo: "2")
            try XCTAssertFalse(dbQueue.read(migrator.hasBeenSuperseded))
        }
    }
    
    func testMergedMigrators() throws {
        // Migrate a database
        var migrator1 = DatabaseMigrator()
        migrator1.registerMigration("1", migrate: { _ in })
        migrator1.registerMigration("3", migrate: { _ in })
        
        let dbQueue = try makeDatabaseQueue()
        try migrator1.migrate(dbQueue)
        
        try XCTAssertEqual(dbQueue.read(migrator1.appliedMigrations), ["1", "3"])
        try XCTAssertEqual(dbQueue.read(migrator1.appliedIdentifiers), ["1", "3"])
        try XCTAssertEqual(dbQueue.read(migrator1.completedMigrations), ["1", "3"])
        try XCTAssertTrue(dbQueue.read(migrator1.hasCompletedMigrations))
        try XCTAssertFalse(dbQueue.read(migrator1.hasBeenSuperseded))
        
        // ---
        // A source code merge inserts a migration between "1" and "3"
        var migrator2 = DatabaseMigrator()
        migrator2.registerMigration("1", migrate: { _ in })
        migrator2.registerMigration("2", migrate: { _ in })
        migrator2.registerMigration("3", migrate: { _ in })
        
        try XCTAssertEqual(dbQueue.read(migrator2.appliedMigrations), ["1", "3"])
        try XCTAssertEqual(dbQueue.read(migrator2.appliedIdentifiers), ["1", "3"])
        try XCTAssertEqual(dbQueue.read(migrator2.completedMigrations), ["1"])
        try XCTAssertFalse(dbQueue.read(migrator2.hasCompletedMigrations))
        try XCTAssertFalse(dbQueue.read(migrator2.hasBeenSuperseded))
        
        // The new source code migrates the database
        try migrator2.migrate(dbQueue)
        
        try XCTAssertEqual(dbQueue.read(migrator1.appliedMigrations), ["1", "3"])
        try XCTAssertEqual(dbQueue.read(migrator1.appliedIdentifiers), ["1", "2", "3"])
        try XCTAssertEqual(dbQueue.read(migrator1.completedMigrations), ["1", "3"])
        try XCTAssertTrue(dbQueue.read(migrator1.hasCompletedMigrations))
        try XCTAssertTrue(dbQueue.read(migrator1.hasBeenSuperseded))
        
        try XCTAssertEqual(dbQueue.read(migrator2.appliedMigrations), ["1", "2", "3"])
        try XCTAssertEqual(dbQueue.read(migrator2.appliedIdentifiers), ["1", "2", "3"])
        try XCTAssertEqual(dbQueue.read(migrator2.completedMigrations), ["1", "2", "3"])
        try XCTAssertTrue(dbQueue.read(migrator2.hasCompletedMigrations))
        try XCTAssertFalse(dbQueue.read(migrator2.hasBeenSuperseded))
        
        // ---
        // A source code merge appends a migration
        var migrator3 = migrator2
        migrator3.registerMigration("4", migrate: { _ in })
        
        try XCTAssertEqual(dbQueue.read(migrator3.appliedMigrations), ["1", "2", "3"])
        try XCTAssertEqual(dbQueue.read(migrator3.appliedIdentifiers), ["1", "2", "3"])
        try XCTAssertEqual(dbQueue.read(migrator3.completedMigrations), ["1", "2", "3"])
        try XCTAssertFalse(dbQueue.read(migrator3.hasCompletedMigrations))
        try XCTAssertFalse(dbQueue.read(migrator3.hasBeenSuperseded))
        
        // The new source code migrates the database
        try migrator3.migrate(dbQueue)
        
        try XCTAssertEqual(dbQueue.read(migrator1.appliedMigrations), ["1", "3"])
        try XCTAssertEqual(dbQueue.read(migrator1.appliedIdentifiers), ["1", "2", "3", "4"])
        try XCTAssertEqual(dbQueue.read(migrator1.completedMigrations), ["1", "3"])
        try XCTAssertTrue(dbQueue.read(migrator1.hasCompletedMigrations))
        try XCTAssertTrue(dbQueue.read(migrator1.hasBeenSuperseded))
        
        try XCTAssertEqual(dbQueue.read(migrator2.appliedMigrations), ["1", "2", "3"])
        try XCTAssertEqual(dbQueue.read(migrator2.appliedIdentifiers), ["1", "2", "3", "4"])
        try XCTAssertEqual(dbQueue.read(migrator2.completedMigrations), ["1", "2", "3"])
        try XCTAssertTrue(dbQueue.read(migrator2.hasCompletedMigrations))
        try XCTAssertTrue(dbQueue.read(migrator2.hasBeenSuperseded))
        
        try XCTAssertEqual(dbQueue.read(migrator3.appliedMigrations), ["1", "2", "3", "4"])
        try XCTAssertEqual(dbQueue.read(migrator3.appliedIdentifiers), ["1", "2", "3", "4"])
        try XCTAssertEqual(dbQueue.read(migrator3.completedMigrations), ["1", "2", "3", "4"])
        try XCTAssertTrue(dbQueue.read(migrator3.hasCompletedMigrations))
        try XCTAssertFalse(dbQueue.read(migrator3.hasBeenSuperseded))
    }
    
    // Regression test for https://github.com/groue/GRDB.swift/issues/741
    func testEraseDatabaseOnSchemaChangeDoesNotDeadLockOnTargetQueue() throws {
        dbConfiguration.targetQueue = DispatchQueue(label: "target")
        let dbQueue = try makeDatabaseQueue()
        
        var migrator = DatabaseMigrator()
        migrator.eraseDatabaseOnSchemaChange = true
        migrator.registerMigration("1", migrate: { _ in })
        try migrator.migrate(dbQueue)
        
        migrator.registerMigration("2", migrate: { _ in })
        try migrator.migrate(dbQueue)
    }
    
    // Regression test for https://github.com/groue/GRDB.swift/issues/741
    func testEraseDatabaseOnSchemaChangeDoesNotDeadLockOnWriteTargetQueue() throws {
        dbConfiguration.writeTargetQueue = DispatchQueue(label: "writerTarget")
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
        
        // ... unless database gets erased
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
                t.column("score", .integer) // <- schema change
            }
            try db.execute(sql: "INSERT INTO player (id, name, score) VALUES (NULL, testFunction(), 1000)")
        }
        migrator2.registerMigration("2") { db in
            try db.execute(sql: "INSERT INTO player (id, name, score) VALUES (NULL, testFunction(), 2000)")
        }
        
        // Apply 1st migrator
        dbConfiguration.prepareDatabase { db in
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
        
        // ... unless database gets erased
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
    
    func testMigrations() throws {
        do {
            let migrator = DatabaseMigrator()
            XCTAssertEqual(migrator.migrations, [])
        }
        do {
            var migrator = DatabaseMigrator()
            migrator.registerMigration("foo", migrate: { _ in })
            XCTAssertEqual(migrator.migrations, ["foo"])
        }
        do {
            var migrator = DatabaseMigrator()
            migrator.registerMigration("foo", migrate: { _ in })
            migrator.registerMigration("bar", migrate: { _ in })
            XCTAssertEqual(migrator.migrations, ["foo", "bar"])
        }
    }
    
    func testMigrationForeignKeyChecks() throws {
        let foreignKeyViolation = """
            CREATE TABLE parent(id INTEGER NOT NULL PRIMARY KEY);
            CREATE TABLE child(parentId INTEGER REFERENCES parent(id));
            INSERT INTO child (parentId) VALUES (1);
            """
        let transientForeignKeyViolation = """
            CREATE TABLE parent(id INTEGER NOT NULL PRIMARY KEY);
            CREATE TABLE child(parentId INTEGER REFERENCES parent(id));
            INSERT INTO child (parentId) VALUES (1);
            DELETE FROM child;
            """
        
        // Foreign key violation
        do {
            var migrator = DatabaseMigrator()
            migrator.registerMigration("A") { db in
                try db.execute(sql: foreignKeyViolation)
            }
            let dbQueue = try makeDatabaseQueue()
            do {
                try migrator.migrate(dbQueue)
                XCTFail("Expected error")
            } catch DatabaseError.SQLITE_CONSTRAINT_FOREIGNKEY { }
            try dbQueue.read { try $0.checkForeignKeys() }
        }
        do {
            var migrator = DatabaseMigrator()
            migrator.registerMigration("A", foreignKeyChecks: .immediate) { db in
                try db.execute(sql: foreignKeyViolation)
            }
            let dbQueue = try makeDatabaseQueue()
            do {
                try migrator.migrate(dbQueue)
                XCTFail("Expected error")
            } catch DatabaseError.SQLITE_CONSTRAINT_FOREIGNKEY { }
            try dbQueue.read { try $0.checkForeignKeys() }
        }
        
        // Transient foreign key violation
        do {
            var migrator = DatabaseMigrator()
            migrator.registerMigration("A") { db in
                try db.execute(sql: transientForeignKeyViolation)
            }
            let dbQueue = try makeDatabaseQueue()
            try migrator.migrate(dbQueue)
            try dbQueue.read { try $0.checkForeignKeys() }
        }
        do {
            var migrator = DatabaseMigrator()
            migrator.registerMigration("A", foreignKeyChecks: .immediate) { db in
                try db.execute(sql: transientForeignKeyViolation)
            }
            let dbQueue = try makeDatabaseQueue()
            do {
                try migrator.migrate(dbQueue)
                XCTFail("Expected error")
            } catch DatabaseError.SQLITE_CONSTRAINT_FOREIGNKEY { }
            try dbQueue.read { try $0.checkForeignKeys() }
        }
    }
    
    func testDisablingDeferredForeignKeyChecks() throws {
        let foreignKeyViolation = """
            CREATE TABLE parent(id INTEGER NOT NULL PRIMARY KEY);
            CREATE TABLE child(parentId INTEGER REFERENCES parent(id));
            INSERT INTO child (parentId) VALUES (1);
            """
        let transientForeignKeyViolation = """
            CREATE TABLE parent(id INTEGER NOT NULL PRIMARY KEY);
            CREATE TABLE child(parentId INTEGER REFERENCES parent(id));
            INSERT INTO child (parentId) VALUES (1);
            DELETE FROM child;
            """
        
        // Foreign key violation
        do {
            var migrator = DatabaseMigrator().disablingDeferredForeignKeyChecks()
            migrator.registerMigration("A") { db in
                try db.execute(sql: foreignKeyViolation)
            }
            let dbQueue = try makeDatabaseQueue()
            try migrator.migrate(dbQueue)
            do {
                // The unique opportunity for corrupt data!
                try dbQueue.read { try $0.checkForeignKeys() }
                XCTFail("Expected foreign key violation")
            } catch DatabaseError.SQLITE_CONSTRAINT_FOREIGNKEY { }
        }
        do {
            var migrator = DatabaseMigrator().disablingDeferredForeignKeyChecks()
            migrator.registerMigration("A", foreignKeyChecks: .immediate) { db in
                try db.execute(sql: foreignKeyViolation)
            }
            let dbQueue = try makeDatabaseQueue()
            do {
                try migrator.migrate(dbQueue)
                XCTFail("Expected error")
            } catch DatabaseError.SQLITE_CONSTRAINT_FOREIGNKEY { }
            try dbQueue.read { try $0.checkForeignKeys() }
        }
        
        // Transient foreign key violation
        do {
            var migrator = DatabaseMigrator().disablingDeferredForeignKeyChecks()
            migrator.registerMigration("A") { db in
                try db.execute(sql: transientForeignKeyViolation)
            }
            let dbQueue = try makeDatabaseQueue()
            try migrator.migrate(dbQueue)
            try dbQueue.read { try $0.checkForeignKeys() }
        }
        do {
            var migrator = DatabaseMigrator().disablingDeferredForeignKeyChecks()
            migrator.registerMigration("A", foreignKeyChecks: .immediate) { db in
                try db.execute(sql: transientForeignKeyViolation)
            }
            let dbQueue = try makeDatabaseQueue()
            do {
                try migrator.migrate(dbQueue)
                XCTFail("Expected error")
            } catch DatabaseError.SQLITE_CONSTRAINT_FOREIGNKEY { }
            try dbQueue.read { try $0.checkForeignKeys() }
        }
    }
    
    func test_disablingDeferredForeignKeyChecks_applies_to_newly_registered_migrations_only() throws {
        let foreignKeyViolation = """
            CREATE TABLE parent(id INTEGER NOT NULL PRIMARY KEY);
            CREATE TABLE child(parentId INTEGER REFERENCES parent(id));
            INSERT INTO child (parentId) VALUES (1);
            """
        
        var migrator = DatabaseMigrator()
        migrator.registerMigration("A") { db in
            try db.execute(sql: foreignKeyViolation)
        }
        migrator = migrator.disablingDeferredForeignKeyChecks()
        migrator.registerMigration("B") { db in
            XCTFail("Should not run")
        }
        let dbQueue = try makeDatabaseQueue()
        do {
            try migrator.migrate(dbQueue)
            XCTFail("Expected error")
        } catch DatabaseError.SQLITE_CONSTRAINT_FOREIGNKEY { }
    }
}
