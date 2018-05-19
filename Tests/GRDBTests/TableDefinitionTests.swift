import XCTest
#if GRDBCIPHER
    import GRDBCipher
#elseif GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class TableDefinitionTests: GRDBTestCase {
    
    func testCreateTable() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            // Simple table creation
            try db.create(table: "test") { t in
                t.column("id", .integer).primaryKey()
                t.column("name", .text)
            }
            
            assertEqualSQL(
                lastSQLQuery,
                ("CREATE TABLE \"test\" (" +
                    "\"id\" INTEGER PRIMARY KEY, " +
                    "\"name\" TEXT" +
                    ")") as String)
        }
    }

    func testTableCreationOptions() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            if #available(iOS 8.2, OSX 10.10, *) {
                try db.create(table: "test", temporary: true, ifNotExists: true, withoutRowID: true) { t in
                    t.column("id", .integer).primaryKey()
                }
                assertEqualSQL(
                    lastSQLQuery,
                    ("CREATE TEMPORARY TABLE IF NOT EXISTS \"test\" (" +
                        "\"id\" INTEGER PRIMARY KEY" +
                        ") WITHOUT ROWID") as String)
            } else {
                try db.create(table: "test", temporary: true, ifNotExists: true) { t in
                    t.column("id", .integer).primaryKey()
                }
                assertEqualSQL(
                    lastSQLQuery,
                    ("CREATE TEMPORARY TABLE IF NOT EXISTS \"test\" (" +
                        "\"id\" INTEGER PRIMARY KEY" +
                        ")") as String)
            }
        }
    }

    func testUntypedColumn() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            // Simple table creation
            try db.create(table: "test") { t in
                t.column("a")
                t.column("b")
            }
            
            assertEqualSQL(lastSQLQuery, "CREATE TABLE \"test\" (\"a\", \"b\")")
        }
    }
    
    func testAutoIncrementedPrimaryKey() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inTransaction { db in
            try db.create(table: "test") { t in
                t.autoIncrementedPrimaryKey("id")
            }
            assertEqualSQL(lastSQLQuery, """
                CREATE TABLE "test" (\
                "id" INTEGER PRIMARY KEY AUTOINCREMENT\
                )
                """)
            return .rollback
        }
        try dbQueue.inTransaction { db in
            try db.create(table: "test") { t in
                t.autoIncrementedPrimaryKey("id", onConflict: .fail)
            }
            assertEqualSQL(lastSQLQuery, """
                CREATE TABLE "test" (\
                "id" INTEGER PRIMARY KEY ON CONFLICT FAIL AUTOINCREMENT\
                )
                """)
            return .rollback
        }
    }

    func testColumnPrimaryKeyOptions() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inTransaction { db in
            try db.create(table: "test") { t in
                t.column("id", .integer).primaryKey(onConflict: .fail)
            }
            assertEqualSQL(
                lastSQLQuery,
                ("CREATE TABLE \"test\" (" +
                    "\"id\" INTEGER PRIMARY KEY ON CONFLICT FAIL" +
                    ")") as String)
            return .rollback
        }
        try dbQueue.inTransaction { db in
            try db.create(table: "test") { t in
                t.column("id", .integer).primaryKey(autoincrement: true)
            }
            assertEqualSQL(
                lastSQLQuery,
                ("CREATE TABLE \"test\" (" +
                    "\"id\" INTEGER PRIMARY KEY AUTOINCREMENT" +
                    ")") as String)
            return .rollback
        }
    }

    func testColumnNotNull() throws {
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
            assertEqualSQL(
                lastSQLQuery,
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

    func testColumnIndexed() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            sqlQueries.removeAll()
            try db.create(table: "test") { t in
                t.column("a", .integer).indexed()
                t.column("b", .integer).indexed()
            }
            assertEqualSQL(sqlQueries[0], "CREATE TABLE \"test\" (\"a\" INTEGER, \"b\" INTEGER)")
            assertEqualSQL(sqlQueries[1], "CREATE INDEX \"test_on_a\" ON \"test\"(\"a\")")
            assertEqualSQL(sqlQueries[2], "CREATE INDEX \"test_on_b\" ON \"test\"(\"b\")")
        }
    }
    
    func testColumnUnique() throws {
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
            assertEqualSQL(
                lastSQLQuery,
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

    func testColumnCheck() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "test") { t in
                t.column("a", .integer).check { $0 > 0 }
                t.column("b", .integer).check(sql: "b <> 2")
                t.column("c", .integer).check { $0 > 0 }.check { $0 < 10 }
            }
            assertEqualSQL(
                lastSQLQuery,
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

    func testColumnDefault() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "test") { t in
                t.column("a", .integer).defaults(to: 1)
                t.column("b", .integer).defaults(to: 1.0)
                t.column("c", .integer).defaults(to: "'fooéı👨👨🏿🇫🇷🇨🇮'")
                t.column("d", .integer).defaults(to: "foo".data(using: .utf8)!)
                t.column("e", .integer).defaults(sql: "NULL")
            }
            assertEqualSQL(
                lastSQLQuery,
                ("CREATE TABLE \"test\" (" +
                    "\"a\" INTEGER DEFAULT 1, " +
                    "\"b\" INTEGER DEFAULT 1.0, " +
                    "\"c\" INTEGER DEFAULT '''fooéı👨👨🏿🇫🇷🇨🇮''', " +
                    "\"d\" INTEGER DEFAULT X'666F6F', " +
                    "\"e\" INTEGER DEFAULT NULL" +
                    ")") as String)
            
            // Sanity check
            try db.execute("INSERT INTO test DEFAULT VALUES")
            XCTAssertEqual(try Int.fetchOne(db, "SELECT a FROM test")!, 1)
            XCTAssertEqual(try String.fetchOne(db, "SELECT c FROM test")!, "'fooéı👨👨🏿🇫🇷🇨🇮'")
        }
    }

    func testColumnCollation() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inTransaction { db in
            try db.create(table: "test") { t in
                t.column("name", .text).collate(.nocase)
            }
            assertEqualSQL(
                lastSQLQuery,
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
            assertEqualSQL(
                lastSQLQuery,
                ("CREATE TABLE \"test\" (" +
                    "\"name\" TEXT COLLATE foo" +
                    ")") as String)
            return .rollback
        }
    }

    func testColumnReference() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "parent") { t in
                t.column("name", .text).primaryKey()
                t.column("email", .text).unique()
            }
            try db.create(table: "pkless") { t in
                t.column("email", .text)
            }
            try db.create(table: "child") { t in
                t.column("parentName", .text).references("parent", onDelete: .cascade, onUpdate: .cascade)
                t.column("parentEmail", .text).references("parent", column: "email", onDelete: .restrict, deferred: true)
                t.column("weird", .text).references("parent", column: "name").references("parent", column: "email")
                t.column("pklessRowId", .text).references("pkless")
            }
            assertEqualSQL(
                lastSQLQuery,
                ("CREATE TABLE \"child\" (" +
                    "\"parentName\" TEXT REFERENCES \"parent\"(\"name\") ON DELETE CASCADE ON UPDATE CASCADE, " +
                    "\"parentEmail\" TEXT REFERENCES \"parent\"(\"email\") ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED, " +
                    "\"weird\" TEXT REFERENCES \"parent\"(\"name\") REFERENCES \"parent\"(\"email\"), " +
                    "\"pklessRowId\" TEXT REFERENCES \"pkless\"(\"rowid\")" +
                    ")") as String)
        }
    }

    func testTablePrimaryKey() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inTransaction { db in
            try db.create(table: "test") { t in
                t.primaryKey(["a", "b"])
                t.column("a", .text)
                t.column("b", .text)
            }
            assertEqualSQL(
                lastSQLQuery,
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
            assertEqualSQL(
                lastSQLQuery,
                ("CREATE TABLE \"test\" (" +
                    "\"a\" TEXT, " +
                    "\"b\" TEXT, " +
                    "PRIMARY KEY (\"a\", \"b\") ON CONFLICT FAIL" +
                    ")") as String)
            return .rollback
        }
    }

    func testTableUniqueKey() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "test") { t in
                t.uniqueKey(["a"])
                t.uniqueKey(["b", "c"], onConflict: .fail)
                t.column("a", .text)
                t.column("b", .text)
                t.column("c", .text)
            }
            assertEqualSQL(
                lastSQLQuery,
                ("CREATE TABLE \"test\" (" +
                    "\"a\" TEXT, " +
                    "\"b\" TEXT, " +
                    "\"c\" TEXT, " +
                    "UNIQUE (\"a\"), " +
                    "UNIQUE (\"b\", \"c\") ON CONFLICT FAIL" +
                    ")") as String)
        }
    }

    func testTableForeignKey() throws {
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
            assertEqualSQL(
                lastSQLQuery,
                ("CREATE TABLE \"child\" (" +
                    "\"c\" TEXT, " +
                    "\"d\" TEXT, " +
                    "\"e\" TEXT, " +
                    "FOREIGN KEY (\"c\", \"d\") REFERENCES \"parent\"(\"a\", \"b\") ON DELETE CASCADE ON UPDATE CASCADE, " +
                    "FOREIGN KEY (\"d\", \"e\") REFERENCES \"parent\"(\"b\", \"a\") ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED" +
                    ")") as String)
        }
    }

    func testTableCheck() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "test") { t in
                t.check(Column("a") + Column("b") < 10)
                t.check(sql: "a + b < 10")
                t.column("a", .integer)
                t.column("b", .integer)
            }
            assertEqualSQL(
                lastSQLQuery,
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

    func testAutoReferences() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "test1") { t in
                t.column("id", .integer).primaryKey()
                t.column("id2", .integer).references("test1")
            }
            assertEqualSQL(
                lastSQLQuery,
                ("CREATE TABLE \"test1\" (" +
                    "\"id\" INTEGER PRIMARY KEY, " +
                    "\"id2\" INTEGER REFERENCES \"test1\"(\"id\")" +
                    ")") as String)
            
            try db.create(table: "test2") { t in
                t.column("id", .integer)
                t.column("id2", .integer).references("test2")
                t.primaryKey(["id"])
            }
            assertEqualSQL(
                lastSQLQuery,
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
            assertEqualSQL(
                lastSQLQuery,
                ("CREATE TABLE \"test3\" (" +
                    "\"a\" INTEGER, " +
                    "\"b\" INTEGER, " +
                    "\"c\" INTEGER, " +
                    "\"d\" INTEGER, " +
                    "PRIMARY KEY (\"a\", \"b\"), " +
                    "FOREIGN KEY (\"c\", \"d\") REFERENCES \"test3\"(\"a\", \"b\")" +
                    ")") as String)
            
            try db.create(table: "test4") { t in
                t.column("parent", .integer).references("test4")
            }
            assertEqualSQL(
                lastSQLQuery,
                ("CREATE TABLE \"test4\" (" +
                    "\"parent\" INTEGER REFERENCES \"test4\"(\"rowid\")" +
                    ")") as String)
        }
    }

    func testRenameTable() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "test") { t in
                t.column("a", .text)
            }
            XCTAssertTrue(try db.tableExists("test"))
            XCTAssertEqual(try db.columns(in: "test").count, 1)
            
            try db.rename(table: "test", to: "foo")
            assertEqualSQL(lastSQLQuery, "ALTER TABLE \"test\" RENAME TO \"foo\"")
            XCTAssertFalse(try db.tableExists("test"))
            XCTAssertTrue(try db.tableExists("foo"))
            XCTAssertEqual(try db.columns(in: "foo").count, 1)
        }
    }

    func testAlterTable() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "test") { t in
                t.column("a", .text)
            }
            try db.create(table: "alt") { t in
                t.column("a", .text)
            }
            
            sqlQueries.removeAll()
            try db.alter(table: "test") { t in
                t.add(column: "b", .text)
                t.add(column: "c", .integer).notNull().defaults(to: 1)
                t.add(column: "d", .text).references("alt")
                t.add(column: "e")
            }
            
            assertEqualSQL(sqlQueries[sqlQueries.count - 4], "ALTER TABLE \"test\" ADD COLUMN \"b\" TEXT")
            assertEqualSQL(sqlQueries[sqlQueries.count - 3], "ALTER TABLE \"test\" ADD COLUMN \"c\" INTEGER NOT NULL DEFAULT 1")
            assertEqualSQL(sqlQueries[sqlQueries.count - 2], "ALTER TABLE \"test\" ADD COLUMN \"d\" TEXT REFERENCES \"alt\"(\"rowid\")")
            assertEqualSQL(sqlQueries[sqlQueries.count - 1], "ALTER TABLE \"test\" ADD COLUMN \"e\"")
        }
    }
    
    func testDropTable() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "test") { t in
                t.column("id", .integer).primaryKey()
                t.column("name", .text)
            }
            XCTAssertTrue(try db.tableExists("test"))
            XCTAssertEqual(try db.columns(in: "test").count, 2)
            
            try db.drop(table: "test")
            assertEqualSQL(lastSQLQuery, "DROP TABLE \"test\"")
            XCTAssertFalse(try db.tableExists("test"))
        }
    }

    func testCreateIndex() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "test") { t in
                t.column("id", .integer).primaryKey()
                t.column("a", .text)
                t.column("b", .text)
            }
            
            try db.create(index: "test_on_a", on: "test", columns: ["a"])
            assertEqualSQL(lastSQLQuery, "CREATE INDEX \"test_on_a\" ON \"test\"(\"a\")")
            
            try db.create(index: "test_on_a_b", on: "test", columns: ["a", "b"], unique: true, ifNotExists: true)
            assertEqualSQL(lastSQLQuery, "CREATE UNIQUE INDEX IF NOT EXISTS \"test_on_a_b\" ON \"test\"(\"a\", \"b\")")
            
            // Sanity check
            XCTAssertEqual(try Set(db.indexes(on: "test").map { $0.name }), ["test_on_a", "test_on_a_b"])
        }
    }
    
    func testCreatePartialIndex() throws {
        #if !GRDBCUSTOMSQLITE && !GRDBCIPHER
            guard #available(iOS 8.2, OSX 10.10, *) else {
                return
            }
        #endif
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "test") { t in
                t.column("id", .integer).primaryKey()
                t.column("a", .text)
                t.column("b", .text)
            }
            
            try db.create(index: "test_on_a_b", on: "test", columns: ["a", "b"], unique: true, ifNotExists: true, condition: Column("a") == 1)
            assertEqualSQL(lastSQLQuery, "CREATE UNIQUE INDEX IF NOT EXISTS \"test_on_a_b\" ON \"test\"(\"a\", \"b\") WHERE (\"a\" = 1)")
            
            // Sanity check
            XCTAssertEqual(try Set(db.indexes(on: "test").map { $0.name }), ["test_on_a_b"])
        }
    }

    func testDropIndex() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "test") { t in
                t.column("id", .integer).primaryKey()
                t.column("name", .text)
            }
            try db.create(index: "test_on_name", on: "test", columns: ["name"])
            
            try db.drop(index: "test_on_name")
            assertEqualSQL(lastSQLQuery, "DROP INDEX \"test_on_name\"")
            
            // Sanity check
            XCTAssertTrue(try db.indexes(on: "test").isEmpty)
        }
    }
}
