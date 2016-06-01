import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class ConcurrencyTests: GRDBTestCase {
    var busyCallback: BusyCallback?
    
    override func setUp() {
        super.setUp()
        
        self.busyCallback = nil
        let busyCallback: BusyCallback = { numberOfTries in
            if let busyCallback = self.busyCallback {
                return busyCallback(numberOfTries: numberOfTries)
            } else {
                // Default give up
                return false
            }
        }
        
        dbConfiguration.busyMode = .Callback(busyCallback)
    }
    
    func testWrappedReadWrite() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE items (id INTEGER PRIMARY KEY)")
                try db.execute("INSERT INTO items (id) VALUES (NULL)")
            }
            let id = dbQueue.inDatabase { db in
                Int.fetchOne(db, "SELECT id FROM items")!
            }
            XCTAssertEqual(id, 1)
        }
    }

    func testDeferredTransactionConcurrency() {
        assertNoError {
            let dbQueue1 = try makeDatabaseQueue()
            #if GRDBCIPHER_USE_ENCRYPTION
                // Work around SQLCipher bug when two connections are open to the
                // same empty database: make sure the database is not empty before
                // running this test
                try dbQueue1.inDatabase { db in
                    try db.execute("CREATE TABLE SQLCipherWorkAround (foo INTEGER)")
                }
            #endif
            let dbQueue2 = try makeDatabaseQueue()
            
            // Queue 1                              Queue 2
            // BEGIN DEFERRED TRANSACTION
            let s1 = dispatch_semaphore_create(0)
            //                                      BEGIN DEFERRED TRANSACTION
            let s2 = dispatch_semaphore_create(0)
            // INSERT INTO stuffs (id) VALUES (NULL)
            let s3 = dispatch_semaphore_create(0)
            //                                      INSERT INTO stuffs (id) VALUES (NULL) <--- Error
            //                                      ROLLBACK
            let s4 = dispatch_semaphore_create(0)
            // COMMIT
            
            try! dbQueue1.inDatabase { db in
                try db.execute("CREATE TABLE stuffs (id INTEGER PRIMARY KEY)")
            }
            
            let queue = dispatch_queue_create("GRDB", DISPATCH_QUEUE_CONCURRENT)
            let group = dispatch_group_create()
            
            // Queue 1
            dispatch_group_async(group, queue) {
                do {
                    try dbQueue1.inTransaction(.Deferred) { db in
                        dispatch_semaphore_signal(s1)
                        dispatch_semaphore_wait(s2, DISPATCH_TIME_FOREVER)
                        try db.execute("INSERT INTO stuffs (id) VALUES (NULL)")
                        dispatch_semaphore_signal(s3)
                        dispatch_semaphore_wait(s4, DISPATCH_TIME_FOREVER)
                        return .Commit
                    }
                }
                catch {
                    XCTFail("\(error)")
                }
            }

            // Queue 2
            var concurrencyError: DatabaseError? = nil
            dispatch_group_async(group, queue) {
                do {
                    dispatch_semaphore_wait(s1, DISPATCH_TIME_FOREVER)
                    try dbQueue2.inTransaction(.Deferred) { db in
                        dispatch_semaphore_signal(s2)
                        dispatch_semaphore_wait(s3, DISPATCH_TIME_FOREVER)
                        try db.execute("INSERT INTO stuffs (id) VALUES (NULL)")
                        return .Commit
                    }
                }
                catch let error as DatabaseError {
                    dispatch_semaphore_signal(s4)
                    concurrencyError = error
                }
                catch {
                    XCTFail("\(error)")
                }
            }
            
            dispatch_group_wait(group, DISPATCH_TIME_FOREVER)
            
            if let concurrencyError = concurrencyError {
                XCTAssertEqual(concurrencyError.code, 5) // SQLITE_BUSY
                XCTAssertEqual(concurrencyError.sql, "INSERT INTO stuffs (id) VALUES (NULL)")
            } else {
                XCTFail("Expected concurrency error")
            }
        }
    }
    
    func testExclusiveTransactionConcurrency() {
        assertNoError {
            let dbQueue1 = try makeDatabaseQueue()
            let dbQueue2 = try makeDatabaseQueue()
            
            // Queue 1                              Queue 2
            // BEGIN EXCLUSIVE TRANSACTION
            let s1 = dispatch_semaphore_create(0)
            //                                      BEGIN EXCLUSIVE TRANSACTION <--- Error
            let s2 = dispatch_semaphore_create(0)
            // COMMIT
            
            let queue = dispatch_queue_create("GRDB", DISPATCH_QUEUE_CONCURRENT)
            let group = dispatch_group_create()
            
            // Queue 1
            dispatch_group_async(group, queue) {
                do {
                    try dbQueue1.inTransaction(.Exclusive) { db in
                        dispatch_semaphore_signal(s1)
                        dispatch_semaphore_wait(s2, DISPATCH_TIME_FOREVER)
                        return .Commit
                    }
                }
                catch {
                    XCTFail("\(error)")
                }
            }
            
            // Queue 2
            var concurrencyError: DatabaseError? = nil
            dispatch_group_async(group, queue) {
                do {
                    dispatch_semaphore_wait(s1, DISPATCH_TIME_FOREVER)
                    try dbQueue2.inTransaction(.Exclusive) { db in
                        return .Commit
                    }
                }
                catch let error as DatabaseError {
                    dispatch_semaphore_signal(s2)
                    concurrencyError = error
                }
                catch {
                    XCTFail("\(error)")
                }
            }
            
            dispatch_group_wait(group, DISPATCH_TIME_FOREVER)
            
            if let concurrencyError = concurrencyError {
                XCTAssertEqual(concurrencyError.code, 5) // SQLITE_BUSY
                XCTAssertEqual(concurrencyError.sql, "BEGIN EXCLUSIVE TRANSACTION")
            } else {
                XCTFail("Expected concurrency error")
            }
        }
    }
    
    func testImmediateTransactionConcurrency() {
        assertNoError {
            let dbQueue1 = try makeDatabaseQueue()
            let dbQueue2 = try makeDatabaseQueue()
            
            // Queue 1                              Queue 2
            // BEGIN IMMEDIATE TRANSACTION
            let s1 = dispatch_semaphore_create(0)
            //                                      BEGIN IMMEDIATE TRANSACTION <--- Error
            let s2 = dispatch_semaphore_create(0)
            // COMMIT
            
            let queue = dispatch_queue_create("GRDB", DISPATCH_QUEUE_CONCURRENT)
            let group = dispatch_group_create()
            
            // Queue 1
            dispatch_group_async(group, queue) {
                do {
                    try dbQueue1.inTransaction(.Immediate) { db in
                        dispatch_semaphore_signal(s1)
                        dispatch_semaphore_wait(s2, DISPATCH_TIME_FOREVER)
                        return .Commit
                    }
                }
                catch {
                    XCTFail("\(error)")
                }
            }
            
            // Queue 2
            var concurrencyError: DatabaseError? = nil
            dispatch_group_async(group, queue) {
                do {
                    dispatch_semaphore_wait(s1, DISPATCH_TIME_FOREVER)
                    try dbQueue2.inTransaction(.Immediate) { db in
                        return .Commit
                    }
                }
                catch let error as DatabaseError {
                    dispatch_semaphore_signal(s2)
                    concurrencyError = error
                }
                catch {
                    XCTFail("\(error)")
                }
            }
            
            dispatch_group_wait(group, DISPATCH_TIME_FOREVER)
            
            if let concurrencyError = concurrencyError {
                XCTAssertEqual(concurrencyError.code, 5) // SQLITE_BUSY
                XCTAssertEqual(concurrencyError.sql, "BEGIN IMMEDIATE TRANSACTION")
            } else {
                XCTFail("Expected concurrency error")
            }
        }
    }
    
    func testBusyCallback() {
        assertNoError {
            let dbQueue1 = try makeDatabaseQueue()
            #if GRDBCIPHER_USE_ENCRYPTION
                // Work around SQLCipher bug when two connections are open to the
                // same empty database: make sure the database is not empty before
                // running this test
                try dbQueue1.inDatabase { db in
                    try db.execute("CREATE TABLE SQLCipherWorkAround (foo INTEGER)")
                }
            #endif
            let dbQueue2 = try makeDatabaseQueue()
            
            // Queue 1                              Queue 2
            // BEGIN EXCLUSIVE TRANSACTION
            let s1 = dispatch_semaphore_create(0)
            // (Waiting)                            BEGIN EXCLUSIVE TRANSACTION <--- Busy
            // (Waiting)                            BEGIN EXCLUSIVE TRANSACTION <--- Busy
            // (Waiting)                            BEGIN EXCLUSIVE TRANSACTION <--- Busy
            // COMMIT
            //                                      BEGIN EXCLUSIVE TRANSACTION
            //                                      COMMIT
            
            var numberOfTries = 0
            self.busyCallback = { n in
                numberOfTries = n
                usleep(10_000) // 0.01s
                return true
            }
            
            let queue = dispatch_queue_create("GRDB", DISPATCH_QUEUE_CONCURRENT)
            let group = dispatch_group_create()
            
            // Queue 1
            dispatch_group_async(group, queue) {
                do {
                    try dbQueue1.inTransaction(.Exclusive) { db in
                        dispatch_semaphore_signal(s1)
                        usleep(100_000) // 0.1s
                        return .Commit
                    }
                }
                catch {
                    XCTFail("\(error)")
                }
            }
            
            // Queue 2
            dispatch_group_async(group, queue) {
                do {
                    dispatch_semaphore_wait(s1, DISPATCH_TIME_FOREVER)
                    try dbQueue2.inTransaction(.Exclusive) { db in
                        return .Commit
                    }
                }
                catch {
                    XCTFail("\(error)")
                }
            }
            
            dispatch_group_wait(group, DISPATCH_TIME_FOREVER)
            
            XCTAssertTrue(numberOfTries > 0)    // Busy handler has been used.
        }
    }

    func testReaderDuringDefaultTransaction() {
        assertNoError {
            let dbQueue1 = try makeDatabaseQueue()
            #if GRDBCIPHER_USE_ENCRYPTION
                // Work around SQLCipher bug when two connections are open to the
                // same empty database: make sure the database is not empty before
                // running this test
                try dbQueue1.inDatabase { db in
                    try db.execute("CREATE TABLE SQLCipherWorkAround (foo INTEGER)")
                }
            #endif
            let dbQueue2 = try makeDatabaseQueue()
            
            // Here we test that a reader can read while a writer is writing.
            
            // Queue 1                              Queue 2
            // BEGIN IMMEDIATE TRANSACTION
            // INSERT INTO stuffs (id) VALUES (NULL)
            let s1 = dispatch_semaphore_create(0)
            //                                      SELECT * FROM stuffs <--- 0 result
            let s2 = dispatch_semaphore_create(0)
            // COMMIT
            let s3 = dispatch_semaphore_create(0)
            //                                      SELECT * FROM stuffs <--- 1 result
            
            try! dbQueue1.inDatabase { db in
                try db.execute("CREATE TABLE stuffs (id INTEGER PRIMARY KEY)")
            }
            
            let queue = dispatch_queue_create("GRDB", DISPATCH_QUEUE_CONCURRENT)
            let group = dispatch_group_create()
            
            // Queue 1
            dispatch_group_async(group, queue) {
                do {
                    try dbQueue1.inTransaction { db in
                        try db.execute("INSERT INTO stuffs (id) VALUES (NULL)")
                        dispatch_semaphore_signal(s1)
                        dispatch_semaphore_wait(s2, DISPATCH_TIME_FOREVER)
                        return .Commit
                    }
                }
                catch {
                    XCTFail("\(error)")
                }
                dispatch_semaphore_signal(s3)
            }
            
            // Queue 2
            var rows1: [Row]?
            var rows2: [Row]?
            dispatch_group_async(group, queue) {
                dbQueue2.inDatabase { db in
                    dispatch_semaphore_wait(s1, DISPATCH_TIME_FOREVER)
                    rows1 = Row.fetchAll(db, "SELECT * FROM stuffs")
                    dispatch_semaphore_signal(s2)
                    dispatch_semaphore_wait(s3, DISPATCH_TIME_FOREVER)
                    rows2 = Row.fetchAll(db, "SELECT * FROM stuffs")
                }
            }
            
            dispatch_group_wait(group, DISPATCH_TIME_FOREVER)
            
            XCTAssertEqual(rows1!.count, 0) // uncommitted changes are not visible
            XCTAssertEqual(rows2!.count, 1) // committed changes are visible
        }
    }
    
    func testReaderInDeferredTransactionDuringDefaultTransaction() {
        assertNoError {
            let dbQueue1 = try makeDatabaseQueue()
            #if GRDBCIPHER_USE_ENCRYPTION
                // Work around SQLCipher bug when two connections are open to the
                // same empty database: make sure the database is not empty before
                // running this test
                try dbQueue1.inDatabase { db in
                    try db.execute("CREATE TABLE SQLCipherWorkAround (foo INTEGER)")
                }
            #endif
            let dbQueue2 = try makeDatabaseQueue()
            
            // The `SELECT * FROM stuffs` statement of Queue 2 prevents Queue 1
            // from committing with SQLITE_BUSY.
            //
            // Without this select, the Queue 2 COMMIT succeeds right away.
            //
            // Both facts are unexpected.
            //
            //
            // Queue 1                              Queue 2
            // BEGIN IMMEDIATE TRANSACTION
            // INSERT INTO stuffs (id) VALUES (NULL)
            let s1 = dispatch_semaphore_create(0)
            //                                      BEGIN DEFERRED TRANSACTION
            //                                      SELECT * FROM stuffs
            let s2 = dispatch_semaphore_create(0)
            // COMMIT <--- Busy                     (Waiting)
            // COMMIT <--- Busy                     (Waiting)
            //                                      COMMIT
            // COMMIT
            
            var numberOfTries = 0
            self.busyCallback = { n in
                numberOfTries = n
                usleep(10_000) // 0.01s
                return true
            }
            
            try! dbQueue1.inDatabase { db in
                try db.execute("CREATE TABLE stuffs (id INTEGER PRIMARY KEY)")
            }
            
            let queue = dispatch_queue_create("GRDB", DISPATCH_QUEUE_CONCURRENT)
            let group = dispatch_group_create()
            
            // Queue 1
            dispatch_group_async(group, queue) {
                do {
                    try dbQueue1.inTransaction { db in
                        try db.execute("INSERT INTO stuffs (id) VALUES (NULL)")
                        dispatch_semaphore_signal(s1)
                        dispatch_semaphore_wait(s2, DISPATCH_TIME_FOREVER)
                        return .Commit
                    }
                }
                catch {
                    XCTFail("\(error)")
                }
            }
            
            // Queue 2
            dispatch_group_async(group, queue) {
                do {
                    dispatch_semaphore_wait(s1, DISPATCH_TIME_FOREVER)
                    try dbQueue2.inTransaction(.Deferred) { db in
                        _ = Row.fetchAll(db, "SELECT * FROM stuffs")
                        dispatch_semaphore_signal(s2)
                        usleep(100_000) // 0.1s
                        return .Commit
                    }
                }
                catch {
                    XCTFail("\(error)")
                }
            }
            
            dispatch_group_wait(group, DISPATCH_TIME_FOREVER)
            
            XCTAssertTrue(numberOfTries > 0)    // Busy handler has been used.
        }
    }
}
