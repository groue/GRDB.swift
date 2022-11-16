#if (compiler(<5.7.1) && (os(macOS) || targetEnvironment(macCatalyst))) || GRDBCIPHER || (GRDBCUSTOMSQLITE && !SQLITE_ENABLE_SNAPSHOT)
#else
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
    
    func test_creation_from_new_database() throws {
        _ = try makeDatabasePool().makeSnapshotPool()
    }
    
    func test_creation_from_non_WAL_database() throws {
        let dbQueue = try makeDatabaseQueue()
        
        var config = Configuration()
        config.readonly = true
        let dbPool = try DatabasePool(path: dbQueue.path, configuration: config)
        
        do {
            _ = try dbPool.makeSnapshotPool()
            XCTFail("Expected error")
        } catch DatabaseError.SQLITE_ERROR { }
    }
    
    func test_read() throws {
        let dbPool = try makeDatabasePool()
        let counter = try Counter(dbPool: dbPool)
        try dbPool.write(counter.increment)
        let snapshot = try dbPool.makeSnapshotPool()
        try dbPool.write(counter.increment)
        
        try XCTAssertEqual(dbPool.read(counter.value), 2)
        try XCTAssertEqual(snapshot.read(counter.value), 1)
        // Reuse the last connection
        try XCTAssertEqual(dbPool.read(counter.value), 2)
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
        let counter = try Counter(dbPool: dbPool)
        
        try dbPool.write(counter.increment)
        let snapshot = try dbPool.makeSnapshotPool()
        try dbPool.write(counter.increment)
        
        try XCTAssertEqual(dbPool.read(counter.value), 2)
        try XCTAssertEqual(snapshot.unsafeRead(counter.value), 1)
        // Reuse the last connection
        try XCTAssertEqual(dbPool.read(counter.value), 2)
    }
    
    func test_unsafeReentrantRead() throws {
        let dbPool = try makeDatabasePool()
        let counter = try Counter(dbPool: dbPool)
        
        try dbPool.write(counter.increment)
        let snapshot = try dbPool.makeSnapshotPool()
        try dbPool.write(counter.increment)
        
        try XCTAssertEqual(dbPool.read(counter.value), 2)
        try XCTAssertEqual(snapshot.unsafeReentrantRead { _ in try snapshot.unsafeReentrantRead(counter.value) }, 1)
        // Reuse the last connection
        try XCTAssertEqual(dbPool.read(counter.value), 2)
    }
    
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func test_read_async() async throws {
        let dbPool = try makeDatabasePool()
        let counter = try Counter(dbPool: dbPool)
        
        try await dbPool.write { try counter.increment($0) }
        let snapshot = try dbPool.makeSnapshotPool()
        try await dbPool.write { try counter.increment($0) }
        
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
        let counter = try Counter(dbPool: dbPool)
        try dbPool.write(counter.increment)
        let snapshot = try dbPool.makeSnapshotPool()
        try? dbPool.writeWithoutTransaction { _ = try $0.checkpoint(.passive) } // ignore if error or not, that's not the point
        try XCTAssertEqual(snapshot.read(counter.value), 1)
        try dbPool.write(counter.increment)
        try XCTAssertEqual(snapshot.read(counter.value), 1)
    }
    
    func testFullCheckpointDoesNotInvalidateSnapshotPool() throws {
        let dbPool = try makeDatabasePool()
        let counter = try Counter(dbPool: dbPool)
        try dbPool.write(counter.increment)
        let snapshot = try dbPool.makeSnapshotPool()
        try? dbPool.writeWithoutTransaction { _ = try $0.checkpoint(.full) } // ignore if error or not, that's not the point
        try XCTAssertEqual(snapshot.read(counter.value), 1)
        try dbPool.write(counter.increment)
        try XCTAssertEqual(snapshot.read(counter.value), 1)
    }
    
    func testRestartCheckpointDoesNotInvalidateSnapshotPool() throws {
        let dbPool = try makeDatabasePool()
        let counter = try Counter(dbPool: dbPool)
        try dbPool.write(counter.increment)
        let snapshot = try dbPool.makeSnapshotPool()
        try? dbPool.writeWithoutTransaction { _ = try $0.checkpoint(.restart) } // ignore if error or not, that's not the point
        try XCTAssertEqual(snapshot.read(counter.value), 1)
        try dbPool.write(counter.increment)
        try XCTAssertEqual(snapshot.read(counter.value), 1)
    }
    
    func testTruncateCheckpointDoesNotInvalidateSnapshotPool() throws {
        let dbPool = try makeDatabasePool()
        let counter = try Counter(dbPool: dbPool)
        try dbPool.write(counter.increment)
        let snapshot = try dbPool.makeSnapshotPool()
        try? dbPool.writeWithoutTransaction { _ = try $0.checkpoint(.truncate) } // ignore if error or not, that's not the point
        try XCTAssertEqual(snapshot.read(counter.value), 1)
        try dbPool.write(counter.increment)
        try XCTAssertEqual(snapshot.read(counter.value), 1)
    }
}
#endif
