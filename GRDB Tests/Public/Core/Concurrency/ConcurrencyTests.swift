import XCTest
import GRDB

class ConcurrencyTests: XCTestCase {
    var databasePath: String!
    var busyCallback: Database.BusyCallback?
    
    var dbQueue1: DatabaseQueue!
    var dbLog1: [String]!
    
    var dbQueue2: DatabaseQueue!
    var dbLog2: [String]!
    
    override func setUp() {
        super.setUp()
        
        databasePath = "/tmp/GRDBConcurrencyTests.sqlite"
        do { try NSFileManager.defaultManager().removeItemAtPath(databasePath) } catch { }
        let busyCallback: Database.BusyCallback = {
            if let busyCallback = self.busyCallback {
                return busyCallback(numberOfTries: $0)
            } else {
                // Default give up
                return false
            }
        }
        let baseConfiguration = Configuration(
            trace: Configuration.logSQL,
            busyMode: .Callback(busyCallback))
        
        dbLog1 = []
        var configuration1 = baseConfiguration
        configuration1.trace = { (sql, arguments) in
            NSLog("Queue 1: %@", sql)
            self.dbLog1.append(sql)
        }
        dbQueue1 = try! DatabaseQueue(path: databasePath, configuration: configuration1)
        
        dbLog2 = []
        var configuration2 = baseConfiguration
        configuration2.trace = { (sql, arguments) in
            NSLog("Queue 2: %@", sql)
            self.dbLog2.append(sql)
        }
        dbQueue2 = try! DatabaseQueue(path: databasePath, configuration: configuration2)
    }
    
    override func tearDown() {
        super.tearDown()
        dbQueue1 = nil
        dbQueue2 = nil
        try! NSFileManager.defaultManager().removeItemAtPath(databasePath)
    }

    func testDeferredTransactionConcurrency() {
        try! dbQueue1.inDatabase { db in
            try db.execute("CREATE TABLE stuffs (id INTEGER PRIMARY KEY)")
        }
        
        // Queue 1                              Queue 2
        // BEGIN DEFERRED TRANSACTION
        let s1 = dispatch_semaphore_create(0)
        //                                      BEGIN DEFERRED TRANSACTION
        let s2 = dispatch_semaphore_create(0)
        // INSERT INTO stuffs (id) VALUES (NULL)
        let s3 = dispatch_semaphore_create(0)
        // Error:                               INSERT INTO stuffs (id) VALUES (NULL)
        //                                      ROLLBACK
        let s4 = dispatch_semaphore_create(0)
        // COMMIT
        
        let queue = dispatch_queue_create("com.github.groue.GRDB", DISPATCH_QUEUE_CONCURRENT)
        let group = dispatch_group_create()
        
        // Queue 1
        dispatch_group_async(group, queue) {
            do {
                try self.dbQueue1.inTransaction(.Deferred) { db in
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
                try self.dbQueue2.inTransaction(.Deferred) { db in
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
            XCTAssertEqual(concurrencyError.code, Int(SQLITE_BUSY))
            XCTAssertEqual(concurrencyError.sql, "INSERT INTO stuffs (id) VALUES (NULL)")
        } else {
            XCTFail("Expected concurrency error")
        }
    }
    
    func testExclusiveTransactionConcurrency() {
        
        // Queue 1                              Queue 2
        // BEGIN EXCLUSIVE TRANSACTION
        let s1 = dispatch_semaphore_create(0)
        // Error:                               BEGIN EXCLUSIVE TRANSACTION
        let s2 = dispatch_semaphore_create(0)
        // COMMIT
        
        let queue = dispatch_queue_create("com.github.groue.GRDB", DISPATCH_QUEUE_CONCURRENT)
        let group = dispatch_group_create()
        
        // Queue 1
        dispatch_group_async(group, queue) {
            do {
                try self.dbQueue1.inTransaction(.Exclusive) { db in
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
                try self.dbQueue2.inTransaction(.Exclusive) { db in
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
            XCTAssertEqual(concurrencyError.code, Int(SQLITE_BUSY))
            XCTAssertEqual(concurrencyError.sql, "BEGIN EXCLUSIVE TRANSACTION")
        } else {
            XCTFail("Expected concurrency error")
        }
    }
    
    func testImmediateTransactionConcurrency() {
        
        // Queue 1                              Queue 2
        // BEGIN IMMEDIATE TRANSACTION
        let s1 = dispatch_semaphore_create(0)
        // Error:                               BEGIN IMMEDIATE TRANSACTION
        let s2 = dispatch_semaphore_create(0)
        // COMMIT
        
        let queue = dispatch_queue_create("com.github.groue.GRDB", DISPATCH_QUEUE_CONCURRENT)
        let group = dispatch_group_create()
        
        // Queue 1
        dispatch_group_async(group, queue) {
            do {
                try self.dbQueue1.inTransaction(.Immediate) { db in
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
                try self.dbQueue2.inTransaction(.Immediate) { db in
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
            XCTAssertEqual(concurrencyError.code, Int(SQLITE_BUSY))
            XCTAssertEqual(concurrencyError.sql, "BEGIN IMMEDIATE TRANSACTION")
        } else {
            XCTFail("Expected concurrency error")
        }
    }
    
    func testBusyCallback() {
        // Queue 1                              Queue 2
        // BEGIN EXCLUSIVE TRANSACTION
        let s1 = dispatch_semaphore_create(0)
        // Busy:                                BEGIN EXCLUSIVE TRANSACTION
        // COMMIT
        //                                      BEGIN EXCLUSIVE TRANSACTION
        //                                      COMMIT
        
        var numberOfTries = 0
        self.busyCallback = { n in
            numberOfTries = n
            usleep(10_000) // 0.01s
            return true
        }

        
        let queue = dispatch_queue_create("com.github.groue.GRDB", DISPATCH_QUEUE_CONCURRENT)
        let group = dispatch_group_create()
        
        // Queue 1
        dispatch_group_async(group, queue) {
            do {
                try self.dbQueue1.inTransaction(.Exclusive) { db in
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
                try self.dbQueue2.inTransaction(.Exclusive) { db in
                    return .Commit
                }
            }
            catch {
                XCTFail("\(error)")
            }
        }
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER)
        XCTAssertTrue(numberOfTries > 0)
    }

    func testReaderDoNotCrashDuringDefaultTransaction() {
        databasePath = "/tmp/GRDBTestReaderDuringDefaultTransaction.sqlite"
        do { try NSFileManager.defaultManager().removeItemAtPath(databasePath) } catch { }
        let dbQueue1 = try! DatabaseQueue(path: databasePath)
        let dbQueue2 = try! DatabaseQueue(path: databasePath)
        
        try! dbQueue1.inDatabase { db in
            try db.execute("CREATE TABLE stuffs (id INTEGER PRIMARY KEY)")
        }
        
        var rows: [Row] = []
        let queue = NSOperationQueue()
        queue.maxConcurrentOperationCount = 2
        queue.addOperation(NSBlockOperation {
            do {
                try dbQueue1.inTransaction { db in
                    try db.execute("INSERT INTO stuffs (id) VALUES (NULL)")
                    sleep(2)    // let other queue try to read.
                    return .Commit
                }
            }
            catch is DatabaseError {
            }
            catch {
                XCTFail("\(error)")
            }
            })
        
        queue.addOperation(NSBlockOperation {
            dbQueue2.inDatabase { db in
                sleep(1)    // let other queue write
                rows = Row.fetchAll(db, "SELECT * FROM stuffs")
            }
            })
        
        queue.waitUntilAllOperationsAreFinished()
        XCTAssertEqual(rows.count, 0)
    }
}
