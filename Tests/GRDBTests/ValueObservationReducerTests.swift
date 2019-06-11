import XCTest
import Dispatch
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

class ValueObservationReducerTests: GRDBTestCase {
    func testRegionsAPI() {
        let reducer = AnyValueReducer(fetch: { _ in }, value: { })
        
        // single region
        _ = ValueObservation.tracking(DatabaseRegion(), reducer: { _ in reducer })
        // variadic
        _ = ValueObservation.tracking(DatabaseRegion(), DatabaseRegion(), reducer: { _ in reducer })
        // array
        _ = ValueObservation.tracking([DatabaseRegion()], reducer: { _ in reducer })
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
            let observation = ValueObservation.tracking(request, reducer: { _ in reducer })
            
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
    
    func testInitialErrorWithoutErrorHandling() throws {
        func test(_ dbWriter: DatabaseWriter) throws {
            struct TestError: Error { }
            let reducer = AnyValueReducer(
                fetch: { _ in throw TestError() },
                value: { _ in fatalError() })
            
            // Create an observation
            let observation = ValueObservation.tracking(DatabaseRegion.fullDatabase, reducer: { _ in reducer })
            
            // Start observation
            do {
                _ = try observation.start(
                    in: dbWriter,
                    onChange: { _ in })
                XCTFail("Expected error")
            } catch is TestError {
            }
        }
        
        try test(makeDatabaseQueue())
        try test(makeDatabasePool())
    }
    
    func testInitialErrorWithErrorHandling() throws {
        func test(_ dbWriter: DatabaseWriter) throws {
            struct TestError: Error { }
            let reducer = AnyValueReducer(
                fetch: { _ in throw TestError() },
                value: { _ in fatalError() })
            
            // Create an observation
            let observation = ValueObservation.tracking(DatabaseRegion.fullDatabase, reducer: { _ in reducer })
            
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
            
            // A reducer which throws an error is requested to do so
            var nextError: Error? = nil // If not null, reducer throws an error
            let reducer = AnyValueReducer(
                fetch: { _ -> Void in
                    if let error = nextError {
                        nextError = nil
                        throw error
                    }
            },
                value: { $0 })
            
            // Create an observation
            let observation = ValueObservation.tracking(DatabaseRegion.fullDatabase, reducer: { _ in reducer })
            
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
            let reducer = AnyValueReducer(
                fetch: { _ in /* don't fetch anything */ },
                value: { _ -> Int? in
                    defer { count += 1 }
                    return count })
            let observation = ValueObservation.tracking(DatabaseRegion.fullDatabase, reducer: { _ in reducer})
            
            // Start observation
            let observer = try observation.start(in: dbWriter) { count in
                counts.append(count)
                notificationExpectation.fulfill()
            }
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
    
    func testMapValueReducer() throws {
        func test(_ dbWriter: DatabaseWriter) throws {
            // We need something to change
            try dbWriter.write { try $0.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT)") }
            
            // Track reducer process
            var counts: [String] = []
            let notificationExpectation = expectation(description: "notification")
            notificationExpectation.assertForOverFulfill = true
            notificationExpectation.expectedFulfillmentCount = 3
            
            // The base reducer
            var count = 0
            let baseReducer = AnyValueReducer(
                fetch: { _ in /* don't fetch anything */ },
                value: { _ -> Int? in
                    count += 1
                    return count
            })
            
            // The mapped reducer
            let reducer = baseReducer.map { count -> String in
                return "\(count)"
            }
            
            // Create an observation
            let observation = ValueObservation.tracking(DatabaseRegion.fullDatabase, reducer: { _ in reducer })
            
            // Start observation
            let observer = try observation.start(in: dbWriter) { count in
                counts.append(count)
                notificationExpectation.fulfill()
            }
            try withExtendedLifetime(observer) {
                try dbWriter.writeWithoutTransaction { db in
                    try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
                    try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
                }
                
                waitForExpectations(timeout: 1, handler: nil)
                XCTAssertEqual(counts, ["1", "2", "3"])
            }
        }
        
        try test(makeDatabaseQueue())
        try test(makeDatabasePool())
    }
    
    func testCompactMapValueReducer() throws {
        func test(_ dbWriter: DatabaseWriter) throws {
            // We need something to change
            try dbWriter.write { try $0.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT)") }
            
            // Track reducer process
            var counts: [String] = []
            let notificationExpectation = expectation(description: "notification")
            notificationExpectation.assertForOverFulfill = true
            notificationExpectation.expectedFulfillmentCount = 2
            
            // The base reducer
            var count = 0
            let baseReducer = AnyValueReducer(
                fetch: { _ in /* don't fetch anything */ },
                value: { _ -> Int? in
                    count += 1
                    return count
            })
            
            // The mapped reducer
            let reducer = baseReducer.compactMap { count -> String? in
                if count % 2 == 0 { return nil }
                return "\(count)"
            }
            
            // Create an observation
            let observation = ValueObservation.tracking(DatabaseRegion.fullDatabase, reducer: { _ in reducer })
            
            // Start observation
            let observer = try observation.start(in: dbWriter) { count in
                counts.append(count)
                notificationExpectation.fulfill()
            }
            try withExtendedLifetime(observer) {
                try dbWriter.writeWithoutTransaction { db in
                    try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
                    try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
                }
                
                waitForExpectations(timeout: 1, handler: nil)
                XCTAssertEqual(counts, ["1", "3"])
            }
        }
        
        try test(makeDatabaseQueue())
        try test(makeDatabasePool())
    }

    func testValueObservationMap() throws {
        func test(_ dbWriter: DatabaseWriter) throws {
            try dbWriter.write { try $0.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT)") }
            
            var counts: [String] = []
            let notificationExpectation = expectation(description: "notification")
            notificationExpectation.assertForOverFulfill = true
            notificationExpectation.expectedFulfillmentCount = 3
            
            struct T: TableRecord { }
            let observation = T.observationForCount().map { "\($0)" }
            let observer = try observation.start(in: dbWriter) { count in
                counts.append(count)
                notificationExpectation.fulfill()
            }
            try withExtendedLifetime(observer) {
                try dbWriter.writeWithoutTransaction { db in
                    try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
                    try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
                }
                
                waitForExpectations(timeout: 1, handler: nil)
                XCTAssertEqual(counts, ["0", "1", "2"])
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
            let observation = ValueObservation.tracking(DatabaseRegion.fullDatabase, reducer: { _ in reducer })
            let observer = try observation.start(in: dbWriter, onChange: { _ in })
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
    
    // TODO: make this test pass reliably
//    func testObserverInvalidation1() throws {
//        func test(_ dbWriter: DatabaseWriter) throws {
//            try dbWriter.write { try $0.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT)") }
//
//            let notificationExpectation = expectation(description: "notification")
//            notificationExpectation.isInverted = true
//
//            do {
//                var observer: TransactionObserver? = nil
//                _ = observer // Avoid "Variable 'observer' was written to, but never read" warning
//                var observation = ValueObservation.tracking(DatabaseRegion.fullDatabase, reducer: { _ in
//                    AnyValueReducer<Void, Void>(
//                        fetch: { _ in observer = nil /* deallocation */  },
//                        value: { _ in () })
//                })
//                observation.scheduling = .unsafe(startImmediately: false)
//                observer = try observation.start(in: dbWriter) { count in
//                    XCTFail("unexpected change notification: \(String(describing: observer))")
//                    notificationExpectation.fulfill()
//                }
//            }
//
//            try dbWriter.write { db in
//                try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
//            }
//            waitForExpectations(timeout: 0.1, handler: nil)
//        }
//
//        try test(makeDatabaseQueue())
//        try test(makeDatabasePool())
//    }
    
    // TODO: make this test pass reliably
//    func testObserverInvalidation2() throws {
//        func test(_ dbWriter: DatabaseWriter) throws {
//            try dbWriter.write { try $0.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT)") }
//            
//            let notificationExpectation = expectation(description: "notification")
//            notificationExpectation.isInverted = true
//            
//            do {
//                var observer: TransactionObserver? = nil
//                _ = observer // Avoid "Variable 'observer' was written to, but never read" warning
//                var observation = ValueObservation.tracking(DatabaseRegion.fullDatabase, reducer: { _ in
//                    AnyValueReducer<Void, Void>(
//                        fetch: { _ in },
//                        value: { _ in observer = nil /* deallocation right before notification */ })
//                })
//                observation.scheduling = .unsafe(startImmediately: false)
//                observer = try observation.start(in: dbWriter) { count in
//                    XCTFail("unexpected change notification: \(String(describing: observer))")
//                    notificationExpectation.fulfill()
//                }
//            }
//            
//            try dbWriter.write { db in
//                try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
//            }
//            waitForExpectations(timeout: 0.1, handler: nil)
//        }
//        
//        try test(makeDatabaseQueue())
//        try test(makeDatabasePool())
//    }
}
