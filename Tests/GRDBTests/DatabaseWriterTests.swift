import XCTest
#if GRDBCUSTOMSQLITE
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
                try db2.execute(sql: "INSERT INTO table1 (id) VALUES (NULL)")
                
                try dbQueue.unsafeReentrantWrite { db3 in
                    try XCTAssertEqual(Int.fetchOne(db3, sql: "SELECT * FROM table1"), 1)
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
                try db2.execute(sql: "INSERT INTO table1 (id) VALUES (NULL)")
                
                try dbPool.unsafeReentrantWrite { db3 in
                    try XCTAssertEqual(Int.fetchOne(db3, sql: "SELECT * FROM table1"), 1)
                    XCTAssertTrue(db1 === db2)
                    XCTAssertTrue(db2 === db3)
                }
            }
        }
    }
    
    func testAsyncWriteWithoutTransactionSuccess() throws {
        func test(_ dbWriter: DatabaseWriter) throws {
            let expectation = self.expectation(description: "updates")
            let semaphore = DispatchSemaphore(value: 0)
            dbWriter.asyncWriteWithoutTransaction { db in
                // Make sure this block executes asynchronously
                semaphore.wait()
                do {
                    try db.execute(sql: "CREATE TABLE testAsyncWriteWithoutTransaction (a)")
                } catch {
                    XCTFail("Unexpected error: \(error)")
                }
                expectation.fulfill()
            }
            semaphore.signal()

            waitForExpectations(timeout: 1, handler: nil)
            let tableExists = try dbWriter.read { try $0.tableExists("testAsyncWriteWithoutTransaction") }
            XCTAssertTrue(tableExists)
        }
        
        try test(makeDatabaseQueue())
        try test(makeDatabasePool())
    }
    
    func testAsyncWriteWithoutTransactionError() throws {
        func test(_ dbWriter: DatabaseWriter) throws {
            let expectation = self.expectation(description: "updates")
            let semaphore = DispatchSemaphore(value: 0)
            dbWriter.asyncWriteWithoutTransaction { db in
                // Make sure this block executes asynchronously
                semaphore.wait()
                do {
                    try db.execute(sql: "This is not SQL")
                    XCTFail("Expected error")
                } catch let error as DatabaseError {
                    XCTAssertEqual(error.sql, "This is not SQL")
                } catch {
                    XCTFail("Unexpected error: \(error)")
                }
                expectation.fulfill()
            }
            semaphore.signal()
            waitForExpectations(timeout: 1, handler: nil)
        }
        
        try test(makeDatabaseQueue())
        try test(makeDatabasePool())
    }
    
    #if compiler(>=5.0)
    func testAsyncWriteSuccess() throws {
        func test(_ dbWriter: DatabaseWriter) throws {
            let expectation = self.expectation(description: "updates")
            let semaphore = DispatchSemaphore(value: 0)
            dbWriter.asyncWrite({ db in
                // Make sure this block executes asynchronously
                semaphore.wait()
                try db.execute(sql: "CREATE TABLE testAsyncWrite (a)")
            }, completion: { db, result in
                XCTAssertFalse(db.isInsideTransaction)
                switch result {
                case .success:
                    break
                case let .failure(error):
                    XCTFail("Unexpected error: \(error)")
                }
                expectation.fulfill()
            })
            semaphore.signal()
            
            waitForExpectations(timeout: 1, handler: nil)
            let tableExists = try dbWriter.read { try $0.tableExists("testAsyncWrite") }
            XCTAssertTrue(tableExists)
        }
        
        try test(makeDatabaseQueue())
        try test(makeDatabasePool())
    }
    #endif
    
    #if compiler(>=5.0)
    func testAsyncWriteError() throws {
        func test(_ dbWriter: DatabaseWriter) throws {
            let expectation = self.expectation(description: "updates")
            let semaphore = DispatchSemaphore(value: 0)
            dbWriter.asyncWrite({ db in
                // Make sure this block executes asynchronously
                semaphore.wait()
                try db.execute(sql: "This is not SQL")
            }, completion: { db, result in
                XCTAssertFalse(db.isInsideTransaction)
                switch result {
                case .success:
                    XCTFail("Expected error")
                case let .failure(error):
                    if let error = error as? DatabaseError {
                        XCTAssertEqual(error.sql, "This is not SQL")
                    } else {
                        XCTFail("Unexpected error: \(error)")
                    }
                }
                expectation.fulfill()
            })
            semaphore.signal()
            waitForExpectations(timeout: 1, handler: nil)
        }
        
        try test(makeDatabaseQueue())
        try test(makeDatabasePool())
    }
    #endif

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
            try db.execute(sql: """
                CREATE TABLE t1 (id INTEGER PRIMARY KEY AUTOINCREMENT, b UNIQUE, c REFERENCES t2(id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED);
                CREATE TABLE t2 (id INTEGER PRIMARY KEY AUTOINCREMENT, b UNIQUE, c REFERENCES t1(id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED);
                CREATE VIRTUAL TABLE ft USING fts4(content);
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
            try XCTAssertTrue(db.tableExists("ft"))
            try XCTAssertTrue(db.viewExists("v"))
            try XCTAssertTrue(db.triggerExists("tr"))
            try XCTAssertEqual(db.indexes(on: "t1").count, 2)
        }
        
        try writer.erase()
        try writer.vacuum()
        
        try writer.read { db in
            try XCTAssertNil(Row.fetchOne(db, sql: "SELECT * FROM sqlite_master"))
        }
    }
    
    // See https://github.com/groue/GRDB.swift/issues/424
    func testIssue424() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.execute(sql: """
                CREATE TABLE t(a);
                INSERT INTO t VALUES (1)
                """)
        }
        try dbQueue.read { db in
            _ = try Row.fetchCursor(db.cachedSelectStatement(sql: "SELECT * FROM t")).next()
        }
        try dbQueue.erase()
    }
    
    // See https://github.com/groue/GRDB.swift/issues/424
    func testIssue424Minimal() throws {
        // SQLCipher can't backup encrypted databases: use a pristine Configuration
        let dbQueue = try makeDatabaseQueue(configuration: Configuration())
        try dbQueue.inDatabase { db in
            try db.execute(sql: """
                CREATE TABLE t(a);
                INSERT INTO t VALUES (1);
                PRAGMA query_only = 1;
                """)
            _ = try Row.fetchCursor(db.cachedSelectStatement(sql: "SELECT * FROM t")).next()
        }
        try DatabaseQueue().backup(to: dbQueue)
    }
}
