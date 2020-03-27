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
    func testImmediateReducer() throws {
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
            let observation = ValueObservation(makeReducer: { reducer })
            
            // Start observation
            let observer = observation.start(
                in: dbWriter,
                scheduler: .immediate,
                onError: {
                    errors.append($0)
                    notificationExpectation.fulfill()
            },
                onChange: {
                    changes.append($0)
                    notificationExpectation.fulfill()
            })
            try withExtendedLifetime(observer) {
                // Test that initial value is synchronously notified
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
            
            struct TestError: Error { }
            var nextError: Error? = nil // If not null, observation throws an error
            let observation = ValueObservation.tracking {
                _ = try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM t")
                if let error = nextError {
                    nextError = nil
                    throw error
                } else {
                    nextError = TestError()
                }
            }

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
