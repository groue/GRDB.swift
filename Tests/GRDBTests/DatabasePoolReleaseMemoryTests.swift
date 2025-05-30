// Import C SQLite functions
#if SWIFT_PACKAGE
import GRDBSQLite
#elseif GRDBCIPHER
import SQLCipher
#elseif !GRDBCUSTOMSQLITE && !GRDBCIPHER
import SQLite3
#endif

import XCTest
@testable import GRDB

class DatabasePoolReleaseMemoryTests: GRDBTestCase {
    
    func testDatabasePoolDeinitClosesAllConnections() throws {
        let openConnectionCountMutex = Mutex(0)
        let totalOpenConnectionCountMutex = Mutex(0)
        
        dbConfiguration.onConnectionDidOpen {
            totalOpenConnectionCountMutex.increment()
            openConnectionCountMutex.increment()
        }
        
        dbConfiguration.onConnectionDidClose {
            openConnectionCountMutex.decrement()
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
        XCTAssertEqual(totalOpenConnectionCountMutex.load(), 2)
        
        // All connections are closed
        XCTAssertEqual(openConnectionCountMutex.load(), 0)
    }
    
#if os(iOS)
    func testDatabasePoolReleasesMemoryOnPressureEvent() throws {
        // Create a database pool, and expect a reader connection to be closed
        let expectation = self.expectation(description: "Reader connection closed")
        
        var configuration = Configuration()
        configuration.onConnectionWillClose { conn in
            if sqlite3_db_readonly(conn, nil) != 0 {
                expectation.fulfill()
            }
        }
        let dbPool = try makeDatabasePool(configuration: configuration)
        
        // Precondition: there is one reader.
        try dbPool.read { _ in }
        
        // Simulate memory warning.
        NotificationCenter.default.post(
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil)
        
        // Postcondition: reader connection was closed
        withExtendedLifetime(dbPool) { _ in
            waitForExpectations(timeout: 0.5)
        }
    }
    
    func testDatabasePoolDoesNotReleaseMemoryOnPressureEventIfDisabled() throws {
        // Create a database pool, and do not expect any reader connection to be closed
        let expectation = self.expectation(description: "Reader connection closed")
        expectation.isInverted = true
        
        var configuration = Configuration()
        configuration.automaticMemoryManagement = false
        configuration.onConnectionWillClose { conn in
            if sqlite3_db_readonly(conn, nil) != 0 {
                expectation.fulfill()
            }
        }
        let dbPool = try makeDatabasePool(configuration: configuration)
        
        // Precondition: there is one reader.
        try dbPool.read { _ in }
        
        // Simulate memory warning.
        NotificationCenter.default.post(
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil)
        
        // Postcondition: no reader connection was closed
        withExtendedLifetime(dbPool) { _ in
            waitForExpectations(timeout: 0.5)
        }
    }
    
    // Regression test for <https://github.com/groue/GRDB.swift/pull/1253#issuecomment-1177166630>
    func testDatabasePoolDoesNotPreventConcurrentReadsOnPressureEvent() throws {
        let dbPool = try makeDatabasePool()
        
        // Start a read that blocks
        let semaphore = DispatchSemaphore(value: 0)
        dbPool.asyncRead { _ in
            semaphore.wait()
        }
        
        // Simulate memory warning.
        NotificationCenter.default.post(
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil)
        
        // Make sure we can read
        try dbPool.read { _ in }
        
        // Cleanup
        semaphore.signal()
    }
    
#endif
    
    func test_DatabasePool_releaseMemory_closes_reader_connections() throws {
        // A complicated test setup that opens multiple reader connections.
        let openConnectionCountMutex = Mutex(0)
        let totalOpenConnectionCountMutex = Mutex(0)
        
        dbConfiguration.onConnectionDidOpen {
            totalOpenConnectionCountMutex.increment()
            openConnectionCountMutex.increment()
        }
        
        dbConfiguration.onConnectionDidClose {
            openConnectionCountMutex.decrement()
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
        XCTAssertEqual(totalOpenConnectionCountMutex.load(), 3)
        
        // Writer is still open
        XCTAssertEqual(openConnectionCountMutex.load(), 1)
    }
    
    func test_DatabasePool_releaseMemory_closes_reader_connections_when_persistentReadOnlyConnections_is_false() throws {
        let persistentConnectionCountMutex = Mutex(0)
        
        dbConfiguration.onConnectionDidOpen {
            persistentConnectionCountMutex.increment()
        }
        
        dbConfiguration.onConnectionDidClose {
            persistentConnectionCountMutex.decrement()
        }
        
        dbConfiguration.persistentReadOnlyConnections = false
        
        let dbPool = try makeDatabasePool()
        XCTAssertEqual(persistentConnectionCountMutex.load(), 1) // writer
        
        try dbPool.read { _ in }
        XCTAssertEqual(persistentConnectionCountMutex.load(), 2) // writer + reader
        
        dbPool.releaseMemory()
        XCTAssertEqual(persistentConnectionCountMutex.load(), 1) // writer
    }
    
    func test_DatabasePool_releaseMemory_does_not_close_reader_connections_when_persistentReadOnlyConnections_is_true() throws {
        let persistentConnectionCountMutex = Mutex(0)
        
        dbConfiguration.onConnectionDidOpen {
            persistentConnectionCountMutex.increment()
        }
        
        dbConfiguration.onConnectionDidClose {
            persistentConnectionCountMutex.decrement()
        }
        
        dbConfiguration.persistentReadOnlyConnections = true
        
        let dbPool = try makeDatabasePool()
        XCTAssertEqual(persistentConnectionCountMutex.load(), 1) // writer
        
        try dbPool.read { _ in }
        XCTAssertEqual(persistentConnectionCountMutex.load(), 2) // writer + reader
        
        dbPool.releaseMemory()
        XCTAssertEqual(persistentConnectionCountMutex.load(), 2) // writer + reader
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
                if let dbPool {
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
        XCTAssertEqual(totalOpenConnectionCountMutex.load(), 2)
        
        // All connections are closed
        XCTAssertEqual(openConnectionCountMutex.load(), 0)
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
                var statement: Statement? = nil
                do {
                    if let dbPool {
                        do {
                            try dbPool.write { db in
                                statement = try db.makeStatement(sql: "CREATE TABLE items (id INTEGER PRIMARY KEY)")
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
