import XCTest
@testable import GRDB

class ColumnInfoTests: GRDBTestCase {
    
    func testColumnInfo() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(sql: """
                CREATE TABLE t (
                    a INT,
                    b TEXT,
                    c VARCHAR(10),
                    d int DEFAULT NULL,
                    e Text NOT NULL DEFAULT 'foo',
                    "fooéı👨👨🏿🇫🇷🇨🇮" INT DEFAULT 0,
                    g INT DEFAULT 1e6,
                    h REAL DEFAULT 1.0,
                    i DATETIME DEFAULT CURRENT_TIMESTAMP,
                    j DATE DEFAULT (DATETIME('now', 'localtime')),
                    "" fooéı👨👨🏿🇫🇷🇨🇮,
                    untyped,
                    PRIMARY KEY(c, a)
                )
                """)
            let columns = try db.columns(in: "t")
            XCTAssertEqual(columns.count, 12)
            
            XCTAssertEqual(columns[0].name, "a")
            XCTAssertEqual(columns[0].isNotNull, false)
            XCTAssertEqual(columns[0].type, "INT")
            XCTAssertEqual(columns[0].columnType?.rawValue, "INT")
            XCTAssertEqual(columns[0].primaryKeyIndex, 2)
            XCTAssertNil(columns[0].defaultValueSQL)
            
            XCTAssertEqual(columns[1].name, "b")
            XCTAssertEqual(columns[1].isNotNull, false)
            XCTAssertEqual(columns[1].type, "TEXT")
            XCTAssertEqual(columns[1].columnType?.rawValue, "TEXT")
            XCTAssertEqual(columns[1].primaryKeyIndex, 0)
            XCTAssertNil(columns[1].defaultValueSQL)
            
            XCTAssertEqual(columns[2].name, "c")
            XCTAssertEqual(columns[2].isNotNull, false)
            XCTAssertEqual(columns[2].type, "VARCHAR(10)")
            XCTAssertEqual(columns[2].columnType?.rawValue, "VARCHAR(10)")
            XCTAssertEqual(columns[2].primaryKeyIndex, 1)
            XCTAssertNil(columns[2].defaultValueSQL)
            
            XCTAssertEqual(columns[3].name, "d")
            XCTAssertEqual(columns[3].isNotNull, false)
            XCTAssertEqual(columns[3].type.uppercased(), "INT") // "int" or "INT" depending of SQLite version
            XCTAssertEqual(columns[3].columnType?.rawValue.uppercased(), "INT") // "int" or "INT" depending of SQLite version
            XCTAssertEqual(columns[3].primaryKeyIndex, 0)
            XCTAssertEqual(columns[3].defaultValueSQL, "NULL")
            
            XCTAssertEqual(columns[4].name, "e")
            XCTAssertEqual(columns[4].isNotNull, true)
            XCTAssertEqual(columns[4].type.uppercased(), "TEXT") // "Text" or "TEXT" depending of SQLite version
            XCTAssertEqual(columns[4].columnType?.rawValue.uppercased(), "TEXT") // "Text" or "TEXT" depending of SQLite version
            XCTAssertEqual(columns[4].primaryKeyIndex, 0)
            XCTAssertEqual(columns[4].defaultValueSQL, "'foo'")
            
            XCTAssertEqual(columns[5].name, "fooéı👨👨🏿🇫🇷🇨🇮")
            XCTAssertEqual(columns[5].isNotNull, false)
            XCTAssertEqual(columns[5].type, "INT")
            XCTAssertEqual(columns[5].columnType?.rawValue, "INT")
            XCTAssertEqual(columns[5].primaryKeyIndex, 0)
            XCTAssertEqual(columns[5].defaultValueSQL, "0")
            
            XCTAssertEqual(columns[6].name, "g")
            XCTAssertEqual(columns[6].isNotNull, false)
            XCTAssertEqual(columns[6].type, "INT")
            XCTAssertEqual(columns[6].columnType?.rawValue, "INT")
            XCTAssertEqual(columns[6].primaryKeyIndex, 0)
            XCTAssertEqual(columns[6].defaultValueSQL, "1e6")
            
            XCTAssertEqual(columns[7].name, "h")
            XCTAssertEqual(columns[7].isNotNull, false)
            XCTAssertEqual(columns[7].type, "REAL")
            XCTAssertEqual(columns[7].columnType?.rawValue, "REAL")
            XCTAssertEqual(columns[7].primaryKeyIndex, 0)
            XCTAssertEqual(columns[7].defaultValueSQL, "1.0")
            
            XCTAssertEqual(columns[8].name, "i")
            XCTAssertEqual(columns[8].isNotNull, false)
            XCTAssertEqual(columns[8].type, "DATETIME")
            XCTAssertEqual(columns[8].columnType?.rawValue, "DATETIME")
            XCTAssertEqual(columns[8].primaryKeyIndex, 0)
            XCTAssertEqual(columns[8].defaultValueSQL, "CURRENT_TIMESTAMP")
            
            XCTAssertEqual(columns[9].name, "j")
            XCTAssertEqual(columns[9].isNotNull, false)
            XCTAssertEqual(columns[9].type, "DATE")
            XCTAssertEqual(columns[9].columnType?.rawValue, "DATE")
            XCTAssertEqual(columns[9].primaryKeyIndex, 0)
            XCTAssertEqual(columns[9].defaultValueSQL, "DATETIME('now', 'localtime')")
            
            XCTAssertEqual(columns[10].name, "")
            XCTAssertEqual(columns[10].isNotNull, false)
            XCTAssertEqual(columns[10].type, "fooéı👨👨🏿🇫🇷🇨🇮")
            XCTAssertEqual(columns[10].columnType?.rawValue, "fooéı👨👨🏿🇫🇷🇨🇮")
            XCTAssertEqual(columns[10].primaryKeyIndex, 0)
            XCTAssertNil(columns[10].defaultValueSQL)
            
            XCTAssertEqual(columns[11].name, "untyped")
            XCTAssertEqual(columns[11].isNotNull, false)
            XCTAssertEqual(columns[11].type, "")
            XCTAssertNil(columns[11].columnType)
            XCTAssertEqual(columns[11].primaryKeyIndex, 0)
            XCTAssertNil(columns[11].defaultValueSQL)
        }
    }
    
    func testGeneratedColumnInfo() throws {
        #if !GRDBCUSTOMSQLITE
        throw XCTSkip("Generated columns are not available")
        #else
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(sql: """
                CREATE TABLE t (
                    a INT,
                    b ALWAYS GENERATED AS (a),
                    c ALWAYS GENERATED AS (a) VIRTUAL,
                    d ALWAYS GENERATED AS (a) STORED,
                    e INT ALWAYS GENERATED AS (a),
                    f TEXT ALWAYS GENERATED AS (a),
                    g ALWAYS GENERATED AS (a) NOT NULL
                )
                """)
            let columns = try db.columns(in: "t")
            XCTAssertEqual(columns.count, 7)
            
            XCTAssertEqual(columns[0].name, "a")
            XCTAssertEqual(columns[0].isNotNull, false)
            XCTAssertEqual(columns[0].type, "INT")
            XCTAssertEqual(columns[0].primaryKeyIndex, 0)
            XCTAssertNil(columns[0].defaultValueSQL)
            
            XCTAssertEqual(columns[1].name, "b")
            XCTAssertEqual(columns[1].isNotNull, false)
            XCTAssertEqual(columns[1].type, "ALWAYS GENERATED")
            XCTAssertEqual(columns[1].primaryKeyIndex, 0)
            XCTAssertNil(columns[1].defaultValueSQL)
            
            XCTAssertEqual(columns[2].name, "c")
            XCTAssertEqual(columns[2].isNotNull, false)
            XCTAssertEqual(columns[2].type, "ALWAYS GENERATED")
            XCTAssertEqual(columns[2].primaryKeyIndex, 0)
            XCTAssertNil(columns[2].defaultValueSQL)
            
            XCTAssertEqual(columns[3].name, "d")
            XCTAssertEqual(columns[3].isNotNull, false)
            XCTAssertEqual(columns[3].type, "ALWAYS GENERATED")
            XCTAssertEqual(columns[3].primaryKeyIndex, 0)
            XCTAssertNil(columns[3].defaultValueSQL)
            
            XCTAssertEqual(columns[4].name, "e")
            XCTAssertEqual(columns[4].isNotNull, false)
            XCTAssertEqual(columns[4].type, "INT ALWAYS GENERATED")
            XCTAssertEqual(columns[4].primaryKeyIndex, 0)
            XCTAssertNil(columns[4].defaultValueSQL)
            
            XCTAssertEqual(columns[5].name, "f")
            XCTAssertEqual(columns[5].isNotNull, false)
            XCTAssertEqual(columns[5].type, "TEXT ALWAYS GENERATED")
            XCTAssertEqual(columns[5].primaryKeyIndex, 0)
            XCTAssertNil(columns[5].defaultValueSQL)
            
            XCTAssertEqual(columns[6].name, "g")
            XCTAssertEqual(columns[6].isNotNull, true)
            XCTAssertEqual(columns[6].type, "ALWAYS GENERATED")
            XCTAssertEqual(columns[6].primaryKeyIndex, 0)
            XCTAssertNil(columns[6].defaultValueSQL)
        }
        #endif
    }
    
    func testViews() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.execute(sql: """
                CREATE TABLE t (
                    a INT,
                    b TEXT,
                    c VARCHAR(10),
                    d int DEFAULT NULL,
                    e Text NOT NULL DEFAULT 'foo',
                    "fooéı👨👨🏿🇫🇷🇨🇮" INT DEFAULT 0,
                    g INT DEFAULT 1e6,
                    h REAL DEFAULT 1.0,
                    i DATETIME DEFAULT CURRENT_TIMESTAMP,
                    j DATE DEFAULT (DATETIME('now', 'localtime')),
                    "" fooéı👨👨🏿🇫🇷🇨🇮,
                    PRIMARY KEY(c, a)
                );
                CREATE VIEW v AS SELECT * FROM t;
                """)
            
            let columns = try db.columns(in: "v")
            XCTAssertEqual(columns.count, 11)
            
            XCTAssertEqual(columns[0].name, "a")
            XCTAssertEqual(columns[0].isNotNull, false)
            XCTAssertEqual(columns[0].type, "INT")
            XCTAssertEqual(columns[0].primaryKeyIndex, 0)
            XCTAssertNil(columns[0].defaultValueSQL)
            
            XCTAssertEqual(columns[1].name, "b")
            XCTAssertEqual(columns[1].isNotNull, false)
            XCTAssertEqual(columns[1].type, "TEXT")
            XCTAssertEqual(columns[1].primaryKeyIndex, 0)
            XCTAssertNil(columns[1].defaultValueSQL)
            
            XCTAssertEqual(columns[2].name, "c")
            XCTAssertEqual(columns[2].isNotNull, false)
            XCTAssertEqual(columns[2].type, "VARCHAR(10)")
            XCTAssertEqual(columns[2].primaryKeyIndex, 0)
            XCTAssertNil(columns[2].defaultValueSQL)
            
            XCTAssertEqual(columns[3].name, "d")
            XCTAssertEqual(columns[3].isNotNull, false)
            XCTAssertEqual(columns[3].type.uppercased(), "INT") // "int" or "INT" depending of SQLite version
            XCTAssertEqual(columns[3].primaryKeyIndex, 0)
            XCTAssertNil(columns[3].defaultValueSQL)
            
            XCTAssertEqual(columns[4].name, "e")
            XCTAssertEqual(columns[3].isNotNull, false)
            XCTAssertEqual(columns[4].type.uppercased(), "TEXT") // "Text" or "TEXT" depending of SQLite version
            XCTAssertEqual(columns[4].primaryKeyIndex, 0)
            XCTAssertNil(columns[4].defaultValueSQL)
            
            XCTAssertEqual(columns[5].name, "fooéı👨👨🏿🇫🇷🇨🇮")
            XCTAssertEqual(columns[5].isNotNull, false)
            XCTAssertEqual(columns[5].type, "INT")
            XCTAssertEqual(columns[5].primaryKeyIndex, 0)
            XCTAssertNil(columns[5].defaultValueSQL)
            
            XCTAssertEqual(columns[6].name, "g")
            XCTAssertEqual(columns[6].isNotNull, false)
            XCTAssertEqual(columns[6].type, "INT")
            XCTAssertEqual(columns[6].primaryKeyIndex, 0)
            XCTAssertNil(columns[6].defaultValueSQL)
            
            XCTAssertEqual(columns[7].name, "h")
            XCTAssertEqual(columns[7].isNotNull, false)
            XCTAssertEqual(columns[7].type, "REAL")
            XCTAssertEqual(columns[7].primaryKeyIndex, 0)
            XCTAssertNil(columns[7].defaultValueSQL)
            
            XCTAssertEqual(columns[8].name, "i")
            XCTAssertEqual(columns[8].isNotNull, false)
            XCTAssertEqual(columns[8].type, "DATETIME")
            XCTAssertEqual(columns[8].primaryKeyIndex, 0)
            XCTAssertNil(columns[8].defaultValueSQL)
            
            XCTAssertEqual(columns[9].name, "j")
            XCTAssertEqual(columns[9].isNotNull, false)
            XCTAssertEqual(columns[9].type, "DATE")
            XCTAssertEqual(columns[9].primaryKeyIndex, 0)
            XCTAssertNil(columns[9].defaultValueSQL)
            
            XCTAssertEqual(columns[10].name, "")
            XCTAssertEqual(columns[10].isNotNull, false)
            XCTAssertEqual(columns[10].type, "fooéı👨👨🏿🇫🇷🇨🇮")
            XCTAssertEqual(columns[10].primaryKeyIndex, 0)
            XCTAssertNil(columns[10].defaultValueSQL)
        }
    }

    // Regression test for https://github.com/groue/GRDB.swift/issues/1124
    // See also https://sqlite.org/forum/forumpost/721da02ba2
    func testIssue1124() throws {
        class Observer: TransactionObserver {
            func observes(eventsOfKind eventKind: DatabaseEventKind) -> Bool { true }
            func databaseDidChange(with event: DatabaseEvent) { }
            func databaseDidCommit(_ db: Database) { }
            func databaseDidRollback(_ db: Database) { }
        }
        let dbQueue = try makeDatabaseQueue()
        dbQueue.add(transactionObserver: Observer(), extent: .databaseLifetime)
        try dbQueue.write { db in
            try db.execute(sql: """
                CREATE VIRTUAL TABLE t1 USING rtree(id,minX,maxX,minY,maxY);
                CREATE TABLE t2 (a);
                ALTER TABLE t2 RENAME TO t3;
                """)
            _ = try db.columns(in: "t1")
        }
    }
    
    func testUnknownSchema() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(sql: "CREATE TABLE t (id INTEGER)")
            do {
                _ = try db.columns(in: "t", in: "invalid")
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
            try db.execute(sql: "CREATE TABLE t (id INTEGER)")
            let columns = try db.columns(in: "t")
            XCTAssertEqual(columns.count, 1)
            XCTAssertEqual(columns[0].name, "id")
            XCTAssertEqual(columns[0].type, "INTEGER")
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
            try db.execute(sql: "CREATE TABLE t (id2 TEXT)")
        }
        let main = try makeDatabaseQueue(filename: "main")
        try main.inDatabase { db in
            try db.execute(sql: "CREATE TABLE t (id1 INTEGER)")
            try db.execute(literal: "ATTACH DATABASE \(attached.path) AS attached")
            
            let columnsMain = try db.columns(in: "t", in: "main")
            XCTAssertEqual(columnsMain.count, 1)
            XCTAssertEqual(columnsMain[0].name, "id1")
            XCTAssertEqual(columnsMain[0].type, "INTEGER")
            
            let columnsAttached = try db.columns(in: "t", in: "attached")
            XCTAssertEqual(columnsAttached.count, 1)
            XCTAssertEqual(columnsAttached[0].name, "id2")
            XCTAssertEqual(columnsAttached[0].type, "TEXT")
        }
    }
    
    // The `t` table in the attached database should never
    // be found unless explicitly specified as it is after
    // `main.t` in resolution order.
    func testUnspecifiedSchemaWithTableNameCollisions() throws {
        #if GRDBCIPHER_USE_ENCRYPTION
        // Avoid error due to key not being provided:
        // file is not a database - while executing `ATTACH DATABASE...`
        throw XCTSkip("This test does not support encrypted databases")
        #endif
        
        let attached = try makeDatabaseQueue(filename: "attached1")
        try attached.inDatabase { db in
            try db.execute(sql: "CREATE TABLE t (id2 TEXT)")
        }
        let main = try makeDatabaseQueue(filename: "main")
        try main.inDatabase { db in
            try db.execute(sql: "CREATE TABLE t (id1 INTEGER)")
            try db.execute(literal: "ATTACH DATABASE \(attached.path) AS attached")
            
            let columnsMain = try db.columns(in: "t")
            XCTAssertEqual(columnsMain.count, 1)
            XCTAssertEqual(columnsMain[0].name, "id1")
            XCTAssertEqual(columnsMain[0].type, "INTEGER")
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
            try db.execute(sql: "CREATE TABLE t (id2 TEXT)")
        }
        let main = try makeDatabaseQueue(filename: "main")
        try main.inDatabase { db in
            try db.execute(literal: "ATTACH DATABASE \(attached.path) AS attached")
            
            let columnsMain = try db.columns(in: "t")
            XCTAssertEqual(columnsMain.count, 1)
            XCTAssertEqual(columnsMain[0].name, "id2")
            XCTAssertEqual(columnsMain[0].type, "TEXT")
        }
    }
}
