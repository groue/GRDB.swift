import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class SQLTableBuilderTests: GRDBTestCase {

    func testCreateTable() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                // Simple table creation
                try db.create(table: "test") { t in
                    t.column("id", .Integer).primaryKey()
                    t.column("name", .Text)
                }
                XCTAssertEqual(self.lastSQLQuery,
                    "CREATE TABLE \"test\" (" +
                        "\"id\" INTEGER PRIMARY KEY, " +
                        "\"name\" TEXT" +
                    ")")
            }
        }
    }
    
    func testTableCreationOptions() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.create(table: "test", temporary: true, ifNotExists: true, withoutRowID: true) { t in
                    t.column("id", .Integer).primaryKey()
                }
                XCTAssertEqual(self.lastSQLQuery,
                    "CREATE TEMPORARY TABLE IF NOT EXISTS \"test\" (" +
                        "\"id\" INTEGER PRIMARY KEY" +
                    ") WITHOUT ROWID")
            }
        }
    }
    
    func testColumnPrimaryKeyOptions() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inTransaction { db in
                try db.create(table: "test") { t in
                    t.column("id", .Integer).primaryKey(ordering: .Desc, onConflict: .Fail)
                }
                XCTAssertEqual(self.lastSQLQuery,
                    "CREATE TABLE \"test\" (" +
                        "\"id\" INTEGER PRIMARY KEY DESC ON CONFLICT FAIL" +
                    ")")
                return .Rollback
            }
            try dbQueue.inTransaction { db in
                try db.create(table: "test") { t in
                    t.column("id", .Integer).primaryKey(autoincrement: true)
                }
                XCTAssertEqual(self.lastSQLQuery,
                    "CREATE TABLE \"test\" (" +
                        "\"id\" INTEGER PRIMARY KEY AUTOINCREMENT" +
                    ")")
                return .Rollback
            }
        }
    }
    
    func testColumnNotNull() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.create(table: "test") { t in
                    t.column("a", .Integer).notNull()
                    t.column("b", .Integer).notNull(onConflict: .Abort)
                    t.column("c", .Integer).notNull(onConflict: .Rollback)
                    t.column("d", .Integer).notNull(onConflict: .Fail)
                    t.column("e", .Integer).notNull(onConflict: .Ignore)
                    t.column("f", .Integer).notNull(onConflict: .Replace)
                }
                XCTAssertEqual(self.lastSQLQuery,
                    "CREATE TABLE \"test\" (" +
                        "\"a\" INTEGER NOT NULL, " +
                        "\"b\" INTEGER NOT NULL, " +
                        "\"c\" INTEGER NOT NULL ON CONFLICT ROLLBACK, " +
                        "\"d\" INTEGER NOT NULL ON CONFLICT FAIL, " +
                        "\"e\" INTEGER NOT NULL ON CONFLICT IGNORE, " +
                        "\"f\" INTEGER NOT NULL ON CONFLICT REPLACE" +
                    ")")
            }
        }
    }
    
    func testColumnUnique() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.create(table: "test") { t in
                    t.column("a", .Integer).unique()
                    t.column("b", .Integer).unique(onConflict: .Abort)
                    t.column("c", .Integer).unique(onConflict: .Rollback)
                    t.column("d", .Integer).unique(onConflict: .Fail)
                    t.column("e", .Integer).unique(onConflict: .Ignore)
                    t.column("f", .Integer).unique(onConflict: .Replace)
                }
                XCTAssertEqual(self.lastSQLQuery,
                    "CREATE TABLE \"test\" (" +
                        "\"a\" INTEGER UNIQUE, " +
                        "\"b\" INTEGER UNIQUE, " +
                        "\"c\" INTEGER UNIQUE ON CONFLICT ROLLBACK, " +
                        "\"d\" INTEGER UNIQUE ON CONFLICT FAIL, " +
                        "\"e\" INTEGER UNIQUE ON CONFLICT IGNORE, " +
                        "\"f\" INTEGER UNIQUE ON CONFLICT REPLACE" +
                    ")")
            }
        }
    }
    
    func testColumnCheck() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.create(table: "test") { t in
                    t.column("a", .Integer).check { $0 > 0 }
                }
                XCTAssertEqual(self.lastSQLQuery,
                    "CREATE TABLE \"test\" (" +
                        "\"a\" INTEGER CHECK ((\"a\" > 0))" +
                    ")")
                
                // Sanity check
                try db.execute("INSERT INTO test (a) VALUES (1)")
                do {
                    try db.execute("INSERT INTO test (a) VALUES (0)")
                    XCTFail()
                } catch {
                }
            }
        }
    }
    
    func testColumnDefault() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.create(table: "test") { t in
                    t.column("a", .Integer).defaults(1)
                }
                XCTAssertEqual(self.lastSQLQuery,
                    "CREATE TABLE \"test\" (" +
                        "\"a\" INTEGER DEFAULT (1)" +
                    ")")
                
                // Sanity check
                try db.execute("INSERT INTO test DEFAULT VALUES")
                XCTAssertEqual(Int.fetchOne(db, "SELECT a FROM test")!, 1)
            }
        }
    }
    
    func testColumnCollation() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inTransaction { db in
                try db.create(table: "test") { t in
                    t.column("name", .Text).collate(.Nocase)
                }
                XCTAssertEqual(self.lastSQLQuery,
                    "CREATE TABLE \"test\" (" +
                        "\"name\" TEXT COLLATE NOCASE" +
                    ")")
                return .Rollback
            }
            
            let collation = DatabaseCollation("foo") { (lhs, rhs) in .OrderedSame }
            dbQueue.addCollation(collation)
            try dbQueue.inTransaction { db in
                try db.create(table: "test") { t in
                    t.column("name", .Text).collate(collation)
                }
                XCTAssertEqual(self.lastSQLQuery,
                    "CREATE TABLE \"test\" (" +
                        "\"name\" TEXT COLLATE foo" +
                    ")")
                return .Rollback
            }
        }
    }
    
    func testDropTable() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.create(table: "test") { t in
                    t.column("id", .Integer).primaryKey()
                    t.column("name", .Text)
                }
                XCTAssertTrue(db.tableExists("test"))
                
                try db.drop(table: "test")
                XCTAssertEqual(self.lastSQLQuery, "DROP TABLE \"test\"")
                XCTAssertFalse(db.tableExists("test"))
            }
        }
    }
}
