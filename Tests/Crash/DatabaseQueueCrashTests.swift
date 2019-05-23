import XCTest
#if GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class DatabaseQueueCrashTests: GRDBCrashTestCase {
    
    
    // =========================================================================
    // MARK: - Reentrancy
    
    func testInDatabaseIsNotReentrant() {
        assertCrash("Database methods are not reentrant.") {
            dbQueue.inDatabase { db in
                dbQueue.inDatabase { db in
                }
            }
        }
    }
    
    func testInTransactionInsideInDatabaseIsNotReentrant() {
        assertCrash("Database methods are not reentrant.") {
            try dbQueue.inDatabase { db in
                try dbQueue.inTransaction { db in
                    return .commit
                }
            }
        }
    }
    
    func testInTransactionIsNotReentrant() {
        assertCrash("Database methods are not reentrant.") {
            try dbQueue.inTransaction { db in
                try dbQueue.inTransaction { db in
                    return .commit
                }
                return .commit
            }
        }
    }
    
    
    // =========================================================================
    // MARK: - Sequence iteration in wrong queue
    
    func testRowSequenceCanNotBeGeneratedOutsideOfDatabaseQueue() {
        assertCrash("Database was not used on the correct thread: execute your statements inside DatabaseQueue.inDatabase() or DatabaseQueue.inTransaction(). If you get this error while iterating the result of a fetch() method, consider using the array returned by fetchAll() instead.") {
            var rows: DatabaseSequence<Row>?
            try dbQueue.inDatabase { db in
                try db.execute(sql: "CREATE TABLE persons (name TEXT)")
                rows = try Row.fetch(db, "SELECT * FROM persons")
            }
            _ = rows!.makeIterator()
        }
    }
    
    func testRowSequenceCanNotBeIteratedOutsideOfDatabaseQueue() {
        assertCrash("Database was not used on the correct thread: execute your statements inside DatabaseQueue.inDatabase() or DatabaseQueue.inTransaction(). If you get this error while iterating the result of a fetch() method, consider using the array returned by fetchAll() instead.") {
            var iterator: DatabaseIterator<Row>?
            try dbQueue.inDatabase { db in
                try db.execute(sql: "CREATE TABLE persons (name TEXT)")
                iterator = try Row.fetch(db, "SELECT * FROM persons").makeIterator()
            }
            _ = iterator!.next()
        }
    }
    

    // =========================================================================
    // MARK: - Concurrency
    
    func testReaderCrashDuringExclusiveTransaction() {
        assertCrash("SQLite error 5 with statement `SELECT * FROM stuffs`: database is locked") {
            let dbQueue1 = try! makeDatabaseQueue(path: dbQueuepath, configuration: dbConfiguration)
            let dbQueue2 = try! makeDatabaseQueue(path: dbQueuepath, configuration: dbConfiguration)
            
            try! dbQueue1.inDatabase { db in
                try db.execute(sql: "CREATE TABLE stuffs (id INTEGER PRIMARY KEY)")
            }
            
            let queue = NSOperationQueue()
            queue.maxConcurrentOperationCount = 2
            queue.addOperation(NSBlockOperation {
                do {
                    try dbQueue1.inTransaction(.exclusive) { db in
                        sleep(2)    // let other queue try to read.
                        return .commit
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
                    sleep(1)    // let other queue open transaction
                    _ = try Row.fetch(db, "SELECT * FROM stuffs")   // Crash expected
                }
                })
            
            queue.waitUntilAllOperationsAreFinished()
        }
    }
}
