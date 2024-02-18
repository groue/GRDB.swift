import XCTest
@testable import GRDB

class DatabasePoolReleaseMemoryTests: GRDBTestCase {
    
    func testDatabasePoolDeinitClosesAllConnections() throws {
        struct Context {
            var openConnectionCount = 0
            var totalOpenConnectionCount = 0
        }
        @Mutex var context = Context()
        
        dbConfiguration.SQLiteConnectionDidOpen = { @Sendable in
            $context.withLock {
                $0.totalOpenConnectionCount += 1
                $0.openConnectionCount += 1
            }
        }
        
        dbConfiguration.SQLiteConnectionDidClose = { @Sendable in
            $context.withLock {
                $0.openConnectionCount -= 1
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
        XCTAssertEqual(context.totalOpenConnectionCount, 2)
        
        // All connections are closed
        XCTAssertEqual(context.openConnectionCount, 0)
    }

#if os(iOS)
    func testDatabasePoolReleasesMemoryOnPressureEvent() throws {
        // Create a database pool, and expect a reader connection to be closed
        let expectation = self.expectation(description: "Reader connection closed")
        
        var configuration = Configuration()
        configuration.SQLiteConnectionWillClose = { conn in
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
        configuration.SQLiteConnectionWillClose = { conn in
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
        struct Context {
            var openConnectionCount = 0
            var totalOpenConnectionCount = 0
        }
        @Mutex var context = Context()
        
        dbConfiguration.SQLiteConnectionDidOpen = { @Sendable in
            $context.withLock {
                $0.totalOpenConnectionCount += 1
                $0.openConnectionCount += 1
            }
        }
        
        dbConfiguration.SQLiteConnectionDidClose = { @Sendable in
            $context.withLock {
                $0.openConnectionCount -= 1
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
        XCTAssertEqual(context.totalOpenConnectionCount, 3)
        
        // Writer is still open
        XCTAssertEqual(context.openConnectionCount, 1)
    }
    
    func test_DatabasePool_releaseMemory_closes_reader_connections_when_persistentReadOnlyConnections_is_false() throws {
        @Mutex var persistentConnectionCount = 0
        
        dbConfiguration.SQLiteConnectionDidOpen = { @Sendable in
            $persistentConnectionCount.increment()
        }
        
        dbConfiguration.SQLiteConnectionDidClose = { @Sendable in
            $persistentConnectionCount.decrement()
        }
        
        dbConfiguration.persistentReadOnlyConnections = false
        
        let dbPool = try makeDatabasePool()
        XCTAssertEqual(persistentConnectionCount, 1) // writer
        
        try dbPool.read { _ in }
        XCTAssertEqual(persistentConnectionCount, 2) // writer + reader
        
        dbPool.releaseMemory()
        XCTAssertEqual(persistentConnectionCount, 1) // writer
    }
    
    func test_DatabasePool_releaseMemory_does_not_close_reader_connections_when_persistentReadOnlyConnections_is_true() throws {
        @Mutex var persistentConnectionCount = 0
        
        dbConfiguration.SQLiteConnectionDidOpen = { @Sendable in
            $persistentConnectionCount.increment()
        }
        
        dbConfiguration.SQLiteConnectionDidClose = { @Sendable in
            $persistentConnectionCount.decrement()
        }
        
        dbConfiguration.persistentReadOnlyConnections = true
        
        let dbPool = try makeDatabasePool()
        XCTAssertEqual(persistentConnectionCount, 1) // writer
        
        try dbPool.read { _ in }
        XCTAssertEqual(persistentConnectionCount, 2) // writer + reader
        
        dbPool.releaseMemory()
        XCTAssertEqual(persistentConnectionCount, 2) // writer + reader
    }
    
    @MainActor
    func test_write_database_access_retains_connection_but_not_database_pool() throws {
        let expectation = self.expectation(description: "")
        class Context: @unchecked Sendable {
            weak var weakPool: DatabasePool?
            init(livingPool: DatabasePool? = nil) {
                self.weakPool = livingPool
            }
        }
        let context = Context(livingPool: nil)

        do {
            let dbPool: DatabasePool = try makeDatabasePool()
            context.weakPool = dbPool
            
            dbPool.asyncWriteWithoutTransaction { db in
                XCTAssertNil(context.weakPool)
                try! XCTAssertEqual(Int.fetchOne(db, sql: "SELECT 1"), 1)
                expectation.fulfill()
            }
        }
        wait(for: [expectation])
    }
    
    @MainActor
    func test_read_database_access_retains_connection_but_not_database_pool() throws {
        let expectation = self.expectation(description: "")
        class Context: @unchecked Sendable {
            weak var weakPool: DatabasePool?
            init(livingPool: DatabasePool? = nil) {
                self.weakPool = livingPool
            }
        }
        let context = Context(livingPool: nil)

        do {
            let dbPool: DatabasePool = try makeDatabasePool()
            context.weakPool = dbPool
            
            dbPool.asyncRead { db in
                XCTAssertNil(context.weakPool)
                try! XCTAssertEqual(Int.fetchOne(db.get(), sql: "SELECT 1"), 1)
                expectation.fulfill()
            }
        }
        wait(for: [expectation])
    }

    func test_write_statement_does_not_retain_database_pool() throws {
        var dbPool: DatabasePool? = try makeDatabasePool()
        weak var weakPool = dbPool
        let statement = try dbPool?.write { db in
            try db.makeStatement(sql: "SELECT 1")
        }
        withExtendedLifetime(statement) {
            XCTAssertNotNil(weakPool)
            dbPool = nil
            XCTAssertNil(weakPool)
        }
    }

    func test_read_statement_does_not_retain_database_pool() throws {
        var dbPool: DatabasePool? = try makeDatabasePool()
        weak var weakPool = dbPool
        let statement = try dbPool?.read { db in
            try db.makeStatement(sql: "SELECT 1")
        }
        withExtendedLifetime(statement) {
            XCTAssertNotNil(weakPool)
            dbPool = nil
            XCTAssertNil(weakPool)
        }
    }
}
