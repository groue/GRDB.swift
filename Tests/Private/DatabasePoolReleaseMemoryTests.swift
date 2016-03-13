import XCTest
@testable import GRDB

class DatabasePoolReleaseMemoryTests: GRDBTestCase {
    
    func testDatabasePoolDeinitClosesAllConnections() {
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
            
            // write & read
            
            try dbPool.execute("CREATE TABLE items (id INTEGER PRIMARY KEY)")
            for _ in 0..<2 {
                try dbPool.execute("INSERT INTO items (id) VALUES (NULL)")
            }
            _ = Int.fetchOne(dbPool, "SELECT COUNT(*) FROM items")
            
            // Release
            dbPool = nil
            
            // One reader, one writer
            XCTAssertEqual(totalOpenConnectionCount, 2)
            
            // All connections are closed
            XCTAssertEqual(openConnectionCount, 0)
        }
    }
    
    func testDatabasePoolReleaseMemoryClosesReaderConnections() {
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
            
            try dbPool.execute("CREATE TABLE items (id INTEGER PRIMARY KEY)")
            for _ in 0..<2 {
                try dbPool.execute("INSERT INTO items (id) VALUES (NULL)")
            }
            
            // Block 1                  Block 2                 Block3
            // SELECT * FROM items
            // step
            // >
            let s1 = dispatch_semaphore_create(0)
            //                          SELECT * FROM items
            //                          step
            //                          >
            let s2 = dispatch_semaphore_create(0)
            // step                     step
            // >
            let s3 = dispatch_semaphore_create(0)
            // end                      end                     releaseMemory
            
            let block1 = { () in
                self.dbPool.read { db in
                    let generator = Row.fetch(db, "SELECT * FROM items").generate()
                    XCTAssertTrue(generator.next() != nil)
                    dispatch_semaphore_signal(s1)
                    dispatch_semaphore_wait(s2, DISPATCH_TIME_FOREVER)
                    XCTAssertTrue(generator.next() != nil)
                    dispatch_semaphore_signal(s3)
                    XCTAssertTrue(generator.next() == nil)
                }
            }
            let block2 = { () in
                dispatch_semaphore_wait(s1, DISPATCH_TIME_FOREVER)
                self.dbPool.read { db in
                    let generator = Row.fetch(db, "SELECT * FROM items").generate()
                    XCTAssertTrue(generator.next() != nil)
                    dispatch_semaphore_signal(s2)
                    XCTAssertTrue(generator.next() != nil)
                    XCTAssertTrue(generator.next() == nil)
                }
            }
            let block3 = { () in
                dispatch_semaphore_wait(s3, DISPATCH_TIME_FOREVER)
                self.dbPool.releaseMemory()
            }
            let queue = dispatch_queue_create(nil, DISPATCH_QUEUE_CONCURRENT)
            dispatch_apply(3, queue) { index in
                [block1, block2, block3][index]()
            }
            
            // Two readers, one writer
            XCTAssertEqual(totalOpenConnectionCount, 3)
            
            // Writer is still open
            XCTAssertEqual(openConnectionCount, 1)
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
            
            try self.dbPool.execute("CREATE TABLE items (id INTEGER PRIMARY KEY)")
            
            // Block 1                  Block 2
            //                          read {
            //                              >
            let s1 = dispatch_semaphore_create(0)
            // dbPool = nil
            // >
            let s2 = dispatch_semaphore_create(0)
            //                              use database
            //                          }
            
            let (block1, block2) = { () -> (() -> (), () -> ()) in
                let block1 = { () in
                    dispatch_semaphore_wait(s1, DISPATCH_TIME_FOREVER)
                    self.dbPool = nil
                    dispatch_semaphore_signal(s2)
                }
                let dbPool = self.dbPool
                let block2 = { [weak dbPool] () in
                    if let dbPool = dbPool {
                        dbPool.read { db in
                            dispatch_semaphore_signal(s1)
                            dispatch_semaphore_wait(s2, DISPATCH_TIME_FOREVER)
                            XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM items"), 0)
                        }
                    } else {
                        XCTFail("expect non nil dbPool")
                    }
                }
                return (block1, block2)
            }()
            let queue = dispatch_queue_create(nil, DISPATCH_QUEUE_CONCURRENT)
            let blocks = [block1, block2]
            dispatch_apply(blocks.count, queue) { index in
                blocks[index]()
            }
            
            // one writer, one reader
            XCTAssertEqual(totalOpenConnectionCount, 2)
            
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
            
            try self.dbPool.execute("CREATE TABLE items (id INTEGER PRIMARY KEY)")
            try self.dbPool.execute("INSERT INTO items (id) VALUES (NULL)")
            try self.dbPool.execute("INSERT INTO items (id) VALUES (NULL)")
            
            // Block 1                  Block 2
            //                          write {
            //                              SELECT
            //                              step
            //                              >
            let s1 = dispatch_semaphore_create(0)
            // dbPool = nil
            // >
            let s2 = dispatch_semaphore_create(0)
            //                              step
            //                              end
            //                          }
            
            let (block1, block2) = { () -> (() -> (), () -> ()) in
                let block1 = { () in
                    dispatch_semaphore_wait(s1, DISPATCH_TIME_FOREVER)
                    self.dbPool = nil
                    dispatch_semaphore_signal(s2)
                }
                let dbPool = self.dbPool
                let block2 = { [weak dbPool] () in
                    weak var connection: Database? = nil
                    var generator: DatabaseGenerator<Int>? = nil
                    do {
                        if let dbPool = dbPool {
                            dbPool.write { db in
                                connection = db
                                generator = Int.fetch(db, "SELECT id FROM items").generate()
                                XCTAssertTrue(generator!.next() != nil)
                                dispatch_semaphore_signal(s1)
                            }
                        } else {
                            XCTFail("expect non nil dbPool")
                        }
                    }
                    dispatch_semaphore_wait(s2, DISPATCH_TIME_FOREVER)
                    do {
                        XCTAssertTrue(dbPool == nil)
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
            // dbPool = nil
            // >
            let s2 = dispatch_semaphore_create(0)
            //                          dbPool is nil
            
            let (block1, block2) = { () -> (() -> (), () -> ()) in
                let block1 = { () in
                    dispatch_semaphore_wait(s1, DISPATCH_TIME_FOREVER)
                    self.dbPool = nil
                    dispatch_semaphore_signal(s2)
                }
                let dbPool = self.dbPool
                let block2 = { [weak dbPool] () in
                    var statement: UpdateStatement? = nil
                    do {
                        if let dbPool = dbPool {
                            do {
                                try dbPool.write { db in
                                    statement = try db.updateStatement("CREATE TABLE items (id INTEGER PRIMARY KEY)")
                                    dispatch_semaphore_signal(s1)
                                }
                            } catch {
                                XCTFail("error: \(error)")
                            }
                        } else {
                            XCTFail("expect non nil dbPool")
                        }
                    }
                    dispatch_semaphore_wait(s2, DISPATCH_TIME_FOREVER)
                    XCTAssertTrue(statement != nil)
                    XCTAssertTrue(dbPool == nil)
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
