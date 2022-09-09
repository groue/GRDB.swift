import XCTest
import Dispatch
@testable import GRDB

class ValueObservationTests: GRDBTestCase {
    func testImmediateError() throws {
        struct TestError: Error { }
        
        func test(_ dbWriter: some DatabaseWriter) throws {
            // Create an observation
            let observation = ValueObservation.trackingConstantRegion { _ in throw TestError() }
            
            // Start observation
            var error: TestError?
            _ = observation.start(
                in: dbWriter,
                scheduling: .immediate,
                onError: { error = $0 as? TestError },
                onChange: { _ in })
            XCTAssertNotNil(error)
        }
        
        try test(makeDatabaseQueue())
        try test(makeDatabasePool())
    }
    
    func testErrorCompletesTheObservation() throws {
        struct TestError: Error { }
        
        func test(_ dbWriter: some DatabaseWriter) throws {
            // We need something to change
            try dbWriter.write { try $0.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT)") }
            
            // Track reducer process
            let notificationExpectation = expectation(description: "notification")
            notificationExpectation.assertForOverFulfill = true
            notificationExpectation.expectedFulfillmentCount = 4
            notificationExpectation.isInverted = true
            
            var nextError: Error? = nil // If not null, observation throws an error
            let observation = ValueObservation.trackingConstantRegion {
                _ = try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM t")
                if let error = nextError {
                    throw error
                }
            }

            // Start observation
            var errorCaught = false
            let cancellable = observation.start(
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
            
            withExtendedLifetime(cancellable) {
                waitForExpectations(timeout: 2, handler: nil)
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
        var region: DatabaseRegion?
        let expectation = self.expectation(description: "")
        let observation = ValueObservation
            .trackingConstantRegion(request.fetchAll)
            .handleEvents(willTrackRegion: {
                region = $0
                expectation.fulfill()
            })
        let observer = observation.start(
            in: dbQueue,
            onError: { error in XCTFail("Unexpected error: \(error)") },
            onChange: { _ in })
        withExtendedLifetime(observer) {
            waitForExpectations(timeout: 2, handler: nil)
            XCTAssertEqual(region!.description, "t(id,name)") // view is NOT tracked
        }
    }
    
    func testPragmaTableOptimization() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write {
            try $0.execute(sql: """
                CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT);
                """)
        }
        
        struct T: TableRecord { }
        
        // A request that requires a pragma introspection query
        let request = T.filter(key: 1).asRequest(of: Row.self)
        
        // Test that no pragma table is included in the observed region.
        // This optimization helps observation that feed from a single table.
        var region: DatabaseRegion?
        let expectation = self.expectation(description: "")
        let observation = ValueObservation
            .trackingConstantRegion(request.fetchAll)
            .handleEvents(willTrackRegion: {
                region = $0
                expectation.fulfill()
            })
        let observer = observation.start(
            in: dbQueue,
            onError: { error in XCTFail("Unexpected error: \(error)") },
            onChange: { _ in })
        withExtendedLifetime(observer) {
            waitForExpectations(timeout: 2, handler: nil)
            XCTAssertEqual(region!.description, "t(id,name)[1]") // pragma_table_xinfo is NOT tracked
        }
    }
    
    // MARK: - Constant Explicit Region
    
    func testTrackingExplicitRegion() throws {
        class TestStream: TextOutputStream {
            @LockedBox var strings: [String] = []
            func write(_ string: String) {
                strings.append(string)
            }
        }
        
        // Test behavior with DatabaseQueue, DatabasePool, etc
        do {
            try assertValueObservation(
                ValueObservation
                    .tracking(region: DatabaseRegion.fullDatabase, fetch: Table("t").fetchCount),
                records: [0, 1, 1, 2, 3, 4],
                setup: { db in
                    try db.execute(sql: """
                        CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT);
                        """)
                },
                recordedUpdates: { db in
                    try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
                    try db.execute(sql: "UPDATE t SET id = id")
                    try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
                    try db.inTransaction {
                        try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
                        try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
                        try db.execute(sql: "DELETE FROM t WHERE id = 1")
                        return .commit
                    }
                    try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
                })
        }
        
        // Track only table "t"
        do {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.write { db in
                try db.execute(sql: """
                    CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT);
                    CREATE TABLE other(id INTEGER PRIMARY KEY AUTOINCREMENT);
                    """)
            }
            
            let logger = TestStream()
            let observation = ValueObservation.tracking(
                region: Table("t"),
                fetch: Table("t").fetchCount)
                .print(to: logger)
            
            let expectation = self.expectation(description: "")
            expectation.expectedFulfillmentCount = 2
            let cancellable = observation.start(
                in: dbQueue,
                onError: { error in XCTFail("Unexpected error: \(error)") },
                onChange: { _ in
                    expectation.fulfill()
            })
            try withExtendedLifetime(cancellable) {
                try dbQueue.writeWithoutTransaction { db in
                    try db.execute(sql: """
                        INSERT INTO other DEFAULT VALUES;
                        INSERT INTO t DEFAULT VALUES;
                        """)
                }
                wait(for: [expectation], timeout: 4)
                XCTAssertEqual(logger.strings, [
                    "start",
                    "fetch",
                    "tracked region: t(*)",
                    "value: 0",
                    "database did change",
                    "fetch",
                    "value: 1",
                ])
            }
        }
        
        // Track only table "other"
        do {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.write { db in
                try db.execute(sql: """
                    CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT);
                    CREATE TABLE other(id INTEGER PRIMARY KEY AUTOINCREMENT);
                    """)
            }
            
            let logger = TestStream()
            let observation = ValueObservation.tracking(
                region: Table("other"),
                fetch: Table("t").fetchCount)
                .print(to: logger)
            
            let expectation = self.expectation(description: "")
            expectation.expectedFulfillmentCount = 2
            let cancellable = observation.start(
                in: dbQueue,
                onError: { error in XCTFail("Unexpected error: \(error)") },
                onChange: { _ in
                    expectation.fulfill()
            })
            try withExtendedLifetime(cancellable) {
                try dbQueue.writeWithoutTransaction { db in
                    try db.execute(sql: """
                        INSERT INTO other DEFAULT VALUES;
                        INSERT INTO t DEFAULT VALUES;
                        """)
                }
                wait(for: [expectation], timeout: 4)
                XCTAssertEqual(logger.strings, [
                    "start",
                    "fetch",
                    "tracked region: other(*)",
                    "value: 0",
                    "database did change",
                    "fetch",
                    "value: 0",
                ])
            }
        }
        
        // Track both "t" and "other"
        do {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.write { db in
                try db.execute(sql: """
                    CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT);
                    CREATE TABLE other(id INTEGER PRIMARY KEY AUTOINCREMENT);
                    """)
            }
            
            let logger = TestStream()
            let observation = ValueObservation.tracking(
                region: Table("t"), Table("other"),
                fetch: Table("t").fetchCount)
                .print(to: logger)
            
            let expectation = self.expectation(description: "")
            expectation.expectedFulfillmentCount = 3
            let cancellable = observation.start(
                in: dbQueue,
                onError: { error in XCTFail("Unexpected error: \(error)") },
                onChange: { _ in
                    expectation.fulfill()
            })
            try withExtendedLifetime(cancellable) {
                try dbQueue.writeWithoutTransaction { db in
                    try db.execute(sql: """
                        INSERT INTO other DEFAULT VALUES;
                        INSERT INTO t DEFAULT VALUES;
                        """)
                }
                wait(for: [expectation], timeout: 4)
                XCTAssertEqual(logger.strings, [
                    "start",
                    "fetch",
                    "tracked region: other(*),t(*)",
                    "value: 0",
                    "database did change",
                    "fetch",
                    "value: 0",
                    "database did change",
                    "fetch",
                    "value: 1",
                ])
            }
        }
    }

    // MARK: - Snapshot Optimization
    
    func testDisallowedSnapshotOptimizationWithAsyncScheduler() throws {
        let dbPool = try makeDatabasePool()
        try dbPool.write { db in
            try db.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT)")
        }
        
        // Force DatabasePool to perform two initial fetches, because between
        // its first read access, and its write access that installs the
        // transaction observer, some write did happen.
        var needsChange = true
        let observation = ValueObservation.trackingConstantRegion { db -> Int in
            if needsChange {
                needsChange = false
                try dbPool.write { db in
                    try db.execute(sql: """
                    INSERT INTO t DEFAULT VALUES;
                    DELETE FROM t;
                    """)
                }
            }
            return try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM t")!
        }
        
        let expectation = self.expectation(description: "")
        expectation.expectedFulfillmentCount = 2
        var observedCounts: [Int] = []
        let cancellable = observation.start(
            in: dbPool,
            scheduling: .async(onQueue: .main),
            onError: { error in XCTFail("Unexpected error: \(error)") },
            onChange: { count in
                observedCounts.append(count)
                expectation.fulfill()
        })
        withExtendedLifetime(cancellable) {
            waitForExpectations(timeout: 2, handler: nil)
            XCTAssertEqual(observedCounts, [0, 0])
        }
    }
    
    func testDisallowedSnapshotOptimizationWithImmediateScheduler() throws {
        let dbPool = try makeDatabasePool()
        try dbPool.write { db in
            try db.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT)")
        }
        
        // Force DatabasePool to perform two initial fetches, because between
        // its first read access, and its write access that installs the
        // transaction observer, some write did happen.
        var needsChange = true
        let observation = ValueObservation.trackingConstantRegion { db -> Int in
            if needsChange {
                needsChange = false
                try dbPool.write { db in
                    try db.execute(sql: """
                    INSERT INTO t DEFAULT VALUES;
                    DELETE FROM t;
                    """)
                }
            }
            return try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM t")!
        }
        
        let expectation = self.expectation(description: "")
        expectation.expectedFulfillmentCount = 2
        var observedCounts: [Int] = []
        let cancellable = observation.start(
            in: dbPool,
            scheduling: .immediate,
            onError: { error in XCTFail("Unexpected error: \(error)") },
            onChange: { count in
                observedCounts.append(count)
                expectation.fulfill()
        })
        withExtendedLifetime(cancellable) {
            waitForExpectations(timeout: 2, handler: nil)
            XCTAssertEqual(observedCounts, [0, 0])
        }
    }
    
    func testAllowedSnapshotOptimizationWithAsyncScheduler() throws {
        let dbPool = try makeDatabasePool()
        try dbPool.write { db in
            try db.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT)")
        }
        
        // Allow pool to perform a single initial fetch, because between
        // its first read access, and its write access that installs the
        // transaction observer, no write did happen.
        var needsChange = true
        let observation = ValueObservation.trackingConstantRegion { db -> Int in
            if needsChange {
                needsChange = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    try! dbPool.write { db in
                        try db.execute(sql: """
                        INSERT INTO t DEFAULT VALUES;
                        """)
                    }
                }
            }
            return try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM t")!
        }
        
        let expectedCounts: [Int]
        #if os(macOS) || targetEnvironment(macCatalyst) || GRDBCIPHER || (GRDBCUSTOMSQLITE && !SQLITE_ENABLE_SNAPSHOT)
        // Optimization not available
        expectedCounts = [0, 0, 1]
        #else
        // Optimization available
        expectedCounts = [0, 1]
        #endif
        
        let expectation = self.expectation(description: "")
        expectation.expectedFulfillmentCount = expectedCounts.count
        var observedCounts: [Int] = []
        let cancellable = observation.start(
            in: dbPool,
            scheduling: .async(onQueue: .main),
            onError: { error in XCTFail("Unexpected error: \(error)") },
            onChange: { count in
                observedCounts.append(count)
                expectation.fulfill()
            })
        withExtendedLifetime(cancellable) {
            waitForExpectations(timeout: 2, handler: nil)
            XCTAssertEqual(observedCounts, expectedCounts)
        }
    }
    
    func testAllowedSnapshotOptimizationWithImmediateScheduler() throws {
        let dbPool = try makeDatabasePool()
        try dbPool.write { db in
            try db.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT)")
        }
        
        // Allow pool to perform a single initial fetch, because between
        // its first read access, and its write access that installs the
        // transaction observer, no write did happen.
        var needsChange = true
        let observation = ValueObservation.trackingConstantRegion { db -> Int in
            if needsChange {
                needsChange = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    try! dbPool.write { db in
                        try db.execute(sql: """
                        INSERT INTO t DEFAULT VALUES;
                        """)
                    }
                }
            }
            return try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM t")!
        }
        
        let expectedCounts: [Int]
        #if os(macOS) || targetEnvironment(macCatalyst) || GRDBCIPHER || (GRDBCUSTOMSQLITE && !SQLITE_ENABLE_SNAPSHOT)
        // Optimization not available
        expectedCounts = [0, 0, 1]
        #else
        // Optimization available
        expectedCounts = [0, 1]
        #endif
        
        let expectation = self.expectation(description: "")
        expectation.expectedFulfillmentCount = expectedCounts.count
        var observedCounts: [Int] = []
        let cancellable = observation.start(
            in: dbPool,
            scheduling: .immediate,
            onError: { error in XCTFail("Unexpected error: \(error)") },
            onChange: { count in
                observedCounts.append(count)
                expectation.fulfill()
            })
        withExtendedLifetime(cancellable) {
            waitForExpectations(timeout: 2, handler: nil)
            XCTAssertEqual(observedCounts, expectedCounts)
        }
    }
    
    // MARK: - Cancellation
    
    func testCancellableLifetime() throws {
        // We need something to change
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { try $0.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT)") }
        
        // Track reducer process
        var changesCount = 0
        let notificationExpectation = expectation(description: "notification")
        notificationExpectation.assertForOverFulfill = true
        notificationExpectation.expectedFulfillmentCount = 2
        
        // Create an observation
        let observation = ValueObservation.trackingConstantRegion {
            try Int.fetchOne($0, sql: "SELECT * FROM t")
        }
        
        // Start observation and deallocate cancellable after second change
        var cancellable: DatabaseCancellable?
        cancellable = observation.start(
            in: dbQueue,
            onError: { error in XCTFail("Unexpected error: \(error)") },
            onChange: { _ in
                changesCount += 1
                if changesCount == 2 {
                    cancellable = nil
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
        
        // Avoid "Variable 'cancellable' was written to, but never read" warning
        _ = cancellable
        
        waitForExpectations(timeout: 2, handler: nil)
        XCTAssertEqual(changesCount, 2)
    }
    
    func testCancellableExplicitCancellation() throws {
        // We need something to change
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { try $0.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT)") }
        
        // Track reducer process
        var changesCount = 0
        let notificationExpectation = expectation(description: "notification")
        notificationExpectation.assertForOverFulfill = true
        notificationExpectation.expectedFulfillmentCount = 2
        
        // Create an observation
        let observation = ValueObservation.trackingConstantRegion {
            try Int.fetchOne($0, sql: "SELECT * FROM t")
        }
        
        // Start observation and cancel cancellable after second change
        var cancellable: DatabaseCancellable!
        cancellable = observation.start(
            in: dbQueue,
            onError: { error in XCTFail("Unexpected error: \(error)") },
            onChange: { _ in
                changesCount += 1
                if changesCount == 2 {
                    cancellable.cancel()
                }
                notificationExpectation.fulfill()
        })
        
        try withExtendedLifetime(cancellable) {
            // notified
            try dbQueue.write { db in
                try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
            }
            
            // not notified
            try dbQueue.write { db in
                try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
            }
            
            waitForExpectations(timeout: 2, handler: nil)
            XCTAssertEqual(changesCount, 2)
        }
    }
    
    func testCancellableInvalidation1() throws {
        // Test that observation stops when cancellable is deallocated
        func test(_ dbWriter: some DatabaseWriter) throws {
            try dbWriter.write { try $0.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT)") }

            let notificationExpectation = expectation(description: "notification")
            notificationExpectation.isInverted = true
            notificationExpectation.expectedFulfillmentCount = 2

            do {
                var cancellable: DatabaseCancellable? = nil
                _ = cancellable // Avoid "Variable 'cancellable' was written to, but never read" warning
                var shouldStopObservation = false
                let observation = ValueObservation(
                    trackingMode: .nonConstantRegionRecordedFromSelection,
                    makeReducer: {
                        AnyValueReducer<Void, Void>(
                            fetch: { _ in
                                if shouldStopObservation {
                                    cancellable = nil /* deallocation */
                                }
                                shouldStopObservation = true
                            },
                            value: { _ in () })
                    })
                cancellable = observation.start(
                    in: dbWriter,
                    scheduling: .immediate,
                    onError: { error in XCTFail("Unexpected error: \(error)") },
                    onChange: { _ in
                        notificationExpectation.fulfill()
                    })
            }

            try dbWriter.write { db in
                try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
            }
            waitForExpectations(timeout: 2, handler: nil)
        }

        try test(makeDatabaseQueue())
        try test(makeDatabasePool())
    }
    
    func testCancellableInvalidation2() throws {
        // Test that observation stops when cancellable is deallocated
        func test(_ dbWriter: some DatabaseWriter) throws {
            try dbWriter.write { try $0.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT)") }
            
            let notificationExpectation = expectation(description: "notification")
            notificationExpectation.isInverted = true
            notificationExpectation.expectedFulfillmentCount = 2
            
            do {
                var cancellable: DatabaseCancellable? = nil
                _ = cancellable // Avoid "Variable 'cancellable' was written to, but never read" warning
                var shouldStopObservation = false
                let observation = ValueObservation(
                    trackingMode: .nonConstantRegionRecordedFromSelection,
                    makeReducer: {
                        AnyValueReducer<Void, Void>(
                            fetch: { _ in },
                            value: { _ in
                                if shouldStopObservation {
                                    cancellable = nil /* deallocation right before notification */
                                }
                                shouldStopObservation = true
                                return ()
                            })
                    })
                cancellable = observation.start(
                    in: dbWriter,
                    scheduling: .immediate,
                    onError: { error in XCTFail("Unexpected error: \(error)") },
                    onChange: { _ in
                        notificationExpectation.fulfill()
                    })
            }
            
            try dbWriter.write { db in
                try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
            }
            waitForExpectations(timeout: 2, handler: nil)
        }
        
        try test(makeDatabaseQueue())
        try test(makeDatabasePool())
    }
    
    func testIssue1209() throws {
        func test(_ dbWriter: some DatabaseWriter) throws {
            try dbWriter.write {
                try $0.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT)")
            }
            
            // We'll start N observations
            let N = 100
            
            // We'll wait for initial value notification before modifying the database
            let initialValueExpectation = expectation(description: "")
            initialValueExpectation.expectedFulfillmentCount = N
            
            // The test will pass if we get change notifications
            let changeExpectation = expectation(description: "")
            changeExpectation.expectedFulfillmentCount = N
            
            // Observe N times
            let cancellables = (0..<N).map { _ in
                ValueObservation
                    .tracking(Table("t").fetchCount)
                    .removeDuplicates()
                    .start(
                        in: dbWriter,
                        onError: { XCTFail("Unexpected error: \($0)") },
                        onChange: { value in
                            if value == 0 {
                                initialValueExpectation.fulfill()
                            } else {
                                changeExpectation.fulfill()
                            }
                        })
            }
            
            wait(for: [initialValueExpectation], timeout: 5)
            dbWriter.asyncWriteWithoutTransaction {
                try! $0.execute(sql: "INSERT INTO t DEFAULT VALUES")
            }
            wait(for: [changeExpectation], timeout: 5)
            
            // Cleanup
            for cancellable in cancellables { cancellable.cancel() }
            try dbWriter.close()
        }
        
        try test(makeDatabaseQueue())
        try test(makeDatabasePool())
    }
    
    // MARK: - Async Await
    
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testAsyncAwait_values_prefix() async throws {
        func test(_ writer: some DatabaseWriter) async throws {
            // We need something to change
            try await writer.write { try $0.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT)") }
            
            let cancellationExpectation = expectation(description: "cancelled")
            let task = Task { () -> [Int] in
                var counts: [Int] = []
                let observation = ValueObservation
                    .trackingConstantRegion(Table("t").fetchCount)
                    .handleEvents(didCancel: { cancellationExpectation.fulfill() })
                
                for try await count in try observation.values(in: writer).prefix(while: { $0 < 3 }) {
                    counts.append(count)
                    try await writer.write { try $0.execute(sql: "INSERT INTO t DEFAULT VALUES") }
                }
                return counts
            }
            
            let counts = try await task.value
            
            // All values were published
            assertValueObservationRecordingMatch(recorded: counts, expected: [0, 1, 2])
            
            // Observation was ended
            wait(for: [cancellationExpectation], timeout: 2)
        }
        
        try await AsyncTest(test).run { try DatabaseQueue() }
        try await AsyncTest(test).runAtTemporaryDatabasePath { try DatabaseQueue(path: $0) }
        try await AsyncTest(test).runAtTemporaryDatabasePath { try DatabasePool(path: $0) }
    }
    
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testAsyncAwait_values_prefix_immediate_scheduling() async throws {
        func test(_ writer: some DatabaseWriter) async throws {
            // We need something to change
            try await writer.write { try $0.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT)") }
            
            let cancellationExpectation = expectation(description: "cancelled")
            let task = Task { @MainActor () -> [Int] in
                var counts: [Int] = []
                let observation = ValueObservation
                    .trackingConstantRegion(Table("t").fetchCount)
                    .handleEvents(didCancel: { cancellationExpectation.fulfill() })
                
                for try await count in try observation.values(in: writer, scheduling: .immediate).prefix(while: { $0 < 3 }) {
                    counts.append(count)
                    try await writer.write { try $0.execute(sql: "INSERT INTO t DEFAULT VALUES") }
                }
                return counts
            }
            
            let counts = try await task.value
            
            // All values were published
            assertValueObservationRecordingMatch(recorded: counts, expected: [0, 1, 2])
            
            // Observation was ended
            wait(for: [cancellationExpectation], timeout: 2)
        }
        
        try await AsyncTest(test).run { try DatabaseQueue() }
        try await AsyncTest(test).runAtTemporaryDatabasePath { try DatabaseQueue(path: $0) }
        try await AsyncTest(test).runAtTemporaryDatabasePath { try DatabasePool(path: $0) }
    }
    
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testAsyncAwait_values_break() async throws {
        func test(_ writer: some DatabaseWriter) async throws {
            // We need something to change
            try await writer.write { try $0.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT)") }
            
            let cancellationExpectation = expectation(description: "cancelled")
            let task = Task { () -> [Int] in
                var counts: [Int] = []
                let observation = ValueObservation
                    .trackingConstantRegion(Table("t").fetchCount)
                    .handleEvents(didCancel: { cancellationExpectation.fulfill() })
                
                for try await count in observation.values(in: writer) {
                    counts.append(count)
                    if count == 2 {
                        break
                    } else {
                        try await writer.write { try $0.execute(sql: "INSERT INTO t DEFAULT VALUES") }
                    }
                }
                return counts
            }
            
            let counts = try await task.value
            
            // All values were published
            assertValueObservationRecordingMatch(recorded: counts, expected: [0, 1, 2])
            
            // Observation was ended
            wait(for: [cancellationExpectation], timeout: 2)
        }
        
        try await AsyncTest(test).run { try DatabaseQueue() }
        try await AsyncTest(test).runAtTemporaryDatabasePath { try DatabaseQueue(path: $0) }
        try await AsyncTest(test).runAtTemporaryDatabasePath { try DatabasePool(path: $0) }
    }
    
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testAsyncAwait_values_immediate_break() async throws {
        func test(_ writer: some DatabaseWriter) async throws {
            // We need something to change
            try await writer.write { try $0.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT)") }
            
            let cancellationExpectation = expectation(description: "cancelled")
            
            let task = Task { @MainActor () -> [Int] in
                var counts: [Int] = []
                let observation = ValueObservation
                    .trackingConstantRegion(Table("t").fetchCount)
                    .handleEvents(didCancel: { cancellationExpectation.fulfill() })
                
                for try await count in observation.values(in: writer, scheduling: .immediate) {
                    counts.append(count)
                    break
                }
                return counts
            }
            
            let counts = try await task.value
            
            // A single value was published
            assertValueObservationRecordingMatch(recorded: counts, expected: [0])
            
            // Observation was ended
            wait(for: [cancellationExpectation], timeout: 2)
        }
        
        try await AsyncTest(test).run { try DatabaseQueue() }
        try await AsyncTest(test).runAtTemporaryDatabasePath { try DatabaseQueue(path: $0) }
        try await AsyncTest(test).runAtTemporaryDatabasePath { try DatabasePool(path: $0) }
    }
    
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testAsyncAwait_values_cancelled() async throws {
        func test(_ writer: some DatabaseWriter) async throws {
            // We need something to change
            try await writer.write { try $0.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT)") }
            
            let cancellationExpectation = expectation(description: "cancelled")
            
            // Launch a task that we'll cancel
            let cancelledTask = Task<String, Error> {
                // Loops until cancelled
                let observation = ValueObservation.trackingConstantRegion(Table("t").fetchCount)
                let cancelledObservation = observation.handleEvents(didCancel: {
                    cancellationExpectation.fulfill()
                })
                for try await _ in cancelledObservation.values(in: writer) { }
                return "cancelled loop"
            }
            
            // Lanch the task that cancels
            Task {
                let observation = ValueObservation.trackingConstantRegion(Table("t").fetchCount)
                for try await count in observation.values(in: writer) {
                    if count == 3 {
                        cancelledTask.cancel()
                        break
                    } else {
                        try await writer.write {
                            try $0.execute(sql: "INSERT INTO t DEFAULT VALUES")
                        }
                    }
                }
            }
            
            // Make sure loop has ended in the cancelled task
            let cancelledValue = try await cancelledTask.value
            XCTAssertEqual(cancelledValue, "cancelled loop")
            
            // Make sure observation was cancelled as well
            wait(for: [cancellationExpectation], timeout: 2)
        }
        
        try await AsyncTest(test).run { try DatabaseQueue() }
        try await AsyncTest(test).runAtTemporaryDatabasePath { try DatabaseQueue(path: $0) }
        try await AsyncTest(test).runAtTemporaryDatabasePath { try DatabasePool(path: $0) }
    }
}
