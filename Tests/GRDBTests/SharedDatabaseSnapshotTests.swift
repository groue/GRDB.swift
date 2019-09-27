#if SQLITE_ENABLE_SNAPSHOT
import XCTest
#if GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class SharedDatabaseSnapshotTests: GRDBTestCase {
    
    func testSnapshotIsReadOnly() throws {
        let dbPool = try makeDatabasePool()
        let snapshot = try dbPool.makeSharedSnapshot()
        do {
            try snapshot.read { db in
                try db.create(table: "t") { $0.column("id", .integer).primaryKey() }
            }
            XCTFail("Expected error")
        } catch is DatabaseError {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testSnapshotSeesLatestTransaction() throws {
        let dbPool = try makeDatabasePool()
        try dbPool.writeWithoutTransaction { db in
            try db.create(table: "t") { $0.column("id", .integer).primaryKey() }
            try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
            let snapshot = try dbPool.makeSharedSnapshot()
            try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
            try XCTAssertEqual(Int.fetchOne(db, sql: "SELECT COUNT(*) FROM t")!, 2)
            try snapshot.read { db in
                try XCTAssertEqual(Int.fetchOne(db, sql: "SELECT COUNT(*) FROM t")!, 1)
            }
            try dbPool.read { db in
                try XCTAssertEqual(Int.fetchOne(db, sql: "SELECT COUNT(*) FROM t")!, 2)
            }
            try snapshot.read { db in
                try XCTAssertEqual(Int.fetchOne(db, sql: "SELECT COUNT(*) FROM t")!, 1)
            }
            try XCTAssertEqual(Int.fetchOne(db, sql: "SELECT COUNT(*) FROM t")!, 2)
            try dbPool.read { db in
                try XCTAssertEqual(Int.fetchOne(db, sql: "SELECT COUNT(*) FROM t")!, 2)
            }
        }
    }
    
    func testSnapshotCreatedOutsideOfWriterQueue() throws {
        let dbPool = try makeDatabasePool()
        try dbPool.write { db in
            try db.create(table: "t") { $0.column("id", .integer).primaryKey() }
            try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
        }
        
        let snapshot = try dbPool.makeSharedSnapshot()
        try snapshot.read { db in
            try XCTAssertEqual(Int.fetchOne(db, sql: "SELECT COUNT(*) FROM t")!, 1)
        }
        try dbPool.write { db in
            try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
            try XCTAssertEqual(Int.fetchOne(db, sql: "SELECT COUNT(*) FROM t")!, 2)
        }
        try snapshot.read { db in
            try XCTAssertEqual(Int.fetchOne(db, sql: "SELECT COUNT(*) FROM t")!, 1)
        }
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
    
    func testPassiveCheckpointDoesNotInvalidatesSnapshot() throws {
        let dbPool = try makeDatabasePool()
        try dbPool.write { db in
            try db.create(table: "t") { $0.column("id", .integer).primaryKey() }
            try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
        }
        let snapshot = try dbPool.makeSharedSnapshot()
        try dbPool.checkpoint(.passive)
        try snapshot.read { db in
            try XCTAssertEqual(Int.fetchOne(db, sql: "SELECT COUNT(*) FROM t")!, 1)
        }
        try dbPool.write { db in
            try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
        }
        try snapshot.read { db in
            try XCTAssertEqual(Int.fetchOne(db, sql: "SELECT COUNT(*) FROM t")!, 1)
        }
    }
    
    func testFullCheckpointDoesNotInvalidatesSnapshot() throws {
        let dbPool = try makeDatabasePool()
        try dbPool.write { db in
            try db.create(table: "t") { $0.column("id", .integer).primaryKey() }
            try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
        }
        let snapshot = try dbPool.makeSharedSnapshot()
        try dbPool.checkpoint(.full)
        try snapshot.read { db in
            try XCTAssertEqual(Int.fetchOne(db, sql: "SELECT COUNT(*) FROM t")!, 1)
        }
        try dbPool.write { db in
            try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
        }
        try snapshot.read { db in
            try XCTAssertEqual(Int.fetchOne(db, sql: "SELECT COUNT(*) FROM t")!, 1)
        }
    }
    
    func testRestartCheckpointDoesNotInvalidatesSnapshot() throws {
        let dbPool = try makeDatabasePool()
        try dbPool.write { db in
            try db.create(table: "t") { $0.column("id", .integer).primaryKey() }
            try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
        }
        let snapshot = try dbPool.makeSharedSnapshot()
        do {
            try dbPool.checkpoint(.restart)
            XCTFail("Expected error")
        } catch let error as DatabaseError {
            XCTAssertEqual(error.resultCode, .SQLITE_BUSY)
        }
        try snapshot.read { db in
            try XCTAssertEqual(Int.fetchOne(db, sql: "SELECT COUNT(*) FROM t")!, 1)
        }
        try dbPool.write { db in
            try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
        }
        try snapshot.read { db in
            try XCTAssertEqual(Int.fetchOne(db, sql: "SELECT COUNT(*) FROM t")!, 1)
        }
    }
    
    func testTruncateCheckpointDoesNotInvalidatesSnapshot() throws {
        let dbPool = try makeDatabasePool()
        try dbPool.write { db in
            try db.create(table: "t") { $0.column("id", .integer).primaryKey() }
            try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
        }
        let snapshot = try dbPool.makeSharedSnapshot()
        do {
            try dbPool.checkpoint(.truncate)
            XCTFail("Expected error")
        } catch let error as DatabaseError {
            XCTAssertEqual(error.resultCode, .SQLITE_BUSY)
        }
        try snapshot.read { db in
            try XCTAssertEqual(Int.fetchOne(db, sql: "SELECT COUNT(*) FROM t")!, 1)
        }
        try dbPool.write { db in
            try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
        }
        try snapshot.read { db in
            try XCTAssertEqual(Int.fetchOne(db, sql: "SELECT COUNT(*) FROM t")!, 1)
        }
    }

    // TODO: test cache, concurrent reads...
}
#endif
