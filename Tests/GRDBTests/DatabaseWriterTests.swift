import XCTest
import GRDB

class DatabaseWriterTests : GRDBTestCase {
    
    func testDatabaseQueueUnsafeReentrantWrite() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.unsafeReentrantWrite { db1 in
            try db1.create(table: "table1") { t in
                t.primaryKey("id", .integer)
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
                t.primaryKey("id", .integer)
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
        func test(_ dbWriter: some DatabaseWriter) throws {
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

            waitForExpectations(timeout: 2, handler: nil)
            let tableExists = try dbWriter.read { try $0.tableExists("testAsyncWriteWithoutTransaction") }
            XCTAssertTrue(tableExists)
        }
        
        try test(makeDatabaseQueue())
        try test(makeDatabasePool())
    }
    
    func testAsyncWriteWithoutTransactionError() throws {
        func test(_ dbWriter: some DatabaseWriter) throws {
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
            waitForExpectations(timeout: 2, handler: nil)
        }
        
        try test(makeDatabaseQueue())
        try test(makeDatabasePool())
    }
    
    func testAsyncWriteSuccess() throws {
        func test(_ dbWriter: some DatabaseWriter) throws {
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
            
            waitForExpectations(timeout: 2, handler: nil)
            let tableExists = try dbWriter.read { try $0.tableExists("testAsyncWrite") }
            XCTAssertTrue(tableExists)
        }
        
        try test(makeDatabaseQueue())
        try test(makeDatabasePool())
    }
    
    func testAsyncWriteError() throws {
        func test(_ dbWriter: some DatabaseWriter) throws {
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
            waitForExpectations(timeout: 2, handler: nil)
        }
        
        try test(makeDatabaseQueue())
        try test(makeDatabasePool())
    }
    
    func testAnyDatabaseWriter() throws {
        // This test passes if this code compiles.
        let dbQueue = try DatabaseQueue()
        let _: any DatabaseWriter = AnyDatabaseWriter(dbQueue)
    }
    
    func testEraseAndVacuum() throws {
        try testEraseAndVacuum(writer: makeDatabaseQueue())
        try testEraseAndVacuum(writer: makeDatabasePool())
    }

    private func testEraseAndVacuum(writer: some DatabaseWriter) throws {
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

    func testVacuumInto() throws {
        guard #available(iOS 14, macOS 10.16, tvOS 14, *) else {
            throw XCTSkip("VACUUM INTO is not available")
        }
        // Prevent SQLCipher failures
        guard Database.sqliteLibVersionNumber >= 3027000 else {
            throw XCTSkip("VACUUM INTO is not available")
        }
        
        func testVacuumInto(writer: some DatabaseWriter) throws {
            var migrator = DatabaseMigrator()
            migrator.registerMigration("init") { db in
                try db.execute(sql: """
                    CREATE TABLE t1 (id INTEGER PRIMARY KEY AUTOINCREMENT, b, c);
                    INSERT INTO t1 (b, c) VALUES (1, 1);
                    INSERT INTO t1 (b, c) VALUES (2, 2);
                    """)
            }
            
            try migrator.migrate(writer)
            
            try writer.read { db in
                try XCTAssertTrue(db.tableExists("t1"))
                XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT count(*) from t1"), 2)
            }
            
            let intoPath = NSTemporaryDirectory().appending(ProcessInfo.processInfo.globallyUniqueString).appending("-vacuum-into-db.sqlite")
            try writer.vacuum(into: intoPath)
            
            // open newly created file and ensure table was copied, and
            // encrypted like the original.
            let newWriter = try DatabaseQueue(path: intoPath, configuration: writer.configuration)
            try newWriter.read { db in
                try XCTAssertTrue(db.tableExists("t1"))
                XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT count(*) from t1"), 2)
            }
        }
        
        try testVacuumInto(writer: makeDatabaseQueue())
        try testVacuumInto(writer: makeDatabasePool())
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
            _ = try Row.fetchCursor(db.cachedStatement(sql: "SELECT * FROM t")).next()
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
            _ = try Row.fetchCursor(db.cachedStatement(sql: "SELECT * FROM t")).next()
        }
        try DatabaseQueue().backup(to: dbQueue)
    }
    
    func testAsyncAwait_write() async throws {
        func setup<T: DatabaseWriter>(_ dbWriter: T) throws -> T {
            try dbWriter.write { db in
                try db.execute(sql: "CREATE TABLE t (id INTEGER PRIMARY KEY)")
            }
            return dbWriter
        }
        func test<T: DatabaseWriter>(_ dbWriter: T) async throws {
            let count = try await dbWriter.write { db -> Int in
                try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
                return try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM t")!
            }
            XCTAssertEqual(count, 1)
        }
        
        try await test(setup(makeDatabaseQueue()))
        try await test(setup(makeDatabasePool()))
    }
    
    func testAsyncAwait_writeWithoutTransaction() async throws {
        func setup<T: DatabaseWriter>(_ dbWriter: T) throws -> T {
            try dbWriter.write { db in
                try db.execute(sql: "CREATE TABLE t (id INTEGER PRIMARY KEY)")
            }
            return dbWriter
        }
        func test<T: DatabaseWriter>(_ dbWriter: T) async throws {
            let count = try await dbWriter.writeWithoutTransaction { db -> Int in
                try db.beginTransaction()
                try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
                let count = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM t")!
                try db.commit()
                return count
            }
            XCTAssertEqual(count, 1)
        }
        
        try await test(setup(makeDatabaseQueue()))
        try await test(setup(makeDatabasePool()))
    }
    
    func testAsyncAwait_barrierWriteWithoutTransaction() async throws {
        func setup<T: DatabaseWriter>(_ dbWriter: T) throws -> T {
            try dbWriter.write { db in
                try db.execute(sql: "CREATE TABLE t (id INTEGER PRIMARY KEY)")
            }
            return dbWriter
        }
        func test<T: DatabaseWriter>(_ dbWriter: T) async throws {
            let count = try await dbWriter.barrierWriteWithoutTransaction { db -> Int in
                try db.beginTransaction()
                try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
                let count = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM t")!
                try db.commit()
                return count
            }
            XCTAssertEqual(count, 1)
        }
        
        try await test(setup(makeDatabaseQueue()))
        try await test(setup(makeDatabasePool()))
    }
    
    func testAsyncAwait_erase() async throws {
        func setup<T: DatabaseWriter>(_ dbWriter: T) throws -> T {
            try dbWriter.write { db in
                try db.execute(sql: "CREATE TABLE t (id INTEGER PRIMARY KEY)")
            }
            return dbWriter
        }
        func test<T: DatabaseWriter>(_ dbWriter: T) async throws {
            try await dbWriter.erase()
            let tableExists = try await dbWriter.read { try $0.tableExists("t") }
            XCTAssertFalse(tableExists)
        }
        
        try await test(setup(makeDatabaseQueue()))
        try await test(setup(makeDatabasePool()))
    }
    
    func testAsyncAwait_vacuum() async throws {
        func setup<T: DatabaseWriter>(_ dbWriter: T) throws -> T {
            try dbWriter.write { db in
                try db.execute(sql: "CREATE TABLE t (id INTEGER PRIMARY KEY)")
            }
            return dbWriter
        }
        func test<T: DatabaseWriter>(_ dbWriter: T) async throws {
            try await dbWriter.vacuum()
        }
        
        try await test(setup(makeDatabaseQueue()))
        try await test(setup(makeDatabasePool()))
    }
    
    @available(iOS 14, macOS 10.16, tvOS 14, *) // async + vacuum into
    func testAsyncAwait_vacuumInto() async throws {
        // Prevent SQLCipher failures
        guard Database.sqliteLibVersionNumber >= 3027000 else {
            throw XCTSkip("VACUUM INTO is not available")
        }
        
        func setup<T: DatabaseWriter>(_ dbWriter: T) throws -> T {
            try dbWriter.write { db in
                try db.execute(sql: "CREATE TABLE t (id INTEGER PRIMARY KEY)")
            }
            return dbWriter
        }
        func test<T: DatabaseWriter>(_ dbWriter: T) async throws {
            let intoPath = NSTemporaryDirectory().appending(ProcessInfo.processInfo.globallyUniqueString).appending("-vacuum-into-db.sqlite")
            try await dbWriter.vacuum(into: intoPath)
            do {
                // open newly created file and ensure table was copied, and
                // encrypted like the original.
                let dbQueue = try DatabaseQueue(path: intoPath, configuration: dbWriter.configuration)
                let tableExists = try await dbQueue.read { try $0.tableExists("t") }
                XCTAssertTrue(tableExists)
            }
            try FileManager().removeItem(atPath: intoPath)
        }
        
        try await test(setup(makeDatabaseQueue()))
        try await test(setup(makeDatabasePool()))
    }
    
    /// A test related to <https://github.com/groue/GRDB.swift/issues/1456>
    func testAsyncWriteThenRead() async throws {
        /// An async read performed after an async write should see the write.
        func test(_ dbWriter: some DatabaseWriter) async throws {
            try await dbWriter.write { db in
                try db.execute(sql: """
                    CREATE TABLE t (id INTEGER PRIMARY KEY);
                    INSERT INTO t VALUES (1);
                    """)
            }
            
            let count = try await dbWriter.read { db in
                try Table("t").fetchCount(db)
            }
            
            XCTAssertEqual(count, 1)
        }
        
        try await test(makeDatabaseQueue())
        try await test(makeDatabasePool())
    }
    
    // MARK: - Task Cancellation
    
    // Regression test for <https://github.com/groue/GRDB.swift/issues/1715>.
    func test_write_is_possible_after_read_cancelled_after_database_access() async throws {
        // When a read access is cancelled, DatabaseQueue needs to execute
        // `PRAGMA query_only=0` in order to restore the read/write access.
        //
        // Here we test that this pragma can run from a cancelled read.
        //
        // Small difficulty: some SQLite versions (seen with 3.43.2) execute
        // the `query_only` pragma at compile time, not only at execution
        // time (yeah, that's an SQLite bug). The problem of this bug is
        // that even if the `PRAGMA query_only=0` is not executed due to
        // Task cancellation, its side effect is still executed when it is
        // compiled, unintentionally. A cancelled `PRAGMA query_only=0`
        // still works!
        //
        // To avoid this SQLite bug from messing with our test, we perform
        // two reads: one that compiles and cache `PRAGMA query_only`
        // statements, and a second read that we cancel. This time the
        // `PRAGMA query_only=0` triggers its side effect if and only if it
        // is actually executed (the behavior we are testing).
        func test(_ dbWriter: some DatabaseWriter) async throws {
            let semaphore = AsyncSemaphore(value: 0)
            let cancelledTaskMutex = Mutex<Task<Void, any Error>?>(nil)
            let task = Task {
                await semaphore.wait()
                
                // First read, not cancelled, so that all `query_only`
                // pragma statements are compiled (see above).
                try await dbWriter.read { db in }
                
                // Second read, cancelled.
                try await dbWriter.read { db in
                    try XCTUnwrap(cancelledTaskMutex.load()).cancel()
                }
            }
            cancelledTaskMutex.store(task)
            semaphore.signal()
            // Wait until reads are completed
            try? await task.value
            
            // Write access is restored after read cancellation (no error is thrown)
            try await dbWriter.write { db in
                try db.execute(sql: "CREATE TABLE test(a)")
            }
        }
        
        try await test(makeDatabaseQueue())
        try await test(makeDatabasePool())
        try await test(AnyDatabaseWriter(makeDatabaseQueue()))
    }
    
    func test_writeWithoutTransaction_is_cancelled_by_Task_cancellation_performed_before_database_access() async throws {
        func test(_ dbWriter: some DatabaseWriter) async throws {
            let semaphore = AsyncSemaphore(value: 0)
            let task = Task {
                await semaphore.wait()
                try await dbWriter.writeWithoutTransaction { db in
                    XCTFail("Should not be executed")
                }
            }
            task.cancel()
            semaphore.signal()
            
            do {
                try await task.value
                XCTFail("Expected error")
            } catch {
                XCTAssert(error is CancellationError)
            }
            
            // Database access is restored after cancellation (no error is thrown)
            try await dbWriter.writeWithoutTransaction { db in
                try db.execute(sql: "SELECT 0")
            }
        }
        
        try await test(makeDatabaseQueue())
        try await test(makeDatabasePool())
        try await test(AnyDatabaseWriter(makeDatabaseQueue()))
    }
    
    func test_writeWithoutTransaction_is_cancelled_by_Task_cancellation_performed_after_database_access() async throws {
        func test(_ dbWriter: some DatabaseWriter) async throws {
            let semaphore = AsyncSemaphore(value: 0)
            let cancelledTaskMutex = Mutex<Task<Void, any Error>?>(nil)
            let task = Task {
                await semaphore.wait()
                try await dbWriter.writeWithoutTransaction { db in
                    try XCTUnwrap(cancelledTaskMutex.load()).cancel()
                }
            }
            cancelledTaskMutex.store(task)
            semaphore.signal()
            
            do {
                try await task.value
                XCTFail("Expected error")
            } catch {
                XCTAssert(error is CancellationError)
            }
            
            // Database access is restored after cancellation (no error is thrown)
            try await dbWriter.writeWithoutTransaction { db in
                try db.execute(sql: "SELECT 0")
            }
        }
        
        try await test(makeDatabaseQueue())
        try await test(makeDatabasePool())
        try await test(AnyDatabaseWriter(makeDatabaseQueue()))
    }
    
    func test_statement_execution_from_writeWithoutTransaction_is_cancelled_by_Task_cancellation_performed_after_database_access() async throws {
        func test(_ dbWriter: some DatabaseWriter) async throws {
            let semaphore = AsyncSemaphore(value: 0)
            let cancelledTaskMutex = Mutex<Task<Void, any Error>?>(nil)
            let task = Task {
                await semaphore.wait()
                try await dbWriter.writeWithoutTransaction { db in
                    try XCTUnwrap(cancelledTaskMutex.load()).cancel()
                    try db.execute(sql: "SELECT 0")
                    XCTFail("Expected error")
                }
            }
            cancelledTaskMutex.store(task)
            semaphore.signal()
            
            do {
                try await task.value
                XCTFail("Expected error")
            } catch {
                XCTAssert(error is CancellationError)
            }
            
            // Database access is restored after cancellation (no error is thrown)
            try await dbWriter.writeWithoutTransaction { db in
                try db.execute(sql: "SELECT 0")
            }
        }
        
        try await test(makeDatabaseQueue())
        try await test(makeDatabasePool())
        try await test(AnyDatabaseWriter(makeDatabaseQueue()))
    }
    
    func test_cursor_iteration_from_writeWithoutTransaction_is_interrupted_by_Task_cancellation_performed_after_database_access() async throws {
        func test(_ dbWriter: some DatabaseWriter) async throws {
            let semaphore = AsyncSemaphore(value: 0)
            let cancelledTaskMutex = Mutex<Task<Void, any Error>?>(nil)
            let task = Task {
                await semaphore.wait()
                try await dbWriter.writeWithoutTransaction { db in
                    let cursor = try Int.fetchCursor(db, sql: """
                        SELECT 1 UNION ALL SELECT 2
                        """)
                    _ = try cursor.next()
                    try XCTUnwrap(cancelledTaskMutex.load()).cancel()
                    _ = try cursor.next()
                    XCTFail("Expected error")
                }
            }
            cancelledTaskMutex.store(task)
            semaphore.signal()
            
            do {
                try await task.value
                XCTFail("Expected error")
            } catch {
                XCTAssert(error is CancellationError)
            }
            
            // Database access is restored after cancellation (no error is thrown)
            try await dbWriter.writeWithoutTransaction { db in
                try db.execute(sql: "SELECT 0")
            }
        }
        
        try await test(makeDatabaseQueue())
        try await test(makeDatabasePool())
        try await test(AnyDatabaseWriter(makeDatabaseQueue()))
    }
    
    func test_write_is_cancelled_by_Task_cancellation_performed_before_database_access() async throws {
        func test(_ dbWriter: some DatabaseWriter) async throws {
            let semaphore = AsyncSemaphore(value: 0)
            let task = Task {
                await semaphore.wait()
                try await dbWriter.write { db in
                    XCTFail("Should not be executed")
                }
            }
            task.cancel()
            semaphore.signal()
            
            do {
                try await task.value
                XCTFail("Expected error")
            } catch {
                XCTAssert(error is CancellationError)
            }
            
            // Database access is restored after cancellation (no error is thrown)
            try await dbWriter.write { db in
                try db.execute(sql: "SELECT 0")
            }
        }
        
        try await test(makeDatabaseQueue())
        try await test(makeDatabasePool())
        try await test(AnyDatabaseWriter(makeDatabaseQueue()))
    }
    
    func test_write_is_cancelled_by_Task_cancellation_performed_after_database_access() async throws {
        func test(_ dbWriter: some DatabaseWriter) async throws {
            let semaphore = AsyncSemaphore(value: 0)
            let cancelledTaskMutex = Mutex<Task<Void, any Error>?>(nil)
            let task = Task {
                await semaphore.wait()
                try await dbWriter.write { db in
                    try XCTUnwrap(cancelledTaskMutex.load()).cancel()
                }
            }
            cancelledTaskMutex.store(task)
            semaphore.signal()
            
            do {
                try await task.value
                XCTFail("Expected error")
            } catch {
                XCTAssert(error is CancellationError)
            }
            
            // Database access is restored after cancellation (no error is thrown)
            try await dbWriter.write { db in
                try db.execute(sql: "SELECT 0")
            }
        }
        
        try await test(makeDatabaseQueue())
        try await test(makeDatabasePool())
        try await test(AnyDatabaseWriter(makeDatabaseQueue()))
    }
    
    func test_statement_execution_from_write_is_cancelled_by_Task_cancellation_performed_after_database_access() async throws {
        func test(_ dbWriter: some DatabaseWriter) async throws {
            let semaphore = AsyncSemaphore(value: 0)
            let cancelledTaskMutex = Mutex<Task<Void, any Error>?>(nil)
            let task = Task {
                await semaphore.wait()
                try await dbWriter.write { db in
                    try XCTUnwrap(cancelledTaskMutex.load()).cancel()
                    try db.execute(sql: "SELECT 0")
                    XCTFail("Expected error")
                }
            }
            cancelledTaskMutex.store(task)
            semaphore.signal()
            
            do {
                try await task.value
                XCTFail("Expected error")
            } catch {
                XCTAssert(error is CancellationError)
            }
            
            // Database access is restored after cancellation (no error is thrown)
            try await dbWriter.write { db in
                try db.execute(sql: "SELECT 0")
            }
        }
        
        try await test(makeDatabaseQueue())
        try await test(makeDatabasePool())
        try await test(AnyDatabaseWriter(makeDatabaseQueue()))
    }
    
    func test_cursor_iteration_from_write_is_interrupted_by_Task_cancellation_performed_after_database_access() async throws {
        func test(_ dbWriter: some DatabaseWriter) async throws {
            let semaphore = AsyncSemaphore(value: 0)
            let cancelledTaskMutex = Mutex<Task<Void, any Error>?>(nil)
            let task = Task {
                await semaphore.wait()
                try await dbWriter.write { db in
                    let cursor = try Int.fetchCursor(db, sql: """
                        SELECT 1 UNION ALL SELECT 2
                        """)
                    _ = try cursor.next()
                    try XCTUnwrap(cancelledTaskMutex.load()).cancel()
                    _ = try cursor.next()
                    XCTFail("Expected error")
                }
            }
            cancelledTaskMutex.store(task)
            semaphore.signal()
            
            do {
                try await task.value
                XCTFail("Expected error")
            } catch {
                XCTAssert(error is CancellationError)
            }
            
            // Database access is restored after cancellation (no error is thrown)
            try await dbWriter.write { db in
                try db.execute(sql: "SELECT 0")
            }
        }
        
        try await test(makeDatabaseQueue())
        try await test(makeDatabasePool())
        try await test(AnyDatabaseWriter(makeDatabaseQueue()))
    }
    
    func test_barrierWriteWithoutTransaction_is_cancelled_by_Task_cancellation_performed_before_database_access() async throws {
        func test(_ dbWriter: some DatabaseWriter) async throws {
            let semaphore = AsyncSemaphore(value: 0)
            let task = Task {
                await semaphore.wait()
                try await dbWriter.barrierWriteWithoutTransaction { db in
                    XCTFail("Should not be executed")
                }
            }
            task.cancel()
            semaphore.signal()
            
            do {
                try await task.value
                XCTFail("Expected error")
            } catch {
                XCTAssert(error is CancellationError)
            }
            
            // Database access is restored after cancellation (no error is thrown)
            try await dbWriter.barrierWriteWithoutTransaction { db in
                try db.execute(sql: "SELECT 0")
            }
        }
        
        try await test(makeDatabaseQueue())
        try await test(makeDatabasePool())
        try await test(AnyDatabaseWriter(makeDatabaseQueue()))
    }
    
    func test_barrierWriteWithoutTransaction_is_cancelled_by_Task_cancellation_performed_after_database_access() async throws {
        func test(_ dbWriter: some DatabaseWriter) async throws {
            let semaphore = AsyncSemaphore(value: 0)
            let cancelledTaskMutex = Mutex<Task<Void, any Error>?>(nil)
            let task = Task {
                await semaphore.wait()
                try await dbWriter.barrierWriteWithoutTransaction { db in
                    try XCTUnwrap(cancelledTaskMutex.load()).cancel()
                }
            }
            cancelledTaskMutex.store(task)
            semaphore.signal()
            
            do {
                try await task.value
                XCTFail("Expected error")
            } catch {
                XCTAssert(error is CancellationError)
            }
            
            // Database access is restored after cancellation (no error is thrown)
            try await dbWriter.barrierWriteWithoutTransaction { db in
                try db.execute(sql: "SELECT 0")
            }
        }
        
        try await test(makeDatabaseQueue())
        try await test(makeDatabasePool())
        try await test(AnyDatabaseWriter(makeDatabaseQueue()))
    }
    
    func test_statement_execution_from_barrierWriteWithoutTransaction_is_cancelled_by_Task_cancellation_performed_after_database_access() async throws {
        func test(_ dbWriter: some DatabaseWriter) async throws {
            let semaphore = AsyncSemaphore(value: 0)
            let cancelledTaskMutex = Mutex<Task<Void, any Error>?>(nil)
            let task = Task {
                await semaphore.wait()
                try await dbWriter.barrierWriteWithoutTransaction { db in
                    try XCTUnwrap(cancelledTaskMutex.load()).cancel()
                    try db.execute(sql: "SELECT 0")
                    XCTFail("Expected error")
                }
            }
            cancelledTaskMutex.store(task)
            semaphore.signal()
            
            do {
                try await task.value
                XCTFail("Expected error")
            } catch {
                XCTAssert(error is CancellationError)
            }
            
            // Database access is restored after cancellation (no error is thrown)
            try await dbWriter.barrierWriteWithoutTransaction { db in
                try db.execute(sql: "SELECT 0")
            }
        }
        
        try await test(makeDatabaseQueue())
        try await test(makeDatabasePool())
        try await test(AnyDatabaseWriter(makeDatabaseQueue()))
    }
    
    func test_cursor_iteration_from_barrierWriteWithoutTransaction_is_interrupted_by_Task_cancellation_performed_after_database_access() async throws {
        func test(_ dbWriter: some DatabaseWriter) async throws {
            let semaphore = AsyncSemaphore(value: 0)
            let cancelledTaskMutex = Mutex<Task<Void, any Error>?>(nil)
            let task = Task {
                await semaphore.wait()
                try await dbWriter.barrierWriteWithoutTransaction { db in
                    let cursor = try Int.fetchCursor(db, sql: """
                        SELECT 1 UNION ALL SELECT 2
                        """)
                    _ = try cursor.next()
                    try XCTUnwrap(cancelledTaskMutex.load()).cancel()
                    _ = try cursor.next()
                    XCTFail("Expected error")
                }
            }
            cancelledTaskMutex.store(task)
            semaphore.signal()
            
            do {
                try await task.value
                XCTFail("Expected error")
            } catch {
                XCTAssert(error is CancellationError)
            }
            
            // Database access is restored after cancellation (no error is thrown)
            try await dbWriter.barrierWriteWithoutTransaction { db in
                try db.execute(sql: "SELECT 0")
            }
        }
        
        try await test(makeDatabaseQueue())
        try await test(makeDatabasePool())
        try await test(AnyDatabaseWriter(makeDatabaseQueue()))
    }
}
