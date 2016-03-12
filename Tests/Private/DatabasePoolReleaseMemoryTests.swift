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
                    print("open")
                    totalOpenConnectionCount += 1
                    openConnectionCount += 1
                }
            }
            
            dbConfiguration.SQLiteConnectionDidClose = {
                dispatch_sync(countQueue) {
                    print("close")
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
                    print("open")
                    totalOpenConnectionCount += 1
                    openConnectionCount += 1
                }
            }
            
            dbConfiguration.SQLiteConnectionDidClose = {
                dispatch_sync(countQueue) {
                    print("close")
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
}
