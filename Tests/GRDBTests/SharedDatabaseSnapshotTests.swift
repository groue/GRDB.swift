#if SQLITE_ENABLE_SNAPSHOT
import XCTest
#if GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class SharedDatabaseSnapshotTests: GRDBTestCase {
    
    private class Counter {
        let dbPool: DatabasePool
        init(dbPool: DatabasePool) throws {
            self.dbPool = dbPool
            try dbPool.write { db in
                try db.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY)")
            }
        }
        
        func increment(_ db: Database) throws {
            try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
        }
        
        func fetch(_ db: Database) throws -> Int {
            return try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM t")!
        }
    }
    
    func testSnapshotIsReadOnly() throws {
        let dbPool = try makeDatabasePool()
        let snapshot = try dbPool.makeSharedSnapshot()
        do {
            try snapshot.read { db in
                try db.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY")
            }
            XCTFail("Expected error")
        } catch is DatabaseError {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testSnapshotSeesLatestTransaction() throws {
        let dbPool = try makeDatabasePool()
        let counter = try Counter(dbPool: dbPool)
        try dbPool.writeWithoutTransaction { db in
            try counter.increment(db)
            let snapshot = try dbPool.makeSharedSnapshot()
            try counter.increment(db)
            try XCTAssertEqual(counter.fetch(db), 2)
            try XCTAssertEqual(snapshot.read(counter.fetch), 1)
            try XCTAssertEqual(dbPool.read(counter.fetch), 2)
            try XCTAssertEqual(snapshot.read(counter.fetch), 1)
            try XCTAssertEqual(counter.fetch(db), 2)
            try XCTAssertEqual(dbPool.read(counter.fetch), 2)
        }
    }
    
    func testSnapshotCreatedOutsideOfWriterQueue() throws {
        let dbPool = try makeDatabasePool()
        let counter = try Counter(dbPool: dbPool)
        try dbPool.write(counter.increment)
        let snapshot = try dbPool.makeSharedSnapshot()
        try XCTAssertEqual(snapshot.read(counter.fetch), 1)
        try dbPool.write { db in
            try counter.increment(db)
            try XCTAssertEqual(counter.fetch(db), 2)
        }
        try XCTAssertEqual(snapshot.read(counter.fetch), 1)
    }
    
    func testCreateSharedSnapshotFromTransactionObserver() throws {
        class Observer: TransactionObserver {
            let dbPool: DatabasePool
            var snapshot: SharedDatabaseSnapshot
            init(dbPool: DatabasePool, snapshot: SharedDatabaseSnapshot) {
                self.dbPool = dbPool
                self.snapshot = snapshot
            }
            
            func observes(eventsOfKind eventKind: DatabaseEventKind) -> Bool { return false }
            func databaseDidChange(with event: DatabaseEvent) { }
            func databaseDidCommit(_ db: Database) {
                // Creating a snapshot from a didCommit callback is an important
                // use case. But we know SQLite snapshots created with
                // sqlite3_snapshot_get() require a transaction. This means that
                // creating a snapshot will open a transaction. We must make
                // sure it does not create any deadlock of reentrancy issue.
                snapshot = try! dbPool.makeSharedSnapshot()
            }
            func databaseDidRollback(_ db: Database) { }
        }
        let dbPool = try makeDatabasePool()
        let counter = try Counter(dbPool: dbPool)
        let observer = try Observer(dbPool: dbPool, snapshot: dbPool.makeSharedSnapshot())
        dbPool.add(transactionObserver: observer)
        try XCTAssertEqual(observer.snapshot.read(counter.fetch), 0)
        try dbPool.write(counter.increment)
        try XCTAssertEqual(observer.snapshot.read(counter.fetch), 1)
    }

    func testSnapshotInheritPoolFunctions() throws {
        let dbPool = try makeDatabasePool()
        let function = DatabaseFunction("foo", argumentCount: 0, pure: true) { _ in return "foo" }
        dbPool.add(function: function)
        
        let snapshot = try dbPool.makeSharedSnapshot()
        try snapshot.read { db in
            try XCTAssertEqual(String.fetchOne(db, sql: "SELECT foo()")!, "foo")
        }
    }
    
    func testSnapshotFunctions() throws {
        let dbPool = try makeDatabasePool()
        let snapshot = try dbPool.makeSharedSnapshot()
        let function = DatabaseFunction("foo", argumentCount: 0, pure: true) { _ in return "foo" }
        snapshot.add(function: function)
        try snapshot.read { db in
            try XCTAssertEqual(String.fetchOne(db, sql: "SELECT foo()")!, "foo")
        }
    }

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
        
        let snapshot = try dbPool.makeSharedSnapshot()
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
        
        let snapshot = try dbPool.makeSharedSnapshot()
        let collation = DatabaseCollation("reverse") { (string1, string2) in
            return (string1 == string2) ? .orderedSame : ((string1 < string2) ? .orderedDescending : .orderedAscending)
        }
        snapshot.add(collation: collation)
        try snapshot.read { db in
            XCTAssertEqual(try String.fetchAll(db, sql: "SELECT text FROM items ORDER BY text COLLATE reverse"), ["c", "b", "a"])
        }
    }
    
    func testDefaultLabel() throws {
        let dbPool = try makeDatabasePool()
        
        let snapshot1 = try dbPool.makeSharedSnapshot()
        try snapshot1.unsafeRead { db in
            XCTAssertEqual(db.configuration.label, nil)
            
            // This test CAN break in future releases: the dispatch queue labels
            // are documented to be a debug-only tool.
            let label = String(utf8String: __dispatch_queue_get_label(nil))
            XCTAssertEqual(label, "GRDB.DatabasePool.reader.1")
        }
        
        let snapshot2 = try dbPool.makeSharedSnapshot()
        try snapshot2.unsafeRead { db in
            XCTAssertEqual(db.configuration.label, nil)
            
            // This test CAN break in future releases: the dispatch queue labels
            // are documented to be a debug-only tool.
            let label = String(utf8String: __dispatch_queue_get_label(nil))
            XCTAssertEqual(label, "GRDB.DatabasePool.reader.1")
        }
    }
    
    func testCustomLabel() throws {
        dbConfiguration.label = "Toreador"
        let dbPool = try makeDatabasePool()
        
        let snapshot1 = try dbPool.makeSharedSnapshot()
        try snapshot1.unsafeRead { db in
            XCTAssertEqual(db.configuration.label, "Toreador")
            
            // This test CAN break in future releases: the dispatch queue labels
            // are documented to be a debug-only tool.
            let label = String(utf8String: __dispatch_queue_get_label(nil))
            XCTAssertEqual(label, "Toreador.reader.1")
        }
        
        let snapshot2 = try dbPool.makeSharedSnapshot()
        try snapshot2.unsafeRead { db in
            XCTAssertEqual(db.configuration.label, "Toreador")
            
            // This test CAN break in future releases: the dispatch queue labels
            // are documented to be a debug-only tool.
            let label = String(utf8String: __dispatch_queue_get_label(nil))
            XCTAssertEqual(label, "Toreador.reader.1")
        }
    }
    
    func testAutomaticCheckpointDoesNotInvalidatesSnapshot() throws {
        let dbPool = try makeDatabasePool()
        let counter = try Counter(dbPool: dbPool)
        try dbPool.write(counter.increment)
        let snapshot = try dbPool.makeSharedSnapshot()
        try XCTAssertEqual(snapshot.read(counter.fetch), 1)
        try dbPool.writeWithoutTransaction { db in
            for _ in 0..<1000 {
                try counter.increment(db)
            }
        }
        try XCTAssertEqual(snapshot.read(counter.fetch), 1)
    }
    
    func testAutomaticCheckpointCanRunWithoutSnapshot() throws {
        let dbPool = try makeDatabasePool()
        let counter = try Counter(dbPool: dbPool)
        try dbPool.writeWithoutTransaction { db in
            for _ in 0..<1000 {
                try counter.increment(db)
            }
        }
    }
    
    func testPassiveCheckpointDoesNotInvalidatesSnapshot() throws {
        let dbPool = try makeDatabasePool()
        let counter = try Counter(dbPool: dbPool)
        try dbPool.write(counter.increment)
        let snapshot = try dbPool.makeSharedSnapshot()
        try? dbPool.checkpoint(.passive) // ignore if error or not, that's not the point
        try XCTAssertEqual(snapshot.read(counter.fetch), 1)
        try dbPool.write(counter.increment)
        try XCTAssertEqual(snapshot.read(counter.fetch), 1)
    }
    
    func testFullCheckpointDoesNotInvalidatesSnapshot() throws {
        let dbPool = try makeDatabasePool()
        let counter = try Counter(dbPool: dbPool)
        try dbPool.write(counter.increment)
        let snapshot = try dbPool.makeSharedSnapshot()
        try? dbPool.checkpoint(.full) // ignore if error or not, that's not the point
        try XCTAssertEqual(snapshot.read(counter.fetch), 1)
        try dbPool.write(counter.increment)
        try XCTAssertEqual(snapshot.read(counter.fetch), 1)
    }
    
    func testRestartCheckpointDoesNotInvalidatesSnapshot() throws {
        let dbPool = try makeDatabasePool()
        let counter = try Counter(dbPool: dbPool)
        try dbPool.write(counter.increment)
        let snapshot = try dbPool.makeSharedSnapshot()
        do {
            try dbPool.checkpoint(.restart)
            XCTFail("Expected error")
        } catch let error as DatabaseError {
            XCTAssertEqual(error.resultCode, .SQLITE_BUSY)
        }
        try XCTAssertEqual(snapshot.read(counter.fetch), 1)
        try dbPool.write(counter.increment)
        try XCTAssertEqual(snapshot.read(counter.fetch), 1)
    }
    
    func testTruncateCheckpointDoesNotInvalidatesSnapshot() throws {
        let dbPool = try makeDatabasePool()
        let counter = try Counter(dbPool: dbPool)
        try dbPool.write(counter.increment)
        let snapshot = try dbPool.makeSharedSnapshot()
        do {
            try dbPool.checkpoint(.truncate)
            XCTFail("Expected error")
        } catch let error as DatabaseError {
            XCTAssertEqual(error.resultCode, .SQLITE_BUSY)
        }
        try XCTAssertEqual(snapshot.read(counter.fetch), 1)
        try dbPool.write(counter.increment)
        try XCTAssertEqual(snapshot.read(counter.fetch), 1)
    }

    func testConcurrentRead() throws {
        let dbPool = try makeDatabasePool()
        try dbPool.write { db in
            try db.execute(sql: "CREATE TABLE items (id INTEGER PRIMARY KEY)")
            for _ in 0..<3 {
                try db.execute(sql: "INSERT INTO items (id) VALUES (NULL)")
            }
        }
        let snapshot = try dbPool.makeSharedSnapshot()
        
        // Block 1                      Block 2
        // snapshot.read {              snapshot.read {
        // SELECT * FROM items          SELECT * FROM items
        // step                         step
        // >
        let s1 = DispatchSemaphore(value: 0)
        //                              step
        //                              <
        let s2 = DispatchSemaphore(value: 0)
        // step                         step
        // step                         end
        // end                          }
        // }
        
        let block1 = { () in
            try! snapshot.read { db in
                let cursor = try Row.fetchCursor(db, sql: "SELECT * FROM items")
                XCTAssertTrue(try cursor.next() != nil)
                s1.signal()
                _ = s2.wait(timeout: .distantFuture)
                XCTAssertTrue(try cursor.next() != nil)
                XCTAssertTrue(try cursor.next() != nil)
                XCTAssertTrue(try cursor.next() == nil)
            }
        }
        let block2 = { () in
            try! snapshot.read { db in
                let cursor = try Row.fetchCursor(db, sql: "SELECT * FROM items")
                XCTAssertTrue(try cursor.next() != nil)
                _ = s1.wait(timeout: .distantFuture)
                XCTAssertTrue(try cursor.next() != nil)
                s2.signal()
                XCTAssertTrue(try cursor.next() != nil)
                XCTAssertTrue(try cursor.next() == nil)
            }
        }
        let blocks = [block1, block2]
        DispatchQueue.concurrentPerform(iterations: blocks.count) { index in
            blocks[index]()
        }
    }
    
    // TODO: test cache...
}
#endif
