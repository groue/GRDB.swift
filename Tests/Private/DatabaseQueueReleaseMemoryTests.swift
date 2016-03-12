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
}
