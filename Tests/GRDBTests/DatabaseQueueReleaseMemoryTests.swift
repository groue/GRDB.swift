import XCTest
#if os(Linux)
    import Dispatch
#endif
#if USING_SQLCIPHER
    @testable import GRDBCipher
#elseif USING_CUSTOMSQLITE
    @testable import GRDBCustomSQLite
#else
    @testable import GRDB
#endif

class DatabaseQueueuReleaseMemoryTests: GRDBTestCase {
    
    func testDatabaseQueueuDeinitClosesConnection() throws {
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
        
        do {
            // Open & release connection
            _ = try makeDatabaseQueue()
        }
        
        // One reader, one writer
        XCTAssertEqual(totalOpenConnectionCount, 1)
        
        // All connections are closed
        XCTAssertEqual(openConnectionCount, 0)
    }

    func testBlocksRetainConnection() throws {
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
        //                          inDatabase {
        //                              >
        let s1 = DispatchSemaphore(value: 0)
        // dbQueue = nil
        // >
        let s2 = DispatchSemaphore(value: 0)
        //                              use database
        //                          }
        
        let (block1, block2) = { () -> (() -> (), () -> ()) in
            var dbQueue: DatabaseQueue? = try! makeDatabaseQueue()
            try! dbQueue!.write { db in
                try db.execute("CREATE TABLE items (id INTEGER PRIMARY KEY)")
            }
            
            let block1 = { () in
                _ = s1.wait(timeout: .distantFuture)
                dbQueue = nil
                s2.signal()
            }
            let block2 = { [weak dbQueue] () in
                if let dbQueue = dbQueue {
                    try! dbQueue.write { db in
                        s1.signal()
                        _ = s2.wait(timeout: .distantFuture)
                        XCTAssertEqual(try Int.fetchOne(db, "SELECT COUNT(*) FROM items"), 0)
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
        XCTAssertEqual(totalOpenConnectionCount, 1)
        
        // All connections are closed
        XCTAssertEqual(openConnectionCount, 0)
    }

    func testDatabaseIteratorRetainConnection() throws {
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
        // dbQueue = nil
        // >
        let s2 = DispatchSemaphore(value: 0)
        //                              step
        //                              end
        //                          }
        
        let (block1, block2) = { () -> (() -> (), () -> ()) in
            var dbQueue: DatabaseQueue? = try! makeDatabaseQueue()
            try! dbQueue!.write { db in
                try db.execute("CREATE TABLE items (id INTEGER PRIMARY KEY)")
                try db.execute("INSERT INTO items (id) VALUES (NULL)")
                try db.execute("INSERT INTO items (id) VALUES (NULL)")
            }
            
            let block1 = { () in
                _ = s1.wait(timeout: .distantFuture)
                dbQueue = nil
                s2.signal()
            }
            let block2 = { [weak dbQueue] () in
                weak var connection: Database? = nil
                var cursor: DatabaseCursor<Int>? = nil
                do {
                    if let dbQueue = dbQueue {
                        try! dbQueue.write { db in
                            connection = db
                            cursor = try Int.fetchCursor(db, "SELECT id FROM items")
                            XCTAssertTrue(try cursor!.next() != nil)
                            s1.signal()
                        }
                    } else {
                        XCTFail("expect non nil dbQueue")
                    }
                }
                _ = s2.wait(timeout: .distantFuture)
                do {
                    XCTAssertTrue(dbQueue == nil)
                    XCTAssertTrue(try! cursor!.next() != nil)
                    XCTAssertTrue(try! cursor!.next() == nil)
                    cursor = nil
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
            var dbQueue: DatabaseQueue? = try! makeDatabaseQueue()
            
            let block1 = { () in
                _ = s1.wait(timeout: .distantFuture)
                dbQueue = nil
                s2.signal()
            }
            let block2 = { [weak dbQueue] () in
                var statement: UpdateStatement? = nil
                do {
                    if let dbQueue = dbQueue {
                        do {
                            try dbQueue.write { db in
                                statement = try db.makeUpdateStatement("CREATE TABLE items (id INTEGER PRIMARY KEY)")
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
