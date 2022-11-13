#if (compiler(<5.7.1) && (os(macOS) || targetEnvironment(macCatalyst))) || GRDBCIPHER || (GRDBCUSTOMSQLITE && !SQLITE_ENABLE_SNAPSHOT)
#else
import XCTest
import GRDB

// test create from non-wal (read-only) snapshot
final class WALSnapshotTokenTests: GRDBTestCase {
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
    
    func testWALSnapshotTokenCreationFromNewDatabase() throws {
        _ = try makeDatabasePool().currentSnapshotToken()
    }
    
    func testWALSnapshotTokenCreationFromNonWALDatabase() throws {
        let dbQueue = try makeDatabaseQueue()
        
        var config = Configuration()
        config.readonly = true
        let dbPool = try DatabasePool(path: dbQueue.path, configuration: config)
        
        do {
            _ = try dbPool.currentSnapshotToken()
            XCTFail("Expected error")
        } catch DatabaseError.SQLITE_ERROR { }
    }
    
    func testWALSnapshotToken() throws {
        let dbPool = try makeDatabasePool()
        let counter = try Counter(dbPool: dbPool)
        
        try dbPool.write(counter.increment)
        let token = try dbPool.currentSnapshotToken()
        try dbPool.write(counter.increment)
        
        try XCTAssertEqual(dbPool.read(counter.value), 2)
        try XCTAssertEqual(dbPool.read(from: token, counter.value), 1)
        // Reuse the last connection
        try XCTAssertEqual(dbPool.read(counter.value), 2)
    }
    
    func testPassiveCheckpointDoesNotInvalidateWALSnapshotToken() throws {
        let dbPool = try makeDatabasePool()
        let counter = try Counter(dbPool: dbPool)
        try dbPool.write(counter.increment)
        let token = try dbPool.currentSnapshotToken()
        try? dbPool.writeWithoutTransaction { _ = try $0.checkpoint(.passive) } // ignore if error or not, that's not the point
        try XCTAssertEqual(dbPool.read(from: token, counter.value), 1)
        try dbPool.write(counter.increment)
        try XCTAssertEqual(dbPool.read(from: token, counter.value), 1)
    }
    
    func testFullCheckpointDoesNotInvalidateWALSnapshotToken() throws {
        let dbPool = try makeDatabasePool()
        let counter = try Counter(dbPool: dbPool)
        try dbPool.write(counter.increment)
        let token = try dbPool.currentSnapshotToken()
        try? dbPool.writeWithoutTransaction { _ = try $0.checkpoint(.full) } // ignore if error or not, that's not the point
        try XCTAssertEqual(dbPool.read(from: token, counter.value), 1)
        try dbPool.write(counter.increment)
        try XCTAssertEqual(dbPool.read(from: token, counter.value), 1)
    }
    
    func testRestartCheckpointDoesNotInvalidateWALSnapshotToken() throws {
        let dbPool = try makeDatabasePool()
        let counter = try Counter(dbPool: dbPool)
        try dbPool.write(counter.increment)
        let token = try dbPool.currentSnapshotToken()
        try? dbPool.writeWithoutTransaction { _ = try $0.checkpoint(.restart) } // ignore if error or not, that's not the point
        try XCTAssertEqual(dbPool.read(from: token, counter.value), 1)
        try dbPool.write(counter.increment)
        try XCTAssertEqual(dbPool.read(from: token, counter.value), 1)
    }
    
    func testTruncateCheckpointDoesNotInvalidateWALSnapshotToken() throws {
        let dbPool = try makeDatabasePool()
        let counter = try Counter(dbPool: dbPool)
        try dbPool.write(counter.increment)
        let token = try dbPool.currentSnapshotToken()
        try? dbPool.writeWithoutTransaction { _ = try $0.checkpoint(.truncate) } // ignore if error or not, that's not the point
        try XCTAssertEqual(dbPool.read(from: token, counter.value), 1)
        try dbPool.write(counter.increment)
        try XCTAssertEqual(dbPool.read(from: token, counter.value), 1)
    }
    
    func testWALSnapshotTokenAndSchemaCache() throws {
        let dbPool = try makeDatabasePool()
        try dbPool.write { db in
            try db.execute(sql: """
                CREATE TABLE player(id INTEGER PRIMARY KEY, name, score);
                """)
        }
        
        let token = try dbPool.currentSnapshotToken()
        
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
            let exists = try dbPool.read(from: token) { try $0.tableExists("team") }
            XCTAssertFalse(exists)
        }
        
        do {
            let exists = try dbPool.read { try $0.tableExists("team") }
            XCTAssertTrue(exists)
        }
    }
    
    func testWALSnapshotTokenAndStatementCache() throws {
        let dbPool = try makeDatabasePool()
        let request = SQLRequest<Int>(sql: "SELECT COUNT(*) FROM player", cached: true)
        try dbPool.write { db in
            try db.execute(sql: """
                CREATE TABLE player(id INTEGER PRIMARY KEY, name, score);
                """)
        }
        
        let token = try dbPool.currentSnapshotToken()
        
        try dbPool.write { db in
            try db.execute(sql: "DROP TABLE player")
        }
        
        do {
            let count = try dbPool.read(from: token) { try request.fetchOne($0) }
            XCTAssertEqual(count, 0)
        }
        
        do {
            _ = try dbPool.read { try request.fetchOne($0) }
            XCTFail("Expected error")
        } catch DatabaseError.SQLITE_ERROR { }
        
        do {
            let count = try dbPool.read(from: token) { try request.fetchOne($0) }
            XCTAssertEqual(count, 0)
        }
    }
}
#endif
