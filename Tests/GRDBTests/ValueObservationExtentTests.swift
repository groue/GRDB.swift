import XCTest
#if GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    #if SWIFT_PACKAGE
        import CSQLite
    #else
        import SQLite3
    #endif
    import GRDB
#endif

class ValueObservationExtentTests: GRDBTestCase {
    func testExtentObserverLifetime() throws {
        // We need something to change
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { try $0.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT)") }
        
        // Track reducer process
        var changesCount = 0
        let notificationExpectation = expectation(description: "notification")
        notificationExpectation.assertForOverFulfill = true
        notificationExpectation.expectedFulfillmentCount = 2
        
        // A reducer
        let reducer = AnyValueReducer(
            fetch: { _ in },
            value: { $0 })
        
        // Create an observation
        let observation = ValueObservation.tracking(DatabaseRegion.fullDatabase, reducer: { _ in reducer })
        
        // Start observation and deallocate observer after second change
        var observer: TransactionObserver?
        observer = try observation.start(in: dbQueue) {
            changesCount += 1
            if changesCount == 2 {
                observer = nil
            }
            notificationExpectation.fulfill()
        }
        
        // notified
        try dbQueue.write { db in
            try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
        }
        
        // not notified
        try dbQueue.write { db in
            try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
        }
        
        // Avoid "Variable 'observer' was written to, but never read" warning
        _ = observer
        
        waitForExpectations(timeout: 1, handler: nil)
        XCTAssertEqual(changesCount, 2)
    }
}
