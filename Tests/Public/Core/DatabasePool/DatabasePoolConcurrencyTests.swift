import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class DatabasePoolConcurrencyTests: GRDBTestCase {
    
    func testWrappedReadWrite() {
        assertNoError {
            let dbPool = try makeDatabasePool()
            try dbPool.write { db in
                try db.execute("CREATE TABLE items (id INTEGER PRIMARY KEY)")
                try db.execute("INSERT INTO items (id) VALUES (NULL)")
            }
            let id = dbPool.read { db in
                Int.fetchOne(db, "SELECT id FROM items")!
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
                let id = dbPool.read { db in
                    Int.fetchOne(db, "SELECT id FROM items")!
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
            // BEGIN DEFERRED TRANSACTION   BEGIN DEFERRED TRANSACTION
            // SELECT * FROM items          SELECT * FROM items
            // step                         step
            // >
            let s1 = DispatchSemaphore(value: 0)
            //                              step
            //                              <
            let s2 = DispatchSemaphore(value: 0)
            // step                         step
            // step                         end
            // end                          COMMIT
            // COMMIT
            
            let block1 = { () in
                dbPool.read { db in
                    let iterator = Row.fetch(db, "SELECT * FROM items").makeIterator()
                    XCTAssertTrue(iterator.next() != nil)
                    s1.signal()
                    _ = s2.wait(timeout: .distantFuture)
                    XCTAssertTrue(iterator.next() != nil)
                    XCTAssertTrue(iterator.next() != nil)
                    XCTAssertTrue(iterator.next() == nil)
                }
            }
            let block2 = { () in
                dbPool.read { db in
                    let iterator = Row.fetch(db, "SELECT * FROM items").makeIterator()
                    XCTAssertTrue(iterator.next() != nil)
                    _ = s1.wait(timeout: .distantFuture)
                    XCTAssertTrue(iterator.next() != nil)
                    s2.signal()
                    XCTAssertTrue(iterator.next() != nil)
                    XCTAssertTrue(iterator.next() == nil)
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
            // BEGIN DEFERRED TRANSACTION
            // SELECT * FROM items
            // step
            // >
            let s1 = DispatchSemaphore(value: 0)
            //                              DELETE * FROM items
            //                              <
            let s2 = DispatchSemaphore(value: 0)
            // step
            // end
            // COMMIT
            
            let block1 = { () in
                dbPool.read { db in
                    let iterator = Row.fetch(db, "SELECT * FROM items").makeIterator()
                    XCTAssertTrue(iterator.next() != nil)
                    s1.signal()
                    _ = s2.wait(timeout: .distantFuture)
                    XCTAssertTrue(iterator.next() != nil)
                    XCTAssertTrue(iterator.next() == nil)
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
            // BEGIN DEFERRED TRANSACTION
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
            // COMMIT
            
            let block1 = { () in
                dbPool.read { db in
                    let iterator = Row.fetch(db, "SELECT * FROM items").makeIterator()
                    XCTAssertTrue(iterator.next() != nil)
                    s1.signal()
                    _ = s2.wait(timeout: .distantFuture)
                    XCTAssertTrue(iterator.next() != nil)
                    XCTAssertTrue(iterator.next() == nil)
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
            // BEGIN DEFERRED TRANSACTION
            // SELECT COUNT(*) FROM items -> 0
            // >
            let s1 = DispatchSemaphore(value: 0)
            //                              INSERT INTO items (id) VALUES (NULL)
            //                              Checkpoint
            //                              <
            let s2 = DispatchSemaphore(value: 0)
            // SELECT COUNT(*) FROM items -> 0
            // COMMIT
            
            let block1 = { () in
                dbPool.read { db in
                    XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM items")!, 0)
                    s1.signal()
                    _ = s2.wait(timeout: .distantFuture)
                    XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM items")!, 0)
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
            // BEGIN IMMEDIATE TRANSACTION
            // INSERT INTO items (id) VALUES (NULL)
            // >
            let s1 = DispatchSemaphore(value: 0)
            //                              BEGIN DEFERRED TRANSACTION
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
            //                              COMMIT
            
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
                dbPool.read { db in
                    _ = s1.wait(timeout: .distantFuture)
                    XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM items")!, 0)
                    s2.signal()
                    _ = s3.wait(timeout: .distantFuture)
                    XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM items")!, 0)
                    s4.signal()
                    _ = s5.wait(timeout: .distantFuture)
                    XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM items")!, 0)
                }
            }
            let blocks = [block1, block2]
            DispatchQueue.concurrentPerform(iterations: blocks.count) { index in
                blocks[index]()
            }
        }
    }
    
    func testNonIsolatedReadMethodIsolationOfStatement() {
        assertNoError {
            let dbPool = try makeDatabasePool()
            try dbPool.write { db in
                try db.execute("CREATE TABLE items (id INTEGER PRIMARY KEY)")
                for _ in 0..<2 {
                    try db.execute("INSERT INTO items (id) VALUES (NULL)")
                }
            }
            
            // Block 1                      Block 2
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
            
            let block1 = { () in
                dbPool.nonIsolatedRead { db in
                    let iterator = Row.fetch(db, "SELECT * FROM items").makeIterator()
                    XCTAssertTrue(iterator.next() != nil)
                    s1.signal()
                    _ = s2.wait(timeout: .distantFuture)
                    XCTAssertTrue(iterator.next() != nil)
                    XCTAssertTrue(iterator.next() == nil)
                    XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM items")!, 0)
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
    
    func testNonIsolatedReadMethodIsolationOfStatementWithCheckpoint() {
        assertNoError {
            let dbPool = try makeDatabasePool()
            try dbPool.write { db in
                try db.execute("CREATE TABLE items (id INTEGER PRIMARY KEY)")
                for _ in 0..<2 {
                    try db.execute("INSERT INTO items (id) VALUES (NULL)")
                }
            }
            
            // Block 1                      Block 2
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
            
            let block1 = { () in
                dbPool.nonIsolatedRead { db in
                    let iterator = Row.fetch(db, "SELECT * FROM items").makeIterator()
                    XCTAssertTrue(iterator.next() != nil)
                    s1.signal()
                    _ = s2.wait(timeout: .distantFuture)
                    XCTAssertTrue(iterator.next() != nil)
                    XCTAssertTrue(iterator.next() == nil)
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
    
    func testNonIsolatedReadMethodIsolationOfBlock() {
        assertNoError {
            let dbPool = try makeDatabasePool()
            try dbPool.write { db in
                try db.execute("CREATE TABLE items (id INTEGER PRIMARY KEY)")
            }
            
            // Block 1                      Block 2
            // SELECT COUNT(*) FROM items -> 0
            // >
            let s1 = DispatchSemaphore(value: 0)
            //                              INSERT INTO items (id) VALUES (NULL)
            //                              Checkpoint
            //                              <
            let s2 = DispatchSemaphore(value: 0)
            // SELECT COUNT(*) FROM items -> 1
            
            let block1 = { () in
                dbPool.nonIsolatedRead { db in
                    XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM items")!, 0)
                    s1.signal()
                    _ = s2.wait(timeout: .distantFuture)
                    XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM items")!, 1)
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
            dbPool.read { db in
                _ = Row.fetchAll(db, "SELECT * FROM search")
            }
        }
    }
}
