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
        let request = SQLRequest<Void>("SELECT * FROM t")
        var observation = ValueObservation.observing(request, reducer: reducer)
        observation.extent = .databaseLifetime
        
        // Start observation
        _ = try dbQueue.add(
            observation: observation,
            onError: nil,
            onChange: { notificationExpectation.fulfill() })
        
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
        let request = SQLRequest<Void>("SELECT * FROM t")
        var observation = ValueObservation.observing(request, reducer: reducer)
        observation.extent = .observerLifetime
        
        // Start observation and deallocate observer after second change
        var observer: TransactionObserver?
        observer = try dbQueue.add(
            observation: observation,
            onError: nil,
            onChange: {
                changesCount += 1
                if changesCount == 2 {
                    observer = nil
                }
                notificationExpectation.fulfill()
        })
        
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
        let request = SQLRequest<Void>("SELECT * FROM t")
        var observation = ValueObservation.observing(request, reducer: reducer)
        observation.extent = .nextTransaction
        
        // Start observation
        let observer = try dbQueue.add(
            observation: observation,
            onError: nil,
            onChange: { notificationExpectation.fulfill() })
        
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
