import XCTest
@testable import GRDB

class PrimaryKeyInfoTests: GRDBTestCase {
    
    func testHiddenRowID() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(sql: "CREATE TABLE items (name TEXT)")
            let primaryKey = try db.primaryKey("items")
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
            XCTAssertEqual(primaryKey.columns, ["a", "b"])
            XCTAssertNil(primaryKey.rowIDColumn)
            XCTAssertFalse(primaryKey.isRowID)
            XCTAssertFalse(primaryKey.tableHasRowID)
        }
    }
}
