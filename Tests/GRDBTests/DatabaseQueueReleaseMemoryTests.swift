import XCTest
@testable import GRDB

class DatabaseQueueReleaseMemoryTests: GRDBTestCase {
    
    func testDatabaseQueueDeinitClosesConnection() throws {
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
        
        do {
            // Open & release connection
            _ = try makeDatabaseQueue()
        }
        
        // One reader, one writer
        XCTAssertEqual(context.totalOpenConnectionCount, 1)
        
        // All connections are closed
        XCTAssertEqual(context.openConnectionCount, 0)
    }
    
    @MainActor
    func test_database_access_retains_connection_but_not_database_queue() throws {
        let expectation = self.expectation(description: "")
        class Context: @unchecked Sendable {
            weak var weakQueue: DatabaseQueue?
            init(livingQueue: DatabaseQueue? = nil) {
                self.weakQueue = livingQueue
            }
        }
        let context = Context(livingQueue: nil)

        do {
            let dbQueue: DatabaseQueue = try makeDatabaseQueue()
            context.weakQueue = dbQueue
            
            dbQueue.asyncWriteWithoutTransaction { db in
                XCTAssertNil(context.weakQueue)
                try! XCTAssertEqual(Int.fetchOne(db, sql: "SELECT 1"), 1)
                expectation.fulfill()
            }
        }
        wait(for: [expectation])
    }
    
    func test_statement_does_not_retain_database_queue() throws {
        var dbQueue: DatabaseQueue? = try makeDatabaseQueue()
        weak var weakQueue = dbQueue
        let statement = try dbQueue?.write { db in
            try db.makeStatement(sql: "SELECT 1")
        }
        withExtendedLifetime(statement) {
            XCTAssertNotNil(weakQueue)
            dbQueue = nil
            XCTAssertNil(weakQueue)
        }
    }
}
