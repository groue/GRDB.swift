import XCTest
import Dispatch
@testable import GRDB

class ValueObservationPrintTests: GRDBTestCase {
    class TestStream: TextOutputStream {
        @LockedBox var strings: [String] = []
        func write(_ string: String) {
            strings.append(string)
        }
    }
    
    // MARK: - Readonly
    
    func test_readonly_success_asynchronousScheduling() throws {
        let dbPool = try makeDatabasePool(filename: "test")
        try dbPool.write { db in
            try db.execute(sql: "CREATE TABLE player(id INTEGER PRIMARY KEY)")
        }
        
        func test(_ dbReader: DatabaseReader) throws {
            let logger = TestStream()
            let observation = ValueObservation
                .tracking { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM player")! }
                .print(to: logger)
            
            let expectation = self.expectation(description: "")
            let cancellable = observation.start(
                in: dbReader,
                scheduling: .async(onQueue: .main),
                onError: { _ in },
                onChange: { _ in expectation.fulfill() })
            withExtendedLifetime(cancellable) {
                waitForExpectations(timeout: 1, handler: nil)
                XCTAssertEqual(logger.strings, [
                    "start",
                    "fetch",
                    "value: 0"])
            }
        }
        
        var config = dbConfiguration!
        config.readonly = true
        try test(makeDatabaseQueue(filename: "test", configuration: config))
        try test(makeDatabasePool(filename: "test", configuration: config))
        try test(makeDatabasePool(filename: "test", configuration: config).makeSnapshot())
    }
    
    func test_readonly_success_immediateScheduling() throws {
        let dbPool = try makeDatabasePool(filename: "test")
        try dbPool.write { db in
            try db.execute(sql: "CREATE TABLE player(id INTEGER PRIMARY KEY)")
        }
        
        func test(_ dbReader: DatabaseReader) throws {
            let logger = TestStream()
            let observation = ValueObservation
                .tracking { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM player")! }
                .print(to: logger)
            
            let expectation = self.expectation(description: "")
            let cancellable = observation.start(
                in: dbReader,
                scheduling: .immediate,
                onError: { _ in },
                onChange: { _ in expectation.fulfill() })
            withExtendedLifetime(cancellable) {
                waitForExpectations(timeout: 1, handler: nil)
                XCTAssertEqual(logger.strings, [
                    "start",
                    "fetch",
                    "value: 0"])
            }
        }
        
        var config = dbConfiguration!
        config.readonly = true
        try test(makeDatabaseQueue(filename: "test", configuration: config))
        try test(makeDatabasePool(filename: "test", configuration: config))
        try test(makeDatabasePool(filename: "test", configuration: config).makeSnapshot())
    }
    
    func test_readonly_failure_asynchronousScheduling() throws {
        _ = try makeDatabasePool(filename: "test")
        
        func test(_ dbReader: DatabaseReader) throws {
            struct TestError: Error { }
            let logger = TestStream()
            let observation = ValueObservation
                .tracking { _ in throw TestError() }
                .print(to: logger)
            
            let expectation = self.expectation(description: "")
            let cancellable = observation.start(
                in: dbReader,
                scheduling: .async(onQueue: .main),
                onError: { _ in expectation.fulfill() },
                onChange: { _ in })
            withExtendedLifetime(cancellable) {
                waitForExpectations(timeout: 1, handler: nil)
                XCTAssertEqual(logger.strings, [
                    "start",
                    "fetch",
                    "error: TestError()"])
            }
        }
        
        var config = dbConfiguration!
        config.readonly = true
        try test(makeDatabaseQueue(filename: "test", configuration: config))
        try test(makeDatabasePool(filename: "test", configuration: config))
        try test(makeDatabasePool(filename: "test", configuration: config).makeSnapshot())
    }
    
    func test_readonly_failure_immediateScheduling() throws {
        _ = try makeDatabasePool(filename: "test")
        
        func test(_ dbReader: DatabaseReader) throws {
            struct TestError: Error { }
            let logger = TestStream()
            let observation = ValueObservation
                .tracking { _ in throw TestError() }
                .print(to: logger)
            
            let expectation = self.expectation(description: "")
            let cancellable = observation.start(
                in: dbReader,
                scheduling: .immediate,
                onError: { _ in expectation.fulfill() },
                onChange: { _ in })
            withExtendedLifetime(cancellable) {
                waitForExpectations(timeout: 1, handler: nil)
                XCTAssertEqual(logger.strings, [
                    "start",
                    "fetch",
                    "error: TestError()"])
            }
        }
        
        var config = dbConfiguration!
        config.readonly = true
        try test(makeDatabaseQueue(filename: "test", configuration: config))
        try test(makeDatabasePool(filename: "test", configuration: config))
        try test(makeDatabasePool(filename: "test", configuration: config).makeSnapshot())
    }
    
    // MARK: - Writeonly
    
    func test_writeonly_success_asynchronousScheduling() throws {
        func test(_ dbWriter: DatabaseWriter) throws {
            try dbWriter.write { db in
                try db.execute(sql: "CREATE TABLE player(id INTEGER PRIMARY KEY)")
            }
            
            let logger = TestStream()
            var observation = ValueObservation
                .tracking { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM player")! }
                .print(to: logger)
            observation.requiresWriteAccess = true
            
            let expectation = self.expectation(description: "")
            expectation.expectedFulfillmentCount = 2
            let cancellable = observation.start(
                in: dbWriter,
                scheduling: .async(onQueue: .main),
                onError: { _ in },
                onChange: { _ in
                    try! dbWriter.write { db in
                        try db.execute(sql: "INSERT INTO player DEFAULT VALUES")
                    }
                    expectation.fulfill()
            })
            withExtendedLifetime(cancellable) {
                waitForExpectations(timeout: 1, handler: nil)
                XCTAssertEqual(logger.strings.prefix(7), [
                    "start",
                    "fetch",
                    "tracked region: player(*)",
                    "value: 0",
                    "database did change",
                    "fetch",
                    "value: 1"])
            }
        }
        
        try test(makeDatabaseQueue())
        try test(makeDatabasePool())
    }
    
    func test_writeonly_success_immediateScheduling() throws {
        func test(_ dbWriter: DatabaseWriter) throws {
            try dbWriter.write { db in
                try db.execute(sql: "CREATE TABLE player(id INTEGER PRIMARY KEY)")
            }
            
            let logger = TestStream()
            var observation = ValueObservation
                .tracking { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM player")! }
                .print(to: logger)
            observation.requiresWriteAccess = true
            
            let expectation = self.expectation(description: "")
            expectation.expectedFulfillmentCount = 2
            let cancellable = observation.start(
                in: dbWriter,
                scheduling: .immediate,
                onError: { _ in },
                onChange: { _ in
                    try! dbWriter.write { db in
                        try db.execute(sql: "INSERT INTO player DEFAULT VALUES")
                    }
                    expectation.fulfill()
            })
            withExtendedLifetime(cancellable) {
                waitForExpectations(timeout: 1, handler: nil)
                XCTAssertEqual(logger.strings.prefix(7), [
                    "start",
                    "fetch",
                    "tracked region: player(*)",
                    "value: 0",
                    "database did change",
                    "fetch",
                    "value: 1"])
            }
        }
        
        try test(makeDatabaseQueue())
        try test(makeDatabasePool())
    }
    
    func test_writeonlyLate_immediateFailure_asynchronousScheduling() throws {
        func test(_ dbWriter: DatabaseWriter) throws {
            let logger = TestStream()
            var observation = ValueObservation
                .tracking { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM player")! }
                .print(to: logger)
            observation.requiresWriteAccess = true
            
            let expectation = self.expectation(description: "")
            let cancellable = observation.start(
                in: dbWriter,
                scheduling: .async(onQueue: .main),
                onError: { _ in expectation.fulfill() },
                onChange: { _ in })
            withExtendedLifetime(cancellable) {
                waitForExpectations(timeout: 1, handler: nil)
                XCTAssertEqual(logger.strings, [
                    "start",
                    "fetch",
                    "error: SQLite error 1 with statement `SELECT COUNT(*) FROM player`: no such table: player"])
            }
        }
        
        try test(makeDatabaseQueue())
        try test(makeDatabasePool())
    }
    
    func test_writeonlyLate_immediateFailure_immediateScheduling() throws {
        func test(_ dbWriter: DatabaseWriter) throws {
            let logger = TestStream()
            var observation = ValueObservation
                .tracking { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM player")! }
                .print(to: logger)
            observation.requiresWriteAccess = true
            
            let expectation = self.expectation(description: "")
            let cancellable = observation.start(
                in: dbWriter,
                scheduling: .immediate,
                onError: { _ in expectation.fulfill() },
                onChange: { _ in })
            withExtendedLifetime(cancellable) {
                waitForExpectations(timeout: 1, handler: nil)
                XCTAssertEqual(logger.strings, [
                    "start",
                    "fetch",
                    "error: SQLite error 1 with statement `SELECT COUNT(*) FROM player`: no such table: player"])
            }
        }
        
        try test(makeDatabaseQueue())
        try test(makeDatabasePool())
    }
    
    func test_writeonlyLate_lateFailure_asynchronousScheduling() throws {
        func test(_ dbWriter: DatabaseWriter) throws {
            try dbWriter.write { db in
                try db.execute(sql: "CREATE TABLE player(id INTEGER PRIMARY KEY)")
            }
            
            let logger = TestStream()
            var observation = ValueObservation
                .tracking { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM player")! }
                .print(to: logger)
            observation.requiresWriteAccess = true
            
            let expectation = self.expectation(description: "")
            let cancellable = observation.start(
                in: dbWriter,
                scheduling: .async(onQueue: .main),
                onError: { _ in expectation.fulfill() },
                onChange: { _ in
                    try! dbWriter.write { db in
                        try db.execute(sql: """
                            INSERT INTO player DEFAULT VALUES;
                            DROP TABLE player;
                            """)
                    }
            })
            withExtendedLifetime(cancellable) {
                waitForExpectations(timeout: 1, handler: nil)
                XCTAssertEqual(logger.strings, [
                    "start",
                    "fetch",
                    "tracked region: player(*)",
                    "value: 0",
                    "database did change",
                    "fetch",
                    "error: SQLite error 1 with statement `SELECT COUNT(*) FROM player`: no such table: player"])
            }
        }
        
        try test(makeDatabaseQueue())
        try test(makeDatabasePool())
    }
    
    func test_writeonlyLate_lateFailure_immediateScheduling() throws {
        func test(_ dbWriter: DatabaseWriter) throws {
            try dbWriter.write { db in
                try db.execute(sql: "CREATE TABLE player(id INTEGER PRIMARY KEY)")
            }
            
            let logger = TestStream()
            var observation = ValueObservation
                .tracking { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM player")! }
                .print(to: logger)
            observation.requiresWriteAccess = true
            
            let expectation = self.expectation(description: "")
            let cancellable = observation.start(
                in: dbWriter,
                scheduling: .immediate,
                onError: { _ in expectation.fulfill() },
                onChange: { _ in
                    try! dbWriter.write { db in
                        try db.execute(sql: """
                            INSERT INTO player DEFAULT VALUES;
                            DROP TABLE player;
                            """)
                    }
            })
            withExtendedLifetime(cancellable) {
                waitForExpectations(timeout: 1, handler: nil)
                XCTAssertEqual(logger.strings, [
                    "start",
                    "fetch",
                    "tracked region: player(*)",
                    "value: 0",
                    "database did change",
                    "fetch",
                    "error: SQLite error 1 with statement `SELECT COUNT(*) FROM player`: no such table: player"])
            }
        }
        
        try test(makeDatabaseQueue())
        try test(makeDatabasePool())
    }
    
    // MARK: - Concurrent
    
    func test_concurrent_success_asynchronousScheduling() throws {
        let dbPool = try makeDatabasePool()
        try dbPool.write { db in
            try db.execute(sql: "CREATE TABLE player(id INTEGER PRIMARY KEY)")
        }
        
        let logger = TestStream()
        // Force DatabasePool to perform two initial fetches, because between
        // its first read access, and its write access that installs the
        // transaction observer, some write did happen.
        var needsChange = true
        let observation = ValueObservation
            .tracking({ db -> Int in
                if needsChange {
                    needsChange = false
                    try dbPool.write { db in
                        try db.execute(sql: """
                        INSERT INTO player DEFAULT VALUES;
                        DELETE FROM player;
                        """)
                    }
                }
                return try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM player")!
            })
            .print(to: logger)
        
        let expectation = self.expectation(description: "")
        expectation.expectedFulfillmentCount = 2
        let cancellable = observation.start(
            in: dbPool,
            scheduling: .async(onQueue: .main),
            onError: { _ in },
            onChange: { _ in expectation.fulfill() })
        withExtendedLifetime(cancellable) {
            waitForExpectations(timeout: 1, handler: nil)
            XCTAssertEqual(logger.strings, [
                "start",
                "fetch",
                "tracked region: player(*)",
                "value: 0",
                "database did change",
                "fetch",
                "value: 0"])
        }
    }
    
    func test_concurrent_success_immediateScheduling() throws {
        let dbPool = try makeDatabasePool()
        try dbPool.write { db in
            try db.execute(sql: "CREATE TABLE player(id INTEGER PRIMARY KEY)")
        }
        
        let logger = TestStream()
        // Force DatabasePool to perform two initial fetches, because between
        // its first read access, and its write access that installs the
        // transaction observer, some write did happen.
        var needsChange = true
        let observation = ValueObservation
            .tracking({ db -> Int in
                if needsChange {
                    needsChange = false
                    try dbPool.write { db in
                        try db.execute(sql: """
                        INSERT INTO player DEFAULT VALUES;
                        DELETE FROM player;
                        """)
                    }
                }
                return try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM player")!
            })
            .print(to: logger)
        
        let expectation = self.expectation(description: "")
        expectation.expectedFulfillmentCount = 2
        let cancellable = observation.start(
            in: dbPool,
            scheduling: .immediate,
            onError: { _ in },
            onChange: { _ in expectation.fulfill() })
        withExtendedLifetime(cancellable) {
            waitForExpectations(timeout: 1, handler: nil)
            XCTAssertEqual(logger.strings, [
                "start",
                "fetch",
                "tracked region: player(*)",
                "value: 0",
                "database did change",
                "fetch",
                "value: 0"])
        }
    }
    
    // MARK: - Varying Database Region
    
    func test_varyingRegion() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.execute(sql: """
                CREATE TABLE a(id INTEGER PRIMARY KEY);
                CREATE TABLE b(id INTEGER PRIMARY KEY);
                CREATE TABLE choice(t TEXT);
                INSERT INTO choice (t) VALUES ('a');
                """)
        }
        
        let logger = TestStream()
        let observation = ValueObservation
            .trackingVaryingRegion({ db -> Int in
                let table = try String.fetchOne(db, sql: "SELECT t FROM choice")!
                return try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM \(table)")!
            })
            .print(to: logger)
        
        let expectation = self.expectation(description: "")
        expectation.expectedFulfillmentCount = 3
        let cancellable = observation.start(
            in: dbQueue,
            scheduling: .async(onQueue: .main),
            onError: { _ in },
            onChange: { _ in
                try! dbQueue.write { db in
                    try db.execute(sql: """
                        UPDATE choice SET t = 'b';
                        INSERT INTO a DEFAULT VALUES;
                        INSERT INTO b DEFAULT VALUES;
                        """)
                }
                expectation.fulfill()
        })
        withExtendedLifetime(cancellable) {
            waitForExpectations(timeout: 1, handler: nil)
            XCTAssertEqual(logger.strings.prefix(11), [
                "start",
                "fetch",
                "tracked region: a(*),choice(t)",
                "value: 0",
                "database did change",
                "fetch",
                "tracked region: b(*),choice(t)",
                "value: 1",
                "database did change",
                "fetch",
                "value: 2"])
        }
    }
}
