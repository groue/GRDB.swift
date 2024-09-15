import XCTest
import Dispatch
@testable import GRDB

class ValueObservationTests: GRDBTestCase {
    // Test passes if it compiles.
    // See <https://github.com/groue/GRDB.swift/issues/1541>
    func testStartFromAnyDatabaseReader(reader: any DatabaseReader) {
        _ = ValueObservation
            .trackingConstantRegion { _ in }
            .start(in: reader, onError: { _ in }, onChange: { })
    }
    
    // Test passes if it compiles.
    // See <https://github.com/groue/GRDB.swift/issues/1541>
    func testStartFromAnyDatabaseWriter(writer: any DatabaseWriter) {
        _ = ValueObservation
            .trackingConstantRegion { _ in }
            .start(in: writer, onError: { _ in }, onChange: { })
    }
    
    // Test passes if it compiles.
    // See <https://github.com/groue/GRDB.swift/issues/1541>
    @available(iOS 13, macOS 10.15, tvOS 13, *)
    func testValuesFromAnyDatabaseWriter(writer: any DatabaseWriter) {
        func observe<T>(
            fetch: @escaping @Sendable (Database) throws -> T
        ) throws -> AsyncValueObservation<T> {
            ValueObservation.tracking(fetch).values(in: writer)
        }
    }
    
    func testImmediateError() throws {
        struct TestError: Error { }
        
        func test(_ dbWriter: some DatabaseWriter) throws {
            // Create an observation
            let observation = ValueObservation.trackingConstantRegion { _ in throw TestError() }
            
            // Start observation
            let errorMutex: Mutex<TestError?> = Mutex(nil)
            _ = observation.start(
                in: dbWriter,
                scheduling: .immediate,
                onError: { error in
                    errorMutex.store(error as? TestError)
                },
                onChange: { _ in })
            XCTAssertNotNil(errorMutex.load())
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
            
            let nextErrorMutex: Mutex<Error?> = Mutex(nil) // If not null, observation throws an error
            let observation = ValueObservation.trackingConstantRegion {
                _ = try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM t")
                try nextErrorMutex.withLock { error in
                    if let error { throw error }
                }
            }
            
            // Start observation
            let errorCaughtMutex = Mutex(false)
            let cancellable = observation.start(
                in: dbWriter,
                onError: { _ in
                    errorCaughtMutex.store(true)
                    notificationExpectation.fulfill()
                },
                onChange: {
                    XCTAssertFalse(errorCaughtMutex.load())
                    nextErrorMutex.store(TestError())
                    notificationExpectation.fulfill()
                    // Trigger another change
                    try! dbWriter.writeWithoutTransaction { db in
                        try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
                    }
                })
            
            withExtendedLifetime(cancellable) {
                waitForExpectations(timeout: 2, handler: nil)
                XCTAssertTrue(errorCaughtMutex.load())
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
        let regionMutex: Mutex<DatabaseRegion?> = Mutex(nil)
        let expectation = self.expectation(description: "")
        let observation = ValueObservation
            .trackingConstantRegion { _ = try request.fetchAll($0) }
            .handleEvents(willTrackRegion: { region in
                regionMutex.store(region)
                expectation.fulfill()
            })
        let observer = observation.start(
            in: dbQueue,
            onError: { error in XCTFail("Unexpected error: \(error)") },
            onChange: { _ in })
        withExtendedLifetime(observer) {
            waitForExpectations(timeout: 2, handler: nil)
            XCTAssertEqual(regionMutex.load()!.description, "t(id,name)") // view is NOT tracked
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
        let regionMutex: Mutex<DatabaseRegion?> = Mutex(nil)
        let expectation = self.expectation(description: "")
        let observation = ValueObservation
            .trackingConstantRegion{ _ = try request.fetchAll($0) }
            .handleEvents(willTrackRegion: { region in
                regionMutex.store(region)
                expectation.fulfill()
            })
        let observer = observation.start(
            in: dbQueue,
            onError: { error in XCTFail("Unexpected error: \(error)") },
            onChange: { _ in })
        withExtendedLifetime(observer) {
            waitForExpectations(timeout: 2, handler: nil)
            XCTAssertEqual(regionMutex.load()?.description, "t(id,name)[1]") // pragma_table_xinfo is NOT tracked
        }
    }
    
    // MARK: - Constant Explicit Region
    
    func testTrackingExplicitRegion() throws {
        class TestStream: TextOutputStream {
            private var stringsMutex: Mutex<[String]> = Mutex([])
            var strings: [String] { stringsMutex.load() }
            func write(_ string: String) {
                stringsMutex.withLock { $0.append(string) }
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
        let needsChangeMutex = Mutex(true)
        let observation = ValueObservation.trackingConstantRegion { db -> Int in
            let needsChange = needsChangeMutex.withLock { needed in
                let wasNeeded = needed
                needed = false
                return wasNeeded
            }
            if needsChange {
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
        let observedCountsMutex: Mutex<[Int]> = Mutex([])
        let cancellable = observation.start(
            in: dbPool,
            scheduling: .async(onQueue: .main),
            onError: { error in XCTFail("Unexpected error: \(error)") },
            onChange: { count in
                observedCountsMutex.withLock { $0.append(count) }
                expectation.fulfill()
            })
        withExtendedLifetime(cancellable) {
            waitForExpectations(timeout: 2, handler: nil)
            XCTAssertEqual(observedCountsMutex.load(), [0, 0])
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
        let needsChangeMutex = Mutex(true)
        let observation = ValueObservation.trackingConstantRegion { db -> Int in
            let needsChange = needsChangeMutex.withLock { needed in
                let wasNeeded = needed
                needed = false
                return wasNeeded
            }
            if needsChange {
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
        let observedCountsMutex: Mutex<[Int]> = Mutex([])
        let cancellable = observation.start(
            in: dbPool,
            scheduling: .immediate,
            onError: { error in XCTFail("Unexpected error: \(error)") },
            onChange: { count in
                observedCountsMutex.withLock { $0.append(count) }
                expectation.fulfill()
            })
        withExtendedLifetime(cancellable) {
            waitForExpectations(timeout: 2, handler: nil)
            XCTAssertEqual(observedCountsMutex.load(), [0, 0])
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
        let needsChangeMutex = Mutex(true)
        let observation = ValueObservation.trackingConstantRegion { db -> Int in
            let needsChange = needsChangeMutex.withLock { needed in
                let wasNeeded = needed
                needed = false
                return wasNeeded
            }
            if needsChange {
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
#if SQLITE_ENABLE_SNAPSHOT || (!GRDBCUSTOMSQLITE && !GRDBCIPHER)
        // Optimization available
        expectedCounts = [0, 1]
#else
        // Optimization not available
        expectedCounts = [0, 0, 1]
#endif
        
        let expectation = self.expectation(description: "")
        expectation.expectedFulfillmentCount = expectedCounts.count
        let observedCountsMutex: Mutex<[Int]> = Mutex([])
        let cancellable = observation.start(
            in: dbPool,
            scheduling: .async(onQueue: .main),
            onError: { error in XCTFail("Unexpected error: \(error)") },
            onChange: { count in
                observedCountsMutex.withLock { $0.append(count) }
                expectation.fulfill()
            })
        withExtendedLifetime(cancellable) {
            waitForExpectations(timeout: 2, handler: nil)
            XCTAssertEqual(observedCountsMutex.load(), expectedCounts)
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
        let needsChangeMutex = Mutex(true)
        let observation = ValueObservation.trackingConstantRegion { db -> Int in
            let needsChange = needsChangeMutex.withLock { needed in
                let wasNeeded = needed
                needed = false
                return wasNeeded
            }
            if needsChange {
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
#if SQLITE_ENABLE_SNAPSHOT || (!GRDBCUSTOMSQLITE && !GRDBCIPHER)
        // Optimization available
        expectedCounts = [0, 1]
#else
        // Optimization not available
        expectedCounts = [0, 0, 1]
#endif
        
        let expectation = self.expectation(description: "")
        expectation.expectedFulfillmentCount = expectedCounts.count
        let observedCountsMutex: Mutex<[Int]> = Mutex([])
        let cancellable = observation.start(
            in: dbPool,
            scheduling: .immediate,
            onError: { error in XCTFail("Unexpected error: \(error)") },
            onChange: { count in
                observedCountsMutex.withLock { $0.append(count) }
                expectation.fulfill()
            })
        withExtendedLifetime(cancellable) {
            waitForExpectations(timeout: 2, handler: nil)
            XCTAssertEqual(observedCountsMutex.load(), expectedCounts)
        }
    }
    
    // MARK: - Snapshot Observation
    
#if SQLITE_ENABLE_SNAPSHOT || (!GRDBCUSTOMSQLITE && !GRDBCIPHER)
    func testDatabaseSnapshotPoolObservation() throws {
        let dbPool = try makeDatabasePool()
        try dbPool.write { try $0.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT)") }
        
        let expectation = XCTestExpectation()
        expectation.assertForOverFulfill = false
        
        let observation = ValueObservation.trackingConstantRegion { db in
            try db.registerAccess(to: Table("t"))
            expectation.fulfill()
            return try DatabaseSnapshotPool(db)
        }
        
        let recorder = observation.record(in: dbPool)
        wait(for: [expectation], timeout: 5)
        try dbPool.write { try $0.execute(sql: "INSERT INTO t DEFAULT VALUES") }
        
        let results = try wait(for: recorder.next(2), timeout: 5)
        XCTAssertEqual(results.count, 2)
        try XCTAssertEqual(results[0].read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM t")! }, 0)
        try XCTAssertEqual(results[1].read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM t")! }, 1)
    }
#endif
    
    // MARK: - Unspecified Changes
    
    func test_ValueObservation_is_triggered_by_explicit_change_notification() throws {
        let dbQueue1 = try makeDatabaseQueue(filename: "test.sqlite")
        try dbQueue1.write { db in
            try db.execute(sql: "CREATE TABLE test(a)")
        }
        
        let undetectedExpectation = expectation(description: "undetected")
        undetectedExpectation.expectedFulfillmentCount = 2 // initial value and change
        undetectedExpectation.isInverted = true

        let detectedExpectation = expectation(description: "detected")
        detectedExpectation.expectedFulfillmentCount = 2 // initial value and change
        
        let observation = ValueObservation.tracking { db in
            try Table("test").fetchCount(db)
        }
        let cancellable = observation.start(
            in: dbQueue1,
            scheduling: .immediate,
            onError: { error in XCTFail("Unexpected error: \(error)") },
            onChange: { _ in
                undetectedExpectation.fulfill()
                detectedExpectation.fulfill()
            })

        try withExtendedLifetime(cancellable) {
            // Change performed from external connection is not detected...
            let dbQueue2 = try makeDatabaseQueue(filename: "test.sqlite")
            try dbQueue2.write { db in
                try db.execute(sql: "INSERT INTO test (a) VALUES (1)")
            }
            wait(for: [undetectedExpectation], timeout: 2)
            
            // ... until we perform an explicit change notification
            try dbQueue1.write { db in
                try db.notifyChanges(in: Table("test"))
            }
            wait(for: [detectedExpectation], timeout: 2)
        }
    }
    
    // MARK: - Cancellation
    
    func testCancellableLifetime() throws {
        // We need something to change
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { try $0.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT)") }
        
        // Track reducer process
        let changesCountMutex = Mutex(0)
        let notificationExpectation = expectation(description: "notification")
        notificationExpectation.assertForOverFulfill = true
        notificationExpectation.expectedFulfillmentCount = 2
        
        // Create an observation
        let observation = ValueObservation.trackingConstantRegion {
            try Int.fetchOne($0, sql: "SELECT * FROM t")
        }
        
        // Start observation and deallocate cancellable after second change
        nonisolated(unsafe) var cancellable: (any DatabaseCancellable)?
        cancellable = observation.start(
            in: dbQueue,
            onError: { error in XCTFail("Unexpected error: \(error)") },
            onChange: { _ in
                if changesCountMutex.increment() == 2 {
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
        XCTAssertEqual(changesCountMutex.load(), 2)
    }
    
    func testCancellableExplicitCancellation() throws {
        // We need something to change
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { try $0.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT)") }
        
        // Track reducer process
        let changesCountMutex = Mutex(0)
        let notificationExpectation = expectation(description: "notification")
        notificationExpectation.assertForOverFulfill = true
        notificationExpectation.expectedFulfillmentCount = 2
        
        // Create an observation
        let observation = ValueObservation.trackingConstantRegion {
            try Int.fetchOne($0, sql: "SELECT * FROM t")
        }
        
        // Start observation and cancel cancellable after second change
        nonisolated(unsafe) var cancellable: (any DatabaseCancellable)!
        cancellable = observation.start(
            in: dbQueue,
            onError: { error in XCTFail("Unexpected error: \(error)") },
            onChange: { _ in
                if changesCountMutex.increment() == 2 {
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
            XCTAssertEqual(changesCountMutex.load(), 2)
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
                nonisolated(unsafe) var cancellable: (any DatabaseCancellable)? = nil
                _ = cancellable // Avoid "Variable 'cancellable' was written to, but never read" warning
                let shouldStopObservationMutex = Mutex(false)
                let observation = ValueObservation(
                    trackingMode: .nonConstantRegionRecordedFromSelection,
                    makeReducer: {
                        AnyValueReducer<Void, Void>(
                            fetch: { _ in
                                shouldStopObservationMutex.withLock { shouldStopObservation in
                                    if shouldStopObservation {
                                        cancellable = nil /* deallocation */
                                    }
                                    shouldStopObservation = true
                                }
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
                nonisolated(unsafe) var cancellable: (any DatabaseCancellable)? = nil
                _ = cancellable // Avoid "Variable 'cancellable' was written to, but never read" warning
                let shouldStopObservationMutex = Mutex(false)
                let observation = ValueObservation(
                    trackingMode: .nonConstantRegionRecordedFromSelection,
                    makeReducer: {
                        AnyValueReducer<Void, Void>(
                            fetch: { _ in },
                            value: { _ in
                                shouldStopObservationMutex.withLock { shouldStopObservation in
                                    if shouldStopObservation {
                                        cancellable = nil /* deallocation right before notification */
                                    }
                                    shouldStopObservation = true
                                }
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
    
    func testIssue1550() throws {
        func test(_ writer: some DatabaseWriter) throws {
            try writer.write { try $0.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT)") }
            
            // Start observing
            let countsMutex: Mutex<[Int]> = Mutex([])
            let cancellable = ValueObservation
                .trackingConstantRegion { try Table("t").fetchCount($0) }
                .start(in: writer) { error in
                    XCTFail("Unexpected error: \(error)")
                } onChange: { count in
                    countsMutex.withLock { $0.append(count) }
                }
            
            // Perform a write after cancellation, but before the
            // observation could schedule the removal of its transaction
            // observer from the writer dispatch queue.
            let semaphore = DispatchSemaphore(value: 0)
            writer.asyncWriteWithoutTransaction { db in
                semaphore.wait()
                do {
                    try db.execute(sql: "INSERT INTO t(id) VALUES (NULL)")
                } catch {
                    XCTFail("Unexpected error: \(error)")
                }
            }
            cancellable.cancel()
            semaphore.signal()
            
            // Wait until a second write could run, after the observation
            // has removed its transaction observer from the writer
            // dispatch queue.
            let secondWriteExpectation = expectation(description: "cancelled")
            writer.asyncWriteWithoutTransaction { _ in
                secondWriteExpectation.fulfill()
            }
            wait(for: [secondWriteExpectation], timeout: 5)
            
            // We should not have been notified of the first write, because
            // it was performed after cancellation.
            XCTAssertFalse(countsMutex.load().contains(1))
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
    
    @available(iOS 13, macOS 10.15, tvOS 13, *)
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
                
                for try await count in try observation.values(in: writer).prefix(while: { $0 <= 3 }) {
                    counts.append(count)
                    try await writer.write { try $0.execute(sql: "INSERT INTO t DEFAULT VALUES") }
                }
                return counts
            }
            
            let counts = try await task.value
            XCTAssertTrue(counts.contains(0))
            XCTAssertTrue(counts.contains(where: { $0 >= 2 }))
            XCTAssertEqual(counts.sorted(), counts)
            
            // Observation was ended
#if compiler(>=5.8)
            await fulfillment(of: [cancellationExpectation], timeout: 2)
#else
            wait(for: [cancellationExpectation], timeout: 2)
#endif
        }
        
        try await AsyncTest(test).run { try DatabaseQueue() }
        try await AsyncTest(test).runAtTemporaryDatabasePath { try DatabaseQueue(path: $0) }
        try await AsyncTest(test).runAtTemporaryDatabasePath { try DatabasePool(path: $0) }
    }
    
    @available(iOS 13, macOS 10.15, tvOS 13, *)
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
                    if count > 3 {
                        break
                    } else {
                        try await writer.write { try $0.execute(sql: "INSERT INTO t DEFAULT VALUES") }
                    }
                }
                return counts
            }
            
            let counts = try await task.value
            XCTAssertTrue(counts.contains(0))
            XCTAssertTrue(counts.contains(where: { $0 >= 2 }))
            XCTAssertEqual(counts.sorted(), counts)
            
            // Observation was ended
#if compiler(>=5.8)
            await fulfillment(of: [cancellationExpectation], timeout: 2)
#else
            wait(for: [cancellationExpectation], timeout: 2)
#endif
        }
        
        try await AsyncTest(test).run { try DatabaseQueue() }
        try await AsyncTest(test).runAtTemporaryDatabasePath { try DatabaseQueue(path: $0) }
        try await AsyncTest(test).runAtTemporaryDatabasePath { try DatabasePool(path: $0) }
    }
    
    @available(iOS 13, macOS 10.15, tvOS 13, *)
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
                    if count >= 3 {
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
#if compiler(>=5.8)
            await fulfillment(of: [cancellationExpectation], timeout: 2)
#else
            wait(for: [cancellationExpectation], timeout: 2)
#endif
        }
        
        try await AsyncTest(test).run { try DatabaseQueue() }
        try await AsyncTest(test).runAtTemporaryDatabasePath { try DatabaseQueue(path: $0) }
        try await AsyncTest(test).runAtTemporaryDatabasePath { try DatabasePool(path: $0) }
    }
    
    // An attempt at finding a regression test for <https://github.com/groue/GRDB.swift/issues/1362>
    func testManyObservations() throws {
        // TODO: Fix flaky test with SQLCipher 3
        #if GRDBCIPHER
        if sqlite3_libversion_number() <= 3020001 {
            throw XCTSkip("Skip flaky test with SQLCipher 3")
        }
        #endif
        
        // We'll start many observations
        let observationCount = 100
        dbConfiguration.maximumReaderCount = 5
        
        func test(_ writer: some DatabaseWriter, scheduling scheduler: some ValueObservationScheduler) throws {
            try writer.write {
                try $0.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT)")
            }
            let observation = ValueObservation.tracking {
                try Table("t").fetchCount($0)
            }
            
            let initialValueExpectation = self.expectation(description: "initialValue")
#if SQLITE_ENABLE_SNAPSHOT || (!GRDBCUSTOMSQLITE && !GRDBCIPHER)
            initialValueExpectation.assertForOverFulfill = true
#else
            // ValueObservation on DatabasePool will notify the first value twice
            initialValueExpectation.assertForOverFulfill = false
#endif
            initialValueExpectation.expectedFulfillmentCount = observationCount
            
            let secondValueExpectation = self.expectation(description: "secondValue")
            secondValueExpectation.expectedFulfillmentCount = observationCount
            
            var cancellables: [AnyDatabaseCancellable] = []
            for _ in 0..<observationCount {
                let cancellable = observation.start(in: writer, scheduling: scheduler) { error in
                    XCTFail("Unexpected error: \(error)")
                } onChange: { count in
                    if count == 0 {
                        initialValueExpectation.fulfill()
                    } else {
                        secondValueExpectation.fulfill()
                    }
                }
                cancellables.append(cancellable)
            }
            
            try withExtendedLifetime(cancellables) {
                wait(for: [initialValueExpectation], timeout: 2)
                try writer.write {
                    try $0.execute(sql: "INSERT INTO t DEFAULT VALUES")
                }
                wait(for: [secondValueExpectation], timeout: 2)
            }
        }
        
        try Test(test).run { try (DatabaseQueue(), .immediate) }
        try Test(test).runAtTemporaryDatabasePath { try (DatabaseQueue(path: $0), .immediate) }
        try Test(test).runAtTemporaryDatabasePath { try (DatabasePool(path: $0), .immediate) }
        
        try Test(test).run { try (DatabaseQueue(), .async(onQueue: .main)) }
        try Test(test).runAtTemporaryDatabasePath { try (DatabaseQueue(path: $0), .async(onQueue: .main)) }
        try Test(test).runAtTemporaryDatabasePath { try (DatabasePool(path: $0), .async(onQueue: .main)) }
    }
    
    // An attempt at finding a regression test for <https://github.com/groue/GRDB.swift/issues/1362>
    func testManyObservationsWithLongConcurrentWrite() throws {
        // We'll start many observations
        let observationCount = 100
        dbConfiguration.maximumReaderCount = 5
        
        func test(_ writer: some DatabaseWriter, scheduling scheduler: some ValueObservationScheduler) throws {
            try writer.write {
                try $0.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT)")
            }
            let observation = ValueObservation.tracking {
                return try Table("t").fetchCount($0)
            }
            
            let initialValueExpectation = self.expectation(description: "")
#if SQLITE_ENABLE_SNAPSHOT || (!GRDBCUSTOMSQLITE && !GRDBCIPHER)
            initialValueExpectation.assertForOverFulfill = true
#else
            // ValueObservation on DatabasePool will notify the first value twice
            initialValueExpectation.assertForOverFulfill = false
#endif
            initialValueExpectation.expectedFulfillmentCount = observationCount
            
            let secondValueExpectation = self.expectation(description: "")
            secondValueExpectation.expectedFulfillmentCount = observationCount
            
            let semaphore = DispatchSemaphore(value: 0)
            writer.asyncWriteWithoutTransaction { db in
                semaphore.signal()
                Thread.sleep(forTimeInterval: 0.5)
            }
            semaphore.wait()
            
            var cancellables: [AnyDatabaseCancellable] = []
            for _ in 0..<observationCount {
                let cancellable = observation.start(in: writer, scheduling: scheduler) { error in
                    XCTFail("Unexpected error: \(error)")
                } onChange: { count in
                    if count == 0 {
                        initialValueExpectation.fulfill()
                    } else {
                        secondValueExpectation.fulfill()
                    }
                }
                cancellables.append(cancellable)
            }
            
            try withExtendedLifetime(cancellables) {
                wait(for: [initialValueExpectation], timeout: 2)
                try writer.write {
                    try $0.execute(sql: "INSERT INTO t DEFAULT VALUES")
                }
                wait(for: [secondValueExpectation], timeout: 2)
            }
        }
        
        try Test(test).run { try (DatabaseQueue(), .async(onQueue: .main)) }
        try Test(test).runAtTemporaryDatabasePath { try (DatabaseQueue(path: $0), .async(onQueue: .main)) }
        try Test(test).runAtTemporaryDatabasePath { try (DatabasePool(path: $0), .async(onQueue: .main)) }
        
        try Test(test).run { try (DatabaseQueue(), .immediate) }
        try Test(test).runAtTemporaryDatabasePath { try (DatabaseQueue(path: $0), .immediate) }
        try Test(test).runAtTemporaryDatabasePath { try (DatabasePool(path: $0), .immediate) }
    }
    
    // Regression test for <https://github.com/groue/GRDB.swift/issues/1362>
    func testIssue1362() throws {
        func test(_ writer: some DatabaseWriter) throws {
            try writer.write { try $0.execute(sql: "CREATE TABLE s(id INTEGER PRIMARY KEY AUTOINCREMENT)") }
            var cancellables = [AnyDatabaseCancellable]()
            
            // Start an observation and wait until it has installed its
            // transaction observer.
            let installedExpectation = expectation(description: "transaction observer installed")
            let finalExpectation = expectation(description: "final value")
            let initialObservation = ValueObservation.trackingConstantRegion(Table("s").fetchCount)
            let cancellable = initialObservation.start(
                in: writer,
                // Immediate initial value so that the next value comes
                // from the write access that installs the transaction observer.
                scheduling: .immediate,
                onError: { error in XCTFail("Unexpected error: \(error)") },
                onChange: { count in
                    if count == 1 {
                        installedExpectation.fulfill()
                    }
                    if count == 2 {
                        finalExpectation.fulfill()
                    }
                })
            cancellables.append(cancellable)
            try writer.write { try $0.execute(sql: "INSERT INTO s DEFAULT VALUES") } // count = 1
            wait(for: [installedExpectation], timeout: 2)
            
            // Start a write that will trigger initialObservation when we decide.
            let semaphore = DispatchSemaphore(value: 0)
            writer.asyncWriteWithoutTransaction { db in
                semaphore.wait()
                do {
                    try db.execute(sql: "INSERT INTO s DEFAULT VALUES") // count = 2
                } catch {
                    XCTFail("Unexpected error: \(error)")
                }
            }
            
            // Start as many observations as there are readers
            for _ in 0..<writer.configuration.maximumReaderCount {
                let observation = ValueObservation.trackingConstantRegion(Table("s").fetchCount)
                let cancellable = observation.start(
                    in: writer,
                    onError: { error in XCTFail("Unexpected error: \(error)") },
                    onChange: { _ in })
                cancellables.append(cancellable)
            }
            
            // Wait until all observations are waiting for the writer so
            // that they can install their transaction observer.
            Thread.sleep(forTimeInterval: 0.5)
            
            // Perform the write that triggers initialObservation
            semaphore.signal()
            
            // initialObservation should get its final value
            wait(for: [finalExpectation], timeout: 2)
            
            withExtendedLifetime(cancellables) {}
        }
        
        try Test(test).runAtTemporaryDatabasePath { try DatabasePool(path: $0) }
    }
    
    // Regression test for <https://github.com/groue/GRDB.swift/issues/1383>
    func testIssue1383() throws {
        do {
            let dbPool = try makeDatabasePool(filename: "test")
            try dbPool.writeWithoutTransaction { db in
                try db.execute(sql: "CREATE TABLE t(a)")
                // Truncate the wal file (size zero)
                try db.checkpoint(.truncate)
            }
        }
        
        do {
            let dbPool = try makeDatabasePool(filename: "test")
            let observation = ValueObservation.tracking(Table("t").fetchCount)
            _ = observation.start(
                in: dbPool, scheduling: .immediate,
                onError: { error in
                    XCTFail("Unexpected error \(error)")
                },
                onChange: { _ in
                })
        }
    }
    
    // Regression test for <https://github.com/groue/GRDB.swift/issues/1383>
    func testIssue1383_async() throws {
        do {
            let dbPool = try makeDatabasePool(filename: "test")
            try dbPool.writeWithoutTransaction { db in
                try db.execute(sql: "CREATE TABLE t(a)")
                // Truncate the wal file (size zero)
                try db.checkpoint(.truncate)
            }
        }
        
        do {
            let dbPool = try makeDatabasePool(filename: "test")
            let observation = ValueObservation.tracking(Table("t").fetchCount)
            let expectation = self.expectation(description: "completion")
            expectation.assertForOverFulfill = false
            let cancellable = observation.start(
                in: dbPool,
                onError: { error in
                    XCTFail("Unexpected error \(error)")
                    expectation.fulfill()
                },
                onChange: { _ in
                    expectation.fulfill()
                })
            withExtendedLifetime(cancellable) { _ in
                wait(for: [expectation], timeout: 2)
            }
        }
    }
    
    // Regression test for <https://github.com/groue/GRDB.swift/issues/1383>
    func testIssue1383_createWal() throws {
        let url = testBundle.url(forResource: "Issue1383", withExtension: "sqlite")!
        // Delete files created by previous test runs
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent().appendingPathComponent("Issue1383.sqlite-wal"))
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent().appendingPathComponent("Issue1383.sqlite-shm"))
        
        let dbPool = try DatabasePool(path: url.path)
        let observation = ValueObservation.tracking(Table("t").fetchCount)
        _ = observation.start(
            in: dbPool, scheduling: .immediate,
            onError: { error in
                XCTFail("Unexpected error \(error)")
            },
            onChange: { _ in
            })
    }
    
    // Regression test for <https://github.com/groue/GRDB.swift/issues/1500>
    func testIssue1500() throws {
        let pool = try makeDatabasePool()
        
        try pool.read { db in
            _ = try db.tableExists("t")
        }
        
        try pool.write { db in
            try db.create(table: "t") { t in
                t.column("a")
            }
        }
        
        _ = ValueObservation
            .trackingConstantRegion { db in
                try db.tableExists("t")
            }
            .start(
                in: pool,
                scheduling: .immediate,
                onError: { error in
                    XCTFail("Unexpected error \(error)")
                },
                onChange: { value in
                    XCTAssertEqual(value, true)
                })
    }
}
