import XCTest
import Dispatch
#if GRDBCUSTOMSQLITE
    @testable import GRDBCustomSQLite
#else
    #if SWIFT_PACKAGE
        import CSQLite
    #else
        import SQLite3
    #endif
    @testable import GRDB
#endif

class ValueObservationTests: GRDBTestCase {
    func testImmediateError() throws {
        func test(_ dbWriter: DatabaseWriter) throws {
            // Create an observation
            struct TestError: Error { }
            let observation = ValueObservation.tracking { _ in throw TestError() }
            
            // Start observation
            var error: TestError?
            _ = observation.start(
                in: dbWriter,
                scheduler: .immediate,
                onError: { error = $0 as? TestError },
                onChange: { _ in })
            XCTAssertNotNil(error)
        }
        
        try test(makeDatabaseQueue())
        try test(makeDatabasePool())
    }
    
    func testErrorCompletesTheObservation() throws {
        func test(_ dbWriter: DatabaseWriter) throws {
            // We need something to change
            try dbWriter.write { try $0.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT)") }
            
            // Track reducer process
            let notificationExpectation = expectation(description: "notification")
            notificationExpectation.assertForOverFulfill = true
            notificationExpectation.expectedFulfillmentCount = 3
            notificationExpectation.isInverted = true
            
            struct TestError: Error { }
            var nextError: Error? = nil // If not null, observation throws an error
            let observation = ValueObservation.tracking {
                _ = try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM t")
                if let error = nextError {
                    throw error
                }
            }

            // Start observation
            var errorCaught = false
            let observer = observation.start(
                in: dbWriter,
                onError: { _ in
                    errorCaught = true
                    notificationExpectation.fulfill()
            },
                onChange: {
                    XCTAssertFalse(errorCaught)
                    nextError = TestError()
                    notificationExpectation.fulfill()
                    // Trigger another change
                    try! dbWriter.writeWithoutTransaction { db in
                        try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
                    }
            })
            
            withExtendedLifetime(observer) {
                waitForExpectations(timeout: 0.3, handler: nil)
                XCTAssertTrue(errorCaught)
            }
        }
        
        try test(makeDatabaseQueue())
        try test(makeDatabasePool())
    }
    
    func testViewOptimization() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write {
            try $0.execute(sql: """
                CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT);
                CREATE VIEW v AS SELECT * FROM t
                """)
        }
        
        // Test that view v is included in the request region
        let request = SQLRequest<Row>(sql: "SELECT name FROM v ORDER BY id")
        try dbQueue.inDatabase { db in
            let region = try request.databaseRegion(db)
            XCTAssertEqual(region.description, "t(id,name),v(id,name)")
        }
        
        // Test that view v is not included in the observed region.
        // This optimization helps observation of views that feed from a
        // single table.
        let observation = ValueObservation.tracking(request.fetchAll)
        let observer = observation.start(
            in: dbQueue,
            scheduler: .immediate, // So that we can test the observedRegion
            onError: { error in XCTFail("Unexpected error: \(error)") },
            onChange: { _ in })
        let token = observer as! ValueObserverToken<ValueReducers.Fetch<[Row]>> // Non-public implementation detail
        XCTAssertEqual(token.observer.observedRegion!.description, "t(id,name)") // view is NOT tracked
    }
    
    // MARK: - Cancellation
    
    func testExtentObserverLifetime() throws {
        // We need something to change
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { try $0.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT)") }
        
        // Track reducer process
        var changesCount = 0
        let notificationExpectation = expectation(description: "notification")
        notificationExpectation.assertForOverFulfill = true
        notificationExpectation.expectedFulfillmentCount = 2
        
        // Create an observation
        let observation = ValueObservation.tracking {
            try Int.fetchOne($0, sql: "SELECT * FROM t")
        }
        
        // Start observation and deallocate observer after second change
        var observer: TransactionObserver?
        observer = observation.start(
            in: dbQueue,
            onError: { error in XCTFail("Unexpected error: \(error)") },
            onChange: { _ in
                changesCount += 1
                if changesCount == 2 {
                    observer = nil
                }
                notificationExpectation.fulfill()
        })
        
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
    
    func testObserverInvalidation1() throws {
        // Test that observation stops when observer is deallocated
        func test(_ dbWriter: DatabaseWriter) throws {
            try dbWriter.write { try $0.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT)") }

            let notificationExpectation = expectation(description: "notification")
            notificationExpectation.isInverted = true
            notificationExpectation.expectedFulfillmentCount = 2

            do {
                var observer: TransactionObserver? = nil
                _ = observer // Avoid "Variable 'observer' was written to, but never read" warning
                var shouldStopObservation = false
                let observation = ValueObservation(makeReducer: {
                    AnyValueReducer<Void, Void>(
                        fetch: { _ in
                            if shouldStopObservation {
                                observer = nil /* deallocation */
                            }
                            shouldStopObservation = true
                    },
                        value: { _ in () })
                })
                observer = observation.start(
                    in: dbWriter,
                    scheduler: .immediate,
                    onError: { error in XCTFail("Unexpected error: \(error)") },
                    onChange: { _ in
                        notificationExpectation.fulfill()
                })
            }

            try dbWriter.write { db in
                try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
            }
            waitForExpectations(timeout: 0.2, handler: nil)
        }

        try test(makeDatabaseQueue())
        try test(makeDatabasePool())
    }
    
    func testObserverInvalidation2() throws {
        // Test that observation stops when observer is deallocated
        func test(_ dbWriter: DatabaseWriter) throws {
            try dbWriter.write { try $0.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT)") }
            
            let notificationExpectation = expectation(description: "notification")
            notificationExpectation.isInverted = true
            notificationExpectation.expectedFulfillmentCount = 2
            
            do {
                var observer: TransactionObserver? = nil
                _ = observer // Avoid "Variable 'observer' was written to, but never read" warning
                var shouldStopObservation = false
                let observation = ValueObservation(makeReducer: {
                    AnyValueReducer<Void, Void>(
                        fetch: { _ in },
                        value: { _ in
                            if shouldStopObservation {
                                observer = nil /* deallocation right before notification */
                            }
                            shouldStopObservation = true
                            return ()
                    })
                })
                observer = observation.start(
                    in: dbWriter,
                    scheduler: .immediate,
                    onError: { error in XCTFail("Unexpected error: \(error)") },
                    onChange: { _ in
                        notificationExpectation.fulfill()
                })
            }
            
            try dbWriter.write { db in
                try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
            }
            waitForExpectations(timeout: 0.2, handler: nil)
        }
        
        try test(makeDatabaseQueue())
        try test(makeDatabasePool())
    }
}
