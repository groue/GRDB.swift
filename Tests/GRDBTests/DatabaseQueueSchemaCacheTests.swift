import XCTest
@testable import GRDB

class DatabaseQueueSchemaCacheTests : GRDBTestCase {
    
    func testCache() throws {
        let dbQueue = try makeDatabaseQueue()
        
        try dbQueue.inDatabase { db in
            try db.execute(sql: "CREATE TABLE items (id INTEGER PRIMARY KEY)")
        }
        
        dbQueue.inDatabase { db in
            // Assert that cache is empty
            XCTAssertTrue(db.schemaCache[.main].primaryKey("items") == nil)
        }
        
        try dbQueue.inDatabase { db in
            // Warm cache
            let primaryKey = try db.primaryKey("items")
            XCTAssertEqual(primaryKey.rowIDColumn, "id")
            
            // Assert that cache is warmed
            XCTAssertTrue(db.schemaCache[.main].primaryKey("items") != nil)
        }
        
        try dbQueue.inDatabase { db in
            // Empty cache after schema change
            try db.execute(sql: "DROP TABLE items")
            
            // Assert that cache is empty
            XCTAssertTrue(db.schemaCache[.main].primaryKey("items") == nil)
        }
        
        try dbQueue.inDatabase { db in
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
    
    func testTempCache() throws {
        let dbQueue = try makeDatabaseQueue()
        
        try dbQueue.inDatabase { db in
            try db.execute(sql: "CREATE TEMPORARY TABLE items (id INTEGER PRIMARY KEY)")
        }
        
        dbQueue.inDatabase { db in
            // Assert that cache is empty
            XCTAssertTrue(db.schemaCache[.temp].primaryKey("items") == nil)
        }
        
        try dbQueue.inDatabase { db in
            // Warm cache
            let primaryKey = try db.primaryKey("items")
            XCTAssertEqual(primaryKey.rowIDColumn, "id")
            
            // Assert that cache is warmed
            XCTAssertTrue(db.schemaCache[.temp].primaryKey("items") != nil)
        }
        
        try dbQueue.inDatabase { db in
            // Empty cache after schema change
            try db.execute(sql: "DROP TABLE items")
            
            // Assert that cache is empty
            XCTAssertTrue(db.schemaCache[.temp].primaryKey("items") == nil)
        }
        
        try dbQueue.inDatabase { db in
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
    
    func testMainShadowedByTemp() throws {
        let dbQueue = try makeDatabaseQueue()
        
        try dbQueue.inDatabase { db in
            do {
                XCTAssertTrue(db.schemaCache[.main].primaryKey("items") == nil)
                XCTAssertTrue(db.schemaCache[.temp].primaryKey("items") == nil)
            }
            
            do {
                try db.execute(sql: """
                    CREATE TABLE items (id INTEGER PRIMARY KEY);
                    INSERT INTO items (id) VALUES (1);
                    """)
                let primaryKey = try db.primaryKey("items")
                XCTAssertEqual(primaryKey.rowIDColumn, "id")
                XCTAssertTrue(db.schemaCache[.main].primaryKey("items")!.value != nil)
                XCTAssertTrue(db.schemaCache[.temp].primaryKey("items")!.value == nil)
                try XCTAssertEqual(Int.fetchOne(db, sql: "SELECT id FROM items"), 1)
            }
            
            do {
                try db.execute(sql: """
                    CREATE TEMPORARY TABLE items (otherID INTEGER PRIMARY KEY);
                    INSERT INTO items (otherID) VALUES (2);
                    """)
                let primaryKey = try db.primaryKey("items")
                XCTAssertEqual(primaryKey.rowIDColumn, "otherID")
                XCTAssertTrue(db.schemaCache[.main].primaryKey("items") == nil)
                XCTAssertTrue(db.schemaCache[.temp].primaryKey("items")!.value != nil)
                try XCTAssertEqual(Int.fetchOne(db, sql: "SELECT otherID FROM items"), 2)
            }
            
            do {
                try db.execute(sql: "DROP TABLE items")
                let primaryKey = try db.primaryKey("items")
                XCTAssertEqual(primaryKey.rowIDColumn, "id")
                XCTAssertTrue(db.schemaCache[.main].primaryKey("items")!.value != nil)
                XCTAssertTrue(db.schemaCache[.temp].primaryKey("items")!.value == nil)
                try XCTAssertEqual(Int.fetchOne(db, sql: "SELECT id FROM items"), 1)
            }
        }
    }
}
