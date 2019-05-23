import XCTest
#if GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class ConcurrencyTests: GRDBTestCase {
    var busyCallback: Database.BusyCallback?
    
    override func setUp() {
        super.setUp()
        
        self.busyCallback = nil
        let busyCallback: Database.BusyCallback = { numberOfTries in
            if let busyCallback = self.busyCallback {
                return busyCallback(numberOfTries)
            } else {
                // Default give up
                return false
            }
        }
        
        dbConfiguration.busyMode = .callback(busyCallback)
    }
    
    func testWrappedReadWrite() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(sql: "CREATE TABLE items (id INTEGER PRIMARY KEY)")
            try db.execute(sql: "INSERT INTO items (id) VALUES (NULL)")
        }
        let id = try dbQueue.inDatabase { db in
            try Int.fetchOne(db, sql: "SELECT id FROM items")!
        }
        XCTAssertEqual(id, 1)
    }

    func testDeferredTransactionConcurrency() throws {
        let dbQueue1 = try makeDatabaseQueue(filename: "test.sqlite")
        #if GRDBCIPHER_USE_ENCRYPTION
            // Work around SQLCipher bug when two connections are open to the
            // same empty database: make sure the database is not empty before
            // running this test
            try dbQueue1.inDatabase { db in
                try db.execute(sql: "CREATE TABLE SQLCipherWorkAround (foo INTEGER)")
            }
        #endif
        let dbQueue2 = try makeDatabaseQueue(filename: "test.sqlite")
        
        // Queue 1                              Queue 2
        // BEGIN DEFERRED TRANSACTION
        let s1 = DispatchSemaphore(value: 0)
        //                                      BEGIN DEFERRED TRANSACTION
        let s2 = DispatchSemaphore(value: 0)
        // INSERT INTO stuffs (id) VALUES (NULL)
        let s3 = DispatchSemaphore(value: 0)
        //                                      INSERT INTO stuffs (id) VALUES (NULL) <--- Error
        //                                      ROLLBACK
        let s4 = DispatchSemaphore(value: 0)
        // COMMIT
        
        try dbQueue1.inDatabase { db in
            try db.execute(sql: "CREATE TABLE stuffs (id INTEGER PRIMARY KEY)")
        }
        
        let queue = DispatchQueue(label: "GRDB", attributes: [.concurrent])
        let group = DispatchGroup()
        
        // Queue 1
        queue.async(group: group) {
            do {
                try dbQueue1.inTransaction(.deferred) { db in
                    s1.signal()
                    _ = s2.wait(timeout: .distantFuture)
                    try db.execute(sql: "INSERT INTO stuffs (id) VALUES (NULL)")
                    s3.signal()
                    _ = s4.wait(timeout: .distantFuture)
                    return .commit
                }
            }
            catch {
                XCTFail("\(error)")
            }
        }
        
        // Queue 2
        var concurrencyError: DatabaseError? = nil
        queue.async(group: group) {
            do {
                _ = s1.wait(timeout: .distantFuture)
                try dbQueue2.inTransaction(.deferred) { db in
                    s2.signal()
                    _ = s3.wait(timeout: .distantFuture)
                    try db.execute(sql: "INSERT INTO stuffs (id) VALUES (NULL)")
                    return .commit
                }
            }
            catch let error as DatabaseError {
                s4.signal()
                concurrencyError = error
            }
            catch {
                XCTFail("\(error)")
            }
        }
        
        _ = group.wait(timeout: .distantFuture)
        
        if let concurrencyError = concurrencyError {
            XCTAssertEqual(concurrencyError.resultCode, .SQLITE_BUSY)
            XCTAssertEqual(concurrencyError.sql, "INSERT INTO stuffs (id) VALUES (NULL)")
        } else {
            XCTFail("Expected concurrency error")
        }
    }

    func testExclusiveTransactionConcurrency() throws {
        let dbQueue1 = try makeDatabaseQueue(filename: "test.sqlite")
        let dbQueue2 = try makeDatabaseQueue(filename: "test.sqlite")
        
        // Queue 1                              Queue 2
        // BEGIN EXCLUSIVE TRANSACTION
        let s1 = DispatchSemaphore(value: 0)
        //                                      BEGIN EXCLUSIVE TRANSACTION <--- Error
        let s2 = DispatchSemaphore(value: 0)
        // COMMIT
        
        let queue = DispatchQueue(label: "GRDB", attributes: [.concurrent])
        let group = DispatchGroup()
        
        // Queue 1
        queue.async(group: group) {
            do {
                try dbQueue1.inTransaction(.exclusive) { db in
                    s1.signal()
                    _ = s2.wait(timeout: .distantFuture)
                    return .commit
                }
            }
            catch {
                XCTFail("\(error)")
            }
        }
        
        // Queue 2
        var concurrencyError: DatabaseError? = nil
        queue.async(group: group) {
            do {
                _ = s1.wait(timeout: .distantFuture)
                try dbQueue2.inTransaction(.exclusive) { db in
                    return .commit
                }
            }
            catch let error as DatabaseError {
                s2.signal()
                concurrencyError = error
            }
            catch {
                XCTFail("\(error)")
            }
        }
        
        _ = group.wait(timeout: .distantFuture)
        
        if let concurrencyError = concurrencyError {
            XCTAssertEqual(concurrencyError.resultCode, .SQLITE_BUSY)
            XCTAssertEqual(concurrencyError.sql, "BEGIN EXCLUSIVE TRANSACTION")
        } else {
            XCTFail("Expected concurrency error")
        }
    }

    func testImmediateTransactionConcurrency() throws {
        let dbQueue1 = try makeDatabaseQueue(filename: "test.sqlite")
        let dbQueue2 = try makeDatabaseQueue(filename: "test.sqlite")
        
        // Queue 1                              Queue 2
        // BEGIN IMMEDIATE TRANSACTION
        let s1 = DispatchSemaphore(value: 0)
        //                                      BEGIN IMMEDIATE TRANSACTION <--- Error
        let s2 = DispatchSemaphore(value: 0)
        // COMMIT
        
        let queue = DispatchQueue(label: "GRDB", attributes: [.concurrent])
        let group = DispatchGroup()
        
        // Queue 1
        queue.async(group: group) {
            do {
                try dbQueue1.inTransaction(.immediate) { db in
                    s1.signal()
                    _ = s2.wait(timeout: .distantFuture)
                    return .commit
                }
            }
            catch {
                XCTFail("\(error)")
            }
        }
        
        // Queue 2
        var concurrencyError: DatabaseError? = nil
        queue.async(group: group) {
            do {
                _ = s1.wait(timeout: .distantFuture)
                try dbQueue2.inTransaction(.immediate) { db in
                    return .commit
                }
            }
            catch let error as DatabaseError {
                s2.signal()
                concurrencyError = error
            }
            catch {
                XCTFail("\(error)")
            }
        }
        
        _ = group.wait(timeout: .distantFuture)
        
        if let concurrencyError = concurrencyError {
            XCTAssertEqual(concurrencyError.resultCode, .SQLITE_BUSY)
            XCTAssertEqual(concurrencyError.sql, "BEGIN IMMEDIATE TRANSACTION")
        } else {
            XCTFail("Expected concurrency error")
        }
    }

    func testBusyCallback() throws {
        let dbQueue1 = try makeDatabaseQueue(filename: "test.sqlite")
        #if GRDBCIPHER_USE_ENCRYPTION
            // Work around SQLCipher bug when two connections are open to the
            // same empty database: make sure the database is not empty before
            // running this test
            try dbQueue1.inDatabase { db in
                try db.execute(sql: "CREATE TABLE SQLCipherWorkAround (foo INTEGER)")
            }
        #endif
        let dbQueue2 = try makeDatabaseQueue(filename: "test.sqlite")
        
        // Queue 1                              Queue 2
        // BEGIN EXCLUSIVE TRANSACTION
        let s1 = DispatchSemaphore(value: 0)
        //                                      BEGIN EXCLUSIVE TRANSACTION <--- Busy
        let s2 = DispatchSemaphore(value: 0)
        // COMMIT
        //                                      BEGIN EXCLUSIVE TRANSACTION
        //                                      COMMIT
        
        var busyCallbackCalled = false
        self.busyCallback = { n in
            busyCallbackCalled = true
            s2.signal()
            return true
        }
        
        let queue = DispatchQueue(label: "GRDB", attributes: [.concurrent])
        let group = DispatchGroup()
        
        // Queue 1
        queue.async(group: group) {
            do {
                try dbQueue1.inTransaction(.exclusive) { db in
                    s1.signal()
                    _ = s2.wait(timeout: .distantFuture)
                    return .commit
                }
            }
            catch {
                XCTFail("\(error)")
            }
        }
        
        // Queue 2
        queue.async(group: group) {
            do {
                _ = s1.wait(timeout: .distantFuture)
                try dbQueue2.inTransaction(.exclusive) { db in
                    return .commit
                }
            }
            catch {
                XCTFail("\(error)")
            }
        }
        
        _ = group.wait(timeout: .distantFuture)
        
        XCTAssertTrue(busyCallbackCalled)
    }

    func testReaderDuringDefaultTransaction() throws {
        let dbQueue1 = try makeDatabaseQueue(filename: "test.sqlite")
        #if GRDBCIPHER_USE_ENCRYPTION
            // Work around SQLCipher bug when two connections are open to the
            // same empty database: make sure the database is not empty before
            // running this test
            try dbQueue1.inDatabase { db in
                try db.execute(sql: "CREATE TABLE SQLCipherWorkAround (foo INTEGER)")
            }
        #endif
        let dbQueue2 = try makeDatabaseQueue(filename: "test.sqlite")
        
        // Here we test that a reader can read while a writer is writing.
        
        // Queue 1                              Queue 2
        // BEGIN IMMEDIATE TRANSACTION
        // INSERT INTO stuffs (id) VALUES (NULL)
        let s1 = DispatchSemaphore(value: 0)
        //                                      SELECT * FROM stuffs <--- 0 result
        let s2 = DispatchSemaphore(value: 0)
        // COMMIT
        let s3 = DispatchSemaphore(value: 0)
        //                                      SELECT * FROM stuffs <--- 1 result
        
        try dbQueue1.inDatabase { db in
            try db.execute(sql: "CREATE TABLE stuffs (id INTEGER PRIMARY KEY)")
        }
        
        let queue = DispatchQueue(label: "GRDB", attributes: [.concurrent])
        let group = DispatchGroup()
        
        // Queue 1
        queue.async(group: group) {
            do {
                try dbQueue1.inTransaction { db in
                    try db.execute(sql: "INSERT INTO stuffs (id) VALUES (NULL)")
                    s1.signal()
                    _ = s2.wait(timeout: .distantFuture)
                    return .commit
                }
            }
            catch {
                XCTFail("\(error)")
            }
            s3.signal()
        }
        
        // Queue 2
        var rows1: [Row]?
        var rows2: [Row]?
        queue.async(group: group) {
            try! dbQueue2.writeWithoutTransaction { db in
                _ = s1.wait(timeout: .distantFuture)
                rows1 = try Row.fetchAll(db, sql: "SELECT * FROM stuffs")
                s2.signal()
                _ = s3.wait(timeout: .distantFuture)
                rows2 = try Row.fetchAll(db, sql: "SELECT * FROM stuffs")
            }
        }
        
        _ = group.wait(timeout: .distantFuture)
        
        XCTAssertEqual(rows1!.count, 0) // uncommitted changes are not visible
        XCTAssertEqual(rows2!.count, 1) // committed changes are visible
    }

    func testReaderInDeferredTransactionDuringDefaultTransaction() throws {
        let dbQueue1 = try makeDatabaseQueue(filename: "test.sqlite")
        #if GRDBCIPHER_USE_ENCRYPTION
            // Work around SQLCipher bug when two connections are open to the
            // same empty database: make sure the database is not empty before
            // running this test
            try dbQueue1.inDatabase { db in
                try db.execute(sql: "CREATE TABLE SQLCipherWorkAround (foo INTEGER)")
            }
        #endif
        let dbQueue2 = try makeDatabaseQueue(filename: "test.sqlite")
        
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
        let s1 = DispatchSemaphore(value: 0)
        //                                      BEGIN DEFERRED TRANSACTION
        //                                      SELECT * FROM stuffs
        let s2 = DispatchSemaphore(value: 0)
        // COMMIT <--- Busy
        let s3 = DispatchSemaphore(value: 0)
        //                                      COMMIT
        // COMMIT
        
        var busyCallbackCalled = false
        self.busyCallback = { n in
            busyCallbackCalled = true
            s3.signal()
            return true
        }
        
        try dbQueue1.inDatabase { db in
            try db.execute(sql: "CREATE TABLE stuffs (id INTEGER PRIMARY KEY)")
        }
        
        let queue = DispatchQueue(label: "GRDB", attributes: [.concurrent])
        let group = DispatchGroup()
        
        // Queue 1
        queue.async(group: group) {
            do {
                try dbQueue1.inTransaction { db in
                    try db.execute(sql: "INSERT INTO stuffs (id) VALUES (NULL)")
                    s1.signal()
                    _ = s2.wait(timeout: .distantFuture)
                    return .commit
                }
            }
            catch {
                XCTFail("\(error)")
            }
        }
        
        // Queue 2
        queue.async(group: group) {
            do {
                _ = s1.wait(timeout: .distantFuture)
                try dbQueue2.inTransaction(.deferred) { db in
                    _ = try Row.fetchAll(db, sql: "SELECT * FROM stuffs")
                    s2.signal()
                    _ = s3.wait(timeout: .distantFuture)
                    return .commit
                }
            }
            catch {
                XCTFail("\(error)")
            }
        }
        
        _ = group.wait(timeout: .distantFuture)
        
        XCTAssertTrue(busyCallbackCalled)
    }
}
