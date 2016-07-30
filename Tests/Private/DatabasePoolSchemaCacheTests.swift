import XCTest
#if USING_SQLCIPHER
    @testable import GRDBCipher
#elseif USING_CUSTOMSQLITE
    @testable import GRDBCustomSQLite
#else
    @testable import GRDB
#endif

class DatabasePoolSchemaCacheTests : GRDBTestCase {
    
    func testCache() {
        assertNoError {
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
            
            dbPool.read { db in
                // Assert that a reader cache is empty
                XCTAssertTrue(db.schemaCache.primaryKey("items") == nil)
                XCTAssertTrue(db.schemaCache.columns(in: "items") == nil)
                XCTAssertTrue(db.schemaCache.indexes(on: "items") == nil)
            }
            
            try dbPool.read { db in
                // Warm cache in a reader
                let primaryKey = try db.primaryKey("items")!
                XCTAssertEqual(primaryKey.rowIDColumn, "id")

                let columns = try db.columns(in: "items")
                XCTAssertEqual(columns.count, 4)
                // TODO: test more properties
                XCTAssertEqual(columns[0].name, "id")
                XCTAssertEqual(columns[1].name, "email")
                XCTAssertEqual(columns[2].name, "foo")
                XCTAssertEqual(columns[3].name, "bar")
                
                let indexes = db.indexes(on: "items")
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
            
            dbPool.read { db in
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
                    XCTAssertEqual(error.code, 1) // SQLITE_ERROR
                    XCTAssertEqual(error.message!, "no such table: items")
                    XCTAssertEqual(error.description, "SQLite error 1: no such table: items")
                }
            }
        }
    }
    
    func testCachedStatementsAreNotShared() {
        // This is a regression test.
        //
        // If cached statements were shared between reader connections, this
        // test would crash with fatal error: Database was not used on the
        // correct thread.
        assertNoError {
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
                dbPool.read { db in
                    let stmt = try! db.cachedSelectStatement("SELECT * FROM items")
                    XCTAssertEqual(Int.fetchOne(stmt)!, 1)
                    s1.signal()
                }
            }
            let block2 = { () in
                dbPool.read { db in
                    _ = s1.wait(timeout: .distantFuture)
                    let stmt = try! db.cachedSelectStatement("SELECT * FROM items")
                    XCTAssertEqual(Int.fetchOne(stmt)!, 1)
                }
            }
            let blocks = [block1, block2]
            DispatchQueue.concurrentPerform(iterations: blocks.count) { index in
                blocks[index]()
            }
        }
    }
}
