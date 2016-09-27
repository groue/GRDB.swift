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
                    t.column("id", .integer).primaryKey()
                    t.column("name", .text)
                }
                XCTAssertEqual(
                    self.lastSQLQuery,
                    ("CREATE TABLE \"test\" (" +
                        "\"id\" INTEGER PRIMARY KEY, " +
                        "\"name\" TEXT" +
                        ")") as String)
            }
        }
    }
    
    func testTableCreationOptions() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                if #available(iOS 8.2, OSX 10.10, *) {
                    try db.create(table: "test", temporary: true, ifNotExists: true, withoutRowID: true) { t in
                        t.column("id", .integer).primaryKey()
                    }
                    XCTAssertEqual(
                        self.lastSQLQuery,
                        ("CREATE TEMPORARY TABLE IF NOT EXISTS \"test\" (" +
                            "\"id\" INTEGER PRIMARY KEY" +
                            ") WITHOUT ROWID") as String)
                } else {
                    try db.create(table: "test", temporary: true, ifNotExists: true) { t in
                        t.column("id", .integer).primaryKey()
                    }
                    XCTAssertEqual(
                        self.lastSQLQuery,
                        ("CREATE TEMPORARY TABLE IF NOT EXISTS \"test\" (" +
                            "\"id\" INTEGER PRIMARY KEY" +
                            ")") as String)
                }
            }
        }
    }
    
    func testColumnPrimaryKeyOptions() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inTransaction { db in
                try db.create(table: "test") { t in
                    t.column("id", .integer).primaryKey(onConflict: .fail)
                }
                XCTAssertEqual(
                    self.lastSQLQuery,
                    ("CREATE TABLE \"test\" (" +
                        "\"id\" INTEGER PRIMARY KEY ON CONFLICT FAIL" +
                        ")") as String)
                return .rollback
            }
            try dbQueue.inTransaction { db in
                try db.create(table: "test") { t in
                    t.column("id", .integer).primaryKey(autoincrement: true)
                }
                XCTAssertEqual(
                    self.lastSQLQuery,
                    ("CREATE TABLE \"test\" (" +
                        "\"id\" INTEGER PRIMARY KEY AUTOINCREMENT" +
                        ")") as String)
                return .rollback
            }
        }
    }
    
    func testColumnNotNull() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.create(table: "test") { t in
                    t.column("a", .integer).notNull()
                    t.column("b", .integer).notNull(onConflict: .abort)
                    t.column("c", .integer).notNull(onConflict: .rollback)
                    t.column("d", .integer).notNull(onConflict: .fail)
                    t.column("e", .integer).notNull(onConflict: .ignore)
                    t.column("f", .integer).notNull(onConflict: .replace)
                }
                XCTAssertEqual(
                    self.lastSQLQuery,
                    ("CREATE TABLE \"test\" (" +
                        "\"a\" INTEGER NOT NULL, " +
                        "\"b\" INTEGER NOT NULL, " +
                        "\"c\" INTEGER NOT NULL ON CONFLICT ROLLBACK, " +
                        "\"d\" INTEGER NOT NULL ON CONFLICT FAIL, " +
                        "\"e\" INTEGER NOT NULL ON CONFLICT IGNORE, " +
                        "\"f\" INTEGER NOT NULL ON CONFLICT REPLACE" +
                        ")") as String)
            }
        }
    }
    
    func testColumnUnique() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.create(table: "test") { t in
                    t.column("a", .integer).unique()
                    t.column("b", .integer).unique(onConflict: .abort)
                    t.column("c", .integer).unique(onConflict: .rollback)
                    t.column("d", .integer).unique(onConflict: .fail)
                    t.column("e", .integer).unique(onConflict: .ignore)
                    t.column("f", .integer).unique(onConflict: .replace)
                }
                XCTAssertEqual(
                    self.lastSQLQuery,
                    ("CREATE TABLE \"test\" (" +
                        "\"a\" INTEGER UNIQUE, " +
                        "\"b\" INTEGER UNIQUE, " +
                        "\"c\" INTEGER UNIQUE ON CONFLICT ROLLBACK, " +
                        "\"d\" INTEGER UNIQUE ON CONFLICT FAIL, " +
                        "\"e\" INTEGER UNIQUE ON CONFLICT IGNORE, " +
                        "\"f\" INTEGER UNIQUE ON CONFLICT REPLACE" +
                        ")") as String)
            }
        }
    }
    
    func testColumnCheck() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.create(table: "test") { t in
                    t.column("a", .integer).check { $0 > 0 }
                    t.column("b", .integer).check(sql: "b <> 2")
                    t.column("c", .integer).check { $0 > 0 }.check { $0 < 10 }
                }
                XCTAssertEqual(
                    self.lastSQLQuery,
                    ("CREATE TABLE \"test\" (" +
                        "\"a\" INTEGER CHECK ((\"a\" > 0)), " +
                        "\"b\" INTEGER CHECK (b <> 2), " +
                        "\"c\" INTEGER CHECK ((\"c\" > 0)) CHECK ((\"c\" < 10))" +
                        ")") as String)
                
                // Sanity check
                try db.execute("INSERT INTO test (a, b, c) VALUES (1, 0, 1)")
                do {
                    try db.execute("INSERT INTO test (a, b, c) VALUES (0, 0, 1)")
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
                    t.column("a", .integer).defaults(to: 1)
                    t.column("b", .integer).defaults(to: 1.0)
                    t.column("c", .integer).defaults(to: "'fooéı👨👨🏿🇫🇷🇨🇮'")
                    t.column("d", .integer).defaults(to: "foo".data(using: .utf8)!)
                    t.column("e", .integer).defaults(sql: "NULL")
                }
                XCTAssertEqual(
                    self.lastSQLQuery,
                    ("CREATE TABLE \"test\" (" +
                        "\"a\" INTEGER DEFAULT 1, " +
                        "\"b\" INTEGER DEFAULT 1.0, " +
                        "\"c\" INTEGER DEFAULT '''fooéı👨👨🏿🇫🇷🇨🇮''', " +
                        "\"d\" INTEGER DEFAULT X'666F6F', " +
                        "\"e\" INTEGER DEFAULT NULL" +
                        ")") as String)
                
                // Sanity check
                try db.execute("INSERT INTO test DEFAULT VALUES")
                XCTAssertEqual(Int.fetchOne(db, "SELECT a FROM test")!, 1)
                XCTAssertEqual(String.fetchOne(db, "SELECT c FROM test")!, "'fooéı👨👨🏿🇫🇷🇨🇮'")
            }
        }
    }
    
    func testColumnCollation() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inTransaction { db in
                try db.create(table: "test") { t in
                    t.column("name", .text).collate(.nocase)
                }
                XCTAssertEqual(
                    self.lastSQLQuery,
                    ("CREATE TABLE \"test\" (" +
                        "\"name\" TEXT COLLATE NOCASE" +
                        ")") as String)
                return .rollback
            }
            
            let collation = DatabaseCollation("foo") { (lhs, rhs) in .orderedSame }
            dbQueue.add(collation: collation)
            try dbQueue.inTransaction { db in
                try db.create(table: "test") { t in
                    t.column("name", .text).collate(collation)
                }
                XCTAssertEqual(
                    self.lastSQLQuery,
                    ("CREATE TABLE \"test\" (" +
                        "\"name\" TEXT COLLATE foo" +
                        ")") as String)
                return .rollback
            }
        }
    }
    
    func testColumnReference() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.create(table: "parent") { t in
                    t.column("name", .text).primaryKey()
                    t.column("email", .text).unique()
                }
                try db.create(table: "child") { t in
                    t.column("parentName", .text).references("parent", onDelete: .cascade, onUpdate: .cascade)
                    t.column("parentEmail", .text).references("parent", column: "email", onDelete: .restrict, deferred: true)
                    t.column("weird", .text).references("parent", column: "name").references("parent", column: "email")
                }
                XCTAssertEqual(
                    self.lastSQLQuery,
                    ("CREATE TABLE \"child\" (" +
                        "\"parentName\" TEXT REFERENCES \"parent\"(\"name\") ON DELETE CASCADE ON UPDATE CASCADE, " +
                        "\"parentEmail\" TEXT REFERENCES \"parent\"(\"email\") ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED, " +
                        "\"weird\" TEXT REFERENCES \"parent\"(\"name\") REFERENCES \"parent\"(\"email\")" +
                        ")") as String)
            }
        }
    }
    
    func testTablePrimaryKey() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inTransaction { db in
                try db.create(table: "test") { t in
                    t.primaryKey(["a", "b"])
                    t.column("a", .text)
                    t.column("b", .text)
                }
                XCTAssertEqual(
                    self.lastSQLQuery,
                    ("CREATE TABLE \"test\" (" +
                        "\"a\" TEXT, " +
                        "\"b\" TEXT, " +
                        "PRIMARY KEY (\"a\", \"b\")" +
                        ")") as String)
                return .rollback
            }
            try dbQueue.inTransaction { db in
                try db.create(table: "test") { t in
                    t.primaryKey(["a", "b"], onConflict: .fail)
                    t.column("a", .text)
                    t.column("b", .text)
                }
                XCTAssertEqual(
                    self.lastSQLQuery,
                    ("CREATE TABLE \"test\" (" +
                        "\"a\" TEXT, " +
                        "\"b\" TEXT, " +
                        "PRIMARY KEY (\"a\", \"b\") ON CONFLICT FAIL" +
                        ")") as String)
                return .rollback
            }
        }
    }
    
    func testTableUniqueKey() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.create(table: "test") { t in
                    t.uniqueKey(["a"])
                    t.uniqueKey(["b", "c"], onConflict: .fail)
                    t.column("a", .text)
                    t.column("b", .text)
                    t.column("c", .text)
                }
                XCTAssertEqual(
                    self.lastSQLQuery,
                    ("CREATE TABLE \"test\" (" +
                        "\"a\" TEXT, " +
                        "\"b\" TEXT, " +
                        "\"c\" TEXT, " +
                        "UNIQUE (\"a\"), " +
                        "UNIQUE (\"b\", \"c\") ON CONFLICT FAIL" +
                        ")") as String)
            }
        }
    }
    
    func testTableForeignKey() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.create(table: "parent") { t in
                    t.primaryKey(["a", "b"])
                    t.column("a", .text)
                    t.column("b", .text)
                }
                try db.create(table: "child") { t in
                    t.foreignKey(["c", "d"], references: "parent", onDelete: .cascade, onUpdate: .cascade)
                    t.foreignKey(["d", "e"], references: "parent", columns: ["b", "a"], onDelete: .restrict, deferred: true)
                    t.column("c", .text)
                    t.column("d", .text)
                    t.column("e", .text)
                }
                XCTAssertEqual(
                    self.lastSQLQuery,
                    ("CREATE TABLE \"child\" (" +
                        "\"c\" TEXT, " +
                        "\"d\" TEXT, " +
                        "\"e\" TEXT, " +
                        "FOREIGN KEY (\"c\", \"d\") REFERENCES \"parent\"(\"a\", \"b\") ON DELETE CASCADE ON UPDATE CASCADE, " +
                        "FOREIGN KEY (\"d\", \"e\") REFERENCES \"parent\"(\"b\", \"a\") ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED" +
                        ")") as String)
            }
        }
    }
    
    func testTableCheck() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.create(table: "test") { t in
                    t.check(Column("a") + Column("b") < 10)
                    t.check(sql: "a + b < 10")
                    t.column("a", .integer)
                    t.column("b", .integer)
                }
                XCTAssertEqual(
                    self.lastSQLQuery,
                    ("CREATE TABLE \"test\" (" +
                        "\"a\" INTEGER, " +
                        "\"b\" INTEGER, " +
                        "CHECK (((\"a\" + \"b\") < 10)), " +
                        "CHECK (a + b < 10)" +
                        ")") as String)
                
                // Sanity check
                try db.execute("INSERT INTO test (a, b) VALUES (1, 0)")
                do {
                    try db.execute("INSERT INTO test (a, b) VALUES (5, 5)")
                    XCTFail()
                } catch {
                }
            }
        }
    }
    
    func testAutoReferences() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.create(table: "test1") { t in
                    t.column("id", .integer).primaryKey()
                    t.column("id2", .integer).references("test1")
                }
                XCTAssertEqual(
                    self.lastSQLQuery,
                    ("CREATE TABLE \"test1\" (" +
                        "\"id\" INTEGER PRIMARY KEY, " +
                        "\"id2\" INTEGER REFERENCES \"test1\"(\"id\")" +
                        ")") as String)
                
                try db.create(table: "test2") { t in
                    t.column("id", .integer)
                    t.column("id2", .integer).references("test2")
                    t.primaryKey(["id"])
                }
                XCTAssertEqual(
                    self.lastSQLQuery,
                    ("CREATE TABLE \"test2\" (" +
                        "\"id\" INTEGER, " +
                        "\"id2\" INTEGER REFERENCES \"test2\"(\"id\"), " +
                        "PRIMARY KEY (\"id\")" +
                        ")") as String)
                
                try db.create(table: "test3") { t in
                    t.column("a", .integer)
                    t.column("b", .integer)
                    t.column("c", .integer)
                    t.column("d", .integer)
                    t.foreignKey(["c", "d"], references: "test3")
                    t.primaryKey(["a", "b"])
                }
                XCTAssertEqual(
                    self.lastSQLQuery,
                    ("CREATE TABLE \"test3\" (" +
                        "\"a\" INTEGER, " +
                        "\"b\" INTEGER, " +
                        "\"c\" INTEGER, " +
                        "\"d\" INTEGER, " +
                        "PRIMARY KEY (\"a\", \"b\"), " +
                        "FOREIGN KEY (\"c\", \"d\") REFERENCES \"test3\"(\"a\", \"b\")" +
                        ")") as String)
            }
        }
    }
    
    func testRenameTable() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.create(table: "test") { t in
                    t.column("a", .text)
                }
                XCTAssertTrue(db.tableExists("test"))
                
                try db.rename(table: "test", to: "foo")
                XCTAssertEqual(self.lastSQLQuery, "ALTER TABLE \"test\" RENAME TO \"foo\"")
                XCTAssertFalse(db.tableExists("test"))
                XCTAssertTrue(db.tableExists("foo"))
            }
        }
    }
    
    func testAlterTable() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.create(table: "test") { t in
                    t.column("a", .text)
                }
                
                self.sqlQueries.removeAll()
                try db.alter(table: "test") { t in
                    t.add(column: "b", .text)
                    t.add(column: "c", .integer).notNull().defaults(to: 1)
                }
                
                XCTAssertEqual(self.sqlQueries[0], "ALTER TABLE \"test\" ADD COLUMN \"b\" TEXT;")
                XCTAssertEqual(self.sqlQueries[1], " ALTER TABLE \"test\" ADD COLUMN \"c\" INTEGER NOT NULL DEFAULT 1")
            }
        }
    }
    
    func testDropTable() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.create(table: "test") { t in
                    t.column("id", .integer).primaryKey()
                    t.column("name", .text)
                }
                XCTAssertTrue(db.tableExists("test"))
                
                try db.drop(table: "test")
                XCTAssertEqual(self.lastSQLQuery, "DROP TABLE \"test\"")
                XCTAssertFalse(db.tableExists("test"))
            }
        }
    }
    
    func testCreateIndex() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.create(table: "test") { t in
                    t.column("id", .integer).primaryKey()
                    t.column("a", .text)
                    t.column("b", .text)
                }
                
                try db.create(index: "test_on_a", on: "test", columns: ["a"])
                XCTAssertEqual(self.lastSQLQuery, "CREATE INDEX \"test_on_a\" ON \"test\"(\"a\")")
                
                try db.create(index: "test_on_a_b", on: "test", columns: ["a", "b"], unique: true, ifNotExists: true, condition: Column("a") == 1)
                XCTAssertEqual(self.lastSQLQuery, "CREATE UNIQUE INDEX IF NOT EXISTS \"test_on_a_b\" ON \"test\"(\"a\", \"b\") WHERE (\"a\" = 1)")
                
                // Sanity check
                XCTAssertEqual(Set(db.indexes(on: "test").map { $0.name }), ["test_on_a", "test_on_a_b"])
            }
        }
    }
    
    func testDropIndex() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.create(table: "test") { t in
                    t.column("id", .integer).primaryKey()
                    t.column("name", .text)
                }
                try db.create(index: "test_on_name", on: "test", columns: ["name"])
                
                try db.drop(index: "test_on_name")
                XCTAssertEqual(self.lastSQLQuery, "DROP INDEX \"test_on_name\"")
                
                // Sanity check
                XCTAssertTrue(db.indexes(on: "test").isEmpty)
            }
        }
    }
}
