import XCTest
#if GRDBCIPHER
    @testable import GRDBCipher
#elseif GRDBCUSTOMSQLITE
    @testable import GRDBCustomSQLite
#else
    @testable import GRDB
#endif

class DatabaseQueueReleaseMemoryTests: GRDBTestCase {
    
    func testDatabaseQueueDeinitClosesConnection() throws {
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
            var dbQueue: DatabaseQueue? = try! self.makeDatabaseQueue()
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

    // TODO: this test should be duplicated for all cursor types
    func testDatabaseCursorRetainSQLiteConnection() throws {
        let countQueue = DispatchQueue(label: "GRDB")
        var openConnectionCount = 0
        
        dbConfiguration.SQLiteConnectionDidOpen = {
            countQueue.sync {
                openConnectionCount += 1
            }
        }
        
        dbConfiguration.SQLiteConnectionDidClose = {
            countQueue.sync {
                openConnectionCount -= 1
            }
        }
        
        var cursor: ColumnCursor<Int>? = nil
        do {
            try! makeDatabaseQueue().inDatabase { db in
                try db.execute("CREATE TABLE items (id INTEGER PRIMARY KEY)")
                try db.execute("INSERT INTO items (id) VALUES (NULL)")
                try db.execute("INSERT INTO items (id) VALUES (NULL)")
                cursor = try Int.fetchCursor(db, "SELECT id FROM items")
                XCTAssertTrue(try cursor!.next() != nil)
                XCTAssertEqual(openConnectionCount, 1)
            }
        }
        XCTAssertEqual(openConnectionCount, 0)
        XCTAssertTrue(try! cursor!.next() != nil)
        XCTAssertTrue(try! cursor!.next() == nil)
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
