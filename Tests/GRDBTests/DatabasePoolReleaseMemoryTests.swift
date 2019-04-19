import XCTest
#if GRDBCUSTOMSQLITE
    @testable import GRDBCustomSQLite
#else
    @testable import GRDB
#endif

class DatabasePoolReleaseMemoryTests: GRDBTestCase {
    
    func testDatabasePoolDeinitClosesAllConnections() throws {
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
                try db.execute(sql: "CREATE TABLE items (id INTEGER PRIMARY KEY)")
            }
            // Reader connection
            try dbPool.read { _ in }
        }
        
        // One reader, one writer
        XCTAssertEqual(totalOpenConnectionCount, 2)
        
        // All connections are closed
        XCTAssertEqual(openConnectionCount, 0)
    }

    func testDatabasePoolReleaseMemoryClosesReaderConnections() throws {
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
            try db.execute(sql: "CREATE TABLE items (id INTEGER PRIMARY KEY)")
            for _ in 0..<2 {
                try db.execute(sql: "INSERT INTO items (id) VALUES (NULL)")
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
            try! dbPool.read { db in
                let cursor = try Row.fetchCursor(db, sql: "SELECT * FROM items")
                XCTAssertTrue(try cursor.next() != nil)
                s1.signal()
                _ = s2.wait(timeout: .distantFuture)
                XCTAssertTrue(try cursor.next() != nil)
                s3.signal()
                XCTAssertTrue(try cursor.next() == nil)
            }
        }
        let block2 = { () in
            _ = s1.wait(timeout: .distantFuture)
            try! dbPool.read { db in
                let cursor = try Row.fetchCursor(db, sql: "SELECT * FROM items")
                XCTAssertTrue(try cursor.next() != nil)
                s2.signal()
                XCTAssertTrue(try cursor.next() != nil)
                XCTAssertTrue(try cursor.next() == nil)
            }
        }
        let block3 = { () in
            _ = s3.wait(timeout: .distantFuture)
            dbPool.releaseMemory()
        }
        let blocks = [block1, block2, block3]
        DispatchQueue.concurrentPerform(iterations: blocks.count) { index in // FIXME: this crashes sometimes
            blocks[index]()
        }
        
        // Two readers, one writer
        XCTAssertEqual(totalOpenConnectionCount, 3)
        
        // Writer is still open
        XCTAssertEqual(openConnectionCount, 1)
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
        //                          read {
        //                              >
        let s1 = DispatchSemaphore(value: 0)
        // dbPool = nil
        // >
        let s2 = DispatchSemaphore(value: 0)
        //                              use database
        //                          }
        
        let (block1, block2) = { () -> (() -> (), () -> ()) in
            var dbPool: DatabasePool? = try! self.makeDatabasePool()
            try! dbPool!.write { db in
                try db.execute(sql: "CREATE TABLE items (id INTEGER PRIMARY KEY)")
            }
            
            let block1 = { () in
                _ = s1.wait(timeout: .distantFuture)
                dbPool = nil
                s2.signal()
            }
            let block2 = { [weak dbPool] () in
                if let dbPool = dbPool {
                    try! dbPool.read { db in
                        s1.signal()
                        _ = s2.wait(timeout: .distantFuture)
                        XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM items"), 0)
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
    
    func testStatementDoNotRetainDatabaseConnection() throws {
        // Block 1                  Block 2
        //                          create statement INSERT
        //                          >
        let s1 = DispatchSemaphore(value: 0)
        // dbPool = nil
        // >
        let s2 = DispatchSemaphore(value: 0)
        //                          dbPool is nil
        
        let (block1, block2) = { () -> (() -> (), () -> ()) in
            var dbPool: DatabasePool? = try! self.makeDatabasePool()
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
                                statement = try db.makeUpdateStatement(sql: "CREATE TABLE items (id INTEGER PRIMARY KEY)")
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
