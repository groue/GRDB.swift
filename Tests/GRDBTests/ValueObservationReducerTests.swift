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

class ValueObservationReducerTests: GRDBTestCase {
    func testReducer() throws {
        // We need something to change
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { try $0.execute("CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT)") }
        
        // Track reducer proceess
        var fetchCount = 0
        var reduceCount = 0
        var errors: [Error] = []
        var changes: [String] = []
        let notificationExpectation = expectation(description: "notification")
        notificationExpectation.assertForOverFulfill = true
        notificationExpectation.expectedFulfillmentCount = 3
        
        // A reducer which tracks its progress
        var dropNext = false // if true, reducer drops next value
        let reducer = AnyValueReducer(
            fetch: { db -> Int in
                fetchCount += 1
                // test for database access
                return try Int.fetchOne(db, "SELECT COUNT(*) FROM t")!
            },
            value: { count -> String? in
                reduceCount += 1
                if dropNext {
                    // test that reducer can drop values
                    dropNext = false
                    return nil
                }
                // test that the fetched type and the notified type can be different
                return count.description
            })
        
        // Create an observation
        let request = SQLRequest<Void>("SELECT * FROM t")
        var observation = ValueObservation.tracking(request, reducer: reducer)
        observation.extent = .databaseLifetime

        // Start observation
        _ = try observation.start(
            in: dbQueue,
            onError: {
                errors.append($0)
                notificationExpectation.fulfill()
            },
            onChange: {
                changes.append($0)
                notificationExpectation.fulfill()
            })
        
        
        // Test that default config synchronously notifies initial value
        XCTAssertEqual(fetchCount, 1)
        XCTAssertEqual(reduceCount, 1)
        XCTAssertEqual(errors.count, 0)
        XCTAssertEqual(changes, ["0"])
        
        try dbQueue.inDatabase { db in
            // Test a 1st notified transaction
            try db.inTransaction {
                try db.execute("INSERT INTO t DEFAULT VALUES")
                return .commit
            }
            
            // Test an untracked transaction
            try db.inTransaction {
                try db.execute("CREATE TABLE ignored(a)")
                return .commit
            }
            
            // Test a dropped transaction
            dropNext = true
            try db.inTransaction {
                try db.execute("INSERT INTO t DEFAULT VALUES")
                try db.execute("INSERT INTO t DEFAULT VALUES")
                return .commit
            }
            
            // Test a rollbacked transaction
            try db.inTransaction {
                try db.execute("INSERT INTO t DEFAULT VALUES")
                return .rollback
            }
            
            // Test a 2nd notified transaction
            try db.inTransaction {
                try db.execute("INSERT INTO t DEFAULT VALUES")
                try db.execute("INSERT INTO t DEFAULT VALUES")
                return .commit
            }
        }
        
        waitForExpectations(timeout: 1, handler: nil)
        XCTAssertEqual(fetchCount, 4)
        XCTAssertEqual(reduceCount, 4)
        XCTAssertEqual(errors.count, 0)
        XCTAssertEqual(changes, ["0", "1", "5"])
    }
    
    func testInitialError() throws {
        struct TestError: Error { }
        let reducer = AnyValueReducer(
            fetch: { _ in throw TestError() },
            value: { _ in fatalError() })
        
        // Create an observation
        let observation = ValueObservation.tracking(DatabaseRegion.fullDatabase, reducer: reducer)
        
        // Start observation
        do {
            let dbQueue = try makeDatabaseQueue()
            _ = try observation.start(
                in: dbQueue,
                onError: { _ in fatalError() },
                onChange: { _ in fatalError() })
            XCTFail("Expected error")
        } catch is TestError {
        }
    }
    
    func testSuccessThenErrorThenSuccess() throws {
        // We need something to change
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { try $0.execute("CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT)") }
        
        // Track reducer proceess
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
        var observation = ValueObservation.tracking(DatabaseRegion.fullDatabase, reducer: reducer)
        observation.extent = .databaseLifetime

        // Start observation
        _ = try observation.start(
            in: dbQueue,
            onError: {
                errors.append($0)
                notificationExpectation.fulfill()
            },
            onChange: {
                changes.append($0)
                notificationExpectation.fulfill()
            })
        
        struct TestError: Error { }
        nextError = TestError()
        try dbQueue.write { db in
            try db.execute("INSERT INTO t DEFAULT VALUES")
        }
        
        try dbQueue.write { db in
            try db.execute("INSERT INTO t DEFAULT VALUES")
        }
        
        waitForExpectations(timeout: 1, handler: nil)
        XCTAssertEqual(errors.count, 1)
        XCTAssertEqual(changes.count, 2)
    }
    
    func testReadMeReducer() throws {
        // Test for the reducer documented in the main README
        
        // We need something to change
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { try $0.execute("CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT)") }
        
        // Track reducer proceess
        var counts: [Int] = []
        let notificationExpectation = expectation(description: "notification")
        notificationExpectation.assertForOverFulfill = true
        notificationExpectation.expectedFulfillmentCount = 2
        
        // The reducer
        var count = 0
        let reducer = AnyValueReducer(
            fetch: { _ in /* don't fetch anything */ },
            value: { _ -> Int? in
                count += 1
                return count
        })
        
        // Create an observation
        var observation = ValueObservation.tracking(DatabaseRegion.fullDatabase, reducer: reducer)
        observation.extent = .databaseLifetime
        
        // Start observation
        _ = try observation.start(in: dbQueue) { count in
            counts.append(count)
            notificationExpectation.fulfill()
        }
        
        try dbQueue.write { db in
            try db.execute("INSERT INTO t DEFAULT VALUES")
        }
        
        waitForExpectations(timeout: 1, handler: nil)
        XCTAssertEqual(counts, [1, 2])
    }
    
    func testMapValueReducer() throws {
        // We need something to change
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { try $0.execute("CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT)") }
        
        // Track reducer proceess
        var counts: [String] = []
        let notificationExpectation = expectation(description: "notification")
        notificationExpectation.assertForOverFulfill = true
        notificationExpectation.expectedFulfillmentCount = 2
        
        // The base reducer
        var count = 0
        let reducer = AnyValueReducer(
            fetch: { _ in /* don't fetch anything */ },
            value: { _ -> Int? in
                count += 1
                return count
        })
        
        // The mapped reducer
        let mapReducer = reducer.map { count -> String? in
            if count % 2 == 0 { return nil }
            return "\(count)"
        }
        
        // Create an observation
        var observation = ValueObservation.tracking(DatabaseRegion.fullDatabase, reducer: mapReducer)
        observation.extent = .databaseLifetime
        
        // Start observation
        _ = try observation.start(in: dbQueue) { count in
            counts.append(count)
            notificationExpectation.fulfill()
        }
        
        try dbQueue.inDatabase { db in
            try db.execute("INSERT INTO t DEFAULT VALUES")
            try db.execute("INSERT INTO t DEFAULT VALUES")
        }
        
        waitForExpectations(timeout: 1, handler: nil)
        XCTAssertEqual(counts, ["1", "3"])
    }
    
    func testValueObservationMap() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { try $0.execute("CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT)") }
        
        var counts: [String] = []
        let notificationExpectation = expectation(description: "notification")
        notificationExpectation.assertForOverFulfill = true
        notificationExpectation.expectedFulfillmentCount = 3
        
        struct T: TableRecord { }
        var observation = ValueObservation
            .trackingCount(T.all())
            .map { "\($0)" }
        observation.extent = .databaseLifetime
        _ = try observation.start(in: dbQueue) { count in
            counts.append(count)
            notificationExpectation.fulfill()
        }
        
        try dbQueue.inDatabase {
            try $0.execute("INSERT INTO t DEFAULT VALUES")
            try $0.execute("INSERT INTO t DEFAULT VALUES")
        }
        
        waitForExpectations(timeout: 1, handler: nil)
        XCTAssertEqual(counts, ["0", "1", "2"])
    }
}
