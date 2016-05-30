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
                try db.execute("CREATE TABLE items (id INTEGER PRIMARY KEY)")
            }
            
            dbPool.write { db in
                // Assert that the writer cache is empty
                XCTAssertTrue(db.schemaCache.primaryKey(tableName: "items") == nil)
            }
            
            dbPool.read { db in
                // Assert that a reader cache is empty
                XCTAssertTrue(db.schemaCache.primaryKey(tableName: "items") == nil)
            }
            
            try dbPool.read { db in
                // Warm cache in a reader
                let primaryKey = try db.primaryKey("items")!
                XCTAssertEqual(primaryKey.rowIDColumn, "id")
                
                // Assert that reader cache is warmed
                XCTAssertTrue(db.schemaCache.primaryKey(tableName: "items") != nil)
            }
            
            dbPool.write { db in
                // Assert that writer cache is warmed
                XCTAssertTrue(db.schemaCache.primaryKey(tableName: "items") != nil)
            }
            
            try dbPool.write { db in
                // Empty cache after schema change
                try db.execute("DROP TABLE items")
                
                // Assert that the writer cache is empty
                XCTAssertTrue(db.schemaCache.primaryKey(tableName: "items") == nil)
            }
            
            dbPool.read { db in
                // Assert that a reader cache is empty
                XCTAssertTrue(db.schemaCache.primaryKey(tableName: "items") == nil)
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
            let s1 = dispatch_semaphore_create(0)
            //                                      SELECT 1 FROM items WHERE id = 1
            
            let block1 = { () in
                dbPool.read { db in
                    let stmt = try! db.cachedSelectStatement("SELECT * FROM items")
                    XCTAssertEqual(Int.fetchOne(stmt)!, 1)
                    dispatch_semaphore_signal(s1)
                }
            }
            let block2 = { () in
                dbPool.read { db in
                    dispatch_semaphore_wait(s1, DISPATCH_TIME_FOREVER)
                    let stmt = try! db.cachedSelectStatement("SELECT * FROM items")
                    XCTAssertEqual(Int.fetchOne(stmt)!, 1)
                }
            }
            let queue = dispatch_queue_create(nil, DISPATCH_QUEUE_CONCURRENT)
            dispatch_apply(2, queue) { index in
                [block1, block2][index]()
            }
        }
    }
}
