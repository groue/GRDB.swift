import XCTest
#if SQLITE_HAS_CODEC
    @testable import GRDBCipher
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
                let primaryKey = try db.primaryKey("items")
                switch primaryKey {
                case .RowID(let columnName):
                    XCTAssertEqual(columnName, "id")
                default:
                    XCTFail()
                }
                
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
}
