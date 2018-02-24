import XCTest
#if GRDBCIPHER
    import GRDBCipher
#elseif GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class DatabaseSnapshotTests: GRDBTestCase {
    
    func testSnapshotIsReadOnly() throws {
        let dbPool = try makeDatabasePool()
        let snapshot = try dbPool.makeSnapshot()
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
        try dbPool.write { db in
            try db.create(table: "t") { $0.column("id", .integer).primaryKey() }
            try db.execute("INSERT INTO t DEFAULT VALUES")
            let snapshot = try dbPool.makeSnapshot()
            try snapshot.read { db in
                try XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM t")!, 1)
            }
            try db.execute("INSERT INTO t DEFAULT VALUES")
            try XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM t")!, 2)
            try snapshot.read { db in
                try XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM t")!, 1)
            }
        }
    }
    
    func testSnapshotDoesNotSeeUncommittedTransaction() throws {
        let dbPool = try makeDatabasePool()
        try dbPool.write { db in
            try db.create(table: "t") { $0.column("id", .integer).primaryKey() }
            try db.beginTransaction()
            try db.execute("INSERT INTO t DEFAULT VALUES")
            let snapshot = try dbPool.makeSnapshot()
            try db.commit()
            try XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM t")!, 1)
            try snapshot.read { db in
                try XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM t")!, 0)
            }
        }
    }
    
    func testSnapshotCreatedOutsideOfWriterQueue() throws {
        let dbPool = try makeDatabasePool()
        try dbPool.write { db in
            try db.create(table: "t") { $0.column("id", .integer).primaryKey() }
            try db.execute("INSERT INTO t DEFAULT VALUES")
        }
        
        let snapshot = try dbPool.makeSnapshot()
        try snapshot.read { db in
            try XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM t")!, 1)
        }
        try dbPool.write { db in
            try db.execute("INSERT INTO t DEFAULT VALUES")
            try XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM t")!, 2)
        }
        try snapshot.read { db in
            try XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM t")!, 1)
        }
    }
    
    func testSnapshotInheritPoolFunctions() throws {
        let dbPool = try makeDatabasePool()
        let function = DatabaseFunction("foo", argumentCount: 0, pure: true) { _ in return "foo" }
        dbPool.add(function: function)
        
        let snapshot = try dbPool.makeSnapshot()
        try snapshot.read { db in
            try XCTAssertEqual(String.fetchOne(db, "SELECT foo()")!, "foo")
        }
    }
    
    func testSnapshotFunctions() throws {
        let dbPool = try makeDatabasePool()
        let snapshot = try dbPool.makeSnapshot()
        let function = DatabaseFunction("foo", argumentCount: 0, pure: true) { _ in return "foo" }
        snapshot.add(function: function)
        try snapshot.read { db in
            try XCTAssertEqual(String.fetchOne(db, "SELECT foo()")!, "foo")
        }
    }

    func testSnapshotInheritPoolCollations() throws {
        let dbPool = try makeDatabasePool()
        let collation = DatabaseCollation("reverse") { (string1, string2) in
            return (string1 == string2) ? .orderedSame : ((string1 < string2) ? .orderedDescending : .orderedAscending)
        }
        dbPool.add(collation: collation)
        
        try dbPool.write { db in
            try db.execute("CREATE TABLE items (text TEXT)")
            try db.execute("INSERT INTO items (text) VALUES ('a')")
            try db.execute("INSERT INTO items (text) VALUES ('b')")
            try db.execute("INSERT INTO items (text) VALUES ('c')")
        }
        
        let snapshot = try dbPool.makeSnapshot()
        try snapshot.read { db in
            XCTAssertEqual(try String.fetchAll(db, "SELECT text FROM items ORDER BY text COLLATE reverse"), ["c", "b", "a"])
        }
    }

    func testSnapshotCollations() throws {
        let dbPool = try makeDatabasePool()
        try dbPool.write { db in
            try db.execute("CREATE TABLE items (text TEXT)")
            try db.execute("INSERT INTO items (text) VALUES ('a')")
            try db.execute("INSERT INTO items (text) VALUES ('b')")
            try db.execute("INSERT INTO items (text) VALUES ('c')")
        }
        
        let snapshot = try dbPool.makeSnapshot()
        let collation = DatabaseCollation("reverse") { (string1, string2) in
            return (string1 == string2) ? .orderedSame : ((string1 < string2) ? .orderedDescending : .orderedAscending)
        }
        snapshot.add(collation: collation)
        try snapshot.read { db in
            XCTAssertEqual(try String.fetchAll(db, "SELECT text FROM items ORDER BY text COLLATE reverse"), ["c", "b", "a"])
        }
    }
}
