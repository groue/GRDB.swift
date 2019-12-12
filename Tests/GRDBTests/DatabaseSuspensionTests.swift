import XCTest
#if GRDBCUSTOMSQLITE
@testable import GRDBCustomSQLite
#else
@testable import GRDB
#endif

class DatabaseSuspensionTests : GRDBTestCase {
    
    private func makeDatabaseQueue(journalMode: String) throws -> DatabaseQueue {
        let dbQueue = try makeDatabaseQueue()
        let actualJournalMode = try dbQueue.inDatabase { try String.fetchOne($0, sql: "PRAGMA journal_mode=\(journalMode)") }
        XCTAssertEqual(actualJournalMode, journalMode)
        return dbQueue
    }
    
    // MARK: - BEGIN TRANSACTION
    
    func testSuspensionPreventsNewTransactionInDeleteJournalMode() throws {
        let dbQueue = try makeDatabaseQueue(journalMode: "delete")
        dbQueue.suspend()
        
        do {
            try dbQueue.inDatabase { db in
                try db.execute(sql: "BEGIN TRANSACTION")
            }
            XCTFail("Expected error")
        } catch let error as DatabaseError {
            XCTAssertEqual(error.resultCode, .SQLITE_ABORT)
            XCTAssertEqual(error.message, "Database is suspended")
            XCTAssertEqual(error.sql, "BEGIN TRANSACTION")
        }
        
        do {
            try dbQueue.inDatabase { db in
                try db.execute(sql: "BEGIN IMMEDIATE TRANSACTION")
            }
            XCTFail("Expected error")
        } catch let error as DatabaseError {
            XCTAssertEqual(error.resultCode, .SQLITE_ABORT)
            XCTAssertEqual(error.message, "Database is suspended")
            XCTAssertEqual(error.sql, "BEGIN IMMEDIATE TRANSACTION")
        }
        
        do {
            try dbQueue.inDatabase { db in
                try db.execute(sql: "BEGIN EXCLUSIVE TRANSACTION")
            }
            XCTFail("Expected error")
        } catch let error as DatabaseError {
            XCTAssertEqual(error.resultCode, .SQLITE_ABORT)
            XCTAssertEqual(error.message, "Database is suspended")
            XCTAssertEqual(error.sql, "BEGIN EXCLUSIVE TRANSACTION")
        }
        
        do {
            try dbQueue.inDatabase { db in
                try db.execute(sql: "SAVEPOINT test")
            }
            XCTFail("Expected error")
        } catch let error as DatabaseError {
            XCTAssertEqual(error.resultCode, .SQLITE_ABORT)
            XCTAssertEqual(error.message, "Database is suspended")
            XCTAssertEqual(error.sql, "SAVEPOINT test")
        }
    }
    
    func testSuspensionDoesNotPreventNewDeferredTransactionInWALMode() throws {
        let dbQueue = try makeDatabaseQueue(journalMode: "wal")
        dbQueue.suspend()
        
        try dbQueue.inDatabase { db in
            try db.execute(sql: "BEGIN TRANSACTION; ROLLBACK")
            try db.execute(sql: "SAVEPOINT test; RELEASE SAVEPOINT test")
        }
    }
    
    func testSuspensionPreventsNewImmediateOrExclusiveTransactionInWALMode() throws {
        let dbQueue = try makeDatabaseQueue(journalMode: "wal")
        dbQueue.suspend()
        
        do {
            try dbQueue.inDatabase { db in
                try db.execute(sql: "BEGIN IMMEDIATE TRANSACTION")
            }
            XCTFail("Expected error")
        } catch let error as DatabaseError {
            XCTAssertEqual(error.resultCode, .SQLITE_ABORT)
            XCTAssertEqual(error.message, "Database is suspended")
            XCTAssertEqual(error.sql, "BEGIN IMMEDIATE TRANSACTION")
        }
        
        do {
            try dbQueue.inDatabase { db in
                try db.execute(sql: "BEGIN EXCLUSIVE TRANSACTION")
            }
            XCTFail("Expected error")
        } catch let error as DatabaseError {
            XCTAssertEqual(error.resultCode, .SQLITE_ABORT)
            XCTAssertEqual(error.message, "Database is suspended")
            XCTAssertEqual(error.sql, "BEGIN EXCLUSIVE TRANSACTION")
        }
    }
    
    // MARK: - COMMIT, ROLLBACK, RELEASE SAVEPOINT, ROLLBACK TRANSACTION TO SAVEPOINT
    
    func testSuspensionDoesNotPreventCommit() throws {
        func test(_ dbQueue: DatabaseQueue) throws {
            try dbQueue.inDatabase { db in
                try db.execute(sql: "BEGIN TRANSACTION")
                dbQueue.suspend()
                try db.execute(sql: "COMMIT")
            }
        }
        try test(makeDatabaseQueue(journalMode: "delete"))
        try test(makeDatabaseQueue(journalMode: "wal"))
    }
    
    func testSuspensionDoesNotPreventRollback() throws {
        func test(_ dbQueue: DatabaseQueue) throws {
            try dbQueue.inDatabase { db in
                try db.execute(sql: "BEGIN TRANSACTION")
                dbQueue.suspend()
                try db.execute(sql: "ROLLBACK")
            }
        }
        try test(makeDatabaseQueue(journalMode: "delete"))
        try test(makeDatabaseQueue(journalMode: "wal"))
    }
    
    func testSuspensionDoesNotPreventReleaseSavePoint() throws {
        func test(_ dbQueue: DatabaseQueue) throws {
            try dbQueue.inDatabase { db in
                try db.execute(sql: "SAVEPOINT test")
                dbQueue.suspend()
                try db.execute(sql: "RELEASE SAVEPOINT test")
            }
        }
        try test(makeDatabaseQueue(journalMode: "delete"))
        try test(makeDatabaseQueue(journalMode: "wal"))
    }
    
    func testSuspensionDoesNotPreventRollbackSavePoint() throws {
        func test(_ dbQueue: DatabaseQueue) throws {
            try dbQueue.inDatabase { db in
                try db.execute(sql: "SAVEPOINT test")
                dbQueue.suspend()
                try db.execute(sql: "ROLLBACK TRANSACTION TO SAVEPOINT test")
                try db.execute(sql: "RELEASE SAVEPOINT test")
            }
        }
        try test(makeDatabaseQueue(journalMode: "delete"))
        try test(makeDatabaseQueue(journalMode: "wal"))
    }
    
    // MARK: - SELECT
    
    func testSuspensionPreventsReadInDeleteJournalMode() throws {
        let dbQueue = try makeDatabaseQueue(journalMode: "delete")
        do {
            try dbQueue.inDatabase { db in
                try db.execute(sql: "CREATE TABLE t(a)")
                dbQueue.suspend()
                _ = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM t")
            }
            XCTFail("Expected error")
        } catch let error as DatabaseError {
            XCTAssertEqual(error.resultCode, .SQLITE_ABORT)
            XCTAssertEqual(error.message, "Database is suspended")
            XCTAssertEqual(error.sql, "SELECT COUNT(*) FROM t")
        }
    }
    
    func testSuspensionDoesNotPreventReadInWALMode() throws {
        let dbQueue = try makeDatabaseQueue(journalMode: "wal")
        try dbQueue.inDatabase { db in
            try db.execute(sql: "CREATE TABLE t(a)")
            dbQueue.suspend()
            
            try XCTAssertEqual(Int.fetchOne(db, sql: "SELECT COUNT(*) FROM t"), 0)
            
            try db.inTransaction(.deferred) {
                try XCTAssertEqual(Int.fetchOne(db, sql: "SELECT COUNT(*) FROM t"), 0)
                return .commit
            }
        }
    }
    
    // MARK: - INSERT
    
    func testSuspensionPreventsWriteInDeleteJournalMode() throws {
        let dbQueue = try makeDatabaseQueue(journalMode: "delete")
        try dbQueue.inDatabase { db in
            try db.execute(sql: "CREATE TABLE t(a)")
            dbQueue.suspend()
            do {
                try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
                XCTFail("Expected error")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_ABORT)
                XCTAssertEqual(error.message, "Database is suspended")
                XCTAssertEqual(error.sql, "INSERT INTO t DEFAULT VALUES")
            }
        }
    }
    
    func testSuspensionPreventsWriteInWALMode() throws {
        let dbQueue = try makeDatabaseQueue(journalMode: "wal")
        try dbQueue.inDatabase { db in
            try db.execute(sql: "CREATE TABLE t(a)")
            dbQueue.suspend()
            
            do {
                try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
                XCTFail("Expected error")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_ABORT)
                XCTAssertEqual(error.message, "Database is suspended")
                XCTAssertEqual(error.sql, "INSERT INTO t DEFAULT VALUES")
            }
            
            do {
                try db.inTransaction(.deferred) {
                    try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
                    return .commit
                }
                XCTFail("Expected error")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_ABORT)
                XCTAssertEqual(error.message, "Database is suspended")
                XCTAssertEqual(error.sql, "INSERT INTO t DEFAULT VALUES")
            }
        }
    }
    
    // MARK: - Automatic ROLLBACK
    
    func testSuspensionRollbacksOnPreventedWrite() throws {
        func test(_ dbQueue: DatabaseQueue) throws {
            do {
                try dbQueue.write { db in
                    try db.execute(sql: "CREATE TABLE t(a)")
                    XCTAssertTrue(db.isInsideTransaction)
                    dbQueue.suspend()
                    do {
                        try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
                        XCTFail("Expected error")
                    } catch let error as DatabaseError {
                        XCTAssertEqual(error.resultCode, .SQLITE_ABORT)
                        XCTAssertEqual(error.message, "Database is suspended")
                        XCTAssertEqual(error.sql, "INSERT INTO t DEFAULT VALUES")
                    }
                    // Aborded transaction
                    XCTAssertFalse(db.isInsideTransaction)
                }
                XCTFail("Expected error")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_ABORT)
                XCTAssertEqual(error.message, "Transaction was aborted")
            }
        }
        try test(makeDatabaseQueue(journalMode: "delete"))
        try test(makeDatabaseQueue(journalMode: "wal"))
    }
    
    // MARK: - Concurrent Lock Prevention
    
    func testSuspensionAbortsDatabaseQueueAccess() throws {
        func test(_ dbQueue: DatabaseQueue) throws {
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
                dbQueue.suspend()
                semaphore2.signal()
            }
            let blocks = [block1, block2]
            DispatchQueue.concurrentPerform(iterations: blocks.count) { index in
                blocks[index]()
            }
        }
        try test(makeDatabaseQueue(journalMode: "delete"))
        try test(makeDatabaseQueue(journalMode: "wal"))
    }
    
    func testSuspensionDoesNotPreventFurtherReadInWALMode() throws {
        let dbQueue = try makeDatabaseQueue(journalMode: "wal")
        try dbQueue.write { db in
            try db.execute(sql: "CREATE TABLE t(a)")
        }
        
        let semaphore1 = DispatchSemaphore(value: 0)
        let semaphore2 = DispatchSemaphore(value: 0)
        
        dbQueue.add(function: DatabaseFunction("wait", argumentCount: 0, pure: true) { _ in
            semaphore1.signal()
            semaphore2.wait()
            return nil
        })
        let block1 = {
            do {
                try dbQueue.inTransaction { db in
                    do {
                        _ = try Row.fetchAll(db, sql: "SELECT wait()")
                        XCTFail("Expected error")
                    } catch let error as DatabaseError {
                        XCTAssertEqual(error.resultCode, .SQLITE_INTERRUPT)
                    }
                    XCTAssertTrue(db.isInsideTransaction)
                    try XCTAssertEqual(Int.fetchOne(db, sql: "SELECT COUNT(*) FROM t"), 0)
                    return .commit
                }
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
        }
        let block2 = {
            semaphore1.wait()
            dbQueue.suspend()
            semaphore2.signal()
        }
        let blocks = [block1, block2]
        DispatchQueue.concurrentPerform(iterations: blocks.count) { index in
            blocks[index]()
        }
    }
    
    func testWriteTransactionAbortedDuringStatementExecution() throws {
        func test(_ dbQueue: DatabaseQueue) throws {
            try dbQueue.write { db in
                try db.execute(sql: "CREATE TABLE t(a)")
            }
            
            let semaphore1 = DispatchSemaphore(value: 0)
            let semaphore2 = DispatchSemaphore(value: 0)
            
            dbQueue.add(function: DatabaseFunction("wait", argumentCount: 0, pure: true) { _ in
                semaphore1.signal()
                semaphore2.wait()
                return nil
            })
            let block1 = {
                do {
                    try dbQueue.write { db in
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
                dbQueue.suspend()
                semaphore2.signal()
            }
            let blocks = [block1, block2]
            DispatchQueue.concurrentPerform(iterations: blocks.count) { index in
                blocks[index]()
            }
        }
        try test(makeDatabaseQueue(journalMode: "delete"))
        try test(makeDatabaseQueue(journalMode: "wal"))
    }
    
    func testWriteTransactionAbortedDuringStatementExecutionPreventsFurtherDatabaseAccess() throws {
        func test(_ dbQueue: DatabaseQueue) throws {
            try dbQueue.write { db in
                try db.execute(sql: "CREATE TABLE t(a)")
            }
            
            let semaphore1 = DispatchSemaphore(value: 0)
            let semaphore2 = DispatchSemaphore(value: 0)
            
            dbQueue.add(function: DatabaseFunction("wait", argumentCount: 0, pure: true) { _ in
                semaphore1.signal()
                semaphore2.wait()
                return nil
            })
            let block1 = {
                do {
                    try dbQueue.write { db in
                        do {
                            try db.execute(sql: "INSERT INTO t SELECT wait()")
                            XCTFail("Expected error")
                        } catch let error as DatabaseError {
                            XCTAssertEqual(error.resultCode, .SQLITE_INTERRUPT)
                        }
                        
                        XCTAssertFalse(db.isInsideTransaction)
                        
                        do {
                            _ = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM t")
                            XCTFail("Expected error")
                        } catch let error as DatabaseError {
                            XCTAssertEqual(error.resultCode, .SQLITE_ABORT)
                            XCTAssertEqual(error.message, "Transaction was aborted")
                            XCTAssertEqual(error.sql, "SELECT COUNT(*) FROM t")
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
                dbQueue.suspend()
                semaphore2.signal()
            }
            let blocks = [block1, block2]
            DispatchQueue.concurrentPerform(iterations: blocks.count) { index in
                blocks[index]()
            }
        }
        try test(makeDatabaseQueue(journalMode: "delete"))
        try test(makeDatabaseQueue(journalMode: "wal"))
    }
    
    // MARK: - resume
    
    func testResume() throws {
        let dbQueue = try makeDatabaseQueue(journalMode: "delete")
        try dbQueue.inDatabase { db in
            try db.execute(sql: "CREATE TABLE t(a)")
            dbQueue.suspend()
            dbQueue.resume()
            try XCTAssertEqual(Int.fetchOne(db, sql: "SELECT COUNT(*) FROM t")!, 0)
        }
    }
    
    // MARK: - journalModeCache
    
    // Test for internals. Make sure the journalModeCache is not set too early,
    // especially not before user can choose the journal mode
    func testJournalModeCache() throws {
        do {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                XCTAssertNil(db.journalModeCache)
                try db.execute(sql: "PRAGMA journal_mode=truncate")
                try db.execute(sql: "CREATE TABLE t(a)")
                XCTAssertNil(db.journalModeCache)
            }
            dbQueue.suspend()
            dbQueue.inDatabase { db in
                XCTAssertNil(db.journalModeCache)
                try? db.execute(sql: "SELECT * FROM sqlite_master")
                XCTAssertEqual(db.journalModeCache, "truncate")
            }
        }
        do {
            var configuration = Configuration()
            configuration.prepareDatabase = { db in
                try db.execute(sql: "PRAGMA journal_mode=truncate")
            }
            let dbQueue = try makeDatabaseQueue(configuration: configuration)
            dbQueue.suspend()
            dbQueue.inDatabase { db in
                XCTAssertNil(db.journalModeCache)
                try? db.execute(sql: "SELECT * FROM sqlite_master")
                XCTAssertEqual(db.journalModeCache, "truncate")
            }
        }
        do {
            let dbPool = try makeDatabasePool()
            try dbPool.write { db in
                XCTAssertNil(db.journalModeCache)
                try db.execute(sql: "CREATE TABLE t(a)")
                XCTAssertNil(db.journalModeCache)
            }
            dbPool.suspend()
            try dbPool.writeWithoutTransaction { db in
                XCTAssertNil(db.journalModeCache)
                try db.execute(sql: "SELECT * FROM sqlite_master")
                XCTAssertEqual(db.journalModeCache, "wal")
            }
            try dbPool.write { db in
                XCTAssertEqual(db.journalModeCache, "wal")
            }
            try dbPool.read { db in
                XCTAssertNil(db.journalModeCache)
                try db.execute(sql: "SELECT * FROM sqlite_master")
                XCTAssertNil(db.journalModeCache)
            }
        }
    }
}
