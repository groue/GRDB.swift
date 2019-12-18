import XCTest
import Dispatch
import Foundation
#if GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class DatabasePoolConcurrencyTests: GRDBTestCase {
    
    func testDatabasePoolFundamental1() throws {
        // Constraint: the sum of values, the balance, must remain zero.
        //
        // This test shows (if needed) that writes that are not wrapped in a
        // transaction can not provide our guarantee, and that deferred
        // transaction provide the immutable view of the database needed by
        // dbPool.read().
        //
        // Reader                                   Writer
        // BEGIN DEFERRED TRANSACTION
        let s1 = DispatchSemaphore(value: 0)
        //                                          INSERT INTO moves VALUES (1)
        let s2 = DispatchSemaphore(value: 0)
        // SELECT SUM(value) AS balance FROM moves
        let s3 = DispatchSemaphore(value: 0)
        //                                          INSERT INTO moves VALUES (-1)
        let s4 = DispatchSemaphore(value: 0)
        // SELECT SUM(value) AS balance FROM moves
        // END
        
        do {
            let dbQueue = try makeDatabaseQueue(filename: "test.sqlite")
            try dbQueue.writeWithoutTransaction { db in
                let journalMode = try String.fetchOne(db, sql: "PRAGMA journal_mode = wal")
                XCTAssertEqual(journalMode, "wal")
                try db.create(table: "moves") { $0.column("value", .integer) }
                try db.execute(sql: "INSERT INTO moves VALUES (0)")
            }
        }
        let s0 = DispatchSemaphore(value: 0)
        let block1 = { () in
            let dbQueue = try! self.makeDatabaseQueue(filename: "test.sqlite")
            s0.signal() // Avoid "database is locked" error: don't open the two databases at the same time
            try! dbQueue.writeWithoutTransaction { db in
                try db.execute(sql: "BEGIN DEFERRED TRANSACTION")
                s1.signal()
                _ = s2.wait(timeout: .distantFuture)
                XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT SUM(value) AS balance FROM moves"), 1)  // Non-zero balance
                s3.signal()
                _ = s4.wait(timeout: .distantFuture)
                XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT SUM(value) AS balance FROM moves"), 1)  // Non-zero balance
                try db.execute(sql: "END")
            }
        }
        let block2 = { () in
            _ = s0.wait(timeout: .distantFuture) // Avoid "database is locked" error: don't open the two databases at the same time
            let dbQueue = try! self.makeDatabaseQueue(filename: "test.sqlite")
            try! dbQueue.writeWithoutTransaction { db in
                _ = s1.wait(timeout: .distantFuture)
                try db.execute(sql: "INSERT INTO moves VALUES (1)")
                s2.signal()
                _ = s3.wait(timeout: .distantFuture)
                try db.execute(sql: "INSERT INTO moves VALUES (-1)")
                s4.signal()
            }
        }
        let blocks = [block1, block2]
        DispatchQueue.concurrentPerform(iterations: blocks.count) { index in
            blocks[index]()
        }
    }
    
    func testDatabasePoolFundamental2() throws {
        // Constraint: the sum of values, the balance, must remain zero.
        //
        // This test shows that deferred transactions play well with concurrent
        // immediate transactions.
        //
        // Reader                                   Writer
        //                                          BEGIN IMMEDIATE TRANSACTION
        let s1 = DispatchSemaphore(value: 0)
        // BEGIN DEFERRED TRANSACTION
        let s2 = DispatchSemaphore(value: 0)
        //                                          INSERT INTO moves VALUES (1)
        let s3 = DispatchSemaphore(value: 0)
        // SELECT SUM(value) AS balance FROM moves
        let s4 = DispatchSemaphore(value: 0)
        //                                          INSERT INTO moves VALUES (-1)
        let s5 = DispatchSemaphore(value: 0)
        // SELECT SUM(value) AS balance FROM moves
        // END                                      END
        
        do {
            let dbQueue = try makeDatabaseQueue(filename: "test.sqlite")
            try dbQueue.writeWithoutTransaction { db in
                let journalMode = try String.fetchOne(db, sql: "PRAGMA journal_mode = wal")
                XCTAssertEqual(journalMode, "wal")
                try db.create(table: "moves") { $0.column("value", .integer) }
                try db.execute(sql: "INSERT INTO moves VALUES (0)")
            }
        }
        let s0 = DispatchSemaphore(value: 0)
        let block1 = { () in
            let dbQueue = try! self.makeDatabaseQueue(filename: "test.sqlite")
            s0.signal() // Avoid "database is locked" error: don't open the two databases at the same time
            try! dbQueue.writeWithoutTransaction { db in
                _ = s1.wait(timeout: .distantFuture)
                try db.execute(sql: "BEGIN DEFERRED TRANSACTION")
                s2.signal()
                _ = s3.wait(timeout: .distantFuture)
                XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT SUM(value) AS balance FROM moves"), 0)  // Zero balance
                s4.signal()
                _ = s5.wait(timeout: .distantFuture)
                XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT SUM(value) AS balance FROM moves"), 0)  // Zero balance
                try db.execute(sql: "END")
            }
        }
        let block2 = { () in
            _ = s0.wait(timeout: .distantFuture) // Avoid "database is locked" error: don't open the two databases at the same time
            let dbQueue = try! self.makeDatabaseQueue(filename: "test.sqlite")
            try! dbQueue.writeWithoutTransaction { db in
                try db.execute(sql: "BEGIN DEFERRED TRANSACTION")
                s1.signal()
                _ = s2.wait(timeout: .distantFuture)
                try db.execute(sql: "INSERT INTO moves VALUES (1)")
                s3.signal()
                _ = s4.wait(timeout: .distantFuture)
                try db.execute(sql: "INSERT INTO moves VALUES (-1)")
                s5.signal()
                try db.execute(sql: "END")
            }
        }
        let blocks = [block1, block2]
        DispatchQueue.concurrentPerform(iterations: blocks.count) { index in
            blocks[index]()
        }
    }
    
    func testDatabasePoolFundamental3() throws {
        // Constraint: the sum of values, the balance, must remain zero.
        //
        // This test shows that deferred transactions play well with concurrent
        // immediate transactions.
        //
        // Reader                                   Writer
        // BEGIN DEFERRED TRANSACTION
        let s1 = DispatchSemaphore(value: 0)
        //                                          BEGIN IMMEDIATE TRANSACTION
        //                                          INSERT INTO moves VALUES (1)
        let s2 = DispatchSemaphore(value: 0)
        // SELECT SUM(value) AS balance FROM moves
        let s3 = DispatchSemaphore(value: 0)
        //                                          INSERT INTO moves VALUES (-1)
        let s4 = DispatchSemaphore(value: 0)
        // SELECT SUM(value) AS balance FROM moves  END
        // END
        
        do {
            let dbQueue = try makeDatabaseQueue(filename: "test.sqlite")
            try dbQueue.writeWithoutTransaction { db in
                let journalMode = try String.fetchOne(db, sql: "PRAGMA journal_mode = wal")
                XCTAssertEqual(journalMode, "wal")
                try db.create(table: "moves") { $0.column("value", .integer) }
                try db.execute(sql: "INSERT INTO moves VALUES (0)")
            }
        }
        let s0 = DispatchSemaphore(value: 0)
        let block1 = { () in
            let dbQueue = try! self.makeDatabaseQueue(filename: "test.sqlite")
            s0.signal() // Avoid "database is locked" error: don't open the two databases at the same time
            try! dbQueue.writeWithoutTransaction { db in
                try db.execute(sql: "BEGIN DEFERRED TRANSACTION")
                s1.signal()
                _ = s2.wait(timeout: .distantFuture)
                XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT SUM(value) AS balance FROM moves"), 0)  // Zero balance
                s3.signal()
                _ = s4.wait(timeout: .distantFuture)
                XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT SUM(value) AS balance FROM moves"), 0)  // Zero balance
                try db.execute(sql: "END")
            }
        }
        let block2 = { () in
            _ = s0.wait(timeout: .distantFuture) // Avoid "database is locked" error: don't open the two databases at the same time
            let dbQueue = try! self.makeDatabaseQueue(filename: "test.sqlite")
            try! dbQueue.writeWithoutTransaction { db in
                _ = s1.wait(timeout: .distantFuture)
                try db.execute(sql: "BEGIN DEFERRED TRANSACTION")
                try db.execute(sql: "INSERT INTO moves VALUES (1)")
                s2.signal()
                _ = s3.wait(timeout: .distantFuture)
                try db.execute(sql: "INSERT INTO moves VALUES (-1)")
                s4.signal()
                try db.execute(sql: "END")
            }
        }
        let blocks = [block1, block2]
        DispatchQueue.concurrentPerform(iterations: blocks.count) { index in
            blocks[index]()
        }
    }
    
    func testWrappedReadWrite() throws {
        let dbPool = try makeDatabasePool()
        try dbPool.write { db in
            try db.execute(sql: "CREATE TABLE items (id INTEGER PRIMARY KEY)")
            try db.execute(sql: "INSERT INTO items (id) VALUES (NULL)")
        }
        let id = try dbPool.read { db in
            try Int.fetchOne(db, sql: "SELECT id FROM items")!
        }
        XCTAssertEqual(id, 1)
    }
    
    func testReadFromPreviousNonWALDatabase() throws {
        do {
            let dbQueue = try makeDatabaseQueue(filename: "test.sqlite")
            try dbQueue.writeWithoutTransaction { db in
                try db.execute(sql: "CREATE TABLE items (id INTEGER PRIMARY KEY)")
                try db.execute(sql: "INSERT INTO items (id) VALUES (NULL)")
            }
        }
        do {
            let dbPool = try makeDatabasePool(filename: "test.sqlite")
            let id = try dbPool.read { db in
                try Int.fetchOne(db, sql: "SELECT id FROM items")!
            }
            XCTAssertEqual(id, 1)
        }
    }
    
    func testWriteOpensATransaction() throws {
        let dbPool = try makeDatabasePool()
        try dbPool.write { db in
            XCTAssertTrue(db.isInsideTransaction)
            do {
                try db.execute(sql: "BEGIN DEFERRED TRANSACTION")
                XCTFail("Expected error")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
                XCTAssertEqual(error.message!, "cannot start a transaction within a transaction")
                XCTAssertEqual(error.sql!, "BEGIN DEFERRED TRANSACTION")
                XCTAssertEqual(error.description, "SQLite error 1 with statement `BEGIN DEFERRED TRANSACTION`: cannot start a transaction within a transaction")
            }
        }
    }
    
    func testWriteWithoutTransactionDoesNotOpenATransaction() throws {
        let dbPool = try makeDatabasePool()
        try dbPool.writeWithoutTransaction { db in
            XCTAssertFalse(db.isInsideTransaction)
            try db.beginTransaction()
            try db.commit()
        }
    }
    
    func testReadOpensATransaction() throws {
        let dbPool = try makeDatabasePool()
        try dbPool.read { db in
            XCTAssertTrue(db.isInsideTransaction)
            do {
                try db.execute(sql: "BEGIN DEFERRED TRANSACTION")
                XCTFail("Expected error")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
                XCTAssertEqual(error.message!, "cannot start a transaction within a transaction")
                XCTAssertEqual(error.sql!, "BEGIN DEFERRED TRANSACTION")
                XCTAssertEqual(error.description, "SQLite error 1 with statement `BEGIN DEFERRED TRANSACTION`: cannot start a transaction within a transaction")
            }
        }
    }
    
    func testReadError() throws {
        let dbPool = try makeDatabasePool()
        
        // Block 1                          Block 2
        // PRAGMA locking_mode=EXCLUSIVE
        // CREATE TABLE
        // >
        let s1 = DispatchSemaphore(value: 0)
        //                                  dbPool.read // throws
        
        let block1 = { () in
            try! dbPool.writeWithoutTransaction { db in
                try db.execute(sql: "PRAGMA locking_mode=EXCLUSIVE")
                try db.execute(sql: "CREATE TABLE items (id INTEGER PRIMARY KEY)")
                s1.signal()
            }
        }
        let block2 = { () in
            _ = s1.wait(timeout: .distantFuture)
            do {
                try dbPool.read { _ in }
                XCTFail("Expected error")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_BUSY)
                XCTAssertEqual(error.message!, "database is locked")
            } catch {
                XCTFail("Expected DatabaseError")
            }
        }
        let blocks = [block1, block2]
        DispatchQueue.concurrentPerform(iterations: blocks.count) { index in
            blocks[index]()
        }
    }
    
    func testConcurrentRead() throws {
        let dbPool = try makeDatabasePool()
        try dbPool.write { db in
            try db.execute(sql: "CREATE TABLE items (id INTEGER PRIMARY KEY)")
            for _ in 0..<3 {
                try db.execute(sql: "INSERT INTO items (id) VALUES (NULL)")
            }
        }
        
        // Block 1                      Block 2
        // dbPool.read {                dbPool.read {
        // SELECT * FROM items          SELECT * FROM items
        // step                         step
        // >
        let s1 = DispatchSemaphore(value: 0)
        //                              step
        //                              <
        let s2 = DispatchSemaphore(value: 0)
        // step                         step
        // step                         end
        // end                          }
        // }
        
        let block1 = { () in
            try! dbPool.read { db in
                let cursor = try Row.fetchCursor(db, sql: "SELECT * FROM items")
                XCTAssertTrue(try cursor.next() != nil)
                s1.signal()
                _ = s2.wait(timeout: .distantFuture)
                XCTAssertTrue(try cursor.next() != nil)
                XCTAssertTrue(try cursor.next() != nil)
                XCTAssertTrue(try cursor.next() == nil)
            }
        }
        let block2 = { () in
            try! dbPool.read { db in
                let cursor = try Row.fetchCursor(db, sql: "SELECT * FROM items")
                XCTAssertTrue(try cursor.next() != nil)
                _ = s1.wait(timeout: .distantFuture)
                XCTAssertTrue(try cursor.next() != nil)
                s2.signal()
                XCTAssertTrue(try cursor.next() != nil)
                XCTAssertTrue(try cursor.next() == nil)
            }
        }
        let blocks = [block1, block2]
        DispatchQueue.concurrentPerform(iterations: blocks.count) { index in
            blocks[index]()
        }
    }
    
    func testReadMethodIsolationOfStatement() throws {
        let dbPool = try makeDatabasePool()
        try dbPool.write { db in
            try db.execute(sql: "CREATE TABLE items (id INTEGER PRIMARY KEY)")
            for _ in 0..<2 {
                try db.execute(sql: "INSERT INTO items (id) VALUES (NULL)")
            }
        }
        
        // Block 1                      Block 2
        // dbPool.read {
        // SELECT * FROM items
        // step
        // >
        let s1 = DispatchSemaphore(value: 0)
        //                              DELETE * FROM items
        //                              <
        let s2 = DispatchSemaphore(value: 0)
        // step
        // end
        // }
        
        let block1 = { () in
            try! dbPool.read { db in
                let cursor = try Row.fetchCursor(db, sql: "SELECT * FROM items")
                XCTAssertTrue(try cursor.next() != nil)
                s1.signal()
                _ = s2.wait(timeout: .distantFuture)
                XCTAssertTrue(try cursor.next() != nil)
                XCTAssertTrue(try cursor.next() == nil)
            }
        }
        let block2 = { () in
            do {
                _ = s1.wait(timeout: .distantFuture)
                defer { s2.signal() }
                try dbPool.writeWithoutTransaction { db in
                    try db.execute(sql: "DELETE FROM items")
                }
            } catch {
                XCTFail("error: \(error)")
            }
        }
        let blocks = [block1, block2]
        DispatchQueue.concurrentPerform(iterations: blocks.count) { index in
            blocks[index]()
        }
    }
    
    func testReadMethodIsolationOfStatementWithCheckpoint() throws {
        let dbPool = try makeDatabasePool()
        try dbPool.write { db in
            try db.execute(sql: "CREATE TABLE items (id INTEGER PRIMARY KEY)")
            for _ in 0..<2 {
                try db.execute(sql: "INSERT INTO items (id) VALUES (NULL)")
            }
        }
        
        // Block 1                      Block 2
        // dbPool.read {
        // SELECT * FROM items
        // step
        // >
        let s1 = DispatchSemaphore(value: 0)
        //                              DELETE * FROM items
        //                              Checkpoint
        //                              <
        let s2 = DispatchSemaphore(value: 0)
        // step
        // end
        // }
        
        let block1 = { () in
            try! dbPool.read { db in
                let cursor = try Row.fetchCursor(db, sql: "SELECT * FROM items")
                XCTAssertTrue(try cursor.next() != nil)
                s1.signal()
                _ = s2.wait(timeout: .distantFuture)
                XCTAssertTrue(try cursor.next() != nil)
                XCTAssertTrue(try cursor.next() == nil)
            }
        }
        let block2 = { () in
            do {
                _ = s1.wait(timeout: .distantFuture)
                defer { s2.signal() }
                try dbPool.writeWithoutTransaction { db in
                    try db.execute(sql: "DELETE FROM items")
                }
                try dbPool.checkpoint()
            } catch {
                XCTFail("error: \(error)")
            }
        }
        let blocks = [block1, block2]
        DispatchQueue.concurrentPerform(iterations: blocks.count) { index in
            blocks[index]()
        }
    }
    
    func testReadBlockIsolationStartingWithRead() throws {
        let dbPool = try makeDatabasePool()
        try dbPool.write { db in
            try db.execute(sql: "CREATE TABLE items (id INTEGER PRIMARY KEY)")
        }
        
        // Block 1                      Block 2
        // dbPool.read {
        // >
        let s1 = DispatchSemaphore(value: 0)
        //                              INSERT INTO items (id) VALUES (NULL)
        //                              <
        let s2 = DispatchSemaphore(value: 0)
        // SELECT COUNT(*) FROM items -> 0
        // >
        let s3 = DispatchSemaphore(value: 0)
        //                              INSERT INTO items (id) VALUES (NULL)
        //                              <
        let s4 = DispatchSemaphore(value: 0)
        // SELECT COUNT(*) FROM items -> 0
        // }
        
        let block1 = { () in
            try! dbPool.read { db in
                s1.signal()
                _ = s2.wait(timeout: .distantFuture)
                XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM items")!, 1)  // Not a bug. The writer did not start a transaction.
                s3.signal()
                _ = s4.wait(timeout: .distantFuture)
                XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM items")!, 1)
            }
        }
        let block2 = { () in
            do {
                _ = s1.wait(timeout: .distantFuture)
                try dbPool.writeWithoutTransaction { db in
                    try db.execute(sql: "INSERT INTO items (id) VALUES (NULL)")
                    s2.signal()
                    _ = s3.wait(timeout: .distantFuture)
                    try db.execute(sql: "INSERT INTO items (id) VALUES (NULL)")
                    s4.signal()
                }
            } catch {
                XCTFail("error: \(error)")
            }
        }
        let blocks = [block1, block2]
        DispatchQueue.concurrentPerform(iterations: blocks.count) { index in
            blocks[index]()
        }
    }
    
    func testReadBlockIsolationStartingWithSelect() throws {
        let dbPool = try makeDatabasePool()
        try dbPool.write { db in
            try db.execute(sql: "CREATE TABLE items (id INTEGER PRIMARY KEY)")
        }
        
        // Block 1                      Block 2
        // dbPool.read {
        // SELECT COUNT(*) FROM items -> 0
        // >
        let s1 = DispatchSemaphore(value: 0)
        //                              INSERT INTO items (id) VALUES (NULL)
        //                              Checkpoint
        //                              <
        let s2 = DispatchSemaphore(value: 0)
        // SELECT COUNT(*) FROM items -> 0
        // }
        
        let block1 = { () in
            try! dbPool.read { db in
                XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM items")!, 0)
                s1.signal()
                _ = s2.wait(timeout: .distantFuture)
                XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM items")!, 0)
            }
        }
        let block2 = { () in
            do {
                _ = s1.wait(timeout: .distantFuture)
                defer { s2.signal() }
                try dbPool.writeWithoutTransaction { db in
                    try db.execute(sql: "INSERT INTO items (id) VALUES (NULL)")
                }
                try dbPool.checkpoint()
            } catch {
                XCTFail("error: \(error)")
            }
        }
        let blocks = [block1, block2]
        DispatchQueue.concurrentPerform(iterations: blocks.count) { index in
            blocks[index]()
        }
    }
    
    func testReadBlockIsolationStartingWithWrite() throws {
        let dbPool = try makeDatabasePool()
        try dbPool.write { db in
            try db.execute(sql: "CREATE TABLE items (id INTEGER PRIMARY KEY)")
        }
        
        // Block 1                      Block 2
        // INSERT INTO items (id) VALUES (NULL)
        // >
        let s1 = DispatchSemaphore(value: 0)
        //                              dbPool.read {
        //                              SELECT COUNT(*) FROM items -> 1
        //                              <
        let s2 = DispatchSemaphore(value: 0)
        // INSERT INTO items (id) VALUES (NULL)
        // >
        let s3 = DispatchSemaphore(value: 0)
        //                              SELECT COUNT(*) FROM items -> 1
        //                              <
        let s4 = DispatchSemaphore(value: 0)
        // >
        let s5 = DispatchSemaphore(value: 0)
        //                              SELECT COUNT(*) FROM items -> 1
        //                              }
        
        let block1 = { () in
            do {
                try dbPool.writeWithoutTransaction { db in
                    try db.execute(sql: "INSERT INTO items (id) VALUES (NULL)")
                    s1.signal()
                    _ = s2.wait(timeout: .distantFuture)
                    try db.execute(sql: "INSERT INTO items (id) VALUES (NULL)")
                    s3.signal()
                    _ = s4.wait(timeout: .distantFuture)
                }
                s5.signal()
            } catch {
                XCTFail("error: \(error)")
            }
        }
        let block2 = { () in
            try! dbPool.read { db in
                _ = s1.wait(timeout: .distantFuture)
                XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM items")!, 1)
                s2.signal()
                _ = s3.wait(timeout: .distantFuture)
                XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM items")!, 1)
                s4.signal()
                _ = s5.wait(timeout: .distantFuture)
                XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM items")!, 1)
            }
        }
        let blocks = [block1, block2]
        DispatchQueue.concurrentPerform(iterations: blocks.count) { index in
            blocks[index]()
        }
    }
    
    func testReadBlockIsolationStartingWithWriteTransaction() throws {
        let dbPool = try makeDatabasePool()
        try dbPool.write { db in
            try db.execute(sql: "CREATE TABLE items (id INTEGER PRIMARY KEY)")
        }
        
        // Block 1                      Block 2
        // BEGIN IMMEDIATE TRANSACTION
        // INSERT INTO items (id) VALUES (NULL)
        // >
        let s1 = DispatchSemaphore(value: 0)
        //                              dbPool.read {
        //                              SELECT COUNT(*) FROM items -> 0
        //                              <
        let s2 = DispatchSemaphore(value: 0)
        // INSERT INTO items (id) VALUES (NULL)
        // >
        let s3 = DispatchSemaphore(value: 0)
        //                              SELECT COUNT(*) FROM items -> 0
        //                              <
        let s4 = DispatchSemaphore(value: 0)
        // COMMIT
        // >
        let s5 = DispatchSemaphore(value: 0)
        //                              SELECT COUNT(*) FROM items -> 0
        //                              }
        
        let block1 = { () in
            do {
                try dbPool.writeInTransaction(.immediate) { db in
                    try db.execute(sql: "INSERT INTO items (id) VALUES (NULL)")
                    s1.signal()
                    _ = s2.wait(timeout: .distantFuture)
                    try db.execute(sql: "INSERT INTO items (id) VALUES (NULL)")
                    s3.signal()
                    _ = s4.wait(timeout: .distantFuture)
                    return .commit
                }
                s5.signal()
            } catch {
                XCTFail("error: \(error)")
            }
        }
        let block2 = { () in
            try! dbPool.read { db in
                _ = s1.wait(timeout: .distantFuture)
                XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM items")!, 0)
                s2.signal()
                _ = s3.wait(timeout: .distantFuture)
                XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM items")!, 0)
                s4.signal()
                _ = s5.wait(timeout: .distantFuture)
                XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM items")!, 0)
            }
        }
        let blocks = [block1, block2]
        DispatchQueue.concurrentPerform(iterations: blocks.count) { index in
            blocks[index]()
        }
    }
    
    func testUnsafeReadMethodIsolationOfStatement() throws {
        let dbPool = try makeDatabasePool()
        try dbPool.write { db in
            try db.execute(sql: "CREATE TABLE items (id INTEGER PRIMARY KEY)")
            for _ in 0..<2 {
                try db.execute(sql: "INSERT INTO items (id) VALUES (NULL)")
            }
        }
        
        // Block 1                      Block 2
        // dbPool.unsafeRead {
        // SELECT * FROM items
        // step
        // >
        let s1 = DispatchSemaphore(value: 0)
        //                              DELETE * FROM items
        //                              <
        let s2 = DispatchSemaphore(value: 0)
        // step
        // end
        // SELECT COUNT(*) FROM items -> 0
        // }
        
        let block1 = { () in
            try! dbPool.unsafeRead { db in
                let cursor = try Row.fetchCursor(db, sql: "SELECT * FROM items")
                XCTAssertTrue(try cursor.next() != nil)
                s1.signal()
                _ = s2.wait(timeout: .distantFuture)
                XCTAssertTrue(try cursor.next() != nil)
                XCTAssertTrue(try cursor.next() == nil)
                XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM items")!, 0)
            }
        }
        let block2 = { () in
            do {
                _ = s1.wait(timeout: .distantFuture)
                defer { s2.signal() }
                try dbPool.writeWithoutTransaction { db in
                    try db.execute(sql: "DELETE FROM items")
                }
            } catch {
                XCTFail("error: \(error)")
            }
        }
        let blocks = [block1, block2]
        DispatchQueue.concurrentPerform(iterations: blocks.count) { index in
            blocks[index]()
        }
    }
    
    func testUnsafeReadMethodIsolationOfStatementWithCheckpoint() throws {
        let dbPool = try makeDatabasePool()
        try dbPool.write { db in
            try db.execute(sql: "CREATE TABLE items (id INTEGER PRIMARY KEY)")
            for _ in 0..<2 {
                try db.execute(sql: "INSERT INTO items (id) VALUES (NULL)")
            }
        }
        
        // Block 1                      Block 2
        // dbPool.unsafeRead {
        // SELECT * FROM items
        // step
        // >
        let s1 = DispatchSemaphore(value: 0)
        //                              DELETE * FROM items
        //                              Checkpoint
        //                              <
        let s2 = DispatchSemaphore(value: 0)
        // step
        // end
        // }
        
        let block1 = { () in
            try! dbPool.unsafeRead { db in
                let cursor = try Row.fetchCursor(db, sql: "SELECT * FROM items")
                XCTAssertTrue(try cursor.next() != nil)
                s1.signal()
                _ = s2.wait(timeout: .distantFuture)
                XCTAssertTrue(try cursor.next() != nil)
                XCTAssertTrue(try cursor.next() == nil)
            }
        }
        let block2 = { () in
            do {
                _ = s1.wait(timeout: .distantFuture)
                defer { s2.signal() }
                try dbPool.writeWithoutTransaction { db in
                    try db.execute(sql: "DELETE FROM items")
                }
                try dbPool.checkpoint()
            } catch {
                XCTFail("error: \(error)")
            }
        }
        let blocks = [block1, block2]
        DispatchQueue.concurrentPerform(iterations: blocks.count) { index in
            blocks[index]()
        }
    }
    
    func testUnsafeReadMethodIsolationOfBlock() throws {
        let dbPool = try makeDatabasePool()
        try dbPool.write { db in
            try db.execute(sql: "CREATE TABLE items (id INTEGER PRIMARY KEY)")
        }
        
        // Block 1                      Block 2
        // dbPool.unsafeRead {
        // SELECT COUNT(*) FROM items -> 0
        // >
        let s1 = DispatchSemaphore(value: 0)
        //                              INSERT INTO items (id) VALUES (NULL)
        //                              Checkpoint
        //                              <
        let s2 = DispatchSemaphore(value: 0)
        // SELECT COUNT(*) FROM items -> 1
        // }
        
        let block1 = { () in
            try! dbPool.unsafeRead { db in
                XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM items")!, 0)
                s1.signal()
                _ = s2.wait(timeout: .distantFuture)
                XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM items")!, 1)
            }
        }
        let block2 = { () in
            do {
                _ = s1.wait(timeout: .distantFuture)
                defer { s2.signal() }
                try dbPool.writeWithoutTransaction { db in
                    try db.execute(sql: "INSERT INTO items (id) VALUES (NULL)")
                }
                try dbPool.checkpoint()
            } catch {
                XCTFail("error: \(error)")
            }
        }
        let blocks = [block1, block2]
        DispatchQueue.concurrentPerform(iterations: blocks.count) { index in
            blocks[index]()
        }
    }
    
    func testLongRunningReadTransaction() throws {
        // A test for a "user-defined" DatabaseSnapshot based on DatabaseQueue
        let dbName = "test.sqlite"
        let dbPool = try makeDatabasePool(filename: dbName)
        dbConfiguration.allowsUnsafeTransactions = true
        dbConfiguration.readonly = true
        let dbQueue = try makeDatabaseQueue(filename: dbName)
        
        try dbPool.write { db in
            try db.create(table: "t") { $0.column("id", .integer).primaryKey() }
            try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
        }
        
        try dbQueue.writeWithoutTransaction { db in
            try db.beginTransaction(.deferred)
        }
        
        try dbQueue.writeWithoutTransaction { db in
            try XCTAssertEqual(Int.fetchOne(db, sql: "SELECT COUNT(*) FROM t")!, 1)
        }
        
        try dbPool.write { db in
            try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
        }
        
        try dbQueue.writeWithoutTransaction { db in
            try XCTAssertEqual(Int.fetchOne(db, sql: "SELECT COUNT(*) FROM t")!, 1)
            try db.rollback()
            try XCTAssertEqual(Int.fetchOne(db, sql: "SELECT COUNT(*) FROM t")!, 2)
        }
    }
    
    func testIssue80() throws {
        // See https://github.com/groue/GRDB.swift/issues/80
        //
        // Here we test that `SELECT * FROM search`, which is announced by
        // SQLite has a statement that modifies the sqlite_master table, is
        // still allowed as a regular select statement.
        //
        // This test uses a database pool, a connection for creating the
        // search virtual table, and another connection for reading.
        //
        // This is the tested setup: don't change it.
        
        let dbPool = try makeDatabasePool()
        try dbPool.write { db in
            try db.execute(sql: "CREATE VIRTUAL TABLE search USING fts3(title)")
        }
        try dbPool.read { db in
            _ = try Row.fetchAll(db, sql: "SELECT * FROM search")
        }
    }
    
    func testDefaultLabel() throws {
        let dbPool = try makeDatabasePool()
        dbPool.writeWithoutTransaction { db in
            XCTAssertEqual(db.configuration.label, nil)
            
            // This test CAN break in future releases: the dispatch queue labels
            // are documented to be a debug-only tool.
            let label = String(utf8String: __dispatch_queue_get_label(nil))
            XCTAssertEqual(label, "GRDB.DatabasePool.writer")
        }
        
        let s1 = DispatchSemaphore(value: 0)
        let s2 = DispatchSemaphore(value: 0)
        let block1 = { () in
            try! dbPool.read { db in
                XCTAssertEqual(db.configuration.label, nil)
                
                // This test CAN break in future releases: the dispatch queue labels
                // are documented to be a debug-only tool.
                let label = String(utf8String: __dispatch_queue_get_label(nil))
                XCTAssertEqual(label, "GRDB.DatabasePool.reader.1")
                
                _ = s1.signal()
                _ = s2.wait(timeout: .distantFuture)
            }
        }
        let block2 = { () in
            _ = s1.wait(timeout: .distantFuture)
            try! dbPool.read { db in
                _ = s2.signal()
                XCTAssertEqual(db.configuration.label, nil)
                
                // This test CAN break in future releases: the dispatch queue labels
                // are documented to be a debug-only tool.
                let label = String(utf8String: __dispatch_queue_get_label(nil))
                XCTAssertEqual(label, "GRDB.DatabasePool.reader.2")
            }
        }
        let blocks = [block1, block2]
        DispatchQueue.concurrentPerform(iterations: blocks.count) { index in
            blocks[index]()
        }
    }
    
    func testCustomLabel() throws {
        dbConfiguration.label = "Toreador"
        let dbPool = try makeDatabasePool()
        dbPool.writeWithoutTransaction { db in
            XCTAssertEqual(db.configuration.label, "Toreador")
            
            // This test CAN break in future releases: the dispatch queue labels
            // are documented to be a debug-only tool.
            let label = String(utf8String: __dispatch_queue_get_label(nil))
            XCTAssertEqual(label, "Toreador.writer")
        }
        
        let s1 = DispatchSemaphore(value: 0)
        let s2 = DispatchSemaphore(value: 0)
        let block1 = { () in
            try! dbPool.read { db in
                XCTAssertEqual(db.configuration.label, "Toreador")
                
                // This test CAN break in future releases: the dispatch queue labels
                // are documented to be a debug-only tool.
                let label = String(utf8String: __dispatch_queue_get_label(nil))
                XCTAssertEqual(label, "Toreador.reader.1")
                
                _ = s1.signal()
                _ = s2.wait(timeout: .distantFuture)
            }
        }
        let block2 = { () in
            _ = s1.wait(timeout: .distantFuture)
            try! dbPool.read { db in
                _ = s2.signal()
                XCTAssertEqual(db.configuration.label, "Toreador")
                
                // This test CAN break in future releases: the dispatch queue labels
                // are documented to be a debug-only tool.
                let label = String(utf8String: __dispatch_queue_get_label(nil))
                XCTAssertEqual(label, "Toreador.reader.2")
            }
        }
        let blocks = [block1, block2]
        DispatchQueue.concurrentPerform(iterations: blocks.count) { index in
            blocks[index]()
        }
    }
    
    func testTargetQueue() throws {
        // dispatchPrecondition(condition:) availability
        if #available(OSX 10.12, iOS 10.0, tvOS 10.0, *) {
            func test(targetQueue: DispatchQueue) throws {
                dbConfiguration.targetQueue = targetQueue
                let dbPool = try makeDatabasePool()
                try dbPool.write { _ in
                    dispatchPrecondition(condition: .onQueue(targetQueue))
                }
                try dbPool.read { _ in
                    dispatchPrecondition(condition: .onQueue(targetQueue))
                }
            }
            
            // background queue
            try test(targetQueue: .global(qos: .background))
            
            // main queue
            let expectation = self.expectation(description: "main")
            DispatchQueue.global(qos: .default).async {
                try! test(targetQueue: .main)
                expectation.fulfill()
            }
            waitForExpectations(timeout: 1, handler: nil)
        }
    }
    
    func testQoS() throws {
        // dispatchPrecondition(condition:) availability
        if #available(OSX 10.12, iOS 10.0, tvOS 10.0, *) {
            func test(qos: DispatchQoS) throws {
                // https://forums.swift.org/t/what-is-the-default-target-queue-for-a-serial-queue/18094/5
                //
                // > [...] the default target queue [for a serial queue] is the
                // > [default] overcommit [global concurrent] queue.
                //
                // We want this default target queue in order to test database QoS
                // with dispatchPrecondition(condition:).
                //
                // > [...] You can get a reference to the overcommit queue by
                // > dropping down to the C function dispatch_get_global_queue
                // > (available in Swift with a __ prefix) and passing the private
                // > value of DISPATCH_QUEUE_OVERCOMMIT.
                // >
                // > [...] Of course you should not do this in production code,
                // > because DISPATCH_QUEUE_OVERCOMMIT is not a public API. I don't
                // > know of a way to get a reference to the overcommit queue using
                // > only public APIs.
                let DISPATCH_QUEUE_OVERCOMMIT: UInt = 2
                let targetQueue = __dispatch_get_global_queue(
                    Int(qos.qosClass.rawValue.rawValue),
                    DISPATCH_QUEUE_OVERCOMMIT)
                
                dbConfiguration.qos = qos
                let dbPool = try makeDatabasePool()
                try dbPool.write { _ in
                    dispatchPrecondition(condition: .onQueue(targetQueue))
                }
                try dbPool.read { _ in
                    dispatchPrecondition(condition: .onQueue(targetQueue))
                }
            }
            
            try test(qos: .background)
            try test(qos: .userInitiated)
        }
    }
    
    // MARK: - ConcurrentRead
    
    func testConcurrentReadOpensATransaction() throws {
        let dbPool = try makeDatabasePool()
        let future = dbPool.writeWithoutTransaction { db in
            dbPool.concurrentRead { db in
                XCTAssertTrue(db.isInsideTransaction)
                do {
                    try db.execute(sql: "BEGIN DEFERRED TRANSACTION")
                    XCTFail("Expected error")
                } catch {
                }
            }
        }
        try future.wait()
    }
    
    func testConcurrentReadOutsideOfTransaction() throws {
        let dbPool = try makeDatabasePool()
        try dbPool.write { db in
            try db.create(table: "persons") { t in
                t.column("id", .integer).primaryKey()
            }
        }
        
        // Writer                       Reader
        // dbPool.writeWithoutTransaction {
        // >
        //                              dbPool.concurrentRead {
        //                              <
        // INSERT INTO items (id) VALUES (NULL)
        // >
        let s1 = DispatchSemaphore(value: 0)
        // }                            SELECT COUNT(*) FROM persons -> 0
        //                              <
        //                              }
        
        let future: DatabaseFuture<Int> = try dbPool.writeWithoutTransaction { db in
            let future: DatabaseFuture<Int> = dbPool.concurrentRead { db in
                _ = s1.wait(timeout: .distantFuture)
                return try! Int.fetchOne(db, sql: "SELECT COUNT(*) FROM persons")!
            }
            try db.execute(sql: "INSERT INTO persons DEFAULT VALUES")
            s1.signal()
            return future
        }
        XCTAssertEqual(try future.wait(), 0)
    }
    
    func testConcurrentReadError() throws {
        let dbPool = try makeDatabasePool()
        try dbPool.writeWithoutTransaction { db in
            try db.execute(sql: "PRAGMA locking_mode=EXCLUSIVE")
            try db.execute(sql: "CREATE TABLE items (id INTEGER PRIMARY KEY)")
            let future = dbPool.concurrentRead { db in
                fatalError("Should not run")
            }
            do {
                try future.wait()
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_BUSY)
                XCTAssertEqual(error.message!, "database is locked")
            }
        }
    }
    
    // MARK: - AsyncConcurrentRead
    
    #if compiler(>=5.0)
    func testAsyncConcurrentReadOpensATransaction() throws {
        let dbPool = try makeDatabasePool()
        var isInsideTransaction: Bool? = nil
        let expectation = self.expectation(description: "read")
        dbPool.writeWithoutTransaction { db in
            dbPool.asyncConcurrentRead { result in
                do {
                    let db = try result.get()
                    isInsideTransaction = db.isInsideTransaction
                    do {
                        try db.execute(sql: "BEGIN DEFERRED TRANSACTION")
                        XCTFail("Expected error")
                    } catch {
                    }
                } catch {
                    XCTFail("Unexpected error: \(error)")
                }
                expectation.fulfill()
            }
        }
        waitForExpectations(timeout: 1, handler: nil)
        XCTAssertEqual(isInsideTransaction, true)
    }
    #endif
    
    #if compiler(>=5.0)
    func testAsyncConcurrentReadOutsideOfTransaction() throws {
        let dbPool = try makeDatabasePool()
        try dbPool.write { db in
            try db.create(table: "persons") { t in
                t.column("id", .integer).primaryKey()
            }
        }
        
        // Writer                       Reader
        // dbPool.writeWithoutTransaction {
        // >
        //                              dbPool.concurrentRead {
        //                              <
        // INSERT INTO items (id) VALUES (NULL)
        // >
        let s1 = DispatchSemaphore(value: 0)
        // }                            SELECT COUNT(*) FROM persons -> 0
        //                              <
        //                              }
        
        var count: Int? = nil
        let expectation = self.expectation(description: "read")
        try dbPool.writeWithoutTransaction { db in
            dbPool.asyncConcurrentRead { result in
                do {
                    _ = s1.wait(timeout: .distantFuture)
                    let db = try result.get()
                    count = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM persons")!
                } catch {
                    XCTFail("Unexpected error: \(error)")
                }
                expectation.fulfill()
            }
            try db.execute(sql: "INSERT INTO persons DEFAULT VALUES")
            s1.signal()
        }
        waitForExpectations(timeout: 1, handler: nil)
        XCTAssertEqual(count, 0)
    }
    #endif
    
    #if compiler(>=5.0)
    func testAsyncConcurrentReadError() throws {
        let dbPool = try makeDatabasePool()
        var readError: DatabaseError? = nil
        let expectation = self.expectation(description: "read")
        try dbPool.writeWithoutTransaction { db in
            try db.execute(sql: "PRAGMA locking_mode=EXCLUSIVE")
            try db.execute(sql: "CREATE TABLE items (id INTEGER PRIMARY KEY)")
            dbPool.asyncConcurrentRead { result in
                guard case let .failure(error) = result,
                    let dbError = error as? DatabaseError
                    else {
                        XCTFail("Unexpected result: \(result)")
                        return
                }
                readError = dbError
                expectation.fulfill()
            }
            waitForExpectations(timeout: 1, handler: nil)
            XCTAssertEqual(readError!.resultCode, .SQLITE_BUSY)
            XCTAssertEqual(readError!.message!, "database is locked")
        }
    }
    #endif
    
    // MARK: - Barrier
    
    func testBarrierLocksReads() throws {
        if #available(OSX 10.10, *) {
            let expectation = self.expectation(description: "lock")
            expectation.isInverted = true
            
            let dbPool = try makeDatabasePool()
            try dbPool.write { db in
                try db.execute(sql: "CREATE TABLE items (id INTEGER PRIMARY KEY)")
            }
            var fetchedValue: Int?
            let s1 = DispatchSemaphore(value: 0)
            let s2 = DispatchSemaphore(value: 0)
            let s3 = DispatchSemaphore(value: 0)
            
            DispatchQueue.global().async {
                try! dbPool.barrierWriteWithoutTransaction { db in
                    try db.execute(sql: "INSERT INTO items (id) VALUES (NULL)")
                    s1.signal()
                    s2.wait()
                }
            }
            
            DispatchQueue.global().async {
                // Wait for barrier to start
                s1.wait()
                
                fetchedValue = try! dbPool.read { db in
                    try Int.fetchOne(db, sql: "SELECT id FROM items")!
                }
                expectation.fulfill()
                s3.signal()
            }
            
            // Assert that read is blocked
            waitForExpectations(timeout: 1)
            
            // Release barrier
            s2.signal()
            
            // Wait for read to complete
            s3.wait()
            XCTAssertEqual(fetchedValue, 1)
        }
    }
    
    func testBarrierIsLockedByOneUnfinishedRead() throws {
        if #available(OSX 10.10, *) {
            let expectation = self.expectation(description: "lock")
            expectation.isInverted = true
            
            let dbPool = try makeDatabasePool()
            try dbPool.write { db in
                try db.execute(sql: "CREATE TABLE items (id INTEGER PRIMARY KEY)")
            }
            
            let s1 = DispatchSemaphore(value: 0)
            let s2 = DispatchSemaphore(value: 0)
            let s3 = DispatchSemaphore(value: 0)
            let s4 = DispatchSemaphore(value: 0)
            
            DispatchQueue.global().async {
                try! dbPool.read { _ in
                    s1.signal()
                    s2.signal()
                    s3.wait()
                }
            }
            
            DispatchQueue.global().async {
                // Wait for read to start
                s1.wait()

                dbPool.barrierWriteWithoutTransaction { _ in }
                expectation.fulfill()
                s4.signal()
            }
            
            // Assert that barrier is blocked
            waitForExpectations(timeout: 1)
            
            // Release read
            s3.signal()
            
            // Wait for barrier to complete
            s4.wait()
        }
    }
    
    // MARK: - Concurrent opening
    
    func testConcurrentOpening() throws {
        for _ in 0..<50 {
            let dbDirectoryName = "DatabasePoolConcurrencyTests-\(ProcessInfo.processInfo.globallyUniqueString)"
            let directoryURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
                .appendingPathComponent(dbDirectoryName, isDirectory: true)
            let dbURL = directoryURL.appendingPathComponent("db.sqlite")
            try FileManager.default.createDirectory(atPath: directoryURL.path, withIntermediateDirectories: true, attributes: nil)
            defer { try! FileManager.default.removeItem(at: directoryURL) }
            DispatchQueue.concurrentPerform(iterations: 10) { n in
                // WTF I could never Google for the proper correct error handling
                // of NSFileCoordinator. What a weird API.
                let coordinator = NSFileCoordinator(filePresenter: nil)
                var coordinatorError: NSError?
                var poolError: Error?
                coordinator.coordinate(writingItemAt: dbURL, options: .forMerging, error: &coordinatorError, byAccessor: { url in
                    do {
                        _ = try DatabasePool(path: url.path)
                    } catch {
                        poolError = error
                    }
                })
                XCTAssert(poolError ?? coordinatorError == nil)
            }
        }
    }
    
    // MARK: - NSFileCoordinator sample code tests
    
    // Test for sample code in Documentation/AppGroupContainers.md.
    // This test passes if this method compiles
    private func openSharedDatabase(at databaseURL: URL) throws -> DatabasePool {
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinatorError: NSError?
        var dbPool: DatabasePool?
        var dbError: Error?
        coordinator.coordinate(writingItemAt: databaseURL, options: .forMerging, error: &coordinatorError, byAccessor: { url in
            do {
                dbPool = try openDatabase(at: url)
            } catch {
                dbError = error
            }
        })
        if let error = dbError ?? coordinatorError {
            throw error
        }
        return dbPool!
    }

    // Test for sample code in Documentation/AppGroupContainers.md.
    // This test passes if this method compiles
    private func openDatabase(at databaseURL: URL) throws -> DatabasePool {
        let dbPool = try DatabasePool(path: databaseURL.path)
        // Perform here other database setups, such as defining
        // the database schema with a DatabaseMigrator.
        return dbPool
    }
    
    // Test for sample code in Documentation/AppGroupContainers.md.
    // This test passes if this method compiles
    private func openSharedReadOnlyDatabase(at databaseURL: URL) throws -> DatabasePool? {
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinatorError: NSError?
        var dbPool: DatabasePool?
        var dbError: Error?
        coordinator.coordinate(readingItemAt: databaseURL, options: .withoutChanges, error: &coordinatorError, byAccessor: { url in
            do {
                dbPool = try openReadOnlyDatabase(at: url)
            } catch {
                dbError = error
            }
        })
        if let error = dbError ?? coordinatorError {
            throw error
        }
        return dbPool
    }

    // Test for sample code in Documentation/AppGroupContainers.md.
    // This test passes if this method compiles
    private func openReadOnlyDatabase(at databaseURL: URL) throws -> DatabasePool? {
        do {
            var configuration = Configuration()
            configuration.readonly = true
            return try DatabasePool(path: databaseURL.path, configuration: configuration)
        } catch {
            if FileManager.default.fileExists(atPath: databaseURL.path) {
                // Something went wrong
                throw error
            } else {
                // Database file does not exist
                return nil
            }
        }
    }
}
