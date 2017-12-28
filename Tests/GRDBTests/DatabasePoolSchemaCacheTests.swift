import XCTest
#if GRDBCIPHER
    @testable import GRDBCipher
#elseif GRDBCUSTOMSQLITE
    @testable import GRDBCustomSQLite
#else
    @testable import GRDB
#endif

class DatabasePoolSchemaCacheTests : GRDBTestCase {
    
    func testCache() throws {
        let dbPool = try makeDatabasePool()
        
        try dbPool.write { db in
            try db.execute("CREATE TABLE items (id INTEGER PRIMARY KEY, email TEXT UNIQUE, foo INT, bar DOUBLE)")
            try db.execute("CREATE INDEX foobar ON items(foo, bar)")
        }
        
        dbPool.write { db in
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
            let primaryKey = try db.primaryKey("items")
            XCTAssertEqual(primaryKey.rowIDColumn, "id")
            
            let columns = try db.columns(in: "items")
            XCTAssertEqual(columns.count, 4)
            XCTAssertEqual(columns[0].name, "id")
            XCTAssertEqual(columns[1].name, "email")
            XCTAssertEqual(columns[2].name, "foo")
            XCTAssertEqual(columns[3].name, "bar")
            
            let indexes = try db.indexes(on: "items")
            XCTAssertEqual(indexes.count, 2)
            for index in indexes {
                switch index.name {
                case "foobar":
                    XCTAssertEqual(index.columns, ["foo", "bar"])
                    XCTAssertFalse(index.isUnique)
                default:
                    XCTAssertEqual(index.columns, ["email"])
                    XCTAssertTrue(index.isUnique)
                }
            }
            
            // Assert that reader cache is warmed
            XCTAssertTrue(db.schemaCache.primaryKey("items") != nil)
            XCTAssertTrue(db.schemaCache.columns(in: "items") != nil)
            XCTAssertTrue(db.schemaCache.indexes(on: "items") != nil)
        }
        
        dbPool.write { db in
            // Assert that writer cache is warmed
            XCTAssertTrue(db.schemaCache.primaryKey("items") != nil)
            XCTAssertTrue(db.schemaCache.columns(in: "items") != nil)
            XCTAssertTrue(db.schemaCache.indexes(on: "items") != nil)
        }
        
        try dbPool.write { db in
            // Empty cache after schema change
            try db.execute("DROP TABLE items")
            
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
            try db.execute("CREATE TABLE items (id INTEGER PRIMARY KEY)")
            try db.execute("INSERT INTO items (id) VALUES (1)")
        }
        
        // Block 1                              Block 2
        // SELECT 1 FROM items WHERE id = 1
        // >
        let s1 = DispatchSemaphore(value: 0)
        //                                      SELECT 1 FROM items WHERE id = 1
        
        let block1 = { () in
            try! dbPool.read { db in
                let stmt = try! db.cachedSelectStatement("SELECT * FROM items")
                XCTAssertEqual(try Int.fetchOne(stmt)!, 1)
                s1.signal()
            }
        }
        let block2 = { () in
            try! dbPool.read { db in
                _ = s1.wait(timeout: .distantFuture)
                let stmt = try! db.cachedSelectStatement("SELECT * FROM items")
                XCTAssertEqual(try Int.fetchOne(stmt)!, 1)
            }
        }
        let blocks = [block1, block2]
        DispatchQueue.concurrentPerform(iterations: blocks.count) { index in
            blocks[index]()
        }
    }
    
    func testReaderWriterCache() throws {
        // This test checks that the schema cache follows snapshot isolation
        dbConfiguration.trace = { print($0) }
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
            try! dbPool.write { db in
                try db.execute("CREATE TABLE foo(id INTEGER PRIMARY KEY)")
                // warm cache if needed
                _ = try db.primaryKey("foo")
                // cache contains the primary key
                XCTAssertNotNil(db.schemaCache.primaryKey("foo"))
                s1.signal()
                _ = s2.wait(timeout: .distantFuture)
                try db.execute("DROP TABLE foo")
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
                try db.makeSelectStatement("SELECT * FROM sqlite_master").cursor().next()
                // warm cache if needed
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
}
