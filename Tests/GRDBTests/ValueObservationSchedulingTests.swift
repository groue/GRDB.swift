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

class ValueObservationSchedulingTests: GRDBTestCase {
    func testImmediateScheduling() throws {
        func test(_ dbWriter: DatabaseWriter) throws {
            // We need something to change
            try dbWriter.write { try $0.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT)") }
            
            var counts: [Int] = []
            let notificationExpectation = expectation(description: "notification")
            notificationExpectation.assertForOverFulfill = true
            notificationExpectation.expectedFulfillmentCount = 2
            
            let key = DispatchSpecificKey<()>()
            DispatchQueue.main.setSpecific(key: key, value: ())
            
            let observation = ValueObservation.tracking { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM t")! }
            let observer = observation.start(
                in: dbWriter,
                scheduler: .immediate,
                onError: { error in XCTFail("Unexpected error: \(error)") },
                onChange: { count in
                    XCTAssertNotNil(DispatchQueue.getSpecific(key: key))
                    counts.append(count)
                    notificationExpectation.fulfill()
            })
            // .immediate scheduler: initial value MUST be synchronously dispatched
            XCTAssertEqual(counts, [0])
            
            try withExtendedLifetime(observer) {
                try dbWriter.write {
                    try $0.execute(sql: "INSERT INTO t DEFAULT VALUES")
                }
                
                waitForExpectations(timeout: 1, handler: nil)
                XCTAssertEqual(counts, [0, 1])
            }
        }
        
        try test(makeDatabaseQueue())
        try test(makeDatabasePool())
    }
    
    func testImmediateError() throws {
        func test(_ dbWriter: DatabaseWriter) throws {
            // We need something to change
            try dbWriter.write { try $0.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT)") }
            
            var errorCount = 0
            let notificationExpectation = expectation(description: "notification")
            notificationExpectation.assertForOverFulfill = true
            notificationExpectation.expectedFulfillmentCount = 2
            
            let key = DispatchSpecificKey<()>()
            DispatchQueue.main.setSpecific(key: key, value: ())
            
            var nextError: Error? = nil // If not null, observation throws an error
            let observation = ValueObservation.tracking { db in
                _ = try Int.fetchOne(db, sql: "SELECT * FROM t")
                if let error = nextError {
                    nextError = nil
                    throw error
                }
            }
            
            let observer = observation.start(
                in: dbWriter,
                scheduler: .immediate,
                onError: { error in
                    XCTAssertNotNil(DispatchQueue.getSpecific(key: key))
                    errorCount += 1
                    notificationExpectation.fulfill()
            },
                onChange: { _ in
                    XCTAssertNotNil(DispatchQueue.getSpecific(key: key))
                    notificationExpectation.fulfill()
            })
            try withExtendedLifetime(observer) {
                struct TestError: Error { }
                nextError = TestError()
                try dbWriter.write {
                    try $0.execute(sql: "INSERT INTO t DEFAULT VALUES")
                }
                
                waitForExpectations(timeout: 1, handler: nil)
                XCTAssertEqual(errorCount, 1)
            }
        }
        
        try test(makeDatabaseQueue())
        try test(makeDatabasePool())
    }
    
    func testCustomQueue() throws {
        func test(_ dbWriter: DatabaseWriter) throws {
            // We need something to change
            try dbWriter.write { try $0.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT)") }
            
            var counts: [Int] = []
            let notificationExpectation = expectation(description: "notification")
            notificationExpectation.assertForOverFulfill = true
            notificationExpectation.expectedFulfillmentCount = 2
            
            let queue = DispatchQueue(label: "")
            let key = DispatchSpecificKey<()>()
            queue.setSpecific(key: key, value: ())
            
            let observation = ValueObservation.tracking { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM t")! }
            
            let observer = observation.start(
                in: dbWriter,
                scheduler: .async(onQueue: queue),
                onError: { error in XCTFail("Unexpected error: \(error)") },
                onChange: { count in
                    XCTAssertNotNil(DispatchQueue.getSpecific(key: key))
                    counts.append(count)
                    notificationExpectation.fulfill()
            })
            try withExtendedLifetime(observer) {
                try dbWriter.write {
                    try $0.execute(sql: "INSERT INTO t DEFAULT VALUES")
                }
                
                waitForExpectations(timeout: 0.5, handler: nil)
                assertValueObservationRecordingMatch(recorded: counts, expected: [0, 1])
            }
        }
        
        try test(makeDatabaseQueue())
        try test(makeDatabasePool())
    }
    
    func testCustomQueueImmediateError() throws {
        func test(_ dbWriter: DatabaseWriter) throws {
            // We need something to change
            try dbWriter.write { try $0.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT)") }
            
            var errorCount = 0
            let notificationExpectation = expectation(description: "notification")
            notificationExpectation.assertForOverFulfill = true
            notificationExpectation.expectedFulfillmentCount = 1
            
            let queue = DispatchQueue(label: "")
            let key = DispatchSpecificKey<()>()
            queue.setSpecific(key: key, value: ())
            
            struct TestError: Error { }
            let observation = ValueObservation.tracking { _ in throw TestError() }
            
            let observer = observation.start(
                in: dbWriter,
                scheduler: .async(onQueue: queue),
                onError: { error in
                    XCTAssertNotNil(DispatchQueue.getSpecific(key: key))
                    errorCount += 1
                    notificationExpectation.fulfill()
            },
                onChange: { _ in XCTFail("Unexpected value") })
            withExtendedLifetime(observer) {
                waitForExpectations(timeout: 1, handler: nil)
                XCTAssertEqual(errorCount, 1)
            }
        }
        
        try test(makeDatabaseQueue())
        try test(makeDatabasePool())
    }
    
    func testCustomQueueDelayedError() throws {
        func test(_ dbWriter: DatabaseWriter) throws {
            // We need something to change
            try dbWriter.write { try $0.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT)") }
            
            var errorCount = 0
            let notificationExpectation = expectation(description: "notification")
            notificationExpectation.assertForOverFulfill = true
            notificationExpectation.expectedFulfillmentCount = 1
            
            let queue = DispatchQueue(label: "")
            let key = DispatchSpecificKey<()>()
            queue.setSpecific(key: key, value: ())
            
            struct TestError: Error { }
            var shouldThrow = false
            let observation = ValueObservation.tracking { db in
                _ = try Int.fetchOne(db, sql: "SELECT * FROM t")
                if shouldThrow {
                    throw TestError()
                }
                shouldThrow = true
            }
            
            let observer = observation.start(
                in: dbWriter,
                scheduler: .async(onQueue: queue),
                onError: { error in
                    XCTAssertNotNil(DispatchQueue.getSpecific(key: key))
                    errorCount += 1
                    notificationExpectation.fulfill()
            },
                onChange: { _ in })
            try withExtendedLifetime(observer) {
                try dbWriter.write {
                    try $0.execute(sql: "INSERT INTO t DEFAULT VALUES")
                }
                
                waitForExpectations(timeout: 1, handler: nil)
                XCTAssertEqual(errorCount, 1)
            }
        }
        
        try test(makeDatabaseQueue())
        try test(makeDatabasePool())
    }
}
