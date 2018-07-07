import XCTest
#if GRDBCIPHER
    import GRDBCipher
#elseif GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class DatabaseWriterTests : GRDBTestCase {
    
    func testDatabaseQueueUnsafeReentrantWrite() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.unsafeReentrantWrite { db1 in
            try db1.create(table: "table1") { t in
                t.column("id", .integer).primaryKey()
            }
            try dbQueue.unsafeReentrantWrite { db2 in
                try db2.execute("INSERT INTO table1 (id) VALUES (NULL)")
                
                try dbQueue.unsafeReentrantWrite { db3 in
                    try XCTAssertEqual(Int.fetchOne(db3, "SELECT * FROM table1"), 1)
                    XCTAssertTrue(db1 === db2)
                    XCTAssertTrue(db2 === db3)
                }
            }
        }
    }
    
    func testDatabasePoolUnsafeReentrantWrite() throws {
        let dbPool = try makeDatabasePool()
        try dbPool.unsafeReentrantWrite { db1 in
            try db1.create(table: "table1") { t in
                t.column("id", .integer).primaryKey()
            }
            try dbPool.unsafeReentrantWrite { db2 in
                try db2.execute("INSERT INTO table1 (id) VALUES (NULL)")
                
                try dbPool.unsafeReentrantWrite { db3 in
                    try XCTAssertEqual(Int.fetchOne(db3, "SELECT * FROM table1"), 1)
                    XCTAssertTrue(db1 === db2)
                    XCTAssertTrue(db2 === db3)
                }
            }
        }
    }
    
    func testAnyDatabaseWriter() {
        // This test passes if this code compiles.
        let writer: DatabaseWriter = DatabaseQueue()
        let _: DatabaseWriter = AnyDatabaseWriter(writer)
    }
    
    func testEraseAndVacuum() throws {
        try testEraseAndVacuum(writer: makeDatabaseQueue())
        try testEraseAndVacuum(writer: makeDatabasePool())
    }

    private func testEraseAndVacuum(writer: DatabaseWriter) throws {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("init") { db in
            // Create a database with recursive constraints, so that we test
            // that those don't prevent database erasure.
            try db.execute("""
                CREATE TABLE t1 (id INTEGER PRIMARY KEY, b UNIQUE, c REFERENCES t2(id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED);
                CREATE TABLE t2 (id INTEGER PRIMARY KEY, b UNIQUE, c REFERENCES t1(id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED);
                CREATE INDEX i ON t1(c);
                CREATE VIEW v AS SELECT id FROM t1;
                CREATE TRIGGER tr AFTER INSERT ON t1 BEGIN INSERT INTO t2 (id, b, c) VALUES (NEW.c, NEW.b, NEW.id); END;
                INSERT INTO t1 (id, b, c) VALUES (1, 1, 1)
                """)
        }
        
        try migrator.migrate(writer)
        
        try writer.read { db in
            try XCTAssertTrue(db.tableExists("t1"))
            try XCTAssertTrue(db.tableExists("t2"))
            try XCTAssertTrue(db.viewExists("v"))
            try XCTAssertTrue(db.triggerExists("tr"))
            try XCTAssertEqual(db.indexes(on: "t1").count, 2)
        }
        
        try writer.erase()
        try writer.vacuum()
        
        try writer.read { db in
            try XCTAssertNil(Row.fetchOne(db, "SELECT * FROM sqlite_master"))
        }
    }
}
