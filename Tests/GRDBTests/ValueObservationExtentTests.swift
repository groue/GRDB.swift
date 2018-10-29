import XCTest
#if GRDBCIPHER
    import GRDBCipher
#elseif GRDBCUSTOMSQLITE
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
    func testDefaultExtentIsObserverLifetime() {
        let observation = ValueObservation.tracking(DatabaseRegion.fullDatabase, fetch: { _ in })
        XCTAssertEqual(observation.extent, .observerLifetime)
    }
    
    func testExtentDatabaseLifetime() throws {
        // We need something to change
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { try $0.execute("CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT)") }
        
        // Track reducer proceess
        let notificationExpectation = expectation(description: "notification")
        notificationExpectation.assertForOverFulfill = true
        notificationExpectation.expectedFulfillmentCount = 3
        
        // A reducer
        let reducer = AnyValueReducer(
            fetch: { _ in },
            value: { $0 })
        
        // Create an observation
        var observation = ValueObservation.tracking(DatabaseRegion.fullDatabase, reducer: reducer)
        observation.extent = .databaseLifetime
        
        // Start observation
        _ = try observation.start(in: dbQueue) {
            notificationExpectation.fulfill()
        }
        
        // notified
        try dbQueue.write { db in
            try db.execute("INSERT INTO t DEFAULT VALUES")
        }
        
        // notified
        try dbQueue.write { db in
            try db.execute("INSERT INTO t DEFAULT VALUES")
        }
        
        waitForExpectations(timeout: 1, handler: nil)
    }

    func testExtentObserverLifetime() throws {
        // We need something to change
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { try $0.execute("CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT)") }
        
        // Track reducer proceess
        var changesCount = 0
        let notificationExpectation = expectation(description: "notification")
        notificationExpectation.assertForOverFulfill = true
        notificationExpectation.expectedFulfillmentCount = 2
        
        // A reducer
        let reducer = AnyValueReducer(
            fetch: { _ in },
            value: { $0 })
        
        // Create an observation
        var observation = ValueObservation.tracking(DatabaseRegion.fullDatabase, reducer: reducer)
        observation.extent = .observerLifetime
        
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
            try db.execute("INSERT INTO t DEFAULT VALUES")
        }
        
        // not notified
        try dbQueue.write { db in
            try db.execute("INSERT INTO t DEFAULT VALUES")
        }
        
        // Avoid "Variable 'observer' was written to, but never read" warning
        _ = observer
        
        waitForExpectations(timeout: 1, handler: nil)
        XCTAssertEqual(changesCount, 2)
    }

    func testExtentNextTransaction() throws {
        // We need something to change
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { try $0.execute("CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT)") }
        
        // Track reducer proceess
        let notificationExpectation = expectation(description: "notification")
        notificationExpectation.assertForOverFulfill = true
        notificationExpectation.expectedFulfillmentCount = 2
        
        // A reducer
        let reducer = AnyValueReducer(
            fetch: { _ in },
            value: { $0 })
        
        // Create an observation
        var observation = ValueObservation.tracking(DatabaseRegion.fullDatabase, reducer: reducer)
        observation.extent = .nextTransaction
        
        // Start observation
        let observer = try observation.start(in: dbQueue) {
            notificationExpectation.fulfill()
        }
        
        try withExtendedLifetime(observer) {
            // notified
            try dbQueue.write { db in
                try db.execute("INSERT INTO t DEFAULT VALUES")
            }
            
            // not notified
            try dbQueue.write { db in
                try db.execute("INSERT INTO t DEFAULT VALUES")
            }
            
            waitForExpectations(timeout: 1, handler: nil)
        }
    }
}
