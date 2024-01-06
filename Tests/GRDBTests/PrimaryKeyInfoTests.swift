import XCTest
@testable import GRDB

class PrimaryKeyInfoTests: GRDBTestCase {
    
    func testMissingTable() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            do {
                _ = try db.primaryKey("items")
                XCTFail("Expected Error")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
                XCTAssertEqual(error.message, "no such table: items")
                XCTAssertEqual(error.description, "SQLite error 1: no such table: items")
            }
        }
    }
    
    func testView() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(sql: "CREATE VIEW items AS SELECT 1")
            do {
                _ = try db.primaryKey("items")
                XCTFail("Expected Error")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
                XCTAssertEqual(error.message, "no such table: items")
                XCTAssertEqual(error.description, "SQLite error 1: no such table: items")
            }
        }
    }
    
    func testHiddenRowID() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(sql: "CREATE TABLE items (name TEXT)")
            let primaryKey = try db.primaryKey("items")
            XCTAssertNil(primaryKey.columnInfos)
            XCTAssertEqual(primaryKey.columns, [Column.rowID.name])
            XCTAssertNil(primaryKey.rowIDColumn)
            XCTAssertTrue(primaryKey.isRowID)
            XCTAssertTrue(primaryKey.tableHasRowID)
        }
    }
    
    func testIntegerPrimaryKey() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(sql: "CREATE TABLE items (id INTEGER PRIMARY KEY, name TEXT)")
            let primaryKey = try db.primaryKey("items")
            XCTAssertEqual(primaryKey.columnInfos?.map(\.name), ["id"])
            XCTAssertEqual(primaryKey.columnInfos?.map(\.type), ["INTEGER"])
            XCTAssertEqual(primaryKey.columns, ["id"])
            XCTAssertEqual(primaryKey.rowIDColumn, "id")
            XCTAssertTrue(primaryKey.isRowID)
            XCTAssertTrue(primaryKey.tableHasRowID)
        }
    }
    
    func testIntegerPrimaryKey2() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(sql: "CREATE TABLE items (id INTEGER, name TEXT, PRIMARY KEY (id))")
            let primaryKey = try db.primaryKey("items")
            XCTAssertEqual(primaryKey.columnInfos?.map(\.name), ["id"])
            XCTAssertEqual(primaryKey.columnInfos?.map(\.type), ["INTEGER"])
            XCTAssertEqual(primaryKey.columns, ["id"])
            XCTAssertEqual(primaryKey.rowIDColumn, "id")
            XCTAssertTrue(primaryKey.isRowID)
            XCTAssertTrue(primaryKey.tableHasRowID)
        }
    }
    
    func testNonRowIDPrimaryKey() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(sql: "CREATE TABLE items (name TEXT PRIMARY KEY)")
            let primaryKey = try db.primaryKey("items")
            XCTAssertEqual(primaryKey.columnInfos?.map(\.name), ["name"])
            XCTAssertEqual(primaryKey.columnInfos?.map(\.type), ["TEXT"])
            XCTAssertEqual(primaryKey.columns, ["name"])
            XCTAssertNil(primaryKey.rowIDColumn)
            XCTAssertFalse(primaryKey.isRowID)
            XCTAssertTrue(primaryKey.tableHasRowID)
        }
    }
    
    func testCompoundPrimaryKey() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(sql: "CREATE TABLE items (a TEXT, b INTEGER, PRIMARY KEY (a,b))")
            let primaryKey = try db.primaryKey("items")
            XCTAssertEqual(primaryKey.columnInfos?.map(\.name), ["a", "b"])
            XCTAssertEqual(primaryKey.columnInfos?.map(\.type), ["TEXT", "INTEGER"])
            XCTAssertEqual(primaryKey.columns, ["a", "b"])
            XCTAssertNil(primaryKey.rowIDColumn)
            XCTAssertFalse(primaryKey.isRowID)
            XCTAssertTrue(primaryKey.tableHasRowID)
        }
    }
    
    func testNonRowIDPrimaryKeyWithoutRowID() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(sql: "CREATE TABLE items (name TEXT PRIMARY KEY) WITHOUT ROWID")
            let primaryKey = try db.primaryKey("items")
            XCTAssertEqual(primaryKey.columnInfos?.map(\.name), ["name"])
            XCTAssertEqual(primaryKey.columnInfos?.map(\.type), ["TEXT"])
            XCTAssertEqual(primaryKey.columns, ["name"])
            XCTAssertNil(primaryKey.rowIDColumn)
            XCTAssertFalse(primaryKey.isRowID)
            XCTAssertFalse(primaryKey.tableHasRowID)
        }
    }
    
    func testCompoundPrimaryKeyWithoutRowID() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(sql: "CREATE TABLE items (a TEXT, b INTEGER, PRIMARY KEY (a,b)) WITHOUT ROWID")
            let primaryKey = try db.primaryKey("items")
            XCTAssertEqual(primaryKey.columnInfos?.map(\.name), ["a", "b"])
            XCTAssertEqual(primaryKey.columnInfos?.map(\.type), ["TEXT", "INTEGER"])
            XCTAssertEqual(primaryKey.columns, ["a", "b"])
            XCTAssertNil(primaryKey.rowIDColumn)
            XCTAssertFalse(primaryKey.isRowID)
            XCTAssertFalse(primaryKey.tableHasRowID)
        }
    }
    
    func testUnknownSchema() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(sql: "CREATE TABLE items (name TEXT)")
            do {
                _ = try db.primaryKey("items", in: "invalid")
                XCTFail("Expected Error")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
                XCTAssertEqual(error.message, "no such schema: invalid")
                XCTAssertEqual(error.description, "SQLite error 1: no such schema: invalid")
            }
        }
    }
    
    func testSpecifiedMainSchema() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(sql: "CREATE TABLE items (name TEXT)")
            let primaryKey = try db.primaryKey("items", in: "main")
            XCTAssertNil(primaryKey.columnInfos)
            XCTAssertEqual(primaryKey.columns, [Column.rowID.name])
            XCTAssertNil(primaryKey.rowIDColumn)
            XCTAssertTrue(primaryKey.isRowID)
            XCTAssertTrue(primaryKey.tableHasRowID)
        }
    }
    
    func testSpecifiedSchemaWithTableNameCollisions() throws {
        #if GRDBCIPHER_USE_ENCRYPTION
        // Avoid error due to key not being provided:
        // file is not a database - while executing `ATTACH DATABASE...`
        throw XCTSkip("This test does not support encrypted databases")
        #endif
        
        let attached = try makeDatabaseQueue(filename: "attached1")
        try attached.inDatabase { db in
            try db.execute(sql: "CREATE TABLE items (id2 INTEGER PRIMARY KEY)")
        }
        let main = try makeDatabaseQueue(filename: "main")
        try main.inDatabase { db in
            try db.execute(sql: "CREATE TABLE items (id1 INTEGER PRIMARY KEY)")
            try db.execute(literal: "ATTACH DATABASE \(attached.path) AS attached")
            
            let primaryKeyMain = try db.primaryKey("items", in: "main")
            XCTAssertEqual(primaryKeyMain.columnInfos?.map(\.name), ["id1"])
            XCTAssertEqual(primaryKeyMain.columnInfos?.map(\.type), ["INTEGER"])
            XCTAssertEqual(primaryKeyMain.columns, ["id1"])
            XCTAssertEqual(primaryKeyMain.rowIDColumn, "id1")
            XCTAssertTrue(primaryKeyMain.isRowID)
            XCTAssertTrue(primaryKeyMain.tableHasRowID)
            
            let primaryKeyAttached = try db.primaryKey("items", in: "attached")
            XCTAssertEqual(primaryKeyAttached.columnInfos?.map(\.name), ["id2"])
            XCTAssertEqual(primaryKeyAttached.columnInfos?.map(\.type), ["INTEGER"])
            XCTAssertEqual(primaryKeyAttached.columns, ["id2"])
            XCTAssertEqual(primaryKeyAttached.rowIDColumn, "id2")
            XCTAssertTrue(primaryKeyAttached.isRowID)
            XCTAssertTrue(primaryKeyAttached.tableHasRowID)
        }
    }
    
    // The `items` table in the attached database should never
    // be found unless explicitly specified as it is after
    // `main.items` in resolution order.
    func testUnspecifiedSchemaWithTableNameCollisions() throws {
        #if GRDBCIPHER_USE_ENCRYPTION
        // Avoid error due to key not being provided:
        // file is not a database - while executing `ATTACH DATABASE...`
        throw XCTSkip("This test does not support encrypted databases")
        #endif
        
        let attached = try makeDatabaseQueue(filename: "attached1")
        try attached.inDatabase { db in
            try db.execute(sql: "CREATE TABLE items (id2 INTEGER PRIMARY KEY)")
        }
        let main = try makeDatabaseQueue(filename: "main")
        try main.inDatabase { db in
            try db.execute(sql: "CREATE TABLE items (id1 INTEGER PRIMARY KEY)")
            try db.execute(literal: "ATTACH DATABASE \(attached.path) AS attached")
            let primaryKey = try db.primaryKey("items")
            XCTAssertEqual(primaryKey.columnInfos?.map(\.name), ["id1"])
            XCTAssertEqual(primaryKey.columnInfos?.map(\.type), ["INTEGER"])
            XCTAssertEqual(primaryKey.columns, ["id1"])
            XCTAssertEqual(primaryKey.rowIDColumn, "id1")
            XCTAssertTrue(primaryKey.isRowID)
            XCTAssertTrue(primaryKey.tableHasRowID)
        }
    }
    
    func testUnspecifiedSchemaFindsAttachedDatabase() throws {
        #if GRDBCIPHER_USE_ENCRYPTION
        // Avoid error due to key not being provided:
        // file is not a database - while executing `ATTACH DATABASE...`
        throw XCTSkip("This test does not support encrypted databases")
        #endif
        
        let attached = try makeDatabaseQueue(filename: "attached1")
        try attached.inDatabase { db in
            try db.execute(sql: "CREATE TABLE items (id INTEGER PRIMARY KEY)")
        }
        let main = try makeDatabaseQueue(filename: "main")
        try main.inDatabase { db in
            try db.execute(literal: "ATTACH DATABASE \(attached.path) AS attached")
            let primaryKey = try db.primaryKey("items")
            XCTAssertEqual(primaryKey.columnInfos?.map(\.name), ["id"])
            XCTAssertEqual(primaryKey.columnInfos?.map(\.type), ["INTEGER"])
            XCTAssertEqual(primaryKey.columns, ["id"])
            XCTAssertEqual(primaryKey.rowIDColumn, "id")
            XCTAssertTrue(primaryKey.isRowID)
            XCTAssertTrue(primaryKey.tableHasRowID)
        }
    }
}
