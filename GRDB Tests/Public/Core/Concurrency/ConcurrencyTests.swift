import XCTest
import GRDB

class ConcurrencyTests: XCTestCase {
    var databasePath: String!
    var dbQueue1: DatabaseQueue!
    var dbQueue2: DatabaseQueue!
    var busyCallback: Database.BusyCallback?
    
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
        let configuration = Configuration(
            trace: Configuration.logSQL,
            busyMode: .Callback(busyCallback))
        dbQueue1 = try! DatabaseQueue(path: databasePath, configuration: configuration)
        dbQueue2 = try! DatabaseQueue(path: databasePath, configuration: configuration)
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
        
        var concurrencyError: DatabaseError? = nil
        
        let queue = NSOperationQueue()
        queue.maxConcurrentOperationCount = 2
        queue.addOperation(NSBlockOperation {
            do {
                try self.dbQueue1.inTransaction(.Deferred) { db in
                    sleep(1)    // make sure other transaction is opened
                    try db.execute("INSERT INTO stuffs (id) VALUES (NULL)")
                    sleep(1)    // let other transaction try to update database
                    return .Commit
                }
            }
            catch let error as DatabaseError {
                concurrencyError = error
            }
            catch {
                XCTFail("\(error)")
            }
            })

        queue.addOperation(NSBlockOperation {
            do {
                try self.dbQueue2.inTransaction(.Deferred) { db in
                    sleep(1)    // make sure other transaction is opened
                    try db.execute("INSERT INTO stuffs (id) VALUES (NULL)")
                    sleep(1)    // let other transaction try to update database
                    return .Commit
                }
            }
            catch let error as DatabaseError {
                concurrencyError = error
            }
            catch {
                XCTFail("\(error)")
            }
            })
        
        queue.waitUntilAllOperationsAreFinished()
        
        if let concurrencyError = concurrencyError {
            XCTAssertEqual(concurrencyError.code, Int(SQLITE_BUSY))
            XCTAssertEqual(concurrencyError.sql, "INSERT INTO stuffs (id) VALUES (NULL)")
        } else {
            XCTFail("Expected concurrency error")
        }
    }
    
    func testExclusiveTransactionConcurrency() {
        var concurrencyError: DatabaseError? = nil
        
        let queue = NSOperationQueue()
        queue.maxConcurrentOperationCount = 2
        queue.addOperation(NSBlockOperation {
            do {
                try self.dbQueue1.inTransaction(.Exclusive) { db in
                    sleep(1)    // let other queue try to open transaction
                    return .Commit
                }
            }
            catch let error as DatabaseError {
                concurrencyError = error
            }
            catch {
                XCTFail("\(error)")
            }
            })
        
        queue.addOperation(NSBlockOperation {
            do {
                try self.dbQueue2.inTransaction(.Exclusive) { db in
                    sleep(1)    // let other queue try to open transaction
                    return .Commit
                }
            }
            catch let error as DatabaseError {
                concurrencyError = error
            }
            catch {
                XCTFail("\(error)")
            }
            })
        
        queue.waitUntilAllOperationsAreFinished()
        
        if let concurrencyError = concurrencyError {
            XCTAssertEqual(concurrencyError.code, Int(SQLITE_BUSY))
            XCTAssertEqual(concurrencyError.sql, "BEGIN EXCLUSIVE TRANSACTION")
        } else {
            XCTFail("Expected concurrency error")
        }
    }
    
    func testImmediateTransactionConcurrency() {
        var concurrencyError: DatabaseError? = nil
        
        let queue = NSOperationQueue()
        queue.maxConcurrentOperationCount = 2
        queue.addOperation(NSBlockOperation {
            do {
                try self.dbQueue1.inTransaction(.Immediate) { db in
                    sleep(1)    // let other queue try to open transaction
                    return .Commit
                }
            }
            catch let error as DatabaseError {
                concurrencyError = error
            }
            catch {
                XCTFail("\(error)")
            }
            })
        
        queue.addOperation(NSBlockOperation {
            do {
                try self.dbQueue2.inTransaction(.Immediate) { db in
                    sleep(1)    // let other queue try to open transaction
                    return .Commit
                }
            }
            catch let error as DatabaseError {
                concurrencyError = error
            }
            catch {
                XCTFail("\(error)")
            }
            })
        
        queue.waitUntilAllOperationsAreFinished()
        
        if let concurrencyError = concurrencyError {
            XCTAssertEqual(concurrencyError.code, Int(SQLITE_BUSY))
            XCTAssertEqual(concurrencyError.sql, "BEGIN IMMEDIATE TRANSACTION")
        } else {
            XCTFail("Expected concurrency error")
        }
    }
    
    func testBusyCallback() {
        self.busyCallback = { numberOfTries in
            // Just wait until lock is released.
            sleep(1)
            return true
        }

        var concurrencyError: DatabaseError? = nil
        
        let queue = NSOperationQueue()
        queue.maxConcurrentOperationCount = 2
        queue.addOperation(NSBlockOperation {
            do {
                try self.dbQueue1.inTransaction(.Exclusive) { db in
                    sleep(1)    // let other queue try to open transaction
                    return .Commit
                }
            }
            catch let error as DatabaseError {
                concurrencyError = error
            }
            catch {
                XCTFail("\(error)")
            }
            })
        
        queue.addOperation(NSBlockOperation {
            do {
                try self.dbQueue2.inTransaction(.Exclusive) { db in
                    sleep(1)    // let other queue try to open transaction
                    return .Commit
                }
            }
            catch let error as DatabaseError {
                concurrencyError = error
            }
            catch {
                XCTFail("\(error)")
            }
            })
        
        queue.waitUntilAllOperationsAreFinished()
        XCTAssertTrue(concurrencyError == nil)
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
