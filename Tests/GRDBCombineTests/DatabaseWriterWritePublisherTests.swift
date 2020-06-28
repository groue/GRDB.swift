#if canImport(Combine)
import Combine
import GRDB
import XCTest

private struct Player: Codable, FetchableRecord, PersistableRecord {
    var id: Int64
    var name: String
    var score: Int?
    
    static func createTable(_ db: Database) throws {
        try db.create(table: "player") { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("name", .text).notNull()
            t.column("score", .integer)
        }
    }
}

class DatabaseWriterWritePublisherTests : XCTestCase {
    
    // MARK: -
    
    func testWritePublisher() throws {
        guard #available(OSX 10.15, iOS 13, tvOS 13, watchOS 6, *) else {
            throw XCTSkip("Combine is not available")
        }
        
        func setUp<Writer: DatabaseWriter>(_ writer: Writer) throws -> Writer {
            try writer.write(Player.createTable)
            return writer
        }
        
        func test(writer: DatabaseWriter) throws {
            try XCTAssertEqual(writer.read(Player.fetchCount), 0)
            let publisher = writer.writePublisher(updates: { db in
                try Player(id: 1, name: "Arthur", score: 1000).insert(db)
            })
            let recorder = publisher.record()
            try wait(for: recorder.single, timeout: 1)
            try XCTAssertEqual(writer.read(Player.fetchCount), 1)
        }
        
        try Test(test)
            .run { try setUp(DatabaseQueue()) }
            .runAtTemporaryDatabasePath { try setUp(DatabaseQueue(path: $0)) }
            .runAtTemporaryDatabasePath { try setUp(DatabasePool(path: $0)) }
    }
    
    // MARK: -
    
    func testWritePublisherValue() throws {
        guard #available(OSX 10.15, iOS 13, tvOS 13, watchOS 6, *) else {
            throw XCTSkip("Combine is not available")
        }
        
        func setUp<Writer: DatabaseWriter>(_ writer: Writer) throws -> Writer {
            try writer.write(Player.createTable)
            return writer
        }
        
        func test(writer: DatabaseWriter) throws {
            let publisher = writer.writePublisher(updates: { db -> Int in
                try Player(id: 1, name: "Arthur", score: 1000).insert(db)
                return try Player.fetchCount(db)
            })
            let recorder = publisher.record()
            let count = try wait(for: recorder.single, timeout: 1)
            XCTAssertEqual(count, 1)
        }
        
        try Test(test)
            .run { try setUp(DatabaseQueue()) }
            .runAtTemporaryDatabasePath { try setUp(DatabaseQueue(path: $0)) }
            .runAtTemporaryDatabasePath { try setUp(DatabasePool(path: $0)) }
    }
    
    // MARK: -
    
    func testWritePublisherError() throws {
        guard #available(OSX 10.15, iOS 13, tvOS 13, watchOS 6, *) else {
            throw XCTSkip("Combine is not available")
        }
        
        func test(writer: DatabaseWriter) throws {
            let publisher = writer.writePublisher(updates: { db in
                try db.execute(sql: "THIS IS NOT SQL")
            })
            let recorder = publisher.record()
            let recording = try wait(for: recorder.recording, timeout: 1)
            XCTAssertTrue(recording.output.isEmpty)
            assertFailure(recording.completion) { (error: DatabaseError) in
                XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
                XCTAssertEqual(error.sql, "THIS IS NOT SQL")
            }
        }
        
        try Test(test)
            .run { DatabaseQueue() }
            .runAtTemporaryDatabasePath { try DatabaseQueue(path: $0) }
            .runAtTemporaryDatabasePath { try DatabasePool(path: $0) }
    }
    
    func testWritePublisherErrorRollbacksTransaction() throws {
        guard #available(OSX 10.15, iOS 13, tvOS 13, watchOS 6, *) else {
            throw XCTSkip("Combine is not available")
        }
        
        func setUp<Writer: DatabaseWriter>(_ writer: Writer) throws -> Writer {
            try writer.write(Player.createTable)
            return writer
        }
        
        func test(writer: DatabaseWriter) throws {
            let publisher = writer.writePublisher(updates: { db in
                try Player(id: 1, name: "Arthur", score: 1000).insert(db)
                try db.execute(sql: "THIS IS NOT SQL")
            })
            let recorder = publisher.record()
            let recording = try wait(for: recorder.recording, timeout: 1)
            XCTAssertTrue(recording.output.isEmpty)
            assertFailure(recording.completion) { (error: DatabaseError) in
                XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
                XCTAssertEqual(error.sql, "THIS IS NOT SQL")
            }
            let count = try writer.read(Player.fetchCount)
            XCTAssertEqual(count, 0)
        }
        
        try Test(test)
            .run { try setUp(DatabaseQueue()) }
            .runAtTemporaryDatabasePath { try setUp(DatabaseQueue(path: $0)) }
            .runAtTemporaryDatabasePath { try setUp(DatabasePool(path: $0)) }
    }
    
    // MARK: -
    
    func testWritePublisherIsAsynchronous() throws {
        guard #available(OSX 10.15, iOS 13, tvOS 13, watchOS 6, *) else {
            throw XCTSkip("Combine is not available")
        }
        
        func setUp<Writer: DatabaseWriter>(_ writer: Writer) throws -> Writer {
            try writer.write(Player.createTable)
            return writer
        }
        
        func test(writer: DatabaseWriter) throws {
            let expectation = self.expectation(description: "")
            let semaphore = DispatchSemaphore(value: 0)
            let cancellable = writer
                .writePublisher(updates: { db in
                    try Player(id: 1, name: "Arthur", score: 1000).insert(db)
                })
                .sink(
                    receiveCompletion: { _ in },
                    receiveValue: { _ in
                        semaphore.wait()
                        expectation.fulfill()
                })
            
            semaphore.signal()
            waitForExpectations(timeout: 1, handler: nil)
            cancellable.cancel()
        }
        
        try Test(test)
            .run { try setUp(DatabaseQueue()) }
            .runAtTemporaryDatabasePath { try setUp(DatabaseQueue(path: $0)) }
            .runAtTemporaryDatabasePath { try setUp(DatabasePool(path: $0)) }
    }
    
    // MARK: -
    
    func testWritePublisherDefaultScheduler() throws {
        guard #available(OSX 10.15, iOS 13, tvOS 13, watchOS 6, *) else {
            throw XCTSkip("Combine is not available")
        }
        
        func setUp<Writer: DatabaseWriter>(_ writer: Writer) throws -> Writer {
            try writer.write(Player.createTable)
            return writer
        }
        
        func test(writer: DatabaseWriter) {
            let expectation = self.expectation(description: "")
            expectation.expectedFulfillmentCount = 2 // value + completion
            let cancellable = writer
                .writePublisher(updates: { db in
                    try Player(id: 1, name: "Arthur", score: 1000).insert(db)
                })
                .sink(
                    receiveCompletion: { completion in
                        dispatchPrecondition(condition: .onQueue(.main))
                        expectation.fulfill()
                },
                    receiveValue: { _ in
                        dispatchPrecondition(condition: .onQueue(.main))
                        expectation.fulfill()
                })
            
            waitForExpectations(timeout: 1, handler: nil)
            cancellable.cancel()
        }
        
        try Test(test)
            .run { try setUp(DatabaseQueue()) }
            .runAtTemporaryDatabasePath { try setUp(DatabaseQueue(path: $0)) }
            .runAtTemporaryDatabasePath { try setUp(DatabasePool(path: $0)) }
    }
    
    // MARK: -
    
    func testWritePublisherCustomScheduler() throws {
        guard #available(OSX 10.15, iOS 13, tvOS 13, watchOS 6, *) else {
            throw XCTSkip("Combine is not available")
        }
        
        func setUp<Writer: DatabaseWriter>(_ writer: Writer) throws -> Writer {
            try writer.write(Player.createTable)
            return writer
        }
        
        func test(writer: DatabaseWriter) {
            let queue = DispatchQueue(label: "test")
            let expectation = self.expectation(description: "")
            expectation.expectedFulfillmentCount = 2 // value + completion
            let cancellable = writer
                .writePublisher(receiveOn: queue, updates: { db in
                    try Player(id: 1, name: "Arthur", score: 1000).insert(db)
                })
                .sink(
                    receiveCompletion: { completion in
                        dispatchPrecondition(condition: .onQueue(queue))
                        expectation.fulfill()
                },
                    receiveValue: { _ in
                        dispatchPrecondition(condition: .onQueue(queue))
                        expectation.fulfill()
                })
            
            waitForExpectations(timeout: 1, handler: nil)
            cancellable.cancel()
        }
        
        try Test(test)
            .run { try setUp(DatabaseQueue()) }
            .runAtTemporaryDatabasePath { try setUp(DatabaseQueue(path: $0)) }
            .runAtTemporaryDatabasePath { try setUp(DatabasePool(path: $0)) }
    }
    
    // MARK: -
    
    // TODO: Fix flaky test with both pool and on-disk queue:
    // - Expectation timeout
    func testWriteThenReadPublisher() throws {
        guard #available(OSX 10.15, iOS 13, tvOS 13, watchOS 6, *) else {
            throw XCTSkip("Combine is not available")
        }
        
        func setUp<Writer: DatabaseWriter>(_ writer: Writer) throws -> Writer {
            try writer.write(Player.createTable)
            return writer
        }
        
        func test(writer: DatabaseWriter) throws {
            let publisher = writer
                .writePublisher(
                    updates: { db in try Player(id: 1, name: "Arthur", score: 1000).insert(db) },
                    thenRead: { db, _ in try Player.fetchCount(db) })
            let recorder = publisher.record()
            let count = try wait(for: recorder.single, timeout: 1)
            XCTAssertEqual(count, 1)
        }
        
        try Test(test)
            .run { try setUp(DatabaseQueue()) }
            .runAtTemporaryDatabasePath { try setUp(DatabaseQueue(path: $0)) }
            .runAtTemporaryDatabasePath { try setUp(DatabasePool(path: $0)) }
    }
    
    // MARK: -
    
    func testWriteThenReadPublisherIsReadonly() throws {
        guard #available(OSX 10.15, iOS 13, tvOS 13, watchOS 6, *) else {
            throw XCTSkip("Combine is not available")
        }
        
        func test(writer: DatabaseWriter) throws {
            let publisher = writer
                .writePublisher(
                    updates: { _ in },
                    thenRead: { db, _ in try Player.createTable(db) })
            let recorder = publisher.record()
            let recording = try wait(for: recorder.recording, timeout: 1)
            XCTAssertTrue(recording.output.isEmpty)
            assertFailure(recording.completion) { (error: DatabaseError) in
                XCTAssertEqual(error.resultCode, .SQLITE_READONLY)
            }
        }
        
        try Test(test)
            .run { DatabaseQueue() }
            .runAtTemporaryDatabasePath { try DatabaseQueue(path: $0) }
            .runAtTemporaryDatabasePath { try DatabasePool(path: $0) }
    }
    
    // MARK: -
    
    func testWriteThenReadPublisherWriteError() throws {
        guard #available(OSX 10.15, iOS 13, tvOS 13, watchOS 6, *) else {
            throw XCTSkip("Combine is not available")
        }
        
        func test(writer: DatabaseWriter) throws {
            let publisher = writer.writePublisher(
                updates: { db in try db.execute(sql: "THIS IS NOT SQL") },
                thenRead: { _, _ in XCTFail("Should not read") })
            let recorder = publisher.record()
            let recording = try wait(for: recorder.recording, timeout: 1)
            XCTAssertTrue(recording.output.isEmpty)
            assertFailure(recording.completion) { (error: DatabaseError) in
                XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
                XCTAssertEqual(error.sql, "THIS IS NOT SQL")
            }
        }
        
        try Test(test)
            .run { DatabaseQueue() }
            .runAtTemporaryDatabasePath { try DatabaseQueue(path: $0) }
            .runAtTemporaryDatabasePath { try DatabasePool(path: $0) }
    }
    
    func testWriteThenReadPublisherWriteErrorRollbacksTransaction() throws {
        guard #available(OSX 10.15, iOS 13, tvOS 13, watchOS 6, *) else {
            throw XCTSkip("Combine is not available")
        }
        
        func setUp<Writer: DatabaseWriter>(_ writer: Writer) throws -> Writer {
            try writer.write(Player.createTable)
            return writer
        }
        
        func test(writer: DatabaseWriter) throws {
            let publisher = writer.writePublisher(
                updates: { db in
                    try Player(id: 1, name: "Arthur", score: 1000).insert(db)
                    try db.execute(sql: "THIS IS NOT SQL")
            },
                thenRead: { _, _ in XCTFail("Should not read") })
            let recorder = publisher.record()
            let recording = try wait(for: recorder.recording, timeout: 1)
            XCTAssertTrue(recording.output.isEmpty)
            assertFailure(recording.completion) { (error: DatabaseError) in
                XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
                XCTAssertEqual(error.sql, "THIS IS NOT SQL")
            }
            let count = try writer.read(Player.fetchCount)
            XCTAssertEqual(count, 0)
        }
        
        try Test(test)
            .run { try setUp(DatabaseQueue()) }
            .runAtTemporaryDatabasePath { try setUp(DatabaseQueue(path: $0)) }
            .runAtTemporaryDatabasePath { try setUp(DatabasePool(path: $0)) }
    }
    
    // MARK: -
    
    // TODO: Fix flaky test with both pool and on-disk queue:
    // - Expectation timeout
    func testWriteThenReadPublisherReadError() throws {
        guard #available(OSX 10.15, iOS 13, tvOS 13, watchOS 6, *) else {
            throw XCTSkip("Combine is not available")
        }
        
        func test(writer: DatabaseWriter) throws {
            let publisher = writer.writePublisher(
                updates: { _ in },
                thenRead: { db, _ in try Row.fetchAll(db, sql: "THIS IS NOT SQL") })
            let recorder = publisher.record()
            let recording = try wait(for: recorder.recording, timeout: 1)
            XCTAssertTrue(recording.output.isEmpty)
            assertFailure(recording.completion) { (error: DatabaseError) in
                XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
                XCTAssertEqual(error.sql, "THIS IS NOT SQL")
            }
        }
        
        try Test(test)
            .run { DatabaseQueue() }
            .runAtTemporaryDatabasePath { try DatabaseQueue(path: $0) }
            .runAtTemporaryDatabasePath { try DatabasePool(path: $0) }
    }
    
    // MARK: - Regression tests
    
    // Regression test against deadlocks created by concurrent completion
    // and cancellations trigerred by .switchToLatest().prefix(1)
    func testDeadlockPrevention() throws {
        guard #available(OSX 10.15, iOS 13, tvOS 13, watchOS 6, *) else {
            throw XCTSkip("Combine is not available")
        }
        
        func setUp<Writer: DatabaseWriter>(_ writer: Writer) throws -> Writer {
            try writer.write(Player.createTable)
            return writer
        }
        
        func test(writer: DatabaseWriter, iteration: Int) throws {
            // print(iteration)
            let scoreSubject = PassthroughSubject<Int, Error>()
            let publisher = scoreSubject
                .map({ score in
                    writer.writePublisher { db -> Int in
                        try Player(id: 1, name: "Arthur", score: score).insert(db)
                        return try Player.fetchCount(db)
                    }
                })
                .switchToLatest()
                .prefix(1)
            let recorder = publisher.record()
            scoreSubject.send(0)
            let count = try wait(for: recorder.single, timeout: 1)
            XCTAssertEqual(count, 1)
        }
        
        try Test(repeatCount: 100, test)
            .run { try setUp(DatabaseQueue()) }
            .runAtTemporaryDatabasePath { try setUp(DatabaseQueue(path: $0)) }
            .runAtTemporaryDatabasePath { try setUp(DatabasePool(path: $0)) }
    }
}
#endif

