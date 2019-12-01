import XCTest
#if GRDBCUSTOMSQLITE
import GRDBCustomSQLite
#else
import GRDB
#endif

class DatabaseAbortedTransactionTests : GRDBTestCase {
    
    func testReadTransactionAbortedByInterrupt() throws {
        func test(_ dbReader: DatabaseReader) throws {
            let semaphore1 = DispatchSemaphore(value: 0)
            let semaphore2 = DispatchSemaphore(value: 0)
            
            dbReader.add(function: DatabaseFunction("wait", argumentCount: 0, pure: true) { _ in
                semaphore1.signal()
                semaphore2.wait()
                return nil
            })
            let block1 = {
                do {
                    _ = try dbReader.read {
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
                dbReader.interrupt()
                semaphore2.signal()
            }
            let blocks = [block1, block2]
            DispatchQueue.concurrentPerform(iterations: blocks.count) { index in
                blocks[index]()
            }
        }
        
        try test(DatabaseQueue())
        try test(makeDatabaseQueue())
        try test(makeDatabasePool())
        try test(makeDatabasePool().makeSnapshot())
    }
    
    func testReadTransactionAbortedByInterruptDoesNotPreventFurtherRead() throws {
        func test(_ dbReader: DatabaseReader) throws {
            let semaphore1 = DispatchSemaphore(value: 0)
            let semaphore2 = DispatchSemaphore(value: 0)
            
            dbReader.add(function: DatabaseFunction("wait", argumentCount: 0, pure: true) { _ in
                semaphore1.signal()
                semaphore2.wait()
                return nil
            })
            let block1 = {
                try! dbReader.read { db in
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
                    try XCTAssertTrue(Bool.fetchOne(db, sql: "SELECT 1")!)
                }
            }
            let block2 = {
                semaphore1.wait()
                dbReader.interrupt()
                semaphore2.signal()
            }
            let blocks = [block1, block2]
            DispatchQueue.concurrentPerform(iterations: blocks.count) { index in
                blocks[index]()
            }
        }
        
        try test(DatabaseQueue())
        try test(makeDatabaseQueue())
        try test(makeDatabasePool())
        try test(makeDatabasePool().makeSnapshot())
    }
    
    func testWriteTransactionAbortedByInterrupt() throws {
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
                dbWriter.interrupt()
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
    
    func testWriteTransactionAbortedByInterruptPreventsFurtherDatabaseAccess() throws {
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
                            XCTAssertEqual(error.message, "Transaction was aborted")
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
                dbWriter.interrupt()
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
    
    func testWriteTransactionAbortedByInterruptDoesNotPreventRollback() throws {
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
                dbWriter.interrupt()
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
    
    func testTransactionAbortedByConflictPreventsFurtherDatabaseAccess() throws {
        func setup<T: DatabaseWriter>(_ dbWriter: T) throws -> T {
            try dbWriter.write { db in
                try db.execute(sql: """
                    CREATE TABLE t(a UNIQUE ON CONFLICT ROLLBACK);
                    """)
            }
            return dbWriter
        }
        func test(_ dbWriter: DatabaseWriter) throws {
            do {
                try dbWriter.write { db in
                    do {
                        try db.execute(sql: """
                            INSERT INTO t (a) VALUES (1);
                            INSERT INTO t (a) VALUES (1);
                            """)
                        XCTFail("Expected error")
                    } catch let error as DatabaseError {
                        XCTAssertEqual(error.resultCode, .SQLITE_CONSTRAINT)
                        XCTAssertEqual(error.message, "UNIQUE constraint failed: t.a")
                        XCTAssertEqual(error.sql, "INSERT INTO t (a) VALUES (1)")
                    } catch {
                        XCTFail("Unexpected error: \(error)")
                    }
                    
                    XCTAssertFalse(db.isInsideTransaction)
                    
                    try db.execute(sql: "INSERT INTO t (a) VALUES (2)")
                }
                XCTFail("Expected error")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_ABORT)
                XCTAssertEqual(error.message, "Transaction was aborted")
                XCTAssertEqual(error.sql, "INSERT INTO t (a) VALUES (2)")
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
        }
        
        try test(setup(DatabaseQueue()))
        try test(setup(makeDatabaseQueue()))
        try test(setup(makeDatabasePool()))
    }
    
    func testTransactionAbortedByUser() throws {
        func setup<T: DatabaseWriter>(_ dbWriter: T) throws -> T {
            try dbWriter.write { db in
                try db.execute(sql: "CREATE TABLE t(a);")
            }
            return dbWriter
        }
        func test(_ dbReader: DatabaseReader) throws {
            do {
                try dbReader.unsafeRead { db in
                    try db.inTransaction {
                        try db.execute(sql: """
                            SELECT * FROM t;
                            ROLLBACK;
                            SELECT * FROM t;
                            """)
                        return .commit
                    }
                }
                XCTFail("Expected error")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_ABORT)
                XCTAssertEqual(error.message, "Transaction was aborted")
                XCTAssertEqual(error.sql, "SELECT * FROM t")
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
        }
        
        try test(setup(DatabaseQueue()))
        try test(setup(makeDatabaseQueue()))
        try test(setup(makeDatabasePool()))
    }
    
    func testReadTransactionRestartHack() throws {
        // Here we test that the "ROLLBACK; BEGIN TRANSACTION;" hack which
        // "refreshes" a DatabaseSnaphot works.
        // See https://github.com/groue/GRDB.swift/issues/619
        // This hack puts temporarily the transaction in the aborded
        // state. Here we test that we don't throw SQLITE_ABORT.
        
        let dbPool = try makeDatabasePool()
        try dbPool.write { db in
            try db.execute(sql: "CREATE TABLE t(a);")
        }
        let snapshot = try dbPool.makeSnapshot()
        try snapshot.read { db in
            try db.execute(sql: """
                ROLLBACK;
                BEGIN TRANSACTION;
                """)
        }
        try snapshot.read { db in
            try db.execute(sql: """
                SELECT * FROM t;
                ROLLBACK;
                BEGIN TRANSACTION;
                SELECT * FROM t;
                """)
        }
    }
}
