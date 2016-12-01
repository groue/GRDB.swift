import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class DatabasePoolConcurrencyTests: GRDBTestCase {
    
    func testDatabasePoolFundamental1() {
        // Constraint: the sum of values, the balance, must remain zero.
        // DatabasePool aims at providing this guarantee, that is to say:
        // no reader should ever see a non-zero balance.
        //
        // This test shows that writes that are not wrapped in a transaction
        // can not provide our guarantee.
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
        
        assertNoError {
            dbConfiguration.trace = { print($0) }
            do {
                let dbQueue = try makeDatabaseQueue(filename: "test.sqlite")
                try dbQueue.inDatabase { db in
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
                try! dbQueue.inDatabase { db in
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
                try! dbQueue.inDatabase { db in
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
    }

    func testDatabasePoolFundamental2() {
        // Constraint: the sum of values, the balance, must remain zero.
        // DatabasePool aims at providing this guarantee, that is to say:
        // no reader should ever see a non-zero balance.
        //
        // This test shows that writes that happen in a transaction are not
        // visible from the reader.
        //
        // Reader                                   Writer
        //                                          BEGIN DEFERRED TRANSACTION
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
        
        assertNoError {
            do {
                let dbQueue = try! makeDatabaseQueue(filename: "test.sqlite")
                try dbQueue.inDatabase { db in
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
                try! dbQueue.inDatabase { db in
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
                try! dbQueue.inDatabase { db in
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
    }
    
    func testDatabasePoolFundamental3() {
        // Constraint: the sum of values, the balance, must remain zero.
        // DatabasePool aims at providing this guarantee, that is to say:
        // no reader should ever see a non-zero balance.
        //
        // This test shows that writes that happen in a transaction are not
        // visible from the reader.
        //
        // Reader                                   Writer
        // BEGIN DEFERRED TRANSACTION
        let s1 = DispatchSemaphore(value: 0)
        //                                          BEGIN DEFERRED TRANSACTION
        //                                          INSERT INTO moves VALUES (1)
        let s2 = DispatchSemaphore(value: 0)
        // SELECT SUM(value) AS balance FROM moves
        let s3 = DispatchSemaphore(value: 0)
        //                                          INSERT INTO moves VALUES (-1)
        let s4 = DispatchSemaphore(value: 0)
        // SELECT SUM(value) AS balance FROM moves  END
        // END
        
        assertNoError {
            do {
                let dbQueue = try! makeDatabaseQueue(filename: "test.sqlite")
                try dbQueue.inDatabase { db in
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
                try! dbQueue.inDatabase { db in
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
                try! dbQueue.inDatabase { db in
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
    }
    
    func testWrappedReadWrite() {
        assertNoError {
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
    }
    
    func testReadFromPreviousNonWALDatabase() {
        assertNoError {
            do {
                let dbQueue = try makeDatabaseQueue(filename: "test.sqlite")
                try dbQueue.inDatabase { db in
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
    }
    
    func testConcurrentRead() {
        assertNoError {
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
    }
    
    func testReadMethodIsolationOfStatement() {
        assertNoError {
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
                    try dbPool.write { db in
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
    }
    
    func testReadMethodIsolationOfStatementWithCheckpoint() {
        assertNoError {
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
                    try dbPool.write { db in
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
    }
    
    func testReadBlockIsolationStartingWithRead() {
        assertNoError {
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
                    XCTAssertEqual(try Int.fetchOne(db, "SELECT COUNT(*) FROM items")!, 0)
                    s3.signal()
                    _ = s4.wait(timeout: .distantFuture)
                    XCTAssertEqual(try Int.fetchOne(db, "SELECT COUNT(*) FROM items")!, 0)
                }
            }
            let block2 = { () in
                do {
                    _ = s1.wait(timeout: .distantFuture)
                    try dbPool.write { db in
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
    }
    
    func testReadBlockIsolationStartingWithSelect() {
        assertNoError {
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
                    try dbPool.write { db in
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
    }
    
    func testReadBlockIsolationStartingWithWrite() {
        assertNoError {
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
                    try dbPool.write { db in
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
    }
    
    func testReadBlockIsolationStartingWithWriteTransaction() {
        assertNoError {
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
    }
    
    func testUnsafeReadMethodIsolationOfStatement() {
        assertNoError {
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
                    try dbPool.write { db in
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
    }
    
    func testUnsafeReadMethodIsolationOfStatementWithCheckpoint() {
        assertNoError {
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
                    try dbPool.write { db in
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
    }
    
    func testUnsafeReadMethodIsolationOfBlock() {
        assertNoError {
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
                    try dbPool.write { db in
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
    }
    
    func testReadFromCurrentStateOutsideOfTransaction() {
        assertNoError {
            dbConfiguration.trace = { print($0) }
            let dbPool = try makeDatabasePool()
            try dbPool.write { db in
                try db.create(table: "persons") { t in
                    t.column("id", .integer).primaryKey()
                }
            }
            
            // Writer                       Reader
            // dbPool.write {
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
            try dbPool.write { db in
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
    }
    
    func testIssue80() {
        // See https://github.com/groue/GRDB.swift/issues/80
        //
        // Here we test that `SELECT * FROM search`, which is announced by
        // SQLite has a statement that modifies the sqlite_master table, is
        // still allowed as a regular select statement.
        assertNoError {
            // This test uses a database pool, a connection for creating the
            // search virtual table, and another connection for reading.
            //
            // This is the tested setup: don't change it.
            
            let dbPool = try makeDatabasePool()
            try dbPool.write { db in
                try db.execute("CREATE VIRTUAL TABLE search  USING fts3(title, tokenize = unicode61)")
            }
            try dbPool.read { db in
                _ = try Row.fetchAll(db, "SELECT * FROM search")
            }
        }
    }
}
