import XCTest
@testable import GRDB

class DatabaseQueueuReleaseMemoryTests: GRDBTestCase {
    
    func testDatabaseQueueuDeinitClosesConnection() {
        assertNoError {
            let countQueue = dispatch_queue_create(nil, nil)
            var openConnectionCount = 0
            var totalOpenConnectionCount = 0
            
            dbConfiguration.SQLiteConnectionDidOpen = {
                dispatch_sync(countQueue) {
                    totalOpenConnectionCount += 1
                    openConnectionCount += 1
                }
            }
            
            dbConfiguration.SQLiteConnectionDidClose = {
                dispatch_sync(countQueue) {
                    openConnectionCount -= 1
                }
            }
            
            // Open connection
            try dbQueue.execute("CREATE TABLE items (id INTEGER PRIMARY KEY)")
            
            // Release
            dbQueue = nil
            
            // One reader, one writer
            XCTAssertEqual(totalOpenConnectionCount, 1)
            
            // All connections are closed
            XCTAssertEqual(openConnectionCount, 0)
        }
    }
    
    func testBlocksRetainConnection() {
        assertNoError {
            let countQueue = dispatch_queue_create(nil, nil)
            var openConnectionCount = 0
            var totalOpenConnectionCount = 0
            
            dbConfiguration.SQLiteConnectionDidOpen = {
                dispatch_sync(countQueue) {
                    totalOpenConnectionCount += 1
                    openConnectionCount += 1
                }
            }
            
            dbConfiguration.SQLiteConnectionDidClose = {
                dispatch_sync(countQueue) {
                    openConnectionCount -= 1
                }
            }
            
            try self.dbQueue.execute("CREATE TABLE items (id INTEGER PRIMARY KEY)")
            
            // Block 1                  Block 2
            //                          inDatabase {
            //                              >
            let s1 = dispatch_semaphore_create(0)
            // dbQueue = nil
            // >
            let s2 = dispatch_semaphore_create(0)
            //                              use database
            //                          }
            
            let (block1, block2) = { () -> (() -> (), () -> ()) in
                let block1 = { () in
                    dispatch_semaphore_wait(s1, DISPATCH_TIME_FOREVER)
                    self.dbQueue = nil
                    dispatch_semaphore_signal(s2)
                }
                let dbQueue = self.dbQueue
                let block2 = { [weak dbQueue] () in
                    if let dbQueue = dbQueue {
                        dbQueue.write { db in
                            dispatch_semaphore_signal(s1)
                            dispatch_semaphore_wait(s2, DISPATCH_TIME_FOREVER)
                            XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM items"), 0)
                        }
                    } else {
                        XCTFail("expect non nil dbQueue")
                    }
                }
                return (block1, block2)
            }()
            let queue = dispatch_queue_create(nil, DISPATCH_QUEUE_CONCURRENT)
            let blocks = [block1, block2]
            dispatch_apply(blocks.count, queue) { index in
                blocks[index]()
            }
            
            // one writer
            XCTAssertEqual(totalOpenConnectionCount, 1)
            
            // All connections are closed
            XCTAssertEqual(openConnectionCount, 0)
        }
    }
    
    func testDatabaseGeneratorRetainConnection() {
        assertNoError {
            let countQueue = dispatch_queue_create(nil, nil)
            var openConnectionCount = 0
            var totalOpenConnectionCount = 0
            
            dbConfiguration.SQLiteConnectionDidOpen = {
                dispatch_sync(countQueue) {
                    totalOpenConnectionCount += 1
                    openConnectionCount += 1
                }
            }
            
            dbConfiguration.SQLiteConnectionDidClose = {
                dispatch_sync(countQueue) {
                    openConnectionCount -= 1
                }
            }
            
            try self.dbQueue.execute("CREATE TABLE items (id INTEGER PRIMARY KEY)")
            try self.dbQueue.execute("INSERT INTO items (id) VALUES (NULL)")
            try self.dbQueue.execute("INSERT INTO items (id) VALUES (NULL)")
            
            // Block 1                  Block 2
            //                          write {
            //                              SELECT
            //                              step
            //                              >
            let s1 = dispatch_semaphore_create(0)
            // dbQueue = nil
            // >
            let s2 = dispatch_semaphore_create(0)
            //                              step
            //                              end
            //                          }
            
            let (block1, block2) = { () -> (() -> (), () -> ()) in
                let block1 = { () in
                    dispatch_semaphore_wait(s1, DISPATCH_TIME_FOREVER)
                    self.dbQueue = nil
                    dispatch_semaphore_signal(s2)
                }
                let dbQueue = self.dbQueue
                let block2 = { [weak dbQueue] () in
                    weak var connection: Database? = nil
                    var generator: DatabaseGenerator<Int>? = nil
                    do {
                        if let dbQueue = dbQueue {
                            dbQueue.write { db in
                                connection = db
                                generator = Int.fetch(db, "SELECT id FROM items").generate()
                                XCTAssertTrue(generator!.next() != nil)
                                dispatch_semaphore_signal(s1)
                            }
                        } else {
                            XCTFail("expect non nil dbQueue")
                        }
                    }
                    dispatch_semaphore_wait(s2, DISPATCH_TIME_FOREVER)
                    do {
                        XCTAssertTrue(dbQueue == nil)
                        XCTAssertTrue(generator!.next() != nil)
                        XCTAssertTrue(generator!.next() == nil)
                        generator = nil
                        XCTAssertTrue(connection == nil)
                    }
                }
                return (block1, block2)
            }()
            let queue = dispatch_queue_create(nil, DISPATCH_QUEUE_CONCURRENT)
            let blocks = [block1, block2]
            dispatch_apply(blocks.count, queue) { index in
                blocks[index]()
            }
            
            // one writer
            XCTAssertEqual(totalOpenConnectionCount, 1)
            
            // All connections are closed
            XCTAssertEqual(openConnectionCount, 0)
        }
    }
    
    func testStatementDoNotRetainDatabaseConnection() {
        assertNoError {
            // Block 1                  Block 2
            //                          create statement INSERT
            //                          >
            let s1 = dispatch_semaphore_create(0)
            // dbQueue = nil
            // >
            let s2 = dispatch_semaphore_create(0)
            //                          dbQueue is nil
            
            let (block1, block2) = { () -> (() -> (), () -> ()) in
                let block1 = { () in
                    dispatch_semaphore_wait(s1, DISPATCH_TIME_FOREVER)
                    self.dbQueue = nil
                    dispatch_semaphore_signal(s2)
                }
                let dbQueue = self.dbQueue
                let block2 = { [weak dbQueue] () in
                    var statement: UpdateStatement? = nil
                    do {
                        if let dbQueue = dbQueue {
                            do {
                                try dbQueue.write { db in
                                    statement = try db.updateStatement("CREATE TABLE items (id INTEGER PRIMARY KEY)")
                                    dispatch_semaphore_signal(s1)
                                }
                            } catch {
                                XCTFail("error: \(error)")
                            }
                        } else {
                            XCTFail("expect non nil dbQueue")
                        }
                    }
                    dispatch_semaphore_wait(s2, DISPATCH_TIME_FOREVER)
                    XCTAssertTrue(statement != nil)
                    XCTAssertTrue(dbQueue == nil)
                }
                return (block1, block2)
            }()
            let queue = dispatch_queue_create(nil, DISPATCH_QUEUE_CONCURRENT)
            let blocks = [block1, block2]
            dispatch_apply(blocks.count, queue) { index in
                blocks[index]()
            }
        }
    }
}
