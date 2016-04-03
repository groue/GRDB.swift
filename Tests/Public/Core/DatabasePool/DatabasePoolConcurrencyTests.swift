import XCTest
#if SQLITE_HAS_CODEC
    import GRDBCipher
#else
    import GRDB
#endif

class DatabasePoolConcurrencyTests: GRDBTestCase {
    
    func testUnwrappedReadWrite() {
        assertNoError {
            let dbPool = try makeDatabasePool()
            try dbPool.execute("CREATE TABLE items (id INTEGER PRIMARY KEY)")
            try dbPool.execute("INSERT INTO items (id) VALUES (NULL)")
            let id = Int.fetchOne(dbPool, "SELECT id FROM items")!
            XCTAssertEqual(id, 1)
        }
    }
    
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
    
    func testConcurrentRead() {
        assertNoError {
            let dbPool = try makeDatabasePool()
            try dbPool.write { db in
                try db.execute("CREATE TABLE items (id INTEGER PRIMARY KEY)")
                for _ in 0..<3 {
                    try db.execute("INSERT INTO items (id) VALUES (NULL)")
                }
            }
            
            // Block 1                  Block 2
            // SELECT * FROM items      SELECT * FROM items
            // step                     step
            // >
            let s1 = dispatch_semaphore_create(0)
            //                          step
            //                          <
            let s2 = dispatch_semaphore_create(0)
            // step                     step
            // step                     end
            // end
            
            let block1 = { () in
                dbPool.read { db in
                    let generator = Row.fetch(db, "SELECT * FROM items").generate()
                    XCTAssertTrue(generator.next() != nil)
                    dispatch_semaphore_signal(s1)
                    dispatch_semaphore_wait(s2, DISPATCH_TIME_FOREVER)
                    XCTAssertTrue(generator.next() != nil)
                    XCTAssertTrue(generator.next() != nil)
                    XCTAssertTrue(generator.next() == nil)
                }
            }
            let block2 = { () in
                dbPool.read { db in
                    let generator = Row.fetch(db, "SELECT * FROM items").generate()
                    XCTAssertTrue(generator.next() != nil)
                    dispatch_semaphore_wait(s1, DISPATCH_TIME_FOREVER)
                    XCTAssertTrue(generator.next() != nil)
                    dispatch_semaphore_signal(s2)
                    XCTAssertTrue(generator.next() != nil)
                    XCTAssertTrue(generator.next() == nil)
                }
            }
            let queue = dispatch_queue_create(nil, DISPATCH_QUEUE_CONCURRENT)
            dispatch_apply(2, queue) { index in
                [block1, block2][index]()
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
            
            // Block 1                  Block 2
            // SELECT * FROM items
            // step
            // >
            let s1 = dispatch_semaphore_create(0)
            //                          DELETE * FROM items
            //                          <
            let s2 = dispatch_semaphore_create(0)
            // step
            // end
            
            let block1 = { () in
                dbPool.read { db in
                    let generator = Row.fetch(db, "SELECT * FROM items").generate()
                    XCTAssertTrue(generator.next() != nil)
                    dispatch_semaphore_signal(s1)
                    dispatch_semaphore_wait(s2, DISPATCH_TIME_FOREVER)
                    XCTAssertTrue(generator.next() != nil)
                    XCTAssertTrue(generator.next() == nil)
                }
            }
            let block2 = { () in
                do {
                    dispatch_semaphore_wait(s1, DISPATCH_TIME_FOREVER)
                    defer { dispatch_semaphore_signal(s2) }
                    try dbPool.write { db in
                        try db.execute("DELETE FROM items")
                    }
                } catch {
                    XCTFail("error: \(error)")
                }
            }
            let queue = dispatch_queue_create(nil, DISPATCH_QUEUE_CONCURRENT)
            dispatch_apply(2, queue) { index in
                [block1, block2][index]()
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
            
            // Block 1                  Block 2
            // SELECT * FROM items
            // step
            // >
            let s1 = dispatch_semaphore_create(0)
            //                          DELETE * FROM items
            //                          Checkpoint
            //                          <
            let s2 = dispatch_semaphore_create(0)
            // step
            // end
            
            let block1 = { () in
                dbPool.read { db in
                    let generator = Row.fetch(db, "SELECT * FROM items").generate()
                    XCTAssertTrue(generator.next() != nil)
                    dispatch_semaphore_signal(s1)
                    dispatch_semaphore_wait(s2, DISPATCH_TIME_FOREVER)
                    XCTAssertTrue(generator.next() != nil)
                    XCTAssertTrue(generator.next() == nil)
                }
            }
            let block2 = { () in
                do {
                    dispatch_semaphore_wait(s1, DISPATCH_TIME_FOREVER)
                    defer { dispatch_semaphore_signal(s2) }
                    try dbPool.write { db in
                        try db.execute("DELETE FROM items")
                    }
                    try dbPool.checkpoint()
                } catch {
                    XCTFail("error: \(error)")
                }
            }
            let queue = dispatch_queue_create(nil, DISPATCH_QUEUE_CONCURRENT)
            dispatch_apply(2, queue) { index in
                [block1, block2][index]()
            }
        }
    }
    
    func testReadMethodIsolationOfBlock() {
        assertNoError {
            let dbPool = try makeDatabasePool()
            try dbPool.write { db in
                try db.execute("CREATE TABLE items (id INTEGER PRIMARY KEY)")
            }
            
            // Block 1                      Block 2
            // SELECT COUNT(*) FROM items
            // >
            let s1 = dispatch_semaphore_create(0)
            //                              INSERT INTO items (id) VALUES (NULL)
            //                              Checkpoint
            //                              <
            let s2 = dispatch_semaphore_create(0)
            // SELECT COUNT(*) FROM items
            
            let block1 = { () in
                dbPool.read { db in
                    XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM items")!, 0)
                    dispatch_semaphore_signal(s1)
                    dispatch_semaphore_wait(s2, DISPATCH_TIME_FOREVER)
                    XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM items")!, 0)
                }
            }
            let block2 = { () in
                do {
                    dispatch_semaphore_wait(s1, DISPATCH_TIME_FOREVER)
                    defer { dispatch_semaphore_signal(s2) }
                    try dbPool.write { db in
                        try db.execute("INSERT INTO items (id) VALUES (NULL)")
                    }
                    try dbPool.checkpoint()
                } catch {
                    XCTFail("error: \(error)")
                }
            }
            let queue = dispatch_queue_create(nil, DISPATCH_QUEUE_CONCURRENT)
            dispatch_apply(2, queue) { index in
                [block1, block2][index]()
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
            
            // Block 1                  Block 2
            // SELECT * FROM items
            // step
            // >
            let s1 = dispatch_semaphore_create(0)
            //                          DELETE * FROM items
            //                          <
            let s2 = dispatch_semaphore_create(0)
            // step
            // end
            // SELECT COUNT(*) FROM items -> 0
            
            let block1 = { () in
                dbPool.nonIsolatedRead { db in
                    let generator = Row.fetch(db, "SELECT * FROM items").generate()
                    XCTAssertTrue(generator.next() != nil)
                    dispatch_semaphore_signal(s1)
                    dispatch_semaphore_wait(s2, DISPATCH_TIME_FOREVER)
                    XCTAssertTrue(generator.next() != nil)
                    XCTAssertTrue(generator.next() == nil)
                    XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM items")!, 0)
                }
            }
            let block2 = { () in
                do {
                    dispatch_semaphore_wait(s1, DISPATCH_TIME_FOREVER)
                    defer { dispatch_semaphore_signal(s2) }
                    try dbPool.write { db in
                        try db.execute("DELETE FROM items")
                    }
                } catch {
                    XCTFail("error: \(error)")
                }
            }
            let queue = dispatch_queue_create(nil, DISPATCH_QUEUE_CONCURRENT)
            dispatch_apply(2, queue) { index in
                [block1, block2][index]()
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
            
            // Block 1                  Block 2
            // SELECT * FROM items
            // step
            // >
            let s1 = dispatch_semaphore_create(0)
            //                          DELETE * FROM items
            //                          Checkpoint
            //                          <
            let s2 = dispatch_semaphore_create(0)
            // step
            // end
            
            let block1 = { () in
                dbPool.nonIsolatedRead { db in
                    let generator = Row.fetch(db, "SELECT * FROM items").generate()
                    XCTAssertTrue(generator.next() != nil)
                    dispatch_semaphore_signal(s1)
                    dispatch_semaphore_wait(s2, DISPATCH_TIME_FOREVER)
                    XCTAssertTrue(generator.next() != nil)
                    XCTAssertTrue(generator.next() == nil)
                }
            }
            let block2 = { () in
                do {
                    dispatch_semaphore_wait(s1, DISPATCH_TIME_FOREVER)
                    defer { dispatch_semaphore_signal(s2) }
                    try dbPool.write { db in
                        try db.execute("DELETE FROM items")
                    }
                    try dbPool.checkpoint()
                } catch {
                    XCTFail("error: \(error)")
                }
            }
            let queue = dispatch_queue_create(nil, DISPATCH_QUEUE_CONCURRENT)
            dispatch_apply(2, queue) { index in
                [block1, block2][index]()
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
            // SELECT COUNT(*) FROM items
            // >
            let s1 = dispatch_semaphore_create(0)
            //                              INSERT INTO items (id) VALUES (NULL)
            //                              Checkpoint
            //                              <
            let s2 = dispatch_semaphore_create(0)
            // SELECT COUNT(*) FROM items
            
            let block1 = { () in
                dbPool.nonIsolatedRead { db in
                    XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM items")!, 0)
                    dispatch_semaphore_signal(s1)
                    dispatch_semaphore_wait(s2, DISPATCH_TIME_FOREVER)
                    XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM items")!, 1)
                }
            }
            let block2 = { () in
                do {
                    dispatch_semaphore_wait(s1, DISPATCH_TIME_FOREVER)
                    defer { dispatch_semaphore_signal(s2) }
                    try dbPool.write { db in
                        try db.execute("INSERT INTO items (id) VALUES (NULL)")
                    }
                    try dbPool.checkpoint()
                } catch {
                    XCTFail("error: \(error)")
                }
            }
            let queue = dispatch_queue_create(nil, DISPATCH_QUEUE_CONCURRENT)
            dispatch_apply(2, queue) { index in
                [block1, block2][index]()
            }
        }
    }
}
