#if SQLITE_ENABLE_SNAPSHOT || (!GRDBCUSTOMSQLITE && !GRDBCIPHER)
import XCTest
import GRDB

// test create from non-wal (read-only) snapshot
final class DatabaseSnapshotPoolTests: GRDBTestCase {
    /// A helper type
    private struct Counter {
        init(dbPool: DatabasePool) throws {
            try dbPool.write { db in
                try db.execute(sql: "CREATE TABLE counter(id INTEGER PRIMARY KEY)")
            }
        }
        
        func increment(_ db: Database) throws {
            try db.execute(sql: "INSERT INTO counter DEFAULT VALUES")
        }
        
        func value(_ db: Database) throws -> Int {
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM counter")!
        }
    }
    
    func test_creation_from_new_DatabasePool() throws {
        _ = try makeDatabasePool().makeSnapshotPool()
    }
    
    func test_creation_from_non_WAL_DatabasePool() throws {
        let dbQueue = try makeDatabaseQueue()
        
        var config = Configuration()
        config.readonly = true
        let dbPool = try DatabasePool(path: dbQueue.path, configuration: config)
        
        do {
            _ = try dbPool.makeSnapshotPool()
            XCTFail("Expected error")
        } catch DatabaseError.SQLITE_ERROR { }
    }
    
    func test_creation_from_DatabasePool_write_and_read() throws {
        let dbPool = try makeDatabasePool()
        let counter = try Counter(dbPool: dbPool) // 0
        try dbPool.write(counter.increment)       // 1
        // We can't open a DatabaseSnapshotPool from an IMMEDIATE
        // transaction (as documented by sqlite3_snapshot_get). So we
        // force a DEFERRED transaction:
        var snapshot: DatabaseSnapshotPool!
        try dbPool.writeInTransaction(.deferred) { db in
            snapshot = try DatabaseSnapshotPool(db) // locked at 1
            return .commit
        }
        try dbPool.write(counter.increment)       // 2
        
        try XCTAssertEqual(dbPool.read(counter.value), 2)
        try XCTAssertEqual(snapshot.read(counter.value), 1)
        // Reuse the last connection
        try XCTAssertEqual(dbPool.read(counter.value), 2)
    }
    
    func test_creation_from_DatabasePool_writeWithoutTransaction_and_read() throws {
        let dbPool = try makeDatabasePool()
        let counter = try Counter(dbPool: dbPool) // 0
        try dbPool.write(counter.increment)       // 1
        let snapshot = try dbPool.writeWithoutTransaction { db in
            try DatabaseSnapshotPool(db)          // locked at 1
        }
        try dbPool.write(counter.increment)       // 2
        
        try XCTAssertEqual(dbPool.read(counter.value), 2)
        try XCTAssertEqual(snapshot.read(counter.value), 1)
        // Reuse the last connection
        try XCTAssertEqual(dbPool.read(counter.value), 2)
    }
    
    func test_creation_from_DatabasePool_uncommitted_write() throws {
        let dbPool = try makeDatabasePool()
        do {
            try dbPool.write { db in
                try db.execute(sql: "CREATE TABLE t(a)")
                _ = try DatabaseSnapshotPool(db)
            }
            XCTFail("Expected error")
        } catch DatabaseError.SQLITE_ERROR { }
    }
    
    func test_creation_from_DatabasePool_read_and_read() throws {
        let dbPool = try makeDatabasePool()
        let counter = try Counter(dbPool: dbPool) // 0
        try dbPool.write(counter.increment)       // 1
        let snapshot = try dbPool.read { db in try DatabaseSnapshotPool(db) } // locked at 1
        try dbPool.write(counter.increment)       // 2
        
        try XCTAssertEqual(dbPool.read(counter.value), 2)
        try XCTAssertEqual(snapshot.read(counter.value), 1)
        // Reuse the last connection
        try XCTAssertEqual(dbPool.read(counter.value), 2)
    }

    func test_creation_from_DatabasePool_unsafeRead_and_read() throws {
        let dbPool = try makeDatabasePool()
        let counter = try Counter(dbPool: dbPool) // 0
        try dbPool.write(counter.increment)       // 1
        let snapshot = try dbPool.unsafeRead { db in try DatabaseSnapshotPool(db) } // locked at 1
        try dbPool.write(counter.increment)       // 2
        
        try XCTAssertEqual(dbPool.read(counter.value), 2)
        try XCTAssertEqual(snapshot.read(counter.value), 1)
        // Reuse the last connection
        try XCTAssertEqual(dbPool.read(counter.value), 2)
    }

    func test_read() throws {
        let dbPool = try makeDatabasePool()
        let counter = try Counter(dbPool: dbPool)    // 0
        try dbPool.write(counter.increment)          // 1
        let snapshot = try dbPool.makeSnapshotPool() // locked at 1
        try dbPool.write(counter.increment)          // 2
        
        try XCTAssertEqual(dbPool.read(counter.value), 2)
        try XCTAssertEqual(snapshot.read(counter.value), 1)
        // Reuse the last connection
        try XCTAssertEqual(dbPool.read(counter.value), 2)
    }
    
    func test_discarded_transaction() throws {
        let dbPool = try makeDatabasePool()
        let counter = try Counter(dbPool: dbPool)    // 0
        try dbPool.write(counter.increment)          // 1
        let snapshot = try dbPool.makeSnapshotPool() // locked at 1
        try dbPool.write(counter.increment)          // 2
        
        try snapshot.read { db in
            try XCTAssertEqual(counter.value(db), 1)
            try db.commit() // lose snapshot
            try XCTAssertEqual(counter.value(db), 2)
        }
        
        // Try to invalidate the snapshot
        try? dbPool.writeWithoutTransaction { _ = try $0.checkpoint(.truncate) }
        
        // Snapshot is not lost, and previous connection is not reused.
        try XCTAssertEqual(snapshot.read(counter.value), 1)
    }
    
    func test_replaced_transaction() throws {
        let dbPool = try makeDatabasePool()
        let counter = try Counter(dbPool: dbPool)    // 0
        try dbPool.write(counter.increment)          // 1
        let snapshot = try dbPool.makeSnapshotPool() // locked at 1
        try dbPool.write(counter.increment)          // 2
        
        try snapshot.read { db in
            try XCTAssertEqual(counter.value(db), 1)
            try db.commit() // lose snapshot
            try db.beginTransaction()
            try XCTAssertEqual(counter.value(db), 2)
        }
        
        // Try to invalidate the snapshot
        try? dbPool.writeWithoutTransaction { _ = try $0.checkpoint(.truncate) }
        
        // Snapshot is not lost, and previous connection is not reused.
        try XCTAssertEqual(snapshot.read(counter.value), 1)
    }
    
    func test_concurrent_read() throws {
        let dbPool = try makeDatabasePool()
        let counter = try Counter(dbPool: dbPool)    // 0
        try dbPool.write(counter.increment)          // 1
        let snapshot = try dbPool.makeSnapshotPool() // locked at 1
        try dbPool.write(counter.increment)          // 2
        
        // Block 1                      Block 2
        // snapshot.read {
        // SELECT COUNT(*) FROM counter
        // >
        let s1 = DispatchSemaphore(value: 0)
        //                              snapshot.read {
        //                              SELECT COUNT(*) FROM counter
        //                              <
        let s2 = DispatchSemaphore(value: 0)
        // end                          end
        // }
        
        let block1: () -> Void = {
            try! snapshot.read { db -> Void in
                try XCTAssertEqual(counter.value(db), 1)
                s1.signal()
                _ = s2.wait(timeout: .distantFuture)
            }
        }
        let block2: () -> Void = {
            _ = s1.wait(timeout: .distantFuture)
            try! snapshot.read { db -> Void in
                try XCTAssertEqual(counter.value(db), 1)
                s2.signal()
            }
        }
        let blocks = [block1, block2]
        DispatchQueue.concurrentPerform(iterations: blocks.count) { index in
            blocks[index]()
        }
    }
    
    func test_unsafeRead() throws {
        let dbPool = try makeDatabasePool()
        let counter = try Counter(dbPool: dbPool)    // 0
        try dbPool.write(counter.increment)          // 1
        let snapshot = try dbPool.makeSnapshotPool() // locked at 1
        try dbPool.write(counter.increment)          // 2
        
        try XCTAssertEqual(dbPool.read(counter.value), 2)
        try XCTAssertEqual(snapshot.unsafeRead(counter.value), 1)
        // Reuse the last connection
        try XCTAssertEqual(dbPool.read(counter.value), 2)
    }
    
    func test_unsafeReentrantRead() throws {
        let dbPool = try makeDatabasePool()
        let counter = try Counter(dbPool: dbPool)    // 0
        try dbPool.write(counter.increment)          // 1
        let snapshot = try dbPool.makeSnapshotPool() // locked at 1
        try dbPool.write(counter.increment)          // 2
        
        try XCTAssertEqual(dbPool.read(counter.value), 2)
        try XCTAssertEqual(snapshot.unsafeReentrantRead { _ in try snapshot.unsafeReentrantRead(counter.value) }, 1)
        // Reuse the last connection
        try XCTAssertEqual(dbPool.read(counter.value), 2)
    }
    
    func test_read_async() async throws {
        let dbPool = try makeDatabasePool()
        let counter = try Counter(dbPool: dbPool)            // 0
        try await dbPool.write { try counter.increment($0) } // 1
        let snapshot = try dbPool.makeSnapshotPool()         // locked at 1
        try await dbPool.write { try counter.increment($0) } // 2
        
        do {
            let count = try await dbPool.read { try counter.value($0) }
            XCTAssertEqual(count, 2)
        }
        do {
            let count = try await snapshot.read { try counter.value($0) }
            XCTAssertEqual(count, 1)
        }
        do {
            // Reuse the last connection
            let count = try await dbPool.read { try counter.value($0) }
            XCTAssertEqual(count, 2)
        }
    }
    
    func testPassiveCheckpointDoesNotInvalidateSnapshotPool() throws {
        let dbPool = try makeDatabasePool()
        let counter = try Counter(dbPool: dbPool)    // 0
        try dbPool.write(counter.increment)          // 1
        let snapshot = try dbPool.makeSnapshotPool() // locked at 1
        try? dbPool.writeWithoutTransaction { _ = try $0.checkpoint(.passive) } // ignore if error or not, that's not the point
        try XCTAssertEqual(snapshot.read(counter.value), 1)
        try dbPool.write(counter.increment)          // 2
        try XCTAssertEqual(snapshot.read(counter.value), 1)
    }
    
    func testFullCheckpointDoesNotInvalidateSnapshotPool() throws {
        let dbPool = try makeDatabasePool()
        let counter = try Counter(dbPool: dbPool)    // 0
        try dbPool.write(counter.increment)          // 1
        let snapshot = try dbPool.makeSnapshotPool() // locked at 1
        try? dbPool.writeWithoutTransaction { _ = try $0.checkpoint(.full) } // ignore if error or not, that's not the point
        try XCTAssertEqual(snapshot.read(counter.value), 1)
        try dbPool.write(counter.increment)          // 2
        try XCTAssertEqual(snapshot.read(counter.value), 1)
    }
    
    func testRestartCheckpointDoesNotInvalidateSnapshotPool() throws {
        let dbPool = try makeDatabasePool()
        let counter = try Counter(dbPool: dbPool)    // 0
        try dbPool.write(counter.increment)          // 1
        let snapshot = try dbPool.makeSnapshotPool() // locked at 1
        try? dbPool.writeWithoutTransaction { _ = try $0.checkpoint(.restart) } // ignore if error or not, that's not the point
        try XCTAssertEqual(snapshot.read(counter.value), 1)
        try dbPool.write(counter.increment)          // 2
        try XCTAssertEqual(snapshot.read(counter.value), 1)
    }
    
    func testTruncateCheckpointDoesNotInvalidateSnapshotPool() throws {
        let dbPool = try makeDatabasePool()
        let counter = try Counter(dbPool: dbPool)    // 0
        try dbPool.write(counter.increment)          // 1
        let snapshot = try dbPool.makeSnapshotPool() // locked at 1
        try? dbPool.writeWithoutTransaction { _ = try $0.checkpoint(.truncate) } // ignore if error or not, that's not the point
        try XCTAssertEqual(snapshot.read(counter.value), 1)
        try dbPool.write(counter.increment)          // 2
        try XCTAssertEqual(snapshot.read(counter.value), 1)
    }
}
#endif
