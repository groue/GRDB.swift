import XCTest
import GRDB

class TableDefinitionTests: GRDBTestCase {
    
    func testCreateTable() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            // Simple table creation
            try db.create(table: "test") { t in
                t.primaryKey("id", .integer)
                t.column("name", .text)
            }
            
            assertEqualSQL(lastSQLQuery!, """
                CREATE TABLE "test" (\
                "id" INTEGER PRIMARY KEY, \
                "name" TEXT\
                )
                """)
        }
    }
    
    func testTableCreationOptions() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "test", temporary: true, ifNotExists: true, withoutRowID: true) { t in
                t.primaryKey("id", .integer)
            }
            assertEqualSQL(lastSQLQuery!, """
                CREATE TEMPORARY TABLE IF NOT EXISTS "test" (\
                "id" INTEGER PRIMARY KEY\
                ) WITHOUT ROWID
                """)
        }
        
        try dbQueue.inDatabase { db in
            try db.create(table: "test2", options: [.temporary, .ifNotExists, .withoutRowID]) { t in
                t.primaryKey("id", .integer)
            }
            assertEqualSQL(lastSQLQuery!, """
                CREATE TEMPORARY TABLE IF NOT EXISTS "test2" (\
                "id" INTEGER PRIMARY KEY\
                ) WITHOUT ROWID
                """)
        }
    }

    func testStrictTableCreationOption() throws {
        guard sqlite3_libversion_number() >= 3037000 else {
            throw XCTSkip("STRICT tables are not available")
        }
        #if !GRDBCUSTOMSQLITE && !GRDBCIPHER
        guard #available(iOS 15.4, macOS 12.4, tvOS 15.4, watchOS 8.5, *) else {
            throw XCTSkip("STRICT tables are not available")
        }
        #endif
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "test3", options: [.strict]) { t in
                t.primaryKey("id", .integer)
                t.column("a", .integer)
                t.column("b", .real)
                t.column("c", .text)
                t.column("d", .blob)
                t.column("e", .any)
            }
            assertEqualSQL(lastSQLQuery!, """
                CREATE TABLE "test3" (\
                "id" INTEGER PRIMARY KEY, \
                "a" INTEGER, \
                "b" REAL, \
                "c" TEXT, \
                "d" BLOB, \
                "e" ANY\
                ) STRICT
                """)
            
            do {
                try db.execute(sql: "INSERT INTO test3 (id, a) VALUES (1, 'foo')")
                XCTFail("Expected DatabaseError.SQLITE_CONSTRAINT_DATATYPE")
            } catch DatabaseError.SQLITE_CONSTRAINT_DATATYPE {
            }
        }
    }
    
    func testColumnLiteral() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            // Simple table creation
            try db.create(table: "test") { t in
                t.column(sql: "a TEXT")
                t.column(literal: "b TEXT DEFAULT \("O'Brien")")
            }
            
            assertEqualSQL(lastSQLQuery!, """
                CREATE TABLE "test" (a TEXT, b TEXT DEFAULT 'O''Brien')
                """)
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
            
            assertEqualSQL(lastSQLQuery!, """
                CREATE TABLE "test" ("a", "b")
                """)
        }
    }
    
    func testAutoIncrementedPrimaryKey() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inTransaction { db in
            try db.create(table: "test") { t in
                t.autoIncrementedPrimaryKey("id")
            }
            assertEqualSQL(lastSQLQuery!, """
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
            assertEqualSQL(lastSQLQuery!, """
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
                t.primaryKey("id", .integer, onConflict: .fail)
            }
            assertEqualSQL(lastSQLQuery!, """
                CREATE TABLE "test" (\
                "id" INTEGER PRIMARY KEY ON CONFLICT FAIL\
                )
                """)
            return .rollback
        }
        try dbQueue.inTransaction { db in
            try db.create(table: "test") { t in
                // legacy api
                t.column("id", .integer).primaryKey(autoincrement: true)
            }
            assertEqualSQL(lastSQLQuery!, """
                CREATE TABLE "test" (\
                "id" INTEGER PRIMARY KEY AUTOINCREMENT\
                )
                """)
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
            assertEqualSQL(lastSQLQuery!, """
                CREATE TABLE "test" (\
                "a" INTEGER NOT NULL, \
                "b" INTEGER NOT NULL, \
                "c" INTEGER NOT NULL ON CONFLICT ROLLBACK, \
                "d" INTEGER NOT NULL ON CONFLICT FAIL, \
                "e" INTEGER NOT NULL ON CONFLICT IGNORE, \
                "f" INTEGER NOT NULL ON CONFLICT REPLACE\
                )
                """)
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
    
    // Regression test for https://github.com/groue/GRDB.swift/issues/838
    func testColumnIndexedInheritsIfNotExistsFlag() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            sqlQueries.removeAll()
            try db.create(table: "test", options: [.ifNotExists]) { t in
                t.column("a", .integer).indexed()
                t.column("b", .integer).indexed()
            }
            assertEqualSQL(sqlQueries[0], "CREATE TABLE IF NOT EXISTS \"test\" (\"a\" INTEGER, \"b\" INTEGER)")
            assertEqualSQL(sqlQueries[1], "CREATE INDEX IF NOT EXISTS \"test_on_a\" ON \"test\"(\"a\")")
            assertEqualSQL(sqlQueries[2], "CREATE INDEX IF NOT EXISTS \"test_on_b\" ON \"test\"(\"b\")")
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
            assertEqualSQL(lastSQLQuery!, """
                CREATE TABLE "test" (\
                "a" INTEGER UNIQUE, \
                "b" INTEGER UNIQUE, \
                "c" INTEGER UNIQUE ON CONFLICT ROLLBACK, \
                "d" INTEGER UNIQUE ON CONFLICT FAIL, \
                "e" INTEGER UNIQUE ON CONFLICT IGNORE, \
                "f" INTEGER UNIQUE ON CONFLICT REPLACE\
                )
                """)
        }
    }
    
    func testColumnCheck() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "test") { t in
                t.column("a", .integer).check { $0 > 0 }
                t.column("b", .integer).check(sql: "b <> 2")
                t.column("c", .integer).check { $0 > 0 }.check { $0 < 10 }
                t.column("d", .integer).check { $0 != Column("c") }
            }
            assertEqualSQL(lastSQLQuery!, """
                CREATE TABLE "test" (\
                "a" INTEGER CHECK ("a" > 0), \
                "b" INTEGER CHECK (b <> 2), \
                "c" INTEGER CHECK ("c" > 0) CHECK ("c" < 10), \
                "d" INTEGER CHECK ("d" <> "c")\
                )
                """)

            // Sanity check
            try db.execute(sql: "INSERT INTO test (a, b, c) VALUES (1, 0, 1)")
            do {
                try db.execute(sql: "INSERT INTO test (a, b, c) VALUES (0, 0, 1)")
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
            assertEqualSQL(lastSQLQuery!, """
                CREATE TABLE "test" (\
                "a" INTEGER DEFAULT 1, \
                "b" INTEGER DEFAULT 1.0, \
                "c" INTEGER DEFAULT '''fooéı👨👨🏿🇫🇷🇨🇮''', \
                "d" INTEGER DEFAULT X'666F6F', \
                "e" INTEGER DEFAULT NULL\
                )
                """)

            // Sanity check
            try db.execute(sql: "INSERT INTO test DEFAULT VALUES")
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT a FROM test")!, 1)
            XCTAssertEqual(try String.fetchOne(db, sql: "SELECT c FROM test")!, "'fooéı👨👨🏿🇫🇷🇨🇮'")
        }
    }
    
    func testColumnCollation() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inTransaction { db in
            try db.create(table: "test") { t in
                t.column("name", .text).collate(.nocase)
            }
            assertEqualSQL(lastSQLQuery!, """
                CREATE TABLE "test" (\
                "name" TEXT COLLATE NOCASE\
                )
                """)
            return .rollback
        }
        
        try dbQueue.inTransaction { db in
            let collation = DatabaseCollation("foo") { (lhs, rhs) in .orderedSame }
            db.add(collation: collation)
            try db.create(table: "test") { t in
                t.column("name", .text).collate(collation)
            }
            assertEqualSQL(lastSQLQuery!, """
                CREATE TABLE "test" (\
                "name" TEXT COLLATE foo\
                )
                """)
            return .rollback
        }
    }
    
    func testColumnReference() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "parent") { t in
                t.primaryKey("name", .text)
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
            assertEqualSQL(lastSQLQuery!, """
                CREATE TABLE "child" (\
                "parentName" TEXT REFERENCES "parent"("name") ON DELETE CASCADE ON UPDATE CASCADE, \
                "parentEmail" TEXT REFERENCES "parent"("email") ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED, \
                "weird" TEXT REFERENCES "parent"("name") REFERENCES "parent"("email"), \
                "pklessRowId" TEXT REFERENCES "pkless"("rowid")\
                )
                """)
        }
    }
    
    func testColumnGeneratedAs() throws {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
        guard sqlite3_libversion_number() >= 3031000 else {
            throw XCTSkip("Generated columns are not available")
        }
#else
        guard #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) else {
            throw XCTSkip("Generated columns are not available")
        }
#endif
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inTransaction { db in
            try db.create(table: "test") { t in
                t.column("a", .integer)
                t.column("b", .integer)
                t.column("c", .text)
                t.column("d", .integer).generatedAs(sql: "a*abs(b)", .virtual)
                t.column("e", .text).generatedAs(sql: "substr(c,b,b+1)", .stored)
                t.column("f").generatedAs(sql: "e")
                t.column("g").generatedAs(Column("a") * 2)
                t.column("h").generatedAs("O'Brien")
            }
            
            assertEqualSQL(lastSQLQuery!, """
                CREATE TABLE "test" (\
                "a" INTEGER, \
                "b" INTEGER, \
                "c" TEXT, \
                "d" INTEGER GENERATED ALWAYS AS (a*abs(b)) VIRTUAL, \
                "e" TEXT GENERATED ALWAYS AS (substr(c,b,b+1)) STORED, \
                "f" GENERATED ALWAYS AS (e) VIRTUAL, \
                "g" GENERATED ALWAYS AS ("a" * 2) VIRTUAL, \
                "h" GENERATED ALWAYS AS ('O''Brien') VIRTUAL\
                )
                """)
            return .rollback
        }
    }
    
    func testTablePrimaryKey() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inTransaction { db in
            try db.create(table: "test") { t in
                // Legacy api
                t.primaryKey(["a", "b"])
                t.column("a", .text)
                t.column("b", .text)
            }
            assertEqualSQL(lastSQLQuery!, """
                CREATE TABLE "test" (\
                "a" TEXT, \
                "b" TEXT, \
                PRIMARY KEY ("a", "b")\
                )
                """)
            return .rollback
        }
        try dbQueue.inTransaction { db in
            try db.create(table: "test") { t in
                t.column("regular1")
                t.primaryKey {
                    t.column("a", .text)
                    t.column("b", .text)
                }
                t.column("regular2")
            }
            assertEqualSQL(lastSQLQuery!, """
                CREATE TABLE "test" (\
                "regular1", \
                "a" TEXT NOT NULL, \
                "b" TEXT NOT NULL, \
                "regular2", \
                PRIMARY KEY ("a", "b")\
                )
                """)
            return .rollback
        }
        try dbQueue.inTransaction { db in
            try db.create(table: "test") { t in
                // Legacy api
                t.primaryKey(["a", "b"], onConflict: .fail)
                t.column("a", .text)
                t.column("b", .text)
            }
            assertEqualSQL(lastSQLQuery!, """
                CREATE TABLE "test" (\
                "a" TEXT, \
                "b" TEXT, \
                PRIMARY KEY ("a", "b") ON CONFLICT FAIL\
                )
                """)
            return .rollback
        }
        try dbQueue.inTransaction { db in
            try db.create(table: "test") { t in
                t.primaryKey(onConflict: .fail) {
                    t.column("a", .text).defaults(to: "O'Reilly")
                    t.column("b", .text)
                }
            }
            assertEqualSQL(lastSQLQuery!, """
                CREATE TABLE "test" (\
                "a" TEXT NOT NULL DEFAULT 'O''Reilly', \
                "b" TEXT NOT NULL, \
                PRIMARY KEY ("a", "b") ON CONFLICT FAIL\
                )
                """)
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
            assertEqualSQL(lastSQLQuery!, """
                CREATE TABLE "test" (\
                "a" TEXT, \
                "b" TEXT, \
                "c" TEXT, \
                UNIQUE ("a"), \
                UNIQUE ("b", "c") ON CONFLICT FAIL\
                )
                """)
        }
    }
    
    func testTableForeignKey() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "parent") { t in
                t.primaryKey {
                    t.column("a", .text)
                    t.column("b", .text)
                }
            }
            try db.create(table: "child") { t in
                t.foreignKey(["c", "d"], references: "parent", onDelete: .cascade, onUpdate: .cascade)
                t.foreignKey(["d", "e"], references: "parent", columns: ["b", "a"], onDelete: .restrict, deferred: true)
                t.column("c", .text)
                t.column("d", .text)
                t.column("e", .text)
            }
            assertEqualSQL(lastSQLQuery!, """
                CREATE TABLE "child" (\
                "c" TEXT, \
                "d" TEXT, \
                "e" TEXT, \
                FOREIGN KEY ("c", "d") REFERENCES "parent"("a", "b") ON DELETE CASCADE ON UPDATE CASCADE, \
                FOREIGN KEY ("d", "e") REFERENCES "parent"("b", "a") ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED\
                )
                """)
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
            assertEqualSQL(lastSQLQuery!, """
                CREATE TABLE "test" (\
                "a" INTEGER, \
                "b" INTEGER, \
                CHECK (("a" + "b") < 10), \
                CHECK (a + b < 10)\
                )
                """)
            
            // Sanity check
            try db.execute(sql: "INSERT INTO test (a, b) VALUES (1, 0)")
            do {
                try db.execute(sql: "INSERT INTO test (a, b) VALUES (5, 5)")
                XCTFail()
            } catch {
            }
        }
    }
    
    @available(*, deprecated)
    func testTableCheck_deprecated() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "test") { t in
                // Deprecated because this does not what the user means!
                t.check("a < b")
                t.column("a", .integer)
                t.column("b", .integer)
            }
            assertEqualSQL(lastSQLQuery!, """
                CREATE TABLE "test" (\
                "a" INTEGER, \
                "b" INTEGER, \
                CHECK ('a < b')\
                )
                """)
            
            // Sanity check: insert should fail because the 'a < b' string is false for SQLite
            do {
                try db.execute(sql: "INSERT INTO test (a, b) VALUES (0, 1)")
                XCTFail()
            } catch {
            }
        }
    }
    
    func testConstraintLiteral() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            // Simple table creation
            try db.create(table: "test") { t in
                t.constraint(sql: "CHECK (a + b < 10)")
                t.constraint(sql: "CHECK (a + b < \(20))")
                t.column("a", .integer)
                t.column("b", .integer)
            }
            
            assertEqualSQL(lastSQLQuery!, """
                CREATE TABLE "test" (\
                "a" INTEGER, \
                "b" INTEGER, \
                CHECK (a + b < 10), \
                CHECK (a + b < 20)\
                )
                """)
        }
    }
    
    func testAutoReferences() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "test1") { t in
                t.primaryKey("id", .integer)
                t.column("id2", .integer).references("test1")
            }
            assertEqualSQL(lastSQLQuery!, """
                CREATE TABLE "test1" (\
                "id" INTEGER PRIMARY KEY, \
                "id2" INTEGER REFERENCES "test1"("id")\
                )
                """)

            try db.create(table: "test2_legacy") { t in
                // Legacy api
                t.column("id", .integer)
                t.column("id2", .integer).references("test2_legacy")
                t.primaryKey(["id"])
            }
            assertEqualSQL(lastSQLQuery!, """
                CREATE TABLE "test2_legacy" (\
                "id" INTEGER, \
                "id2" INTEGER REFERENCES "test2_legacy"("id"), \
                PRIMARY KEY ("id")\
                )
                """)
            
            try db.create(table: "test2") { t in
                t.column("id2", .integer).references("test2")
                t.primaryKey {
                    t.column("id", .integer)
                }
            }
            assertEqualSQL(lastSQLQuery!, """
                CREATE TABLE "test2" (\
                "id2" INTEGER REFERENCES "test2"("id"), \
                "id" INTEGER NOT NULL, \
                PRIMARY KEY ("id")\
                )
                """)
            
            try db.create(table: "test3Legacy") { t in
                t.column("a", .integer)
                t.column("b", .integer)
                t.column("c", .integer)
                t.column("d", .integer)
                t.foreignKey(["c", "d"], references: "test3Legacy")
                t.primaryKey(["a", "b"])
            }
            assertEqualSQL(lastSQLQuery!, """
                CREATE TABLE "test3Legacy" (\
                "a" INTEGER, \
                "b" INTEGER, \
                "c" INTEGER, \
                "d" INTEGER, \
                PRIMARY KEY ("a", "b"), \
                FOREIGN KEY ("c", "d") REFERENCES "test3Legacy"("a", "b")\
                )
                """)

            try db.create(table: "test3") { t in
                t.column("c", .integer)
                t.column("d", .integer)
                t.foreignKey(["c", "d"], references: "test3")
                t.primaryKey {
                    t.column("a", .integer)
                    t.column("b", .integer)
                }
            }
            assertEqualSQL(lastSQLQuery!, """
                CREATE TABLE "test3" (\
                "c" INTEGER, \
                "d" INTEGER, \
                "a" INTEGER NOT NULL, \
                "b" INTEGER NOT NULL, \
                PRIMARY KEY ("a", "b"), \
                FOREIGN KEY ("c", "d") REFERENCES "test3"("a", "b")\
                )
                """)

            try db.create(table: "test4") { t in
                t.column("parent", .integer).references("test4")
            }
            assertEqualSQL(lastSQLQuery!, """
                CREATE TABLE "test4" (\
                "parent" INTEGER REFERENCES "test4"("rowid")\
                )
                """)
            
            try db.create(table: "test5") { t in
                t.column("parent", .integer)
                t.foreignKey(["parent"], references: "test5")
            }
            assertEqualSQL(lastSQLQuery!, """
                CREATE TABLE "test5" (\
                "parent" INTEGER, \
                FOREIGN KEY ("parent") REFERENCES "test5"("rowid")\
                )
                """)
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
            assertEqualSQL(lastSQLQuery!, "ALTER TABLE \"test\" RENAME TO \"foo\"")
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
                t.addColumn(sql: "f TEXT")
                t.addColumn(literal: "g TEXT DEFAULT \("O'Brien")")
            }
            
            assertEqualSQL(sqlQueries[sqlQueries.count - 6], "ALTER TABLE \"test\" ADD COLUMN \"b\" TEXT")
            assertEqualSQL(sqlQueries[sqlQueries.count - 5], "ALTER TABLE \"test\" ADD COLUMN \"c\" INTEGER NOT NULL DEFAULT 1")
            assertEqualSQL(sqlQueries[sqlQueries.count - 4], "ALTER TABLE \"test\" ADD COLUMN \"d\" TEXT REFERENCES \"alt\"(\"rowid\")")
            assertEqualSQL(sqlQueries[sqlQueries.count - 3], "ALTER TABLE \"test\" ADD COLUMN \"e\"")
            assertEqualSQL(sqlQueries[sqlQueries.count - 2], "ALTER TABLE \"test\" ADD COLUMN f TEXT")
            assertEqualSQL(sqlQueries[sqlQueries.count - 1], "ALTER TABLE \"test\" ADD COLUMN g TEXT DEFAULT 'O''Brien'")
        }
    }
    
    func testAlterTableAddAutoReferencingForeignKey() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            do {
                try db.create(table: "hiddenRowIdTable") { t in
                    t.column("a", .text)
                }
                
                sqlQueries.removeAll()
                try db.alter(table: "hiddenRowIdTable") { t in
                    t.add(column: "ref").references("hiddenRowIdTable")
                }
                XCTAssertEqual(lastSQLQuery, """
                    ALTER TABLE "hiddenRowIdTable" ADD COLUMN "ref" REFERENCES "hiddenRowIdTable"("rowid")
                    """)
            }
            
            do {
                try db.create(table: "explicitPrimaryKey") { t in
                    t.primaryKey("code", .text)
                    t.column("a", .text)
                }
                
                sqlQueries.removeAll()
                try db.alter(table: "explicitPrimaryKey") { t in
                    t.add(column: "ref").references("explicitPrimaryKey")
                }
                XCTAssertEqual(lastSQLQuery, """
                    ALTER TABLE "explicitPrimaryKey" ADD COLUMN "ref" REFERENCES "explicitPrimaryKey"("code")
                    """)
            }
        }
    }
    
    func testAlterTableAddColumnInvalidatesSchemaCache() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "test") { t in
                t.column("a", .text)
            }
            try XCTAssertEqual(db.columns(in: "test").map(\.name), ["a"])

            try db.alter(table: "test") { t in
                t.add(column: "b", .text)
            }
            try XCTAssertEqual(db.columns(in: "test").map(\.name), ["a", "b"])
        }
    }

    func testAlterTableRenameColumn() throws {
        guard sqlite3_libversion_number() >= 3025000 else {
            throw XCTSkip("ALTER TABLE RENAME COLUMN is not available")
        }
        #if !GRDBCUSTOMSQLITE && !GRDBCIPHER
        guard #available(iOS 13, tvOS 13, watchOS 6, *) else {
            throw XCTSkip("ALTER TABLE RENAME COLUMN is not available")
        }
        #endif
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "test") { t in
                t.column("a", .text)
            }
            
            sqlQueries.removeAll()
            try db.alter(table: "test") { t in
                t.rename(column: "a", to: "b")
                t.add(column: "c")
                t.rename(column: "c", to: "d")
            }
            
            assertEqualSQL(sqlQueries[sqlQueries.count - 3], "ALTER TABLE \"test\" RENAME COLUMN \"a\" TO \"b\"")
            assertEqualSQL(sqlQueries[sqlQueries.count - 2], "ALTER TABLE \"test\" ADD COLUMN \"c\"")
            assertEqualSQL(sqlQueries[sqlQueries.count - 1], "ALTER TABLE \"test\" RENAME COLUMN \"c\" TO \"d\"")
        }
    }

    func testAlterTableRenameColumnInvalidatesSchemaCache() throws {
        guard sqlite3_libversion_number() >= 3025000 else {
            throw XCTSkip("ALTER TABLE RENAME COLUMN is not available")
        }
        #if !GRDBCUSTOMSQLITE && !GRDBCIPHER
        guard #available(iOS 13, tvOS 13, watchOS 6, *) else {
            throw XCTSkip("ALTER TABLE RENAME COLUMN is not available")
        }
        #endif
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "test") { t in
                t.column("a", .text)
            }
            try XCTAssertEqual(db.columns(in: "test").map(\.name), ["a"])
            
            try db.alter(table: "test") { t in
                t.rename(column: "a", to: "b")
            }
            try XCTAssertEqual(db.columns(in: "test").map(\.name), ["b"])
        }
    }
    
    func testAlterTableAddGeneratedVirtualColumn() throws {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
        guard sqlite3_libversion_number() >= 3031000 else {
            throw XCTSkip("Generated columns are not available")
        }
#else
        guard #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) else {
            throw XCTSkip("Generated columns are not available")
        }
#endif
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "test") { t in
                t.column("a", .integer)
                t.column("b", .integer)
                t.column("c", .text)
            }
            
            sqlQueries.removeAll()
            try db.alter(table: "test") { t in
                t.add(column: "d", .integer).generatedAs(sql: "a*abs(b)", .virtual)
                t.add(column: "e", .text).generatedAs(sql: "substr(c,b,b+1)", .virtual)
                t.add(column: "f").generatedAs(sql: "e", .virtual)
                t.add(column: "g").generatedAs(Column("a") * 2)
                t.add(column: "h").generatedAs("O'Brien")
            }
            
            let latestQueries = Array(sqlQueries.suffix(5))
            assertEqualSQL(latestQueries[0], "ALTER TABLE \"test\" ADD COLUMN \"d\" INTEGER GENERATED ALWAYS AS (a*abs(b)) VIRTUAL")
            assertEqualSQL(latestQueries[1], "ALTER TABLE \"test\" ADD COLUMN \"e\" TEXT GENERATED ALWAYS AS (substr(c,b,b+1)) VIRTUAL")
            assertEqualSQL(latestQueries[2], "ALTER TABLE \"test\" ADD COLUMN \"f\" GENERATED ALWAYS AS (e) VIRTUAL")
            assertEqualSQL(latestQueries[3], "ALTER TABLE \"test\" ADD COLUMN \"g\" GENERATED ALWAYS AS (\"a\" * 2) VIRTUAL")
            assertEqualSQL(latestQueries[4], "ALTER TABLE \"test\" ADD COLUMN \"h\" GENERATED ALWAYS AS ('O''Brien') VIRTUAL")
        }
    }
    
    func testAlterTableDropColumn() throws {
        guard sqlite3_libversion_number() >= 3035000 else {
            throw XCTSkip("ALTER TABLE DROP COLUMN is not available")
        }
        #if !GRDBCUSTOMSQLITE && !GRDBCIPHER
        guard #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) else {
            throw XCTSkip("ALTER TABLE DROP COLUMN is not available")
        }
        #endif
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "test") { t in
                t.column("a", .text)
                t.column("b", .text)
            }
            
            sqlQueries.removeAll()
            try db.alter(table: "test") { t in
                t.drop(column: "b")
            }
            assertEqualSQL(lastSQLQuery!, "ALTER TABLE \"test\" DROP COLUMN \"b\"")
        }
    }
    
    func testAlterTableDropColumnInvalidatesSchemaCache() throws {
        guard sqlite3_libversion_number() >= 3035000 else {
            throw XCTSkip("ALTER TABLE DROP COLUMN is not available")
        }
        #if !GRDBCUSTOMSQLITE && !GRDBCIPHER
        guard #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) else {
            throw XCTSkip("ALTER TABLE DROP COLUMN is not available")
        }
        #endif
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "test") { t in
                t.column("a", .text)
                t.column("b", .text)
            }
            try XCTAssertEqual(db.columns(in: "test").map(\.name), ["a", "b"])
            
            try db.alter(table: "test") { t in
                t.drop(column: "b")
            }
            try XCTAssertEqual(db.columns(in: "test").map(\.name), ["a"])
        }
    }
    
    func testDropTable() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "test") { t in
                t.primaryKey("id", .integer)
                t.column("name", .text)
            }
            XCTAssertTrue(try db.tableExists("test"))
            XCTAssertEqual(try db.columns(in: "test").count, 2)
            
            try db.drop(table: "test")
            assertEqualSQL(lastSQLQuery!, "DROP TABLE \"test\"")
            XCTAssertFalse(try db.tableExists("test"))
        }
    }
    
    func testCreateIndex() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "test") { t in
                t.primaryKey("id", .integer)
                t.column("a", .text)
                t.column("b", .text)
            }
            
            try db.create(index: "test_on_a", on: "test", columns: ["a"])
            assertEqualSQL(lastSQLQuery!, "CREATE INDEX \"test_on_a\" ON \"test\"(\"a\")")
            
            try db.create(index: "test_on_a_b", on: "test", columns: ["a", "b"], unique: true, ifNotExists: true)
            assertEqualSQL(lastSQLQuery!, "CREATE UNIQUE INDEX IF NOT EXISTS \"test_on_a_b\" ON \"test\"(\"a\", \"b\")")
            
            try db.create(index: "test_on_a_b_2", on: "test", columns: ["a", "b"], options: [.unique, .ifNotExists])
            assertEqualSQL(lastSQLQuery!, "CREATE UNIQUE INDEX IF NOT EXISTS \"test_on_a_b_2\" ON \"test\"(\"a\", \"b\")")
            
            try db.create(index: "test_on_a_plus_b", on: "test", expressions: [Column("a") + Column("b")], options: [.unique, .ifNotExists])
            assertEqualSQL(lastSQLQuery!, "CREATE UNIQUE INDEX IF NOT EXISTS \"test_on_a_plus_b\" ON \"test\"(\"a\" + \"b\")")
            
            try db.create(index: "test_on_a_nocase", on: "test", expressions: [Column("a").collating(.nocase)], options: [.unique, .ifNotExists])
            assertEqualSQL(lastSQLQuery!, "CREATE UNIQUE INDEX IF NOT EXISTS \"test_on_a_nocase\" ON \"test\"(\"a\" COLLATE NOCASE)")

            // Sanity check
            XCTAssertEqual(try Set(db.indexes(on: "test").map(\.name)), ["test_on_a", "test_on_a_b", "test_on_a_b_2", "test_on_a_nocase"])
        }
    }
    
    func testCreateIndexOn() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "test") { t in
                t.primaryKey("id", .integer)
                t.column("a", .text)
                t.column("b", .text)
            }
            
            try db.create(indexOn: "test", columns: ["a"])
            assertEqualSQL(lastSQLQuery!, "CREATE INDEX \"index_test_on_a\" ON \"test\"(\"a\")")
            
            try db.create(indexOn: "test", columns: ["a", "b"], options: [.unique])
            assertEqualSQL(lastSQLQuery!, "CREATE UNIQUE INDEX \"index_test_on_a_b\" ON \"test\"(\"a\", \"b\")")
            
            try db.create(indexOn: "test", columns: ["b"], options: [.unique, .ifNotExists])
            assertEqualSQL(lastSQLQuery!, "CREATE UNIQUE INDEX IF NOT EXISTS \"index_test_on_b\" ON \"test\"(\"b\")")
            
            // Sanity check
            XCTAssertEqual(try Set(db.indexes(on: "test").map(\.name)), ["index_test_on_a", "index_test_on_a_b", "index_test_on_b"])
        }
    }
    
    func testCreatePartialIndex() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "test") { t in
                t.primaryKey("id", .integer)
                t.column("a", .text)
                t.column("b", .text)
            }
            
            try db.create(index: "test_on_a_b", on: "test", columns: ["a", "b"], options: [.unique, .ifNotExists], condition: Column("a") == 1)
            assertEqualSQL(lastSQLQuery!, "CREATE UNIQUE INDEX IF NOT EXISTS \"test_on_a_b\" ON \"test\"(\"a\", \"b\") WHERE \"a\" = 1")
            
            try db.create(index: "test_on_a_plus_b", on: "test", expressions: [Column("a") + Column("b")], options: [.unique, .ifNotExists], condition: Column("a") == 1)
            assertEqualSQL(lastSQLQuery!, "CREATE UNIQUE INDEX IF NOT EXISTS \"test_on_a_plus_b\" ON \"test\"(\"a\" + \"b\") WHERE \"a\" = 1")
            
            // Sanity check
            XCTAssertEqual(try Set(db.indexes(on: "test").map(\.name)), ["test_on_a_b"])
        }
    }
    
    func testDropIndex() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "test") { t in
                t.primaryKey("id", .integer)
                t.column("name", .text)
            }
            try db.create(index: "test_on_name", on: "test", columns: ["name"])
            
            try db.drop(index: "test_on_name")
            assertEqualSQL(lastSQLQuery!, "DROP INDEX \"test_on_name\"")
            
            // Sanity check
            XCTAssertTrue(try db.indexes(on: "test").isEmpty)
        }
    }
    
    func testDropIndexOn() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "test") { t in
                t.primaryKey("id", .integer)
                t.column("a", .text)
                t.column("b", .text)
                t.column("c", .text)
                t.column("d", .text)
            }
            try db.create(index: "custom_name_a", on: "test", columns: ["a"])
            try db.create(index: "custom_name_b", on: "test", columns: ["a", "b"])
            try db.create(indexOn: "test", columns: ["c"])
            try db.create(indexOn: "test", columns: ["c", "d"])
            
            // Custom name
            try db.drop(indexOn: "test", columns: ["a"])
            assertEqualSQL(lastSQLQuery!, "DROP INDEX \"custom_name_a\"")
            
            // Custom name, case insensitivity
            try db.drop(indexOn: "TEST", columns: ["A", "B"])
            assertEqualSQL(lastSQLQuery!, "DROP INDEX \"custom_name_b\"")
            
            // Default name
            try db.drop(indexOn: "test", columns: ["c"])
            assertEqualSQL(lastSQLQuery!, "DROP INDEX \"index_test_on_c\"")
            
            // Default name, case insensitivity
            try db.drop(indexOn: "TEST", columns: ["C", "D"])
            assertEqualSQL(lastSQLQuery!, "DROP INDEX \"index_test_on_c_d\"")
            
            // Non existing index: no error
            try db.drop(indexOn: "test", columns: ["a", "b", "c", "d"])
            
            // Non existing table: error
            do {
                try db.drop(indexOn: "missing", columns: ["a"])
                XCTFail("Expected error")
            } catch { }

            // Sanity check
            XCTAssertTrue(try db.indexes(on: "test").isEmpty)
        }
    }

    func testReindex() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.reindex(collation: .binary)
            assertEqualSQL(lastSQLQuery!, "REINDEX BINARY")
            
            try db.reindex(collation: .localizedCompare)
            assertEqualSQL(lastSQLQuery!, "REINDEX swiftLocalizedCompare")
        }
    }
    
    func testCreateView() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name")
                t.column("score")
            }
            
            do {
                let request = SQLRequest(literal: """
                    SELECT * FROM player WHERE name = \("O'Brien")
                    """)
                try db.create(view: "view1", as: request)
                assertEqualSQL(lastSQLQuery!, """
                    CREATE VIEW "view1" AS SELECT * FROM player WHERE name = 'O''Brien'
                    """)
            }
            
            do {
                let request = Table("player").filter(Column("name") == "O'Brien")
                try db.create(view: "view2", as: request)
                assertEqualSQL(lastSQLQuery!, """
                    CREATE VIEW "view2" AS SELECT * FROM "player" WHERE "name" = 'O''Brien'
                    """)
            }
            
            do {
                let sql: SQL = """
                    SELECT * FROM player WHERE name = \("O'Brien")
                    """
                try db.create(view: "view3", asLiteral: sql)
                assertEqualSQL(lastSQLQuery!, """
                    CREATE VIEW "view3" AS SELECT * FROM player WHERE name = 'O''Brien'
                    """)
            }
        }
    }
    
    func testCreateViewOptions() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name")
                t.column("score")
            }
            
            let request = SQLRequest(literal: """
                SELECT * FROM player WHERE name = \("O'Brien")
                """)
            
            do {
                try db.create(view: "view1", options: .ifNotExists, as: request)
                assertEqualSQL(lastSQLQuery!, """
                    CREATE VIEW IF NOT EXISTS "view1" AS SELECT * FROM player WHERE name = 'O''Brien'
                    """)
            }
            
            do {
                try db.create(view: "view2", options: .temporary, as: request)
                assertEqualSQL(lastSQLQuery!, """
                    CREATE TEMPORARY VIEW "view2" AS SELECT * FROM player WHERE name = 'O''Brien'
                    """)
            }
            
            do {
                try db.create(view: "view3", options: [.temporary, .ifNotExists], as: request)
                assertEqualSQL(lastSQLQuery!, """
                    CREATE TEMPORARY VIEW IF NOT EXISTS "view3" AS SELECT * FROM player WHERE name = 'O''Brien'
                    """)
            }
            
            do {
                try db.create(view: "view4", columns: ["a", "b", "c"], as: request)
                assertEqualSQL(lastSQLQuery!, """
                    CREATE VIEW "view4" ("a", "b", "c") AS SELECT * FROM player WHERE name = 'O''Brien'
                    """)
            }
        }
    }
    
    func testDropView() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(view: "test", as: SQLRequest(literal: "SELECT 'test', 42"))
            XCTAssertTrue(try db.viewExists("test"))
            XCTAssertEqual(try db.columns(in: "test").count, 2)
            
            try db.drop(view: "test")
            assertEqualSQL(lastSQLQuery!, "DROP VIEW \"test\"")
            XCTAssertFalse(try db.viewExists("test"))
        }
    }
}
