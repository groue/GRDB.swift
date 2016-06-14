import XCTest
#if USING_SQLCIPHER
    @testable import GRDBCipher
#elseif USING_CUSTOMSQLITE
    @testable import GRDBCustomSQLite
#else
    @testable import GRDB
#endif

class DatabasePoolReleaseMemoryTests: GRDBTestCase {
    
    func testDatabasePoolDeinitClosesAllConnections() {
        assertNoError {
            let countQueue = DispatchQueue(label: "GRDB")
            var openConnectionCount = 0
            var totalOpenConnectionCount = 0
            
            dbConfiguration.SQLiteConnectionDidOpen = {
                countQueue.sync {
                    totalOpenConnectionCount += 1
                    openConnectionCount += 1
                }
            }
            
            dbConfiguration.SQLiteConnectionDidClose = {
                countQueue.sync {
                    openConnectionCount -= 1
                }
            }
            
            // write & read
            
            do {
                // Create and release DatabasePool
                let dbPool = try makeDatabasePool()
                // Writer connection
                try dbPool.write { db in
                    try db.execute("CREATE TABLE items (id INTEGER PRIMARY KEY)")
                }
                // Reader connection
                dbPool.read { _ in }
            }
            
            // One reader, one writer
            XCTAssertEqual(totalOpenConnectionCount, 2)
            
            // All connections are closed
            XCTAssertEqual(openConnectionCount, 0)
        }
    }
    
    func testDatabasePoolReleaseMemoryClosesReaderConnections() {
        assertNoError {
            let countQueue = DispatchQueue(label: "GRDB")
            var openConnectionCount = 0
            var totalOpenConnectionCount = 0
            
            dbConfiguration.SQLiteConnectionDidOpen = {
                countQueue.sync {
                    totalOpenConnectionCount += 1
                    openConnectionCount += 1
                }
            }
            
            dbConfiguration.SQLiteConnectionDidClose = {
                countQueue.sync {
                    openConnectionCount -= 1
                }
            }
            
            let dbPool = try makeDatabasePool()
            try dbPool.write { db in
                try db.execute("CREATE TABLE items (id INTEGER PRIMARY KEY)")
                for _ in 0..<2 {
                    try db.execute("INSERT INTO items (id) VALUES (NULL)")
                }
            }
            
            // Block 1                  Block 2                 Block3
            // SELECT * FROM items
            // step
            // >
            let s1 = DispatchSemaphore(value: 0)
            //                          SELECT * FROM items
            //                          step
            //                          >
            let s2 = DispatchSemaphore(value: 0)
            // step                     step
            // >
            let s3 = DispatchSemaphore(value: 0)
            // end                      end                     releaseMemory
            
            let block1 = { () in
                dbPool.read { db in
                    let iterator = Row.fetch(db, "SELECT * FROM items").makeIterator()
                    XCTAssertTrue(iterator.next() != nil)
                    s1.signal()
                    _ = s2.wait(timeout: .distantFuture)
                    XCTAssertTrue(iterator.next() != nil)
                    s3.signal()
                    XCTAssertTrue(iterator.next() == nil)
                }
            }
            let block2 = { () in
                _ = s1.wait(timeout: .distantFuture)
                dbPool.read { db in
                    let iterator = Row.fetch(db, "SELECT * FROM items").makeIterator()
                    XCTAssertTrue(iterator.next() != nil)
                    s2.signal()
                    XCTAssertTrue(iterator.next() != nil)
                    XCTAssertTrue(iterator.next() == nil)
                }
            }
            let block3 = { () in
                _ = s3.wait(timeout: .distantFuture)
                dbPool.releaseMemory()
            }
            let blocks = [block1, block2, block3]
            DispatchQueue.concurrentPerform(iterations: blocks.count) { index in
                blocks[index]()
            }
            
            // Two readers, one writer
            XCTAssertEqual(totalOpenConnectionCount, 3)
            
            // Writer is still open
            XCTAssertEqual(openConnectionCount, 1)
        }
    }

    func testBlocksRetainConnection() {
        assertNoError {
            let countQueue = DispatchQueue(label: "GRDB")
            var openConnectionCount = 0
            var totalOpenConnectionCount = 0
            
            dbConfiguration.SQLiteConnectionDidOpen = {
                countQueue.sync {
                    totalOpenConnectionCount += 1
                    openConnectionCount += 1
                }
            }
            
            dbConfiguration.SQLiteConnectionDidClose = {
                countQueue.sync {
                    openConnectionCount -= 1
                }
            }
            
            // Block 1                  Block 2
            //                          read {
            //                              >
            let s1 = DispatchSemaphore(value: 0)
            // dbPool = nil
            // >
            let s2 = DispatchSemaphore(value: 0)
            //                              use database
            //                          }
            
            let (block1, block2) = { () -> (() -> (), () -> ()) in
                var dbPool: DatabasePool? = try! makeDatabasePool()
                try! dbPool!.write { db in
                    try db.execute("CREATE TABLE items (id INTEGER PRIMARY KEY)")
                }
                
                let block1 = { () in
                    _ = s1.wait(timeout: .distantFuture)
                    dbPool = nil
                    s2.signal()
                }
                let block2 = { [weak dbPool] () in
                    if let dbPool = dbPool {
                        dbPool.read { db in
                            s1.signal()
                            _ = s2.wait(timeout: .distantFuture)
                            XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM items"), 0)
                        }
                    } else {
                        XCTFail("expect non nil dbPool")
                    }
                }
                return (block1, block2)
            }()
            let blocks = [block1, block2]
            DispatchQueue.concurrentPerform(iterations: blocks.count) { index in
                blocks[index]()
            }
            
            // one writer, one reader
            XCTAssertEqual(totalOpenConnectionCount, 2)
            
            // All connections are closed
            XCTAssertEqual(openConnectionCount, 0)
        }
    }
    
    func testDatabaseIteratorRetainConnection() {
        // Until iOS 8.2, OSX 10.10, GRDB does not support deallocating a
        // database when some statements are not finalized.
        guard #available(iOS 8.2, OSX 10.10, *) else {
            return
        }
        assertNoError {
            let countQueue = DispatchQueue(label: "GRDB")
            var openConnectionCount = 0
            var totalOpenConnectionCount = 0
            
            dbConfiguration.SQLiteConnectionDidOpen = {
                countQueue.sync {
                    totalOpenConnectionCount += 1
                    openConnectionCount += 1
                }
            }
            
            dbConfiguration.SQLiteConnectionDidClose = {
                countQueue.sync {
                    openConnectionCount -= 1
                }
            }
            
            // Block 1                  Block 2
            //                          write {
            //                              SELECT
            //                              step
            //                              >
            let s1 = DispatchSemaphore(value: 0)
            // dbPool = nil
            // >
            let s2 = DispatchSemaphore(value: 0)
            //                              step
            //                              end
            //                          }
            
            let (block1, block2) = { () -> (() -> (), () -> ()) in
                var dbPool: DatabasePool? = try! makeDatabasePool()
                try! dbPool!.write { db in
                    try db.execute("CREATE TABLE items (id INTEGER PRIMARY KEY)")
                    try db.execute("INSERT INTO items (id) VALUES (NULL)")
                    try db.execute("INSERT INTO items (id) VALUES (NULL)")
                }
                
                let block1 = { () in
                    _ = s1.wait(timeout: .distantFuture)
                    dbPool = nil
                    s2.signal()
                }
                let block2 = { [weak dbPool] () in
                    weak var connection: Database? = nil
                    var iterator: DatabaseIterator<Int>? = nil
                    do {
                        if let dbPool = dbPool {
                            dbPool.write { db in
                                connection = db
                                iterator = Int.fetch(db, "SELECT id FROM items").makeIterator()
                                XCTAssertTrue(iterator!.next() != nil)
                                s1.signal()
                            }
                        } else {
                            XCTFail("expect non nil dbPool")
                        }
                    }
                    _ = s2.wait(timeout: .distantFuture)
                    do {
                        XCTAssertTrue(dbPool == nil)
                        XCTAssertTrue(iterator!.next() != nil)
                        XCTAssertTrue(iterator!.next() == nil)
                        iterator = nil
                        XCTAssertTrue(connection == nil)
                    }
                }
                return (block1, block2)
            }()
            let blocks = [block1, block2]
            DispatchQueue.concurrentPerform(iterations: blocks.count) { index in
                blocks[index]()
            }
            
            // one writer
            XCTAssertEqual(totalOpenConnectionCount, 1)
            
            // All connections are closed
            XCTAssertEqual(openConnectionCount, 0)
        }
    }
    
    func testStatementDoNotRetainDatabaseConnection() {
        // Until iOS 8.2, OSX 10.10, GRDB does not support deallocating a
        // database when some statements are not finalized.
        guard #available(iOS 8.2, OSX 10.10, *) else {
            return
        }
        assertNoError {
            // Block 1                  Block 2
            //                          create statement INSERT
            //                          >
            let s1 = DispatchSemaphore(value: 0)
            // dbPool = nil
            // >
            let s2 = DispatchSemaphore(value: 0)
            //                          dbPool is nil
            
            let (block1, block2) = { () -> (() -> (), () -> ()) in
                var dbPool: DatabasePool? = try! makeDatabasePool()
                let block1 = { () in
                    _ = s1.wait(timeout: .distantFuture)
                    dbPool = nil
                    s2.signal()
                }
                let block2 = { [weak dbPool] () in
                    var statement: UpdateStatement? = nil
                    do {
                        if let dbPool = dbPool {
                            do {
                                try dbPool.write { db in
                                    statement = try db.makeUpdateStatement("CREATE TABLE items (id INTEGER PRIMARY KEY)")
                                    s1.signal()
                                }
                            } catch {
                                XCTFail("error: \(error)")
                            }
                        } else {
                            XCTFail("expect non nil dbPool")
                        }
                    }
                    _ = s2.wait(timeout: .distantFuture)
                    XCTAssertTrue(statement != nil)
                    XCTAssertTrue(dbPool == nil)
                }
                return (block1, block2)
            }()
            let blocks = [block1, block2]
            DispatchQueue.concurrentPerform(iterations: blocks.count) { index in
                blocks[index]()
            }
        }
    }
}
