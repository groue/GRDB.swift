import XCTest
import GRDB

class IndexInfoTests: GRDBTestCase {
    
    func testIndexes() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            do {
                _ = try db.indexes(on: "missing")
                XCTFail("Expected DatabaseError")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
                XCTAssertEqual(error.message, "no such table: missing")
            }
            
            do {
                try db.execute(sql: "CREATE TABLE persons (id INTEGER PRIMARY KEY, name TEXT, email TEXT UNIQUE)")
                let indexes = try db.indexes(on: "persons")
                
                XCTAssertEqual(indexes.count, 1)
                XCTAssertEqual(indexes[0].name, "sqlite_autoindex_persons_1")
                XCTAssertEqual(indexes[0].origin, .uniqueConstraint)
                XCTAssertEqual(indexes[0].columns, ["email"])
                XCTAssertTrue(indexes[0].isUnique)
            }
            
            do {
                try db.execute(sql: "CREATE TABLE citizenships (year INTEGER, personId INTEGER NOT NULL, countryIsoCode TEXT NOT NULL, PRIMARY KEY (personId, countryIsoCode))")
                try db.execute(sql: "CREATE INDEX citizenshipsOnYear ON citizenships(year)")
                let indexes = try db.indexes(on: "citizenships")
                
                XCTAssertEqual(indexes.count, 2)
                if let i = indexes.firstIndex(where: { $0.columns == ["year"] }) {
                    XCTAssertEqual(indexes[i].name, "citizenshipsOnYear")
                    XCTAssertEqual(indexes[i].origin, .createIndex)
                    XCTAssertEqual(indexes[i].columns, ["year"])
                    XCTAssertFalse(indexes[i].isUnique)
                } else {
                    XCTFail()
                }
                if let i = indexes.firstIndex(where: { $0.columns == ["personId", "countryIsoCode"] }) {
                    XCTAssertEqual(indexes[i].name, "sqlite_autoindex_citizenships_1")
                    XCTAssertEqual(indexes[i].origin, .primaryKeyConstraint)
                    XCTAssertEqual(indexes[i].columns, ["personId", "countryIsoCode"])
                    XCTAssertTrue(indexes[i].isUnique)
                } else {
                    XCTFail()
                }
            }
        }
    }

    func testColumnsThatUniquelyIdentityRows() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(sql: "CREATE TABLE persons (id INTEGER PRIMARY KEY, name TEXT, email TEXT UNIQUE)")
            try XCTAssertTrue(db.table("persons", hasUniqueKey: ["rowid"]))
            try XCTAssertTrue(db.table("persons", hasUniqueKey: ["id"]))
            try XCTAssertTrue(db.table("persons", hasUniqueKey: ["email"]))
            try XCTAssertFalse(db.table("persons", hasUniqueKey: []))
            try XCTAssertFalse(db.table("persons", hasUniqueKey: ["name"]))
            try XCTAssertTrue(db.table("persons", hasUniqueKey: ["id", "email"]))
            
            try db.execute(sql: "CREATE TABLE citizenships (year INTEGER, personId INTEGER NOT NULL, countryIsoCode TEXT NOT NULL, PRIMARY KEY (personId, countryIsoCode))")
            try db.execute(sql: "CREATE INDEX citizenshipsOnYear ON citizenships(year)")
            try XCTAssertTrue(db.table("citizenships", hasUniqueKey: ["rowid"]))
            try XCTAssertTrue(db.table("citizenships", hasUniqueKey: ["personId", "countryIsoCode"]))
            try XCTAssertTrue(db.table("citizenships", hasUniqueKey: ["countryIsoCode", "personId"]))
            try XCTAssertFalse(db.table("citizenships", hasUniqueKey: []))
            try XCTAssertFalse(db.table("citizenships", hasUniqueKey: ["year"]))
            try XCTAssertFalse(db.table("citizenships", hasUniqueKey: ["personId"]))
            try XCTAssertFalse(db.table("citizenships", hasUniqueKey: ["countryIsoCode"]))
        }
    }
    
    // Regression test for https://github.com/groue/GRDB.swift/issues/840
    func testIndexOnExpressionIsExcluded() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            do {
                try db.execute(sql: """
                    CREATE TABLE player (id INTEGER PRIMARY KEY, name TEXT);
                    CREATE INDEX expressionIndex ON player (LENGTH(name));
                    CREATE INDEX columnIndex ON player (name);
                    """)
                let indexes = try db.indexes(on: "player")
                XCTAssertEqual(indexes.count, 1)
                XCTAssertEqual(indexes[0].name, "columnIndex")
                XCTAssertEqual(indexes[0].origin, .createIndex)
                XCTAssertEqual(indexes[0].columns, ["name"])
                XCTAssertFalse(indexes[0].isUnique)
            }
        }
    }
}
