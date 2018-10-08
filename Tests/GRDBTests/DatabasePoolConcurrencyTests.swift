import XCTest
#if GRDBCIPHER
    import GRDBCipher
#elseif GRDBCUSTOMSQLITE
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
                let journalMode = try String.fetchOne(db, "PRAGMA journal_mode = wal")
                XCTAssertEqual(journalMode, "wal")
                try db.create(table: "moves") { $0.column("value", .integer) }
                try db.execute("INSERT INTO moves VALUES (0)")
            }
        }
        let s0 = DispatchSemaphore(value: 0)
        let block1 = { () in
            let dbQueue = try! self.makeDatabaseQueue(filename: "test.sqlite")
            s0.signal() // Avoid "database is locked" error: don't open the two databases at the same time
            try! dbQueue.writeWithoutTransaction { db in
                try db.execute("BEGIN DEFERRED TRANSACTION")
                s1.signal()
                _ = s2.wait(timeout: .distantFuture)
                XCTAssertEqual(try Int.fetchOne(db, "SELECT SUM(value) AS balance FROM moves"), 1)  // Non-zero balance
                s3.signal()
                _ = s4.wait(timeout: .distantFuture)
                XCTAssertEqual(try Int.fetchOne(db, "SELECT SUM(value) AS balance FROM moves"), 1)  // Non-zero balance
                try db.execute("END")
            }
        }
        let block2 = { () in
            _ = s0.wait(timeout: .distantFuture) // Avoid "database is locked" error: don't open the two databases at the same time
            let dbQueue = try! self.makeDatabaseQueue(filename: "test.sqlite")
            try! dbQueue.writeWithoutTransaction { db in
                _ = s1.wait(timeout: .distantFuture)
                try db.execute("INSERT INTO moves VALUES (1)")
                s2.signal()
                _ = s3.wait(timeout: .distantFuture)
                try db.execute("INSERT INTO moves VALUES (-1)")
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
                let journalMode = try String.fetchOne(db, "PRAGMA journal_mode = wal")
                XCTAssertEqual(journalMode, "wal")
                try db.create(table: "moves") { $0.column("value", .integer) }
                try db.execute("INSERT INTO moves VALUES (0)")
            }
        }
        let s0 = DispatchSemaphore(value: 0)
        let block1 = { () in
            let dbQueue = try! self.makeDatabaseQueue(filename: "test.sqlite")
            s0.signal() // Avoid "database is locked" error: don't open the two databases at the same time
            try! dbQueue.writeWithoutTransaction { db in
                _ = s1.wait(timeout: .distantFuture)
                try db.execute("BEGIN DEFERRED TRANSACTION")
                s2.signal()
                _ = s3.wait(timeout: .distantFuture)
                XCTAssertEqual(try Int.fetchOne(db, "SELECT SUM(value) AS balance FROM moves"), 0)  // Zero balance
                s4.signal()
                _ = s5.wait(timeout: .distantFuture)
                XCTAssertEqual(try Int.fetchOne(db, "SELECT SUM(value) AS balance FROM moves"), 0)  // Zero balance
                try db.execute("END")
            }
        }
        let block2 = { () in
            _ = s0.wait(timeout: .distantFuture) // Avoid "database is locked" error: don't open the two databases at the same time
            let dbQueue = try! self.makeDatabaseQueue(filename: "test.sqlite")
            try! dbQueue.writeWithoutTransaction { db in
                try db.execute("BEGIN DEFERRED TRANSACTION")
                s1.signal()
                _ = s2.wait(timeout: .distantFuture)
                try db.execute("INSERT INTO moves VALUES (1)")
                s3.signal()
                _ = s4.wait(timeout: .distantFuture)
                try db.execute("INSERT INTO moves VALUES (-1)")
                s5.signal()
                try db.execute("END")
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
                let journalMode = try String.fetchOne(db, "PRAGMA journal_mode = wal")
                XCTAssertEqual(journalMode, "wal")
                try db.create(table: "moves") { $0.column("value", .integer) }
                try db.execute("INSERT INTO moves VALUES (0)")
            }
        }
        let s0 = DispatchSemaphore(value: 0)
        let block1 = { () in
            let dbQueue = try! self.makeDatabaseQueue(filename: "test.sqlite")
            s0.signal() // Avoid "database is locked" error: don't open the two databases at the same time
            try! dbQueue.writeWithoutTransaction { db in
                try db.execute("BEGIN DEFERRED TRANSACTION")
                s1.signal()
                _ = s2.wait(timeout: .distantFuture)
                XCTAssertEqual(try Int.fetchOne(db, "SELECT SUM(value) AS balance FROM moves"), 0)  // Zero balance
                s3.signal()
                _ = s4.wait(timeout: .distantFuture)
                XCTAssertEqual(try Int.fetchOne(db, "SELECT SUM(value) AS balance FROM moves"), 0)  // Zero balance
                try db.execute("END")
            }
        }
        let block2 = { () in
            _ = s0.wait(timeout: .distantFuture) // Avoid "database is locked" error: don't open the two databases at the same time
            let dbQueue = try! self.makeDatabaseQueue(filename: "test.sqlite")
            try! dbQueue.writeWithoutTransaction { db in
                _ = s1.wait(timeout: .distantFuture)
                try db.execute("BEGIN DEFERRED TRANSACTION")
                try db.execute("INSERT INTO moves VALUES (1)")
                s2.signal()
                _ = s3.wait(timeout: .distantFuture)
                try db.execute("INSERT INTO moves VALUES (-1)")
                s4.signal()
                try db.execute("END")
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
            try db.execute("CREATE TABLE items (id INTEGER PRIMARY KEY)")
            try db.execute("INSERT INTO items (id) VALUES (NULL)")
        }
        let id = try dbPool.read { db in
            try Int.fetchOne(db, "SELECT id FROM items")!
        }
        XCTAssertEqual(id, 1)
    }

    func testReadFromPreviousNonWALDatabase() throws {
        do {
            let dbQueue = try makeDatabaseQueue(filename: "test.sqlite")
            try dbQueue.writeWithoutTransaction { db in
                try db.execute("CREATE TABLE items (id INTEGER PRIMARY KEY)")
                try db.execute("INSERT INTO items (id) VALUES (NULL)")
            }
        }
        do {
            let dbPool = try makeDatabasePool(filename: "test.sqlite")
            let id = try dbPool.read { db in
                try Int.fetchOne(db, "SELECT id FROM items")!
            }
            XCTAssertEqual(id, 1)
        }
    }

    func testWriteOpensATransaction() throws {
        let dbPool = try makeDatabasePool()
        try dbPool.write { db in
            XCTAssertTrue(db.isInsideTransaction)
            do {
                try db.execute("BEGIN DEFERRED TRANSACTION")
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
                try db.execute("BEGIN DEFERRED TRANSACTION")
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
                try db.execute("PRAGMA locking_mode=EXCLUSIVE")
                try db.execute("CREATE TABLE items (id INTEGER PRIMARY KEY)")
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
                XCTAssertTrue(error.sql == nil)
                XCTAssertEqual(error.description, "SQLite error 5: database is locked")
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
            try db.execute("CREATE TABLE items (id INTEGER PRIMARY KEY)")
            for _ in 0..<3 {
                try db.execute("INSERT INTO items (id) VALUES (NULL)")
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
                let cursor = try Row.fetchCursor(db, "SELECT * FROM items")
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
                let cursor = try Row.fetchCursor(db, "SELECT * FROM items")
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
            try db.execute("CREATE TABLE items (id INTEGER PRIMARY KEY)")
            for _ in 0..<2 {
                try db.execute("INSERT INTO items (id) VALUES (NULL)")
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
                let cursor = try Row.fetchCursor(db, "SELECT * FROM items")
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
                    try db.execute("DELETE FROM items")
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
            try db.execute("CREATE TABLE items (id INTEGER PRIMARY KEY)")
            for _ in 0..<2 {
                try db.execute("INSERT INTO items (id) VALUES (NULL)")
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
                let cursor = try Row.fetchCursor(db, "SELECT * FROM items")
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
                    try db.execute("DELETE FROM items")
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
            try db.execute("CREATE TABLE items (id INTEGER PRIMARY KEY)")
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
                XCTAssertEqual(try Int.fetchOne(db, "SELECT COUNT(*) FROM items")!, 1)  // Not a bug. The writer did not start a transaction.
                s3.signal()
                _ = s4.wait(timeout: .distantFuture)
                XCTAssertEqual(try Int.fetchOne(db, "SELECT COUNT(*) FROM items")!, 1)
            }
        }
        let block2 = { () in
            do {
                _ = s1.wait(timeout: .distantFuture)
                try dbPool.writeWithoutTransaction { db in
                    try db.execute("INSERT INTO items (id) VALUES (NULL)")
                    s2.signal()
                    _ = s3.wait(timeout: .distantFuture)
                    try db.execute("INSERT INTO items (id) VALUES (NULL)")
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
            try db.execute("CREATE TABLE items (id INTEGER PRIMARY KEY)")
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
                XCTAssertEqual(try Int.fetchOne(db, "SELECT COUNT(*) FROM items")!, 0)
                s1.signal()
                _ = s2.wait(timeout: .distantFuture)
                XCTAssertEqual(try Int.fetchOne(db, "SELECT COUNT(*) FROM items")!, 0)
            }
        }
        let block2 = { () in
            do {
                _ = s1.wait(timeout: .distantFuture)
                defer { s2.signal() }
                try dbPool.writeWithoutTransaction { db in
                    try db.execute("INSERT INTO items (id) VALUES (NULL)")
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
            try db.execute("CREATE TABLE items (id INTEGER PRIMARY KEY)")
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
                    try db.execute("INSERT INTO items (id) VALUES (NULL)")
                    s1.signal()
                    _ = s2.wait(timeout: .distantFuture)
                    try db.execute("INSERT INTO items (id) VALUES (NULL)")
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
                XCTAssertEqual(try Int.fetchOne(db, "SELECT COUNT(*) FROM items")!, 1)
                s2.signal()
                _ = s3.wait(timeout: .distantFuture)
                XCTAssertEqual(try Int.fetchOne(db, "SELECT COUNT(*) FROM items")!, 1)
                s4.signal()
                _ = s5.wait(timeout: .distantFuture)
                XCTAssertEqual(try Int.fetchOne(db, "SELECT COUNT(*) FROM items")!, 1)
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
            try db.execute("CREATE TABLE items (id INTEGER PRIMARY KEY)")
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
                    try db.execute("INSERT INTO items (id) VALUES (NULL)")
                    s1.signal()
                    _ = s2.wait(timeout: .distantFuture)
                    try db.execute("INSERT INTO items (id) VALUES (NULL)")
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
                XCTAssertEqual(try Int.fetchOne(db, "SELECT COUNT(*) FROM items")!, 0)
                s2.signal()
                _ = s3.wait(timeout: .distantFuture)
                XCTAssertEqual(try Int.fetchOne(db, "SELECT COUNT(*) FROM items")!, 0)
                s4.signal()
                _ = s5.wait(timeout: .distantFuture)
                XCTAssertEqual(try Int.fetchOne(db, "SELECT COUNT(*) FROM items")!, 0)
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
            try db.execute("CREATE TABLE items (id INTEGER PRIMARY KEY)")
            for _ in 0..<2 {
                try db.execute("INSERT INTO items (id) VALUES (NULL)")
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
                let cursor = try Row.fetchCursor(db, "SELECT * FROM items")
                XCTAssertTrue(try cursor.next() != nil)
                s1.signal()
                _ = s2.wait(timeout: .distantFuture)
                XCTAssertTrue(try cursor.next() != nil)
                XCTAssertTrue(try cursor.next() == nil)
                XCTAssertEqual(try Int.fetchOne(db, "SELECT COUNT(*) FROM items")!, 0)
            }
        }
        let block2 = { () in
            do {
                _ = s1.wait(timeout: .distantFuture)
                defer { s2.signal() }
                try dbPool.writeWithoutTransaction { db in
                    try db.execute("DELETE FROM items")
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
            try db.execute("CREATE TABLE items (id INTEGER PRIMARY KEY)")
            for _ in 0..<2 {
                try db.execute("INSERT INTO items (id) VALUES (NULL)")
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
                let cursor = try Row.fetchCursor(db, "SELECT * FROM items")
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
                    try db.execute("DELETE FROM items")
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
            try db.execute("CREATE TABLE items (id INTEGER PRIMARY KEY)")
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
                XCTAssertEqual(try Int.fetchOne(db, "SELECT COUNT(*) FROM items")!, 0)
                s1.signal()
                _ = s2.wait(timeout: .distantFuture)
                XCTAssertEqual(try Int.fetchOne(db, "SELECT COUNT(*) FROM items")!, 1)
            }
        }
        let block2 = { () in
            do {
                _ = s1.wait(timeout: .distantFuture)
                defer { s2.signal() }
                try dbPool.writeWithoutTransaction { db in
                    try db.execute("INSERT INTO items (id) VALUES (NULL)")
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

    func testReadFromCurrentStateOpensATransaction() throws {
        let dbPool = try makeDatabasePool()
        let s = DispatchSemaphore(value: 0)
        try dbPool.writeWithoutTransaction { db in
            try dbPool.readFromCurrentState { db in
                XCTAssertTrue(db.isInsideTransaction)
                do {
                    try db.execute("BEGIN DEFERRED TRANSACTION")
                    XCTFail("Expected error")
                } catch {
                }
                s.signal()
            }
        }
        _ = s.wait(timeout: .distantFuture)
    }

    func testConcurrentReadOpensATransaction() throws {
        let dbPool = try makeDatabasePool()
        let future = dbPool.writeWithoutTransaction { db in
            dbPool.concurrentRead { db in
                XCTAssertTrue(db.isInsideTransaction)
                do {
                    try db.execute("BEGIN DEFERRED TRANSACTION")
                    XCTFail("Expected error")
                } catch {
                }
            }
        }
        try future.wait()
    }

    func testReadFromCurrentStateOutsideOfTransaction() throws {
        let dbPool = try makeDatabasePool()
        try dbPool.write { db in
            try db.create(table: "persons") { t in
                t.column("id", .integer).primaryKey()
            }
        }
        
        // Writer                       Reader
        // dbPool.writeWithoutTransaction {
        // >
        //                              dbPool.readFromCurrentState {
        //                              <
        // INSERT INTO items (id) VALUES (NULL)
        // >
        let s1 = DispatchSemaphore(value: 0)
        // }                            SELECT COUNT(*) FROM persons -> 0
        //                              <
        let s2 = DispatchSemaphore(value: 0)
        //                              }
        
        var i: Int! = nil
        try dbPool.writeWithoutTransaction { db in
            try dbPool.readFromCurrentState { db in
                _ = s1.wait(timeout: .distantFuture)
                i = try! Int.fetchOne(db, "SELECT COUNT(*) FROM persons")!
                s2.signal()
            }
            try db.execute("INSERT INTO persons DEFAULT VALUES")
            s1.signal()
        }
        _ = s2.wait(timeout: .distantFuture)
        XCTAssertEqual(i, 0)
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
        
        let future: Future<Int> = try dbPool.writeWithoutTransaction { db in
            let future: Future<Int> = dbPool.concurrentRead { db in
                _ = s1.wait(timeout: .distantFuture)
                return try! Int.fetchOne(db, "SELECT COUNT(*) FROM persons")!
            }
            try db.execute("INSERT INTO persons DEFAULT VALUES")
            s1.signal()
            return future
        }
        XCTAssertEqual(try future.wait(), 0)
    }

    func testReadFromCurrentStateError() throws {
        let dbPool = try makeDatabasePool()
        try dbPool.writeWithoutTransaction { db in
            try db.execute("PRAGMA locking_mode=EXCLUSIVE")
            try db.execute("CREATE TABLE items (id INTEGER PRIMARY KEY)")
            do {
                try dbPool.readFromCurrentState { db in
                    fatalError("Should not run")
                }
                XCTFail("Expected error")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_BUSY)
                XCTAssertEqual(error.message!, "database is locked")
                XCTAssertTrue(error.sql == nil)
                XCTAssertEqual(error.description, "SQLite error 5: database is locked")
            }
        }
    }
    
    func testConcurrentReadError() throws {
        let dbPool = try makeDatabasePool()
        try dbPool.writeWithoutTransaction { db in
            try db.execute("PRAGMA locking_mode=EXCLUSIVE")
            try db.execute("CREATE TABLE items (id INTEGER PRIMARY KEY)")
            let future = dbPool.concurrentRead { db in
                fatalError("Should not run")
            }
            do {
                try future.wait()
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_BUSY)
                XCTAssertEqual(error.message!, "database is locked")
                XCTAssertTrue(error.sql == nil)
                XCTAssertEqual(error.description, "SQLite error 5: database is locked")
            }
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
            try db.execute("INSERT INTO t DEFAULT VALUES")
        }
        
        try dbQueue.writeWithoutTransaction { db in
            try db.beginTransaction(.deferred)
        }
        
        try dbQueue.writeWithoutTransaction { db in
            try XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM t")!, 1)
        }
        
        try dbPool.write { db in
            try db.execute("INSERT INTO t DEFAULT VALUES")
        }
        
        try dbQueue.writeWithoutTransaction { db in
            try XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM t")!, 1)
            try db.rollback()
            try XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM t")!, 2)
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
            try db.execute("CREATE VIRTUAL TABLE search USING fts3(title)")
        }
        try dbPool.read { db in
            _ = try Row.fetchAll(db, "SELECT * FROM search")
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
}
