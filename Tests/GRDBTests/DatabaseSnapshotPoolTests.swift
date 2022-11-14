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
    
    func testSnapshotPoolCreationFromNewDatabase() throws {
        _ = try makeDatabasePool().makeSnapshotPool()
    }
    
    func testSnapshotPoolCreationFromNonWALDatabase() throws {
        let dbQueue = try makeDatabaseQueue()
        
        var config = Configuration()
        config.readonly = true
        let dbPool = try DatabasePool(path: dbQueue.path, configuration: config)
        
        do {
            _ = try dbPool.makeSnapshotPool()
            XCTFail("Expected error")
        } catch DatabaseError.SQLITE_ERROR { }
    }
    
    func testSnapshotPool() throws {
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
    
    func testSnapshotPoolAndSchemaCache() throws {
        let dbPool = try makeDatabasePool()
        try dbPool.write { db in
            try db.execute(sql: """
                CREATE TABLE player(id INTEGER PRIMARY KEY, name, score);
                """)
        }
        
        let snapshot = try dbPool.makeSnapshotPool()
        
        try dbPool.write { db in
            try db.execute(sql: """
                CREATE TABLE team(id INTEGER PRIMARY KEY, name, color);
                """)
        }
        
        do {
            let exists = try dbPool.read { try $0.tableExists("team") }
            XCTAssertTrue(exists)
        }
        
        do {
            let exists = try snapshot.read { try $0.tableExists("team") }
            XCTAssertFalse(exists)
        }
        
        do {
            let exists = try dbPool.read { try $0.tableExists("team") }
            XCTAssertTrue(exists)
        }
    }
    
    func testSnapshotPoolAndStatementCache() throws {
        let dbPool = try makeDatabasePool()
        let request = SQLRequest<Int>(sql: "SELECT COUNT(*) FROM player", cached: true)
        try dbPool.write { db in
            try db.execute(sql: """
                CREATE TABLE player(id INTEGER PRIMARY KEY, name, score);
                """)
        }
        
        let snapshot = try dbPool.makeSnapshotPool()
        
        try dbPool.write { db in
            try db.execute(sql: "DROP TABLE player")
        }
        
        do {
            let count = try snapshot.read { try request.fetchOne($0) }
            XCTAssertEqual(count, 0)
        }
        
        do {
            _ = try dbPool.read { try request.fetchOne($0) }
            XCTFail("Expected error")
        } catch DatabaseError.SQLITE_ERROR { }
        
        do {
            let count = try snapshot.read { try request.fetchOne($0) }
            XCTAssertEqual(count, 0)
        }
    }
}
#endif
