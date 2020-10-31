import XCTest
import GRDB

class TableDefinitionTests: GRDBTestCase {
    
    func testCreateTable() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            // Simple table creation
            try db.create(table: "test") { t in
                t.column("id", .integer).primaryKey()
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
                t.column("id", .integer).primaryKey()
            }
            assertEqualSQL(lastSQLQuery!, """
                CREATE TEMPORARY TABLE IF NOT EXISTS "test" (\
                "id" INTEGER PRIMARY KEY\
                ) WITHOUT ROWID
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
                t.column("id", .integer).primaryKey(onConflict: .fail)
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
            try db.create(table: "test", ifNotExists: true) { t in
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
            }
            assertEqualSQL(lastSQLQuery!, """
                CREATE TABLE "test" (\
                "a" INTEGER CHECK ("a" > 0), \
                "b" INTEGER CHECK (b <> 2), \
                "c" INTEGER CHECK ("c" > 0) CHECK ("c" < 10)\
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
        #if !GRDBCUSTOMSQLITE
        throw XCTSkip("Generated columns are not available")
        #else
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
        #endif
    }
    
    func testTablePrimaryKey() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inTransaction { db in
            try db.create(table: "test") { t in
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
    
    func testAutoReferences() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "test1") { t in
                t.column("id", .integer).primaryKey()
                t.column("id2", .integer).references("test1")
            }
            assertEqualSQL(lastSQLQuery!, """
                CREATE TABLE "test1" (\
                "id" INTEGER PRIMARY KEY, \
                "id2" INTEGER REFERENCES "test1"("id")\
                )
                """)

            try db.create(table: "test2") { t in
                t.column("id", .integer)
                t.column("id2", .integer).references("test2")
                t.primaryKey(["id"])
            }
            assertEqualSQL(lastSQLQuery!, """
                CREATE TABLE "test2" (\
                "id" INTEGER, \
                "id2" INTEGER REFERENCES "test2"("id"), \
                PRIMARY KEY ("id")\
                )
                """)
            
            try db.create(table: "test3") { t in
                t.column("a", .integer)
                t.column("b", .integer)
                t.column("c", .integer)
                t.column("d", .integer)
                t.foreignKey(["c", "d"], references: "test3")
                t.primaryKey(["a", "b"])
            }
            assertEqualSQL(lastSQLQuery!, """
                CREATE TABLE "test3" (\
                "a" INTEGER, \
                "b" INTEGER, \
                "c" INTEGER, \
                "d" INTEGER, \
                PRIMARY KEY ("a", "b"), \
                FOREIGN KEY ("c", "d") REFERENCES "test3"("a", "b")\
                )
                """)

            try db.create(table: "test4") { t in
                t.column("parent", .integer).references("test4")
            }
            assertEqualSQL(
                lastSQLQuery!,
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
            }
            
            assertEqualSQL(sqlQueries[sqlQueries.count - 4], "ALTER TABLE \"test\" ADD COLUMN \"b\" TEXT")
            assertEqualSQL(sqlQueries[sqlQueries.count - 3], "ALTER TABLE \"test\" ADD COLUMN \"c\" INTEGER NOT NULL DEFAULT 1")
            assertEqualSQL(sqlQueries[sqlQueries.count - 2], "ALTER TABLE \"test\" ADD COLUMN \"d\" TEXT REFERENCES \"alt\"(\"rowid\")")
            assertEqualSQL(sqlQueries[sqlQueries.count - 1], "ALTER TABLE \"test\" ADD COLUMN \"e\"")
        }
    }
    
    func testAlterTableRenameColumn() throws {
        guard sqlite3_libversion_number() >= 3025000 else {
            throw XCTSkip("ALTER TABLE RENAME COLUMN is not available")
        }
        #if !GRDBCUSTOMSQLITE && !GRDBCIPHER
        guard #available(iOS 13.0, tvOS 13.0, watchOS 6.0, *) else {
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
    
    func testAlterTableAddGeneratedVirtualColumn() throws {
        #if !GRDBCUSTOMSQLITE
        throw XCTSkip("Generated columns are not available")
        #else
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
        #endif
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
            assertEqualSQL(lastSQLQuery!, "DROP TABLE \"test\"")
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
            assertEqualSQL(lastSQLQuery!, "CREATE INDEX \"test_on_a\" ON \"test\"(\"a\")")
            
            try db.create(index: "test_on_a_b", on: "test", columns: ["a", "b"], unique: true, ifNotExists: true)
            assertEqualSQL(lastSQLQuery!, "CREATE UNIQUE INDEX IF NOT EXISTS \"test_on_a_b\" ON \"test\"(\"a\", \"b\")")
            
            // Sanity check
            XCTAssertEqual(try Set(db.indexes(on: "test").map(\.name)), ["test_on_a", "test_on_a_b"])
        }
    }
    
    func testCreatePartialIndex() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "test") { t in
                t.column("id", .integer).primaryKey()
                t.column("a", .text)
                t.column("b", .text)
            }
            
            try db.create(index: "test_on_a_b", on: "test", columns: ["a", "b"], unique: true, ifNotExists: true, condition: Column("a") == 1)
            assertEqualSQL(lastSQLQuery!, "CREATE UNIQUE INDEX IF NOT EXISTS \"test_on_a_b\" ON \"test\"(\"a\", \"b\") WHERE \"a\" = 1")
            
            // Sanity check
            XCTAssertEqual(try Set(db.indexes(on: "test").map(\.name)), ["test_on_a_b"])
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
            assertEqualSQL(lastSQLQuery!, "DROP INDEX \"test_on_name\"")
            
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
}
