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
    
    /// Helps dealing with various SQLite versions
    private func region(sql: String, in dbReader: DatabaseReader) throws -> String {
        try dbReader.read { db in
            try db
                .makeStatement(sql: sql)
                .databaseRegion
                .description
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
                .trackingConstantRegion { try Int.fetchOne($0, sql: "SELECT MAX(id) FROM player") }
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
                    "value: nil"])
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
                .trackingConstantRegion { try Int.fetchOne($0, sql: "SELECT MAX(id) FROM player") }
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
                    "value: nil"])
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
                .trackingConstantRegion { _ in throw TestError() }
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
                    "failure: TestError()"])
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
                .trackingConstantRegion { _ in throw TestError() }
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
                    "failure: TestError()"])
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
                .trackingConstantRegion { try Int.fetchOne($0, sql: "SELECT MAX(id) FROM player") }
                .print(to: logger)
            observation.requiresWriteAccess = true
            
            let expectedRegion = try region(sql: "SELECT MAX(id) FROM player", in: dbWriter)
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
                    "tracked region: \(expectedRegion)",
                    "value: nil",
                    "database did change",
                    "fetch",
                    "value: Optional(1)"])
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
                .trackingConstantRegion { try Int.fetchOne($0, sql: "SELECT MAX(id) FROM player") }
                .print(to: logger)
            observation.requiresWriteAccess = true
            
            let expectedRegion = try region(sql: "SELECT MAX(id) FROM player", in: dbWriter)
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
                    "tracked region: \(expectedRegion)",
                    "value: nil",
                    "database did change",
                    "fetch",
                    "value: Optional(1)"])
            }
        }
        
        try test(makeDatabaseQueue())
        try test(makeDatabasePool())
    }
    
    func test_writeonly_immediateFailure_asynchronousScheduling() throws {
        func test(_ dbWriter: DatabaseWriter) throws {
            let logger = TestStream()
            var observation = ValueObservation
                .trackingConstantRegion { try Int.fetchOne($0, sql: "SELECT MAX(id) FROM player") }
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
                    "failure: SQLite error 1: no such table: player - while executing `SELECT MAX(id) FROM player`"])
            }
        }
        
        try test(makeDatabaseQueue())
        try test(makeDatabasePool())
    }
    
    func test_writeonly_immediateFailure_immediateScheduling() throws {
        func test(_ dbWriter: DatabaseWriter) throws {
            let logger = TestStream()
            var observation = ValueObservation
                .trackingConstantRegion { try Int.fetchOne($0, sql: "SELECT MAX(id) FROM player") }
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
                    "failure: SQLite error 1: no such table: player - while executing `SELECT MAX(id) FROM player`"])
            }
        }
        
        try test(makeDatabaseQueue())
        try test(makeDatabasePool())
    }
    
    func test_writeonly_lateFailure_asynchronousScheduling() throws {
        func test(_ dbWriter: DatabaseWriter) throws {
            try dbWriter.write { db in
                try db.execute(sql: "CREATE TABLE player(id INTEGER PRIMARY KEY)")
            }
            
            let logger = TestStream()
            var observation = ValueObservation
                .trackingConstantRegion { try Int.fetchOne($0, sql: "SELECT MAX(id) FROM player") }
                .print(to: logger)
            observation.requiresWriteAccess = true
            
            let expectedRegion = try region(sql: "SELECT MAX(id) FROM player", in: dbWriter)
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
                    "tracked region: \(expectedRegion)",
                    "value: nil",
                    "database did change",
                    "fetch",
                    "failure: SQLite error 1: no such table: player - while executing `SELECT MAX(id) FROM player`"])
            }
        }
        
        try test(makeDatabaseQueue())
        try test(makeDatabasePool())
    }
    
    func test_writeonly_lateFailure_immediateScheduling() throws {
        func test(_ dbWriter: DatabaseWriter) throws {
            try dbWriter.write { db in
                try db.execute(sql: "CREATE TABLE player(id INTEGER PRIMARY KEY)")
            }
            
            let logger = TestStream()
            var observation = ValueObservation
                .trackingConstantRegion { try Int.fetchOne($0, sql: "SELECT MAX(id) FROM player") }
                .print(to: logger)
            observation.requiresWriteAccess = true
            
            let expectedRegion = try region(sql: "SELECT MAX(id) FROM player", in: dbWriter)
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
                    "tracked region: \(expectedRegion)",
                    "value: nil",
                    "database did change",
                    "fetch",
                    "failure: SQLite error 1: no such table: player - while executing `SELECT MAX(id) FROM player`"])
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
            .trackingConstantRegion { db -> Int? in
                if needsChange {
                    needsChange = false
                    try dbPool.write { db in
                        try db.execute(sql: """
                        INSERT INTO player DEFAULT VALUES;
                        DELETE FROM player;
                        """)
                    }
                }
                return try Int.fetchOne(db, sql: "SELECT MAX(id) FROM player")
            }
            .print(to: logger)
        
        let expectedRegion = try region(sql: "SELECT MAX(id) FROM player", in: dbPool)
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
                "value: nil",
                "database did change",
                "fetch",
                "tracked region: \(expectedRegion)",
                "value: nil"])
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
            .trackingConstantRegion { db -> Int? in
                if needsChange {
                    needsChange = false
                    try dbPool.write { db in
                        try db.execute(sql: """
                        INSERT INTO player DEFAULT VALUES;
                        DELETE FROM player;
                        """)
                    }
                }
                return try Int.fetchOne(db, sql: "SELECT MAX(id) FROM player")
            }
            .print(to: logger)
        
        let expectedRegion = try region(sql: "SELECT MAX(id) FROM player", in: dbPool)
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
                "value: nil",
                "database did change",
                "fetch",
                "tracked region: \(expectedRegion)",
                "value: nil"])
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
            .tracking { db -> Int? in
                let table = try String.fetchOne(db, sql: "SELECT t FROM choice")!
                return try Int.fetchOne(db, sql: "SELECT MAX(id) FROM \(table)")
            }
            .print(to: logger)
        
        let expectedRegionA = try region(sql: "SELECT MAX(id) FROM a", in: dbQueue)
        let expectedRegionB = try region(sql: "SELECT MAX(id) FROM b", in: dbQueue)
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
                "tracked region: \(expectedRegionA),choice(t)",
                "value: nil",
                "database did change",
                "fetch",
                "tracked region: \(expectedRegionB),choice(t)",
                "value: Optional(1)",
                "database did change",
                "fetch",
                "value: Optional(2)"])
        }
    }
    
    // MARK: - Variations
    
    func test_prefix() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.execute(sql: "CREATE TABLE player(id INTEGER PRIMARY KEY)")
        }
        
        let logger1 = TestStream()
        let logger2 = TestStream()
        let observation = ValueObservation
            .trackingConstantRegion { try Int.fetchOne($0, sql: "SELECT MAX(id) FROM player") }
            .print("", to: logger1)
            .print("log", to: logger2)
        
        let expectation = self.expectation(description: "")
        let cancellable = observation.start(
            in: dbQueue,
            scheduling: .async(onQueue: .main),
            onError: { _ in },
            onChange: { _ in expectation.fulfill() })
        withExtendedLifetime(cancellable) {
            waitForExpectations(timeout: 1, handler: nil)
            XCTAssertEqual(logger1.strings.prefix(4), [
                "start",
                "fetch",
                "tracked region: player(*)",
                "value: nil"])
            XCTAssertEqual(logger2.strings.prefix(4), [
                "log: start",
                "log: fetch",
                "log: tracked region: player(*)",
                "log: value: nil"])
        }
    }

    func test_chain() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.execute(sql: "CREATE TABLE player(id INTEGER PRIMARY KEY)")
        }
        
        let logger1 = TestStream()
        let logger2 = TestStream()
        let observation = ValueObservation
            .trackingConstantRegion { try Int.fetchOne($0, sql: "SELECT MAX(id) FROM player") }
            .print(to: logger1)
            .removeDuplicates()
            .map { _ in "foo" }
            .print(to: logger2)
        
        let expectation = self.expectation(description: "")
        let cancellable = observation.start(
            in: dbQueue,
            scheduling: .async(onQueue: .main),
            onError: { _ in },
            onChange: { _ in expectation.fulfill() })
        withExtendedLifetime(cancellable) {
            waitForExpectations(timeout: 1, handler: nil)
            XCTAssertEqual(logger1.strings.prefix(4), [
                "start",
                "fetch",
                "tracked region: player(*)",
                "value: nil"])
            XCTAssertEqual(logger2.strings.prefix(4), [
                "start",
                "fetch",
                "tracked region: player(*)",
                "value: foo"])
        }
    }
    
    func test_handleEvents() throws {
        func waitFor<R: ValueReducer>(_ observation: ValueObservation<R>) throws {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.write { db in
                try db.execute(sql: "CREATE TABLE player(id INTEGER PRIMARY KEY)")
            }
            
            let expectation = self.expectation(description: "")
            expectation.expectedFulfillmentCount = 2
            let cancellable = observation.start(
                in: dbQueue,
                scheduling: .async(onQueue: .main),
                onError: { _ in },
                onChange: { _ in
                    try! dbQueue.write { db in
                        try db.execute(sql: "INSERT INTO player DEFAULT VALUES")
                    }
                    expectation.fulfill()
            })
            withExtendedLifetime(cancellable) {
                waitForExpectations(timeout: 1, handler: nil)
            }
        }
        
        func waitForError<R: ValueReducer>(_ observation: ValueObservation<R>) throws {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.write { db in
                try db.execute(sql: "CREATE TABLE player(id INTEGER PRIMARY KEY)")
            }
            
            let expectation = self.expectation(description: "")
            let cancellable = observation.start(
                in: dbQueue,
                scheduling: .async(onQueue: .main),
                onError: { _ in expectation.fulfill() },
                onChange: { _ in
                    try! dbQueue.write { db in
                        try db.execute(sql: """
                            INSERT INTO player DEFAULT VALUES;
                            DROP TABLE player;
                            """)
                    }
            })
            withExtendedLifetime(cancellable) {
                waitForExpectations(timeout: 1, handler: nil)
            }
        }
        
        func waitForCancel<R: ValueReducer>(_ observation: ValueObservation<R>) throws {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.write { db in
                try db.execute(sql: "CREATE TABLE player(id INTEGER PRIMARY KEY)")
            }
            
            let expectation = self.expectation(description: "")
            let cancellable = observation.start(
                in: dbQueue,
                scheduling: .async(onQueue: .main),
                onError: { _ in },
                onChange: { _ in
                    expectation.fulfill()
            })
            withExtendedLifetime(cancellable) {
                waitForExpectations(timeout: 1, handler: nil)
                cancellable.cancel()
            }
        }
        
        let observation = ValueObservation.trackingConstantRegion {
            try Int.fetchOne($0, sql: "SELECT MAX(id) FROM player")
        }
        
        do {
            let logger = TestStream()
            try waitFor(observation.handleEvents(willStart: { logger.write("start") }))
            XCTAssertEqual(logger.strings, ["start"])
        }
        do {
            let logger = TestStream()
            try waitFor(observation.handleEvents(willTrackRegion: { _ in logger.write("region") }))
            XCTAssertEqual(logger.strings, ["region"])
        }
        do {
            let logger = TestStream()
            try waitFor(observation.handleEvents(databaseDidChange: { logger.write("change") }))
            XCTAssertEqual(logger.strings.prefix(1), ["change"])
        }
        do {
            let logger = TestStream()
            try waitFor(observation.handleEvents(willFetch: { logger.write("fetch") }))
            XCTAssertEqual(logger.strings.prefix(2), ["fetch", "fetch"])
        }
        do {
            let logger = TestStream()
            try waitFor(observation.handleEvents(didReceiveValue: { _ in logger.write("value") }))
            XCTAssertEqual(logger.strings.prefix(2), ["value", "value"])
        }
        do {
            let logger = TestStream()
            try waitForError(observation.handleEvents(didFail: { _ in logger.write("error") }))
            XCTAssertEqual(logger.strings, ["error"])
        }
        do {
            let logger = TestStream()
            try waitForCancel(observation.handleEvents(didCancel: { logger.write("cancel") }))
            XCTAssertEqual(logger.strings, ["cancel"])
        }
    }

}
