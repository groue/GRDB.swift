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
                    PRIMARY KEY(c, a)
                )
                """)
            let columns = try db.columns(in: "t")
            XCTAssertEqual(columns.count, 11)
            
            XCTAssertEqual(columns[0].name, "a")
            XCTAssertEqual(columns[0].isNotNull, false)
            XCTAssertEqual(columns[0].type, "INT")
            // D. Richard Hipp wrote in SQLite mailing list on Tue Apr 30 22:43:47 EDT 2013 (http://mailinglists.sqlite.org/cgi-bin/mailman/private/sqlite-users/2013-April/046034.html):
            //
            // > Re: Incorrect documentation for PRAGMA table_info (pk column)
            // >
            // > For SQLite 3.7.15 and earlier, the "pk" columns meaning was undocumented
            // > and hence undefined.  As it happened it was always 1.  Beginning with
            // > SQLite 3.7.16 we defined the meaning of the "pk" column to be the 1-based
            // > index of the column in the primary key.
            //
            // https://sqlite.org/releaselog/3_7_16.html
            //
            // > Enhance the PRAGMA table_info command so that the "pk" column
            // > is an increasing integer to show the order of columns in the
            // > primary key.
            if sqlite3_libversion_number() < 3007016 {
                XCTAssertEqual(columns[0].primaryKeyIndex, 1)
            } else {
                XCTAssertEqual(columns[0].primaryKeyIndex, 2)
            }
            XCTAssertNil(columns[0].defaultValueSQL)
            
            XCTAssertEqual(columns[1].name, "b")
            XCTAssertEqual(columns[1].isNotNull, false)
            XCTAssertEqual(columns[1].type, "TEXT")
            XCTAssertEqual(columns[1].primaryKeyIndex, 0)
            XCTAssertNil(columns[1].defaultValueSQL)
            
            XCTAssertEqual(columns[2].name, "c")
            XCTAssertEqual(columns[2].isNotNull, false)
            XCTAssertEqual(columns[2].type, "VARCHAR(10)")
            XCTAssertEqual(columns[2].primaryKeyIndex, 1)
            XCTAssertNil(columns[2].defaultValueSQL)
            
            XCTAssertEqual(columns[3].name, "d")
            XCTAssertEqual(columns[3].isNotNull, false)
            XCTAssertEqual(columns[3].type.uppercased(), "INT") // "int" or "INT" depending of SQLite version
            XCTAssertEqual(columns[3].primaryKeyIndex, 0)
            XCTAssertEqual(columns[3].defaultValueSQL, "NULL")
            
            XCTAssertEqual(columns[4].name, "e")
            XCTAssertEqual(columns[4].isNotNull, true)
            XCTAssertEqual(columns[4].type.uppercased(), "TEXT") // "Text" or "TEXT" depending of SQLite version
            XCTAssertEqual(columns[4].primaryKeyIndex, 0)
            XCTAssertEqual(columns[4].defaultValueSQL, "'foo'")
            
            XCTAssertEqual(columns[5].name, "fooéı👨👨🏿🇫🇷🇨🇮")
            XCTAssertEqual(columns[5].isNotNull, false)
            XCTAssertEqual(columns[5].type, "INT")
            XCTAssertEqual(columns[5].primaryKeyIndex, 0)
            XCTAssertEqual(columns[5].defaultValueSQL, "0")
            
            XCTAssertEqual(columns[6].name, "g")
            XCTAssertEqual(columns[6].isNotNull, false)
            XCTAssertEqual(columns[6].type, "INT")
            XCTAssertEqual(columns[6].primaryKeyIndex, 0)
            XCTAssertEqual(columns[6].defaultValueSQL, "1e6")
            
            XCTAssertEqual(columns[7].name, "h")
            XCTAssertEqual(columns[7].isNotNull, false)
            XCTAssertEqual(columns[7].type, "REAL")
            XCTAssertEqual(columns[7].primaryKeyIndex, 0)
            XCTAssertEqual(columns[7].defaultValueSQL, "1.0")
            
            XCTAssertEqual(columns[8].name, "i")
            XCTAssertEqual(columns[8].isNotNull, false)
            XCTAssertEqual(columns[8].type, "DATETIME")
            XCTAssertEqual(columns[8].primaryKeyIndex, 0)
            XCTAssertEqual(columns[8].defaultValueSQL, "CURRENT_TIMESTAMP")
            
            XCTAssertEqual(columns[9].name, "j")
            XCTAssertEqual(columns[9].isNotNull, false)
            XCTAssertEqual(columns[9].type, "DATE")
            XCTAssertEqual(columns[9].primaryKeyIndex, 0)
            XCTAssertEqual(columns[9].defaultValueSQL, "DATETIME('now', 'localtime')")
            
            XCTAssertEqual(columns[10].name, "")
            XCTAssertEqual(columns[10].isNotNull, false)
            XCTAssertEqual(columns[10].type, "fooéı👨👨🏿🇫🇷🇨🇮")
            XCTAssertEqual(columns[10].primaryKeyIndex, 0)
            XCTAssertNil(columns[10].defaultValueSQL)
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
}
