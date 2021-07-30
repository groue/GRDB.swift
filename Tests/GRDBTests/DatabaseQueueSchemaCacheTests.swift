import XCTest
@testable import GRDB

class DatabaseQueueSchemaCacheTests : GRDBTestCase {
    
    func testCache() throws {
        try makeDatabaseQueue().inDatabase { db in
            try db.execute(sql: "CREATE TABLE items (id INTEGER PRIMARY KEY)")

            // Assert that cache is empty
            XCTAssertTrue(db.schemaCache[.main].primaryKey("items") == nil)

            // Warm cache
            let primaryKey = try db.primaryKey("items")
            XCTAssertEqual(primaryKey.rowIDColumn, "id")
            
            // Assert that cache is warmed
            XCTAssertTrue(db.schemaCache[.main].primaryKey("items") != nil)

            // Empty cache after schema change
            try db.execute(sql: "DROP TABLE items")
            
            // Assert that cache is empty
            XCTAssertTrue(db.schemaCache[.main].primaryKey("items") == nil)

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
    
    func testCacheInvalidationWithCursor() throws {
        try makeDatabaseQueue().inDatabase { db in
            try db.execute(sql: "CREATE TABLE items (id INTEGER PRIMARY KEY)")
            
            // Assert that cache is empty
            XCTAssertTrue(db.schemaCache[.main].primaryKey("items") == nil)
            
            // Warm cache
            let primaryKey = try db.primaryKey("items")
            XCTAssertEqual(primaryKey.rowIDColumn, "id")
            
            // Assert that cache is warmed
            XCTAssertTrue(db.schemaCache[.main].primaryKey("items") != nil)
            
            // Assert that cache is still warm until the DROP TABLE statement has been executed
            let statement = try db.makeStatement(sql: "DROP TABLE items")
            XCTAssertTrue(db.schemaCache[.main].primaryKey("items") != nil)
            let cursor = try Row.fetchCursor(statement)
            XCTAssertTrue(db.schemaCache[.main].primaryKey("items") != nil)
            _ = try cursor.next()

            // Assert that cache is empty after cursor has run sqlite3_step
            XCTAssertTrue(db.schemaCache[.main].primaryKey("items") == nil)
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
                XCTAssertTrue(db.schemaCache[.temp].primaryKey("items") == nil)
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
    
    func testMainShadowedByAttachedDatabase() throws {
        #if SQLITE_HAS_CODEC
        // Avoid error due to key not being provided:
        // file is not a database - while executing `ATTACH DATABASE...`
        throw XCTSkip("This test does not suppport encrypted databases")
        #endif
        
        let attached1 = try makeDatabaseQueue(filename: "attached1")
        try attached1.write { db in
            try db.execute(sql: """
                CREATE TABLE item (attached1Column TEXT);
                INSERT INTO item VALUES('attached1');
                """)
            try XCTAssertEqual(String.fetchOne(db, sql: "SELECT * FROM item"), "attached1")
            try XCTAssertEqual(db.columns(in: "item").first?.name, "attached1Column")
        }
        
        let attached2 = try makeDatabaseQueue(filename: "attached2")
        try attached2.write { db in
            try db.execute(sql: """
                CREATE TABLE item (attached2Column TEXT);
                INSERT INTO item VALUES('attached2');
                """)
            try XCTAssertEqual(String.fetchOne(db, sql: "SELECT * FROM item"), "attached2")
            try XCTAssertEqual(db.columns(in: "item").first?.name, "attached2Column")
        }
        
        let main = try makeDatabaseQueue(filename: "main")
        try main.writeWithoutTransaction { db in
            try XCTAssertFalse(db.tableExists("item"))
            
            try db.execute(literal: "ATTACH DATABASE \(attached1.path) AS attached1")
            try XCTAssertEqual(String.fetchOne(db, sql: "SELECT * FROM item"), "attached1")
            try XCTAssertEqual(Row.fetchOne(db, sql: "PRAGMA table_info(item)")?["name"], "attached1Column")
            try XCTAssertEqual(Row.fetchOne(db, sql: "PRAGMA attached1.table_info(item)")?["name"], "attached1Column")
            try XCTAssertTrue(db.tableExists("item"))
            try XCTAssertEqual(db.columns(in: "item").first?.name, "attached1Column")
            
            // Main shadows attached1
            try db.execute(sql: """
                CREATE TABLE item (mainColumn TEXT);
                INSERT INTO item VALUES('main');
                """)
            try XCTAssertEqual(String.fetchOne(db, sql: "SELECT * FROM item"), "main")
            try XCTAssertEqual(Row.fetchOne(db, sql: "PRAGMA main.table_info(item)")?["name"], "mainColumn")
            try XCTAssertEqual(Row.fetchOne(db, sql: "PRAGMA attached1.table_info(item)")?["name"], "attached1Column")
            try XCTAssertEqual(Row.fetchOne(db, sql: "PRAGMA table_info(item)")?["name"], "mainColumn")
            try XCTAssertTrue(db.tableExists("item"))
            try XCTAssertEqual(db.columns(in: "item").first?.name, "mainColumn")
            
            // Main no longer shadows attached1
            try db.execute(sql: "DROP TABLE item")
            try XCTAssertEqual(String.fetchOne(db, sql: "SELECT * FROM item"), "attached1")
            try XCTAssertEqual(Row.fetchOne(db, sql: "PRAGMA attached1.table_info(item)")?["name"], "attached1Column")
            try XCTAssertEqual(Row.fetchOne(db, sql: "PRAGMA table_info(item)")?["name"], "attached1Column")
            try XCTAssertTrue(db.tableExists("item"))
            try XCTAssertEqual(db.columns(in: "item").first?.name, "attached1Column")
            
            // Attached1 shadows attached2
            try db.execute(literal: "ATTACH DATABASE \(attached2.path) AS attached2")
            try XCTAssertEqual(String.fetchOne(db, sql: "SELECT * FROM item"), "attached1")
            try XCTAssertEqual(Row.fetchOne(db, sql: "PRAGMA attached1.table_info(item)")?["name"], "attached1Column")
            try XCTAssertEqual(Row.fetchOne(db, sql: "PRAGMA attached2.table_info(item)")?["name"], "attached2Column")
            try XCTAssertEqual(Row.fetchOne(db, sql: "PRAGMA table_info(item)")?["name"], "attached1Column")
            try XCTAssertTrue(db.tableExists("item"))
            try XCTAssertEqual(db.columns(in: "item").first?.name, "attached1Column")
            
            // Attached1 no longer shadows attached2
            try db.execute(sql: "DETACH DATABASE attached1")
            try XCTAssertEqual(String.fetchOne(db, sql: "SELECT * FROM item"), "attached2")
            try XCTAssertEqual(Row.fetchOne(db, sql: "PRAGMA attached2.table_info(item)")?["name"], "attached2Column")
            try XCTAssertEqual(Row.fetchOne(db, sql: "PRAGMA table_info(item)")?["name"], "attached2Column")
            try XCTAssertTrue(db.tableExists("item"))
            try XCTAssertEqual(db.columns(in: "item").first?.name, "attached2Column")
            
            // Attached2 no longer shadows main
            try db.execute(sql: "DETACH DATABASE attached2")
            try XCTAssertFalse(db.tableExists("item"))
        }
    }
}
