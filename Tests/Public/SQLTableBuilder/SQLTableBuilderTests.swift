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
                    t.column("id", .Integer).primaryKey(onConflict: .Fail)
                }
                XCTAssertEqual(self.lastSQLQuery,
                    "CREATE TABLE \"test\" (" +
                        "\"id\" INTEGER PRIMARY KEY ON CONFLICT FAIL" +
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
                    t.column("b", .Integer).check(sql: "b <> 2")
                    t.column("c", .Integer).check { $0 > 0 }.check { $0 < 10 }
                }
                XCTAssertEqual(self.lastSQLQuery,
                    "CREATE TABLE \"test\" (" +
                        "\"a\" INTEGER CHECK ((\"a\" > 0)), " +
                        "\"b\" INTEGER CHECK (b <> 2), " +
                        "\"c\" INTEGER CHECK ((\"c\" > 0)) CHECK ((\"c\" < 10))" +
                    ")")
                
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
                    t.column("a", .Integer).defaults(to: 1)
                    t.column("b", .Integer).defaults(to: 1.0)
                    t.column("c", .Integer).defaults(to: "'fooéı👨👨🏿🇫🇷🇨🇮'")
                    t.column("d", .Integer).defaults(to: "foo".dataUsingEncoding(NSUTF8StringEncoding)!)
                    t.column("e", .Integer).defaults(sql: "NULL")
                }
                XCTAssertEqual(self.lastSQLQuery,
                    "CREATE TABLE \"test\" (" +
                        "\"a\" INTEGER DEFAULT 1, " +
                        "\"b\" INTEGER DEFAULT 1.0, " +
                        "\"c\" INTEGER DEFAULT '''fooéı👨👨🏿🇫🇷🇨🇮''', " +
                        "\"d\" INTEGER DEFAULT x'666f6f', " +
                        "\"e\" INTEGER DEFAULT NULL" +
                    ")")
                
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
    
    func testColumnReference() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.create(table: "parent") { t in
                    t.column("name", .Text).primaryKey()
                    t.column("email", .Text).unique()
                }
                try db.create(table: "child") { t in
                    t.column("parentName", .Text).references("parent", onDelete: .Cascade, onUpdate: .Cascade)
                    t.column("parentEmail", .Text).references("parent", column: "email", onDelete: .Restrict, deferred: true)
                    t.column("weird", .Text).references("parent", column: "name").references("parent", column: "email")
                }
                XCTAssertEqual(self.lastSQLQuery,
                    "CREATE TABLE \"child\" (" +
                        "\"parentName\" TEXT REFERENCES \"parent\"(\"name\") ON DELETE CASCADE ON UPDATE CASCADE, " +
                        "\"parentEmail\" TEXT REFERENCES \"parent\"(\"email\") ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED, " +
                        "\"weird\" TEXT REFERENCES \"parent\"(\"name\") REFERENCES \"parent\"(\"email\")" +
                    ")")
            }
        }
    }
    
    func testTablePrimaryKey() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inTransaction { db in
                try db.create(table: "test") { t in
                    t.primaryKey(["a", "b"])
                    t.column("a", .Text)
                    t.column("b", .Text)
                }
                XCTAssertEqual(self.lastSQLQuery,
                    "CREATE TABLE \"test\" (" +
                        "\"a\" TEXT, " +
                        "\"b\" TEXT, " +
                        "PRIMARY KEY (\"a\", \"b\")" +
                    ")")
                return .Rollback
            }
            try dbQueue.inTransaction { db in
                try db.create(table: "test") { t in
                    t.primaryKey(["a", "b"], onConflict: .Fail)
                    t.column("a", .Text)
                    t.column("b", .Text)
                }
                XCTAssertEqual(self.lastSQLQuery,
                    "CREATE TABLE \"test\" (" +
                        "\"a\" TEXT, " +
                        "\"b\" TEXT, " +
                        "PRIMARY KEY (\"a\", \"b\") ON CONFLICT FAIL" +
                    ")")
                return .Rollback
            }
        }
    }
    
    func testTableUniqueKey() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.create(table: "test") { t in
                    t.uniqueKey(["a"])
                    t.uniqueKey(["b", "c"], onConflict: .Fail)
                    t.column("a", .Text)
                    t.column("b", .Text)
                    t.column("c", .Text)
                }
                XCTAssertEqual(self.lastSQLQuery,
                    "CREATE TABLE \"test\" (" +
                        "\"a\" TEXT, " +
                        "\"b\" TEXT, " +
                        "\"c\" TEXT, " +
                        "UNIQUE (\"a\"), " +
                        "UNIQUE (\"b\", \"c\") ON CONFLICT FAIL" +
                    ")")
            }
        }
    }
    
    func testTableForeignKey() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.create(table: "parent") { t in
                    t.primaryKey(["a", "b"])
                    t.column("a", .Text)
                    t.column("b", .Text)
                }
                try db.create(table: "child") { t in
                    t.foreignKey(["c", "d"], references: "parent", onDelete: .Cascade, onUpdate: .Cascade)
                    t.foreignKey(["d", "e"], references: "parent", columns: ["b", "a"], onDelete: .Restrict, deferred: true)
                    t.column("c", .Text)
                    t.column("d", .Text)
                    t.column("e", .Text)
                }
                XCTAssertEqual(self.lastSQLQuery,
                    "CREATE TABLE \"child\" (" +
                        "\"c\" TEXT, " +
                        "\"d\" TEXT, " +
                        "\"e\" TEXT, " +
                        "FOREIGN KEY (\"c\", \"d\") REFERENCES \"parent\"(\"a\", \"b\") ON DELETE CASCADE ON UPDATE CASCADE, " +
                        "FOREIGN KEY (\"d\", \"e\") REFERENCES \"parent\"(\"b\", \"a\") ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED" +
                    ")")
            }
        }
    }
    
    func testTableCheck() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.create(table: "test") { t in
                    t.check(SQLColumn("a") + SQLColumn("b") < 10)
                    t.check(sql: "a + b < 10")
                    t.column("a", .Integer)
                    t.column("b", .Integer)
                }
                XCTAssertEqual(self.lastSQLQuery,
                    "CREATE TABLE \"test\" (" +
                        "\"a\" INTEGER, " +
                        "\"b\" INTEGER, " +
                        "CHECK (((\"a\" + \"b\") < 10)), " +
                        "CHECK (a + b < 10)" +
                    ")")
                
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
                    t.column("id", .Integer).primaryKey()
                    t.column("id2", .Integer).references("test1")
                }
                XCTAssertEqual(self.lastSQLQuery,
                    "CREATE TABLE \"test1\" (" +
                        "\"id\" INTEGER PRIMARY KEY, " +
                        "\"id2\" INTEGER REFERENCES \"test1\"(\"id\")" +
                    ")")
                
                try db.create(table: "test2") { t in
                    t.column("id", .Integer)
                    t.column("id2", .Integer).references("test2")
                    t.primaryKey(["id"])
                }
                XCTAssertEqual(self.lastSQLQuery,
                    "CREATE TABLE \"test2\" (" +
                        "\"id\" INTEGER, " +
                        "\"id2\" INTEGER REFERENCES \"test2\"(\"id\"), " +
                        "PRIMARY KEY (\"id\")" +
                    ")")
                
                try db.create(table: "test3") { t in
                    t.column("a", .Integer)
                    t.column("b", .Integer)
                    t.column("c", .Integer)
                    t.column("d", .Integer)
                    t.foreignKey(["c", "d"], references: "test3")
                    t.primaryKey(["a", "b"])
                }
                XCTAssertEqual(self.lastSQLQuery,
                    "CREATE TABLE \"test3\" (" +
                        "\"a\" INTEGER, " +
                        "\"b\" INTEGER, " +
                        "\"c\" INTEGER, " +
                        "\"d\" INTEGER, " +
                        "PRIMARY KEY (\"a\", \"b\"), " +
                        "FOREIGN KEY (\"c\", \"d\") REFERENCES \"test3\"(\"a\", \"b\")" +
                    ")")
            }
        }
    }
    
    func testRenameTable() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.create(table: "test") { t in
                    t.column("a", .Text)
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
                    t.column("a", .Text)
                }
                
                self.sqlQueries.removeAll()
                try db.alter(table: "test") { t in
                    t.add(column: "b", .Text)
                    t.add(column: "c", .Integer).notNull().defaults(to: 1)
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
    
    func testCreateIndex() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.create(table: "test") { t in
                    t.column("id", .Integer).primaryKey()
                    t.column("a", .Text)
                    t.column("b", .Text)
                }
                
                try db.create(index: "test_on_a", on: "test", columns: ["a"])
                XCTAssertEqual(self.lastSQLQuery, "CREATE INDEX \"test_on_a\" ON \"test\"(\"a\")")
                
                try db.create(index: "test_on_a_b", on: "test", columns: ["a", "b"], unique: true, ifNotExists: true, condition: SQLColumn("a") == 1)
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
                    t.column("id", .Integer).primaryKey()
                    t.column("name", .Text)
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
