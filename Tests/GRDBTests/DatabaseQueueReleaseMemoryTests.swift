import XCTest
@testable import GRDB

class DatabaseQueueReleaseMemoryTests: GRDBTestCase {
    
    func testDatabaseQueueDeinitClosesConnection() throws {
        let openConnectionCountMutex = Mutex(0)
        let totalOpenConnectionCountMutex = Mutex(0)
        
        dbConfiguration.onConnectionDidOpen {
            totalOpenConnectionCountMutex.increment()
            openConnectionCountMutex.increment()
        }
        
        dbConfiguration.onConnectionDidClose {
            openConnectionCountMutex.decrement()
        }
        
        do {
            // Open & release connection
            _ = try makeDatabaseQueue()
        }
        
        // One reader, one writer
        XCTAssertEqual(totalOpenConnectionCountMutex.load(), 1)
        
        // All connections are closed
        XCTAssertEqual(openConnectionCountMutex.load(), 0)
    }
    
    func testBlocksRetainConnection() throws {
        let openConnectionCountMutex = Mutex(0)
        let totalOpenConnectionCountMutex = Mutex(0)
        
        dbConfiguration.onConnectionDidOpen {
            totalOpenConnectionCountMutex.increment()
            openConnectionCountMutex.increment()
        }
        
        dbConfiguration.onConnectionDidClose {
            openConnectionCountMutex.decrement()
        }
        
        // Block 1                  Block 2
        //                          inDatabase {
        //                              >
        let s1 = DispatchSemaphore(value: 0)
        // dbQueue = nil
        // >
        let s2 = DispatchSemaphore(value: 0)
        //                              use database
        //                          }
        
        let (block1, block2) = { () -> (() -> (), () -> ()) in
            var dbQueue: DatabaseQueue? = try! self.makeDatabaseQueue()
            try! dbQueue!.write { db in
                try db.execute(sql: "CREATE TABLE items (id INTEGER PRIMARY KEY)")
            }
            
            let block1 = { () in
                _ = s1.wait(timeout: .distantFuture)
                dbQueue = nil
                s2.signal()
            }
            let block2 = { [weak dbQueue] () in
                if let dbQueue {
                    try! dbQueue.write { db in
                        s1.signal()
                        _ = s2.wait(timeout: .distantFuture)
                        XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM items"), 0)
                    }
                } else {
                    XCTFail("expect non nil dbQueue")
                }
            }
            return (block1, block2)
        }()
        let blocks = [block1, block2]
        DispatchQueue.concurrentPerform(iterations: blocks.count) { index in
            blocks[index]()
        }
        
        // one writer
        XCTAssertEqual(totalOpenConnectionCountMutex.load(), 1)
        
        // All connections are closed
        XCTAssertEqual(openConnectionCountMutex.load(), 0)
    }
    
    func testStatementDoNotRetainDatabaseConnection() throws {
        // Block 1                  Block 2
        //                          create statement INSERT
        //                          >
        let s1 = DispatchSemaphore(value: 0)
        // dbQueue = nil
        // >
        let s2 = DispatchSemaphore(value: 0)
        //                          dbQueue is nil
        
        let (block1, block2) = { () -> (() -> (), () -> ()) in
            var dbQueue: DatabaseQueue? = try! self.makeDatabaseQueue()
            
            let block1 = { () in
                _ = s1.wait(timeout: .distantFuture)
                dbQueue = nil
                s2.signal()
            }
            let block2 = { [weak dbQueue] () in
                var statement: Statement? = nil
                do {
                    if let dbQueue {
                        do {
                            try dbQueue.write { db in
                                statement = try db.makeStatement(sql: "CREATE TABLE items (id INTEGER PRIMARY KEY)")
                                s1.signal()
                            }
                        } catch {
                            XCTFail("error: \(error)")
                        }
                    } else {
                        XCTFail("expect non nil dbQueue")
                    }
                }
                _ = s2.wait(timeout: .distantFuture)
                XCTAssertTrue(statement != nil)
                XCTAssertTrue(dbQueue == nil)
            }
            return (block1, block2)
        }()
        let blocks = [block1, block2]
        DispatchQueue.concurrentPerform(iterations: blocks.count) { index in
            blocks[index]()
        }
    }
}
