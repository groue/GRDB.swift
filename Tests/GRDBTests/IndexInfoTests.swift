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
    
    func testUnknownSchema() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(sql: """
                CREATE TABLE player (id INTEGER PRIMARY KEY, name TEXT);
                CREATE INDEX columnIndex ON player (name);
                """)
            do {
                _ = try db.indexes(on: "player", in: "invalid")
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
            try db.execute(sql: """
                CREATE TABLE player (id INTEGER PRIMARY KEY, name TEXT);
                CREATE INDEX columnIndex ON player (name);
                """)
            let indexes = try db.indexes(on: "player", in: "main")
            XCTAssertEqual(indexes.count, 1)
            XCTAssertEqual(indexes[0].name, "columnIndex")
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
            try db.execute(sql: """
                CREATE TABLE player (id INTEGER PRIMARY KEY, name TEXT);
                CREATE INDEX columnIndexAttached ON player (name);
                """)
        }
        let main = try makeDatabaseQueue(filename: "main")
        try main.inDatabase { db in
            try db.execute(sql: """
                CREATE TABLE player (id INTEGER PRIMARY KEY, name TEXT);
                CREATE INDEX columnIndex ON player (name);
                """)
            try db.execute(literal: "ATTACH DATABASE \(attached.path) AS attached")
            let mainIndexes = try db.indexes(on: "player", in: "main")
            XCTAssertEqual(mainIndexes.count, 1)
            XCTAssertEqual(mainIndexes[0].name, "columnIndex")
            
            let attachedIndexes = try db.indexes(on: "player", in: "attached")
            XCTAssertEqual(attachedIndexes.count, 1)
            XCTAssertEqual(attachedIndexes[0].name, "columnIndexAttached")
        }
    }
    
    // The `player` table in the attached database should never
    // be found unless explicitly specified as it is after
    // `main.player` in resolution order.
    func testUnspecifiedSchemaWithTableNameCollisions() throws {
        #if GRDBCIPHER_USE_ENCRYPTION
        // Avoid error due to key not being provided:
        // file is not a database - while executing `ATTACH DATABASE...`
        throw XCTSkip("This test does not support encrypted databases")
        #endif
        
        let attached = try makeDatabaseQueue(filename: "attached1")
        try attached.inDatabase { db in
            try db.execute(sql: """
                CREATE TABLE player (id INTEGER PRIMARY KEY, name TEXT);
                CREATE INDEX columnIndexAttached ON player (name);
                """)
        }
        let main = try makeDatabaseQueue(filename: "main")
        try main.inDatabase { db in
            try db.execute(sql: """
                CREATE TABLE player (id INTEGER PRIMARY KEY, name TEXT);
                CREATE INDEX columnIndex ON player (name);
                """)
            try db.execute(literal: "ATTACH DATABASE \(attached.path) AS attached")
            let mainIndexes = try db.indexes(on: "player")
            XCTAssertEqual(mainIndexes.count, 1)
            XCTAssertEqual(mainIndexes[0].name, "columnIndex")
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
            try db.execute(sql: """
                CREATE TABLE player (id INTEGER PRIMARY KEY, name TEXT);
                CREATE INDEX columnIndexAttached ON player (name);
                """)
        }
        let main = try makeDatabaseQueue(filename: "main")
        try main.inDatabase { db in
            try db.execute(literal: "ATTACH DATABASE \(attached.path) AS attached")
            let attachedIndexes = try db.indexes(on: "player", in: "attached")
            XCTAssertEqual(attachedIndexes.count, 1)
            XCTAssertEqual(attachedIndexes[0].name, "columnIndexAttached")
        }
    }
}
