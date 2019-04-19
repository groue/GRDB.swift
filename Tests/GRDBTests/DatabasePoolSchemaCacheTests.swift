import XCTest
#if GRDBCUSTOMSQLITE
    @testable import GRDBCustomSQLite
#else
    @testable import GRDB
#endif

class DatabasePoolSchemaCacheTests : GRDBTestCase {
    
    func testCache() throws {
        let dbPool = try makeDatabasePool()
        
        try dbPool.write { db in
            try db.execute(sql: "CREATE TABLE items (id INTEGER PRIMARY KEY, email TEXT UNIQUE, foo INT, bar DOUBLE)")
            try db.execute(sql: "CREATE INDEX foobar ON items(foo, bar)")
        }
        
        try dbPool.write { db in
            // Assert that the writer cache is empty
            XCTAssertTrue(db.schemaCache.primaryKey("items") == nil)
            XCTAssertTrue(db.schemaCache.columns(in: "items") == nil)
            XCTAssertTrue(db.schemaCache.indexes(on: "items") == nil)
        }
        
        try dbPool.read { db in
            // Assert that a reader cache is empty
            XCTAssertTrue(db.schemaCache.primaryKey("items") == nil)
            XCTAssertTrue(db.schemaCache.columns(in: "items") == nil)
            XCTAssertTrue(db.schemaCache.indexes(on: "items") == nil)
        }
        
        try dbPool.read { db in
            // Warm cache in a reader
            _ = try db.primaryKey("items")
            _ = try db.columns(in: "items")
            _ = try db.indexes(on: "items")
            
            // Assert that reader cache is warmed
            XCTAssertTrue(db.schemaCache.primaryKey("items") != nil)
            XCTAssertTrue(db.schemaCache.columns(in: "items") != nil)
            XCTAssertTrue(db.schemaCache.indexes(on: "items") != nil)
        }
        
        try dbPool.write { db in
            // Warm cache in the writer
            _ = try db.primaryKey("items")
            _ = try db.columns(in: "items")
            _ = try db.indexes(on: "items")
            
            // Assert that writer cache is warmed
            XCTAssertTrue(db.schemaCache.primaryKey("items") != nil)
            XCTAssertTrue(db.schemaCache.columns(in: "items") != nil)
            XCTAssertTrue(db.schemaCache.indexes(on: "items") != nil)
        }
        
        try dbPool.write { db in
            // Empty cache after schema change
            try db.execute(sql: "DROP TABLE items")
            
            // Assert that the writer cache is empty
            XCTAssertTrue(db.schemaCache.primaryKey("items") == nil)
            XCTAssertTrue(db.schemaCache.columns(in: "items") == nil)
            XCTAssertTrue(db.schemaCache.indexes(on: "items") == nil)
        }
        
        try dbPool.read { db in
            // Assert that a reader cache is empty
            XCTAssertTrue(db.schemaCache.primaryKey("items") == nil)
            XCTAssertTrue(db.schemaCache.columns(in: "items") == nil)
            XCTAssertTrue(db.schemaCache.indexes(on: "items") == nil)
        }
        
        try dbPool.read { db in
            do {
                // Assert that cache is used: we expect an error now that
                // the cache is empty.
                _ = try db.primaryKey("items")
                XCTFail()
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
                XCTAssertEqual(error.message!, "no such table: items")
                XCTAssertEqual(error.description, "SQLite error 1: no such table: items")
            }
        }
    }

    func testCachedStatementsAreNotShared() throws {
        // This is a regression test.
        //
        // If cached statements were shared between reader connections, this
        // test would crash with fatal error: Database was not used on the
        // correct thread.
        let dbPool = try makeDatabasePool()
        try dbPool.write { db in
            try db.execute(sql: "CREATE TABLE items (id INTEGER PRIMARY KEY)")
            try db.execute(sql: "INSERT INTO items (id) VALUES (1)")
        }
        
        // Block 1                              Block 2
        // SELECT 1 FROM items WHERE id = 1
        // >
        let s1 = DispatchSemaphore(value: 0)
        //                                      SELECT 1 FROM items WHERE id = 1
        
        let block1 = { () in
            try! dbPool.read { db in
                let stmt = try! db.cachedSelectStatement(sql: "SELECT * FROM items")
                XCTAssertEqual(try Int.fetchOne(stmt)!, 1)
                s1.signal()
            }
        }
        let block2 = { () in
            try! dbPool.read { db in
                _ = s1.wait(timeout: .distantFuture)
                let stmt = try! db.cachedSelectStatement(sql: "SELECT * FROM items")
                XCTAssertEqual(try Int.fetchOne(stmt)!, 1)
            }
        }
        let blocks = [block1, block2]
        DispatchQueue.concurrentPerform(iterations: blocks.count) { index in
            blocks[index]()
        }
    }
    
    func testCacheSnapshotIsolation() throws {
        // This test checks that the schema cache follows snapshot isolation.
        // and that writer and readers do not naively share the same cache.
        let dbPool = try makeDatabasePool()
        
        // writer                   reader
        // CREATE TABLE foo
        // table exists: true
        // >
        let s1 = DispatchSemaphore(value: 0)
        //                          table exists: true
        //                          <
        let s2 = DispatchSemaphore(value: 0)
        // DROP TABLE foo
        // table exists: false
        // >
        let s3 = DispatchSemaphore(value: 0)
        //                          table exists: true
        //                          <
        let s4 = DispatchSemaphore(value: 0)
        // table exists: false

        let block1 = { () in
            try! dbPool.writeWithoutTransaction { db in
                try db.execute(sql: "CREATE TABLE foo(id INTEGER PRIMARY KEY)")
                // warm cache
                _ = try db.primaryKey("foo")
                // cache contains the primary key
                XCTAssertNotNil(db.schemaCache.primaryKey("foo"))
                s1.signal()
                _ = s2.wait(timeout: .distantFuture)
                try db.execute(sql: "DROP TABLE foo")
                // cache does not contain the primary key
                XCTAssertNil(db.schemaCache.primaryKey("foo"))
                s3.signal()
                _ = s4.wait(timeout: .distantFuture)
                // cache does not contain the primary key
                XCTAssertNil(db.schemaCache.primaryKey("foo"))
            }
        }
        let block2 = { () in
            _ = s1.wait(timeout: .distantFuture)
            try! dbPool.read { db in
                // activate snapshot isolation so that foo table is visible during the whole read. Any read is enough.
                try db.makeSelectStatement(sql: "SELECT * FROM sqlite_master").makeCursor().next()
                // warm cache
                _ = try db.primaryKey("foo")
                // cache contains the primary key
                XCTAssertNotNil(db.schemaCache.primaryKey("foo"))
                s2.signal()
                _ = s3.wait(timeout: .distantFuture)
                // cache contains the primary key
                XCTAssertNotNil(db.schemaCache.primaryKey("foo"))
                // warm cache if needed
                _ = try db.primaryKey("foo")
                s4.signal()
            }
        }
        let blocks = [block1, block2]
        DispatchQueue.concurrentPerform(iterations: blocks.count) { index in
            blocks[index]()
        }
    }
    
    func testUnsafeReaderHasNoDatabaseCache() throws {
        let dbPool = try makeDatabasePool()
        
        try dbPool.write { db in
            try db.execute(sql: "CREATE TABLE items (id INTEGER PRIMARY KEY, email TEXT UNIQUE, foo INT, bar DOUBLE)")
            try db.execute(sql: "CREATE INDEX foobar ON items(foo, bar)")
        }
        
        try dbPool.unsafeRead { db in
            // Assert that a cache is empty
            XCTAssertTrue(db.schemaCache.primaryKey("items") == nil)
            XCTAssertTrue(db.schemaCache.columns(in: "items") == nil)
            XCTAssertTrue(db.schemaCache.indexes(on: "items") == nil)
            
            // Warm cache in a reader
            _ = try db.primaryKey("items")
            _ = try db.columns(in: "items")
            _ = try db.indexes(on: "items")
            
            // Assert that a reader cache is still empty
            XCTAssertTrue(db.schemaCache.primaryKey("items") == nil)
            XCTAssertTrue(db.schemaCache.columns(in: "items") == nil)
            XCTAssertTrue(db.schemaCache.indexes(on: "items") == nil)
        }
    }
}
