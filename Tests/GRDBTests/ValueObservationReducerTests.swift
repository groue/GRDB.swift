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

class ValueObservationReducerTests: GRDBTestCase {
    func testRegionsAPI() {
        // single region
        _ = ValueObservation.tracking(DatabaseRegion(), fetch: { _ in })
        // variadic
        _ = ValueObservation.tracking(DatabaseRegion(), DatabaseRegion(), fetch: { _ in })
        // array
        _ = ValueObservation.tracking([DatabaseRegion()], fetch: { _ in })
    }
    
    func testReducer() throws {
        func test(_ dbWriter: DatabaseWriter) throws {
            // We need something to change
            try dbWriter.write { try $0.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT)") }
            
            // Track reducer process
            var fetchCount = 0
            var reduceCount = 0
            var errors: [Error] = []
            var changes: [String] = []
            let notificationExpectation = expectation(description: "notification")
            notificationExpectation.assertForOverFulfill = true
            notificationExpectation.expectedFulfillmentCount = 3
            
            // A reducer which tracks its progress
            let reducer = AnyValueReducer(
                fetch: { db -> Int in
                    fetchCount += 1
                    // test for database access
                    return try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM t")!
            },
                value: { count -> String? in
                    reduceCount += 1
                    if count == 3 {
                        // test that reducer can drop values
                        return nil
                    }
                    // test that the fetched type and the notified type can be different
                    return count.description
            })
            
            // Create an observation
            let request = SQLRequest<Void>(sql: "SELECT * FROM t")
            let observation = ValueObservation(baseRegion: request.databaseRegion, makeReducer: { reducer })
            
            // Start observation
            let observer = observation.start(
                in: dbWriter,
                onError: {
                    errors.append($0)
                    notificationExpectation.fulfill()
            },
                onChange: {
                    changes.append($0)
                    notificationExpectation.fulfill()
            })
            try withExtendedLifetime(observer) {
                // Test that default config synchronously notifies initial value
                XCTAssertEqual(fetchCount, 1)
                XCTAssertEqual(reduceCount, 1)
                XCTAssertEqual(errors.count, 0)
                XCTAssertEqual(changes, ["0"])
                
                try dbWriter.writeWithoutTransaction { db in
                    // Test a 1st notified transaction
                    try db.inTransaction {
                        try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
                        return .commit
                    }
                    
                    // Test an untracked transaction
                    try db.inTransaction {
                        try db.execute(sql: "CREATE TABLE ignored(a)")
                        return .commit
                    }
                    
                    // Test a dropped transaction
                    try db.inTransaction {
                        try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
                        try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
                        return .commit
                    }
                    
                    // Test a rollbacked transaction
                    try db.inTransaction {
                        try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
                        return .rollback
                    }
                    
                    // Test a 2nd notified transaction
                    try db.inTransaction {
                        try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
                        try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
                        return .commit
                    }
                }
                
                waitForExpectations(timeout: 1, handler: nil)
                XCTAssertEqual(fetchCount, 4)
                XCTAssertEqual(reduceCount, 4)
                XCTAssertEqual(errors.count, 0)
                XCTAssertEqual(changes, ["0", "1", "5"])
            }
        }
        
        try test(makeDatabaseQueue())
        try test(makeDatabasePool())
    }
    
    func testInitialErrorWithErrorHandling() throws {
        func test(_ dbWriter: DatabaseWriter) throws {
            // Create an observation
            struct TestError: Error { }
            let observation = ValueObservation.tracking(DatabaseRegion.fullDatabase, fetch: { _ in throw TestError() })
            
            // Start observation
            var error: TestError?
            _ = observation.start(
                in: dbWriter,
                onError: { error = $0 as? TestError },
                onChange: { _ in })
            XCTAssertNotNil(error)
        }
        
        try test(makeDatabaseQueue())
        try test(makeDatabasePool())
    }
    
    func testSuccessThenErrorThenSuccess() throws {
        func test(_ dbWriter: DatabaseWriter) throws {
            // We need something to change
            try dbWriter.write { try $0.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT)") }
            
            // Track reducer process
            var errors: [Error] = []
            var changes: [Void] = []
            let notificationExpectation = expectation(description: "notification")
            notificationExpectation.assertForOverFulfill = true
            notificationExpectation.expectedFulfillmentCount = 3
            
            var nextError: Error? = nil // If not null, observation throws an error
            let observation = ValueObservation.tracking(DatabaseRegion.fullDatabase, fetch: { _ -> Void in
                if let error = nextError {
                    nextError = nil
                    throw error
                }
            })

            // Start observation
            let observer = observation.start(
                in: dbWriter,
                onError: {
                    errors.append($0)
                    notificationExpectation.fulfill()
            },
                onChange: {
                    changes.append($0)
                    notificationExpectation.fulfill()
            })
            
            try withExtendedLifetime(observer) {
                struct TestError: Error { }
                nextError = TestError()
                try dbWriter.writeWithoutTransaction { db in
                    try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
                    try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
                }
                
                waitForExpectations(timeout: 1, handler: nil)
                XCTAssertEqual(errors.count, 1)
                XCTAssertEqual(changes.count, 2)
            }
        }
        
        try test(makeDatabaseQueue())
        try test(makeDatabasePool())
    }
    
    func testReadMeReducer() throws {
        func test(_ dbWriter: DatabaseWriter) throws {
            // Test for the reducer documented in the main README
            
            // We need something to change
            try dbWriter.write { try $0.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT)") }
            
            // Track reducer process
            var counts: [Int] = []
            let notificationExpectation = expectation(description: "notification")
            notificationExpectation.assertForOverFulfill = true
            notificationExpectation.expectedFulfillmentCount = 2
            
            // Create an observation
            var count = 0
            let observation = ValueObservation.tracking(DatabaseRegion.fullDatabase, fetch: { _ -> Int in
                defer { count += 1 }
                return count
            })
            
            // Start observation
            let observer = observation.start(
                in: dbWriter,
                onError: { error in XCTFail("Unexpected error: \(error)") },
                onChange: { count in
                    counts.append(count)
                    notificationExpectation.fulfill()
            })
            try withExtendedLifetime(observer) {
                try dbWriter.write { db in
                    try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
                }
                
                waitForExpectations(timeout: 1, handler: nil)
                XCTAssertEqual(counts, [0, 1])
            }
        }
        
        try test(makeDatabaseQueue())
        try test(makeDatabasePool())
    }
    
    func testReducerQueueLabel() throws {
        func test(_ dbWriter: DatabaseWriter, expectedLabels: [String]) throws {
            try dbWriter.write { try $0.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT)") }
            
            let reduceExpectation = expectation(description: "notification")
            reduceExpectation.assertForOverFulfill = true
            reduceExpectation.expectedFulfillmentCount = expectedLabels.count
            
            var labels: [String] = []
            let reducer = AnyValueReducer(fetch: { _ in }, value: { _ in
                // This test CAN break in future releases: the dispatch queue labels
                // are documented to be a debug-only tool.
                if let label = String(utf8String: __dispatch_queue_get_label(nil)) {
                    labels.append(label)
                }
                reduceExpectation.fulfill()
            })
            let observation = ValueObservation(
                baseRegion: { _ in DatabaseRegion.fullDatabase },
                makeReducer: { reducer })
            let observer = observation.start(
                in: dbWriter,
                onError: { error in XCTFail("Unexpected error: \(error)") },
                onChange: { _ in })
            try withExtendedLifetime(observer) {
                try dbWriter.write { db in
                    try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
                }
                
                waitForExpectations(timeout: 1, handler: nil)
                XCTAssertEqual(labels, expectedLabels)
            }
        }
        do {
            // dbQueue with default label
            dbConfiguration.label = nil
            let dbQueue = try makeDatabaseQueue()
            try test(dbQueue, expectedLabels: ["GRDB.DatabaseQueue", "GRDB.ValueObservation.reducer"])
        }
        do {
            // dbQueue with custom label
            dbConfiguration.label = "Custom"
            let dbQueue = try makeDatabaseQueue()
            try test(dbQueue, expectedLabels: ["Custom", "Custom.ValueObservation.reducer"])
        }
        do {
            // dbPool with default label
            dbConfiguration.label = nil
            let dbPool = try makeDatabasePool()
            try test(dbPool, expectedLabels: ["GRDB.DatabasePool.writer", "GRDB.ValueObservation.reducer"])
        }
        do {
            // dbPool with custom label
            dbConfiguration.label = "Custom"
            let dbPool = try makeDatabasePool()
            try test(dbPool, expectedLabels: ["Custom.writer", "Custom.ValueObservation.reducer"])
        }
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
                var observation = ValueObservation(
                    baseRegion: { _ in DatabaseRegion.fullDatabase },
                    makeReducer: {
                        AnyValueReducer<Void, Void>(
                            fetch: { _ in
                                if shouldStopObservation {
                                    observer = nil /* deallocation */
                                }
                                shouldStopObservation = true
                        },
                            value: { _ in () })
                })
                observation.scheduling = .unsafe
                observer = observation.start(
                    in: dbWriter,
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
                var observation = ValueObservation(
                    baseRegion: { _ in DatabaseRegion.fullDatabase },
                    makeReducer: {
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
                observation.scheduling = .unsafe
                observer = observation.start(
                    in: dbWriter,
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
