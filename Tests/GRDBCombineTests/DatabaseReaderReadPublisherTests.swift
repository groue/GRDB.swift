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

class DatabaseReaderReadPublisherTests : XCTestCase {
    
    // MARK: -
    
    func testReadPublisher() throws {
        guard #available(OSX 10.15, iOS 13, tvOS 13, watchOS 6, *) else {
            throw XCTSkip("Combine is not available")
        }
        
        func setUp<Writer: DatabaseWriter>(_ writer: Writer) throws -> Writer {
            try writer.write(Player.createTable)
            return writer
        }
        
        func test(reader: DatabaseReader) throws {
            let publisher = reader.readPublisher(value: { db in
                try Player.fetchCount(db)
            })
            let recorder = publisher.record()
            let value = try wait(for: recorder.single, timeout: 1)
            XCTAssertEqual(value, 0)
        }
        
        try Test(test)
            .run { try setUp(DatabaseQueue()) }
            .runAtTemporaryDatabasePath { try setUp(DatabaseQueue(path: $0)) }
            .runAtTemporaryDatabasePath { try setUp(DatabasePool(path: $0)) }
            .runAtTemporaryDatabasePath { try setUp(DatabasePool(path: $0)).makeSnapshot() }
    }
    
    // MARK: -
    
    func testReadPublisherError() throws {
        guard #available(OSX 10.15, iOS 13, tvOS 13, watchOS 6, *) else {
            throw XCTSkip("Combine is not available")
        }
        
        func test(reader: DatabaseReader) throws {
            let publisher = reader.readPublisher(value: { db in
                try Row.fetchAll(db, sql: "THIS IS NOT SQL")
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
            .runAtTemporaryDatabasePath { try DatabasePool(path: $0).makeSnapshot() }
    }
    
    // MARK: -
    
    func testReadPublisherIsAsynchronous() throws {
        guard #available(OSX 10.15, iOS 13, tvOS 13, watchOS 6, *) else {
            throw XCTSkip("Combine is not available")
        }
        
        func setUp<Writer: DatabaseWriter>(_ writer: Writer) throws -> Writer {
            try writer.write(Player.createTable)
            return writer
        }
        
        func test(reader: DatabaseReader) throws {
            let expectation = self.expectation(description: "")
            let semaphore = DispatchSemaphore(value: 0)
            let cancellable = reader
                .readPublisher(value: { db in
                    try Player.fetchCount(db)
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
            .runAtTemporaryDatabasePath { try setUp(DatabasePool(path: $0)).makeSnapshot() }
    }
    
    // MARK: -
    
    func testReadPublisherDefaultScheduler() throws {
        guard #available(OSX 10.15, iOS 13, tvOS 13, watchOS 6, *) else {
            throw XCTSkip("Combine is not available")
        }
        
        func setUp<Writer: DatabaseWriter>(_ writer: Writer) throws -> Writer {
            try writer.write(Player.createTable)
            return writer
        }
        
        func test(reader: DatabaseReader) {
            let expectation = self.expectation(description: "")
            let cancellable = reader
                .readPublisher(value: { db in
                    try Player.fetchCount(db)
                })
                .sink(
                    receiveCompletion: { completion in
                        dispatchPrecondition(condition: .onQueue(.main))
                        expectation.fulfill()
                },
                    receiveValue: { _ in
                        dispatchPrecondition(condition: .onQueue(.main))
                })
            
            waitForExpectations(timeout: 1, handler: nil)
            cancellable.cancel()
        }
        
        try Test(test)
            .run { try setUp(DatabaseQueue()) }
            .runAtTemporaryDatabasePath { try setUp(DatabaseQueue(path: $0)) }
            .runAtTemporaryDatabasePath { try setUp(DatabasePool(path: $0)) }
            .runAtTemporaryDatabasePath { try setUp(DatabasePool(path: $0)).makeSnapshot() }
    }
    
    // MARK: -
    
    func testReadPublisherCustomScheduler() throws {
        guard #available(OSX 10.15, iOS 13, tvOS 13, watchOS 6, *) else {
            throw XCTSkip("Combine is not available")
        }
        
        func setUp<Writer: DatabaseWriter>(_ writer: Writer) throws -> Writer {
            try writer.write(Player.createTable)
            return writer
        }
        
        func test(reader: DatabaseReader) {
            let queue = DispatchQueue(label: "test")
            let expectation = self.expectation(description: "")
            let cancellable = reader
                .readPublisher(receiveOn: queue, value: { db in
                    try Player.fetchCount(db)
                })
                .sink(
                    receiveCompletion: { completion in
                        dispatchPrecondition(condition: .onQueue(queue))
                        expectation.fulfill()
                },
                    receiveValue: { _ in
                        dispatchPrecondition(condition: .onQueue(queue))
                })
            
            waitForExpectations(timeout: 1, handler: nil)
            cancellable.cancel()
        }
        
        try Test(test)
            .run { try setUp(DatabaseQueue()) }
            .runAtTemporaryDatabasePath { try setUp(DatabaseQueue(path: $0)) }
            .runAtTemporaryDatabasePath { try setUp(DatabasePool(path: $0)) }
            .runAtTemporaryDatabasePath { try setUp(DatabasePool(path: $0)).makeSnapshot() }
    }
    
    // MARK: -
    
    func testReadPublisherIsReadonly() throws {
        guard #available(OSX 10.15, iOS 13, tvOS 13, watchOS 6, *) else {
            throw XCTSkip("Combine is not available")
        }
        
        func test(reader: DatabaseReader) throws {
            let publisher = reader.readPublisher(value: { db in
                try Player.createTable(db)
            })
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
            .runAtTemporaryDatabasePath { try DatabasePool(path: $0).makeSnapshot() }
    }
}
#endif
