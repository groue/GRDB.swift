import XCTest
#if GRDBCUSTOMSQLITE
import GRDBCustomSQLite
#else
import GRDB
#endif

class DatabaseExclusiveLockPreventionTests : GRDBTestCase {
    
    func testExclusiveLockPreventionPreventsNewTransaction() throws {
        let dbQueue = try makeDatabaseQueue()
        dbQueue.startPreventingExclusiveLock()
        do {
            try dbQueue.inDatabase { db in
                try db.execute(sql: "BEGIN TRANSACTION")
            }
            XCTFail("Expected error")
        } catch let error as DatabaseError {
            XCTAssertEqual(error.resultCode, .SQLITE_ABORT)
            XCTAssertEqual(error.message, "Can't acquire exclusive lock")
            XCTAssertEqual(error.sql, "BEGIN TRANSACTION")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testExclusiveLockPreventionDoesNotPreventCommit() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(sql: "BEGIN TRANSACTION")
            dbQueue.startPreventingExclusiveLock()
            try db.execute(sql: "COMMIT")
        }
    }
    
    func testExclusiveLockPreventionDoesNotPreventRollback() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(sql: "BEGIN TRANSACTION")
            dbQueue.startPreventingExclusiveLock()
            try db.execute(sql: "ROLLBACK")
        }
    }
    
    func testExclusiveLockPreventionDoesNotPreventRead() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(sql: "CREATE TABLE t(a);")
            dbQueue.startPreventingExclusiveLock()
            try XCTAssertEqual(Int.fetchOne(db, sql: "SELECT COUNT(*) FROM t"), 0)
        }
    }
    
    func testExclusiveLockPreventionDoesNotPreventSavepoint() throws {
        // This is because savepoints do not acquire exclusive locks.
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(sql: "CREATE TABLE t(a);")
            dbQueue.startPreventingExclusiveLock()
            try db.execute(sql: "SAVEPOINT test")
            try db.execute(sql: "RELEASE SAVEPOINT test")
        }
    }
    
    func testExclusiveLockPreventionPreventsWrite() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(sql: "CREATE TABLE t(a);")
            dbQueue.startPreventingExclusiveLock()
            do {
                try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
                XCTFail("Expected error")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_ABORT)
                XCTAssertEqual(error.message, "Can't acquire exclusive lock")
                XCTAssertEqual(error.sql, "INSERT INTO t DEFAULT VALUES")
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
        }
    }
    
    func testExclusiveLockPreventionRollbacksOnPreventedWrite() throws {
        do {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.write { db in
                try db.execute(sql: "CREATE TABLE t(a);")
                XCTAssertTrue(db.isInsideTransaction)
                dbQueue.startPreventingExclusiveLock()
                do {
                    try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
                    XCTFail("Expected error")
                } catch let error as DatabaseError {
                    XCTAssertEqual(error.resultCode, .SQLITE_ABORT)
                    XCTAssertEqual(error.message, "Can't acquire exclusive lock")
                    XCTAssertEqual(error.sql, "INSERT INTO t DEFAULT VALUES")
                } catch {
                    XCTFail("Unexpected error: \(error)")
                }
                // Aborded transaction
                XCTAssertFalse(db.isInsideTransaction)
            }
            XCTFail("Expected error")
        } catch let error as DatabaseError {
            XCTAssertEqual(error.resultCode, .SQLITE_ABORT)
            XCTAssertEqual(error.message, "Transaction was aborted")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        
        
        do {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute(sql: "CREATE TABLE t(a);")
                dbQueue.startPreventingExclusiveLock()
                try db.execute(sql: "SAVEPOINT test")
                do {
                    try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
                    XCTFail("Expected error")
                } catch let error as DatabaseError {
                    XCTAssertEqual(error.resultCode, .SQLITE_ABORT)
                    XCTAssertEqual(error.message, "Can't acquire exclusive lock")
                    XCTAssertEqual(error.sql, "INSERT INTO t DEFAULT VALUES")
                } catch {
                    XCTFail("Unexpected error: \(error)")
                }
                // Aborded transaction
                XCTAssertFalse(db.isInsideTransaction)
            }
        }
    }
    
    func testExclusiveLockPreventionAbortsDatabaseQueueAccess() throws {
        let dbQueue = try makeDatabaseQueue()
        
        let semaphore1 = DispatchSemaphore(value: 0)
        let semaphore2 = DispatchSemaphore(value: 0)
        dbQueue.add(function: DatabaseFunction("wait", argumentCount: 0, pure: true) { _ in
            semaphore1.signal()
            semaphore2.wait()
            return nil
        })
        
        let block1 = {
            do {
                _ = try dbQueue.inDatabase {
                    try Row.fetchAll($0, sql: "SELECT wait()")
                }
                XCTFail("Expected error")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_INTERRUPT)
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
        }
        let block2 = {
            semaphore1.wait()
            dbQueue.startPreventingExclusiveLock()
            semaphore2.signal()
        }
        let blocks = [block1, block2]
        DispatchQueue.concurrentPerform(iterations: blocks.count) { index in
            blocks[index]()
        }
    }
    
    func testExclusiveLockPreventionDoesNotAbortDatabasePoolReadTransaction() throws {
        let dbPool = try makeDatabasePool()
        
        let semaphore1 = DispatchSemaphore(value: 0)
        let semaphore2 = DispatchSemaphore(value: 0)
        
        dbPool.add(function: DatabaseFunction("wait", argumentCount: 0, pure: true) { _ in
            semaphore1.signal()
            semaphore2.wait()
            return nil
        })
        let block1 = {
            do {
                _ = try dbPool.read {
                    try Row.fetchAll($0, sql: "SELECT wait()")
                }
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
        }
        let block2 = {
            semaphore1.wait()
            dbPool.startPreventingExclusiveLock()
            semaphore2.signal()
        }
        let blocks = [block1, block2]
        DispatchQueue.concurrentPerform(iterations: blocks.count) { index in
            blocks[index]()
        }
    }

    func testExclusiveLockPreventionDoesNotPreventFurtherDatabaseQueueRead() throws {
        let dbQueue = try makeDatabaseQueue()
        
        try dbQueue.write { db in
            try db.execute(sql: "CREATE TABLE t(a);")
        }
        
        let semaphore1 = DispatchSemaphore(value: 0)
        let semaphore2 = DispatchSemaphore(value: 0)
        
        dbQueue.add(function: DatabaseFunction("wait", argumentCount: 0, pure: true) { _ in
            semaphore1.signal()
            semaphore2.wait()
            return nil
        })
        let block1 = {
            try! dbQueue.inDatabase { db in
                let wasInTransaction = db.isInsideTransaction
                do {
                    _ = try Row.fetchAll(db, sql: "SELECT wait()")
                    XCTFail("Expected error")
                } catch let error as DatabaseError {
                    XCTAssertEqual(error.resultCode, .SQLITE_INTERRUPT)
                } catch {
                    XCTFail("Unexpected error: \(error)")
                }
                XCTAssertEqual(db.isInsideTransaction, wasInTransaction)
                try XCTAssertEqual(Int.fetchOne(db, sql: "SELECT COUNT(*) FROM t"), 0)
            }
        }
        let block2 = {
            semaphore1.wait()
            dbQueue.startPreventingExclusiveLock()
            semaphore2.signal()
        }
        let blocks = [block1, block2]
        DispatchQueue.concurrentPerform(iterations: blocks.count) { index in
            blocks[index]()
        }
    }
    
    func testWriteTransactionAbortedDuringStatementExecution() throws {
        func setup<T: DatabaseWriter>(_ dbWriter: T) throws -> T {
            try dbWriter.write { db in
                try db.execute(sql: "CREATE TABLE t(a);")
            }
            return dbWriter
        }
        func test(_ dbWriter: DatabaseWriter) throws {
            let semaphore1 = DispatchSemaphore(value: 0)
            let semaphore2 = DispatchSemaphore(value: 0)
            
            dbWriter.add(function: DatabaseFunction("wait", argumentCount: 0, pure: true) { _ in
                semaphore1.signal()
                semaphore2.wait()
                return nil
            })
            let block1 = {
                do {
                    try dbWriter.write { db in
                        try db.execute(sql: "INSERT INTO t SELECT wait()")
                    }
                    XCTFail("Expected error")
                } catch let error as DatabaseError {
                    // Transactions throw the first uncatched error: SQLITE_INTERRUPT
                    XCTAssertEqual(error.resultCode, .SQLITE_INTERRUPT)
                    XCTAssertEqual(error.message, "interrupted")
                    XCTAssertEqual(error.sql, "INSERT INTO t SELECT wait()")
                } catch {
                    XCTFail("Unexpected error: \(error)")
                }
            }
            let block2 = {
                semaphore1.wait()
                dbWriter.startPreventingExclusiveLock()
                semaphore2.signal()
            }
            let blocks = [block1, block2]
            DispatchQueue.concurrentPerform(iterations: blocks.count) { index in
                blocks[index]()
            }
        }
        
        try test(setup(DatabaseQueue()))
        try test(setup(makeDatabaseQueue()))
        try test(setup(makeDatabasePool()))
    }
    
    func testWriteTransactionAbortedDuringStatementExecutionPreventsFurtherDatabaseAccess() throws {
        func setup<T: DatabaseWriter>(_ dbWriter: T) throws -> T {
            try dbWriter.write { db in
                try db.execute(sql: "CREATE TABLE t(a);")
            }
            return dbWriter
        }
        func test(_ dbWriter: DatabaseWriter) throws {
            let semaphore1 = DispatchSemaphore(value: 0)
            let semaphore2 = DispatchSemaphore(value: 0)
            
            dbWriter.add(function: DatabaseFunction("wait", argumentCount: 0, pure: true) { _ in
                semaphore1.signal()
                semaphore2.wait()
                return nil
            })
            let block1 = {
                do {
                    try dbWriter.write { db in
                        do {
                            try db.execute(sql: "INSERT INTO t SELECT wait()")
                            XCTFail("Expected error")
                        } catch let error as DatabaseError {
                            XCTAssertEqual(error.resultCode, .SQLITE_INTERRUPT)
                        } catch {
                            XCTFail("Unexpected error: \(error)")
                        }
                        
                        XCTAssertFalse(db.isInsideTransaction)
                        
                        do {
                            _ = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM t")
                            XCTFail("Expected error")
                        } catch let error as DatabaseError {
                            XCTAssertEqual(error.resultCode, .SQLITE_ABORT)
                            XCTAssertEqual(error.message, "Transaction was aborted")
                            XCTAssertEqual(error.sql, "SELECT COUNT(*) FROM t")
                        } catch {
                            XCTFail("Unexpected error: \(error)")
                        }
                        
                        do {
                            try db.execute(sql: "INSERT INTO t (a) VALUES (0)")
                            XCTFail("Expected error")
                        } catch let error as DatabaseError {
                            XCTAssertEqual(error.resultCode, .SQLITE_ABORT)
                            XCTAssertEqual(error.message, "Can't acquire exclusive lock")
                            XCTAssertEqual(error.sql, "INSERT INTO t (a) VALUES (0)")
                        } catch {
                            XCTFail("Unexpected error: \(error)")
                        }
                    }
                    XCTFail("Expected error")
                } catch let error as DatabaseError {
                    // SQLITE_INTERRUPT has been caught. So we get SQLITE_ABORT
                    // from the last commit.
                    XCTAssertEqual(error.resultCode, .SQLITE_ABORT)
                    XCTAssertEqual(error.message, "Transaction was aborted")
                } catch {
                    XCTFail("Unexpected error: \(error)")
                }
            }
            let block2 = {
                semaphore1.wait()
                dbWriter.startPreventingExclusiveLock()
                semaphore2.signal()
            }
            let blocks = [block1, block2]
            DispatchQueue.concurrentPerform(iterations: blocks.count) { index in
                blocks[index]()
            }
        }
        
        try test(setup(DatabaseQueue()))
        try test(setup(makeDatabaseQueue()))
        try test(setup(makeDatabasePool()))
    }
    
    func testWriteTransactionAbortedDuringStatementExecutionDoesNotPreventRollback() throws {
        func setup<T: DatabaseWriter>(_ dbWriter: T) throws -> T {
            try dbWriter.write { db in
                try db.execute(sql: "CREATE TABLE t(a);")
            }
            return dbWriter
        }
        func test(_ dbWriter: DatabaseWriter) throws {
            let semaphore1 = DispatchSemaphore(value: 0)
            let semaphore2 = DispatchSemaphore(value: 0)
            
            dbWriter.add(function: DatabaseFunction("wait", argumentCount: 0, pure: true) { _ in
                semaphore1.signal()
                semaphore2.wait()
                return nil
            })
            let block1 = {
                try! dbWriter.writeWithoutTransaction { db in
                    try db.inTransaction {
                        do {
                            try db.execute(sql: "INSERT INTO t SELECT wait()")
                            XCTFail("Expected error")
                        } catch let error as DatabaseError {
                            XCTAssertEqual(error.resultCode, .SQLITE_INTERRUPT)
                        } catch {
                            XCTFail("Unexpected error: \(error)")
                        }
                        
                        XCTAssertFalse(db.isInsideTransaction)
                        return .rollback
                    }
                }
            }
            let block2 = {
                semaphore1.wait()
                dbWriter.startPreventingExclusiveLock()
                semaphore2.signal()
            }
            let blocks = [block1, block2]
            DispatchQueue.concurrentPerform(iterations: blocks.count) { index in
                blocks[index]()
            }
        }
        
        try test(setup(DatabaseQueue()))
        try test(setup(makeDatabaseQueue()))
        try test(setup(makeDatabasePool()))
    }
}
