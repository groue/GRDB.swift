import XCTest
#if GRDBCUSTOMSQLITE
@testable import GRDBCustomSQLite
#else
@testable import GRDB
#endif

class DatabaseSnapshotTests: GRDBTestCase {
    
    /// A helper class
    private class Counter {
        let dbPool: DatabasePool
        init(dbPool: DatabasePool) throws {
            self.dbPool = dbPool
            try dbPool.write { db in
                try db.execute(sql: "CREATE TABLE counter(id INTEGER PRIMARY KEY)")
            }
        }
        
        func increment(_ db: Database) throws {
            try db.execute(sql: "INSERT INTO counter DEFAULT VALUES")
        }
        
        func value(_ db: Database) throws -> Int {
            return try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM counter")!
        }
    }
    
    // MARK: - Creation
    
    func testSnapshotCanReadBeforeDatabaseModification() throws {
        let dbPool = try makeDatabasePool()
        let snapshot = try dbPool.makeSnapshot()
        try XCTAssertEqual(snapshot.read { try $0.tableExists("foo") }, false)
    }
    
    func testSnapshotCreatedFromMainQueueCanRead() throws {
        let dbPool = try makeDatabasePool()
        let counter = try Counter(dbPool: dbPool)
        let snapshot = try dbPool.makeSnapshot()
        try XCTAssertEqual(snapshot.read(counter.value), 0)
    }
    
    func testSnapshotCreatedFromWriterOutsideOfTransactionCanRead() throws {
        let dbPool = try makeDatabasePool()
        let counter = try Counter(dbPool: dbPool)
        let snapshot = try dbPool.writeWithoutTransaction { db -> DatabaseSnapshot in
            XCTAssertFalse(db.isInsideTransaction)
            let snapshot = try dbPool.makeSnapshot()
            try counter.increment(db)
            return snapshot
        }
        try XCTAssertEqual(snapshot.read(counter.value), 0)
    }
    
    func testSnapshotCreatedFromReaderTransactionCanRead() throws {
        let dbPool = try makeDatabasePool()
        let counter = try Counter(dbPool: dbPool)
        let snapshot = try dbPool.read { db -> DatabaseSnapshot in
            XCTAssertTrue(db.isInsideTransaction)
            return try dbPool.makeSnapshot()
        }
        try XCTAssertEqual(snapshot.read(counter.value), 0)
    }
    
    func testSnapshotCreatedFromReaderOutsideOfTransactionCanRead() throws {
        let dbPool = try makeDatabasePool()
        let counter = try Counter(dbPool: dbPool)
        let snapshot = try dbPool.unsafeRead { db -> DatabaseSnapshot in
            XCTAssertFalse(db.isInsideTransaction)
            return try dbPool.makeSnapshot()
        }
        try XCTAssertEqual(snapshot.read(counter.value), 0)
    }
    
    func testSnapshotCreatedFromTransactionObserver() throws {
        // Creating a snapshot from a didCommit callback is an important use
        // case. But we know SQLite snapshots created with
        // sqlite3_snapshot_get() require a transaction. This means that
        // creating a snapshot will open a transaction. We must make sure this
        // transaction does not create any deadlock of reentrancy issue with
        // transaction observers.
        class Observer: TransactionObserver {
            let dbPool: DatabasePool
            var snapshot: DatabaseSnapshot
            init(dbPool: DatabasePool, snapshot: DatabaseSnapshot) {
                self.dbPool = dbPool
                self.snapshot = snapshot
            }
            
            func observes(eventsOfKind eventKind: DatabaseEventKind) -> Bool { return false }
            func databaseDidChange(with event: DatabaseEvent) { }
            func databaseDidCommit(_ db: Database) {
                snapshot = try! dbPool.makeSnapshot()
            }
            func databaseDidRollback(_ db: Database) { }
        }
        let dbPool = try makeDatabasePool()
        let counter = try Counter(dbPool: dbPool)
        let observer = try Observer(dbPool: dbPool, snapshot: dbPool.makeSnapshot())
        dbPool.add(transactionObserver: observer)
        try XCTAssertEqual(observer.snapshot.read(counter.value), 0)
        try dbPool.write(counter.increment)
        try XCTAssertEqual(observer.snapshot.read(counter.value), 1)
    }
    
    // MARK: - Behavior
    
    func testSnapshotIsReadOnly() throws {
        let dbPool = try makeDatabasePool()
        let snapshot = try dbPool.makeSnapshot()
        do {
            try snapshot.read { db in
                try db.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY")
            }
            XCTFail("Expected error")
        } catch is DatabaseError { }
    }
    
    func testSnapshotIsImmutable() throws {
        let dbPool = try makeDatabasePool()
        let counter = try Counter(dbPool: dbPool)
        try dbPool.writeWithoutTransaction { db in
            try counter.increment(db)
            let snapshot = try dbPool.makeSnapshot()
            try counter.increment(db)
            try XCTAssertEqual(counter.value(db), 2)
            try XCTAssertEqual(snapshot.read(counter.value), 1)
            try XCTAssertEqual(dbPool.read(counter.value), 2)
            try XCTAssertEqual(snapshot.read(counter.value), 1)
            try XCTAssertEqual(counter.value(db), 2)
            try XCTAssertEqual(dbPool.read(counter.value), 2)
        }
    }
    
    // MARK: - Functions
    
    func testSnapshotInheritPoolFunctions() throws {
        let dbPool = try makeDatabasePool()
        let function = DatabaseFunction("foo", argumentCount: 0, pure: true) { _ in return "foo" }
        dbPool.add(function: function)
        
        let snapshot = try dbPool.makeSnapshot()
        try snapshot.read { db in
            try XCTAssertEqual(String.fetchOne(db, sql: "SELECT foo()")!, "foo")
        }
    }
    
    func testSnapshotFunctions() throws {
        let dbPool = try makeDatabasePool()
        let snapshot = try dbPool.makeSnapshot()
        let function = DatabaseFunction("foo", argumentCount: 0, pure: true) { _ in return "foo" }
        snapshot.add(function: function)
        try snapshot.read { db in
            try XCTAssertEqual(String.fetchOne(db, sql: "SELECT foo()")!, "foo")
        }
    }
    
    // MARK: - Collations
    
    func testSnapshotInheritPoolCollations() throws {
        let dbPool = try makeDatabasePool()
        let collation = DatabaseCollation("reverse") { (string1, string2) in
            return (string1 == string2) ? .orderedSame : ((string1 < string2) ? .orderedDescending : .orderedAscending)
        }
        dbPool.add(collation: collation)
        
        try dbPool.write { db in
            try db.execute(sql: "CREATE TABLE items (text TEXT)")
            try db.execute(sql: "INSERT INTO items (text) VALUES ('a')")
            try db.execute(sql: "INSERT INTO items (text) VALUES ('b')")
            try db.execute(sql: "INSERT INTO items (text) VALUES ('c')")
        }
        
        let snapshot = try dbPool.makeSnapshot()
        try snapshot.read { db in
            XCTAssertEqual(try String.fetchAll(db, sql: "SELECT text FROM items ORDER BY text COLLATE reverse"), ["c", "b", "a"])
        }
    }
    
    func testSnapshotCollations() throws {
        let dbPool = try makeDatabasePool()
        try dbPool.write { db in
            try db.execute(sql: "CREATE TABLE items (text TEXT)")
            try db.execute(sql: "INSERT INTO items (text) VALUES ('a')")
            try db.execute(sql: "INSERT INTO items (text) VALUES ('b')")
            try db.execute(sql: "INSERT INTO items (text) VALUES ('c')")
        }
        
        let snapshot = try dbPool.makeSnapshot()
        let collation = DatabaseCollation("reverse") { (string1, string2) in
            return (string1 == string2) ? .orderedSame : ((string1 < string2) ? .orderedDescending : .orderedAscending)
        }
        snapshot.add(collation: collation)
        try snapshot.read { db in
            XCTAssertEqual(try String.fetchAll(db, sql: "SELECT text FROM items ORDER BY text COLLATE reverse"), ["c", "b", "a"])
        }
    }
    
    // MARK: - Concurrency
    
    func testDefaultLabel() throws {
        let dbPool = try makeDatabasePool()
        
        let snapshot1 = try dbPool.makeSnapshot()
        snapshot1.unsafeRead { db in
            XCTAssertEqual(db.configuration.label, nil)
            
            // This test CAN break in future releases: the dispatch queue labels
            // are documented to be a debug-only tool.
            let label = String(utf8String: __dispatch_queue_get_label(nil))
            XCTAssertEqual(label, "GRDB.DatabasePool.snapshot.1")
        }
        
        let snapshot2 = try dbPool.makeSnapshot()
        snapshot2.unsafeRead { db in
            XCTAssertEqual(db.configuration.label, nil)
            
            // This test CAN break in future releases: the dispatch queue labels
            // are documented to be a debug-only tool.
            let label = String(utf8String: __dispatch_queue_get_label(nil))
            XCTAssertEqual(label, "GRDB.DatabasePool.snapshot.2")
        }
    }
    
    func testCustomLabel() throws {
        dbConfiguration.label = "Toreador"
        let dbPool = try makeDatabasePool()
        
        let snapshot1 = try dbPool.makeSnapshot()
        snapshot1.unsafeRead { db in
            XCTAssertEqual(db.configuration.label, "Toreador")
            
            // This test CAN break in future releases: the dispatch queue labels
            // are documented to be a debug-only tool.
            let label = String(utf8String: __dispatch_queue_get_label(nil))
            XCTAssertEqual(label, "Toreador.snapshot.1")
        }
        
        let snapshot2 = try dbPool.makeSnapshot()
        snapshot2.unsafeRead { db in
            XCTAssertEqual(db.configuration.label, "Toreador")
            
            // This test CAN break in future releases: the dispatch queue labels
            // are documented to be a debug-only tool.
            let label = String(utf8String: __dispatch_queue_get_label(nil))
            XCTAssertEqual(label, "Toreador.snapshot.2")
        }
    }
    
    // MARK: - Checkpoints
    
    func testAutomaticCheckpointDoesNotInvalidateSnapshot() throws {
        let dbPool = try makeDatabasePool()
        let counter = try Counter(dbPool: dbPool)
        try dbPool.write(counter.increment)
        let snapshot = try dbPool.makeSnapshot()
        try XCTAssertEqual(snapshot.read(counter.value), 1)
        try dbPool.writeWithoutTransaction { db in
            // 1000 is enough to trigger automatic snapshot
            for _ in 0..<1000 {
                try counter.increment(db)
            }
        }
        try XCTAssertEqual(snapshot.read(counter.value), 1)
    }
    
    func testPassiveCheckpointDoesNotInvalidateSnapshot() throws {
        let dbPool = try makeDatabasePool()
        let counter = try Counter(dbPool: dbPool)
        try dbPool.write(counter.increment)
        let snapshot = try dbPool.makeSnapshot()
        try? dbPool.checkpoint(.passive) // ignore if error or not, that's not the point
        try XCTAssertEqual(snapshot.read(counter.value), 1)
        try dbPool.write(counter.increment)
        try XCTAssertEqual(snapshot.read(counter.value), 1)
    }
    
    func testFullCheckpointDoesNotInvalidateSnapshot() throws {
        let dbPool = try makeDatabasePool()
        let counter = try Counter(dbPool: dbPool)
        try dbPool.write(counter.increment)
        let snapshot = try dbPool.makeSnapshot()
        try? dbPool.checkpoint(.full) // ignore if error or not, that's not the point
        try XCTAssertEqual(snapshot.read(counter.value), 1)
        try dbPool.write(counter.increment)
        try XCTAssertEqual(snapshot.read(counter.value), 1)
    }
    
    func testRestartCheckpointDoesNotInvalidateSnapshot() throws {
        let dbPool = try makeDatabasePool()
        let counter = try Counter(dbPool: dbPool)
        try dbPool.write(counter.increment)
        let snapshot = try dbPool.makeSnapshot()
        try? dbPool.checkpoint(.restart) // ignore if error or not, that's not the point
        try XCTAssertEqual(snapshot.read(counter.value), 1)
        try dbPool.write(counter.increment)
        try XCTAssertEqual(snapshot.read(counter.value), 1)
    }
    
    func testTruncateCheckpointDoesNotInvalidateSnapshot() throws {
        let dbPool = try makeDatabasePool()
        let counter = try Counter(dbPool: dbPool)
        try dbPool.write(counter.increment)
        let snapshot = try dbPool.makeSnapshot()
        try? dbPool.checkpoint(.truncate) // ignore if error or not, that's not the point
        try XCTAssertEqual(snapshot.read(counter.value), 1)
        try dbPool.write(counter.increment)
        try XCTAssertEqual(snapshot.read(counter.value), 1)
    }
    
    // MARK: - Schema Cache
    
    func testSnapshotSchemaCache() throws {
        let dbPool = try makeDatabasePool()
        try dbPool.write { db in
            try db.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY)")
        }
        let snapshot = try dbPool.makeSnapshot()
        try snapshot.read { db in
            // Schema cache is updated
            XCTAssertNil(db.schemaCache.primaryKey("t"))
            _ = try db.primaryKey("t")
            XCTAssertNotNil(db.schemaCache.primaryKey("t"))
        }
        snapshot.read { db in
            // Schema cache is not cleared between reads
            XCTAssertNotNil(db.schemaCache.primaryKey("t"))
        }
    }
}
