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

class DatabaseWriterImmediateWritePublisherTests : XCTestCase {
    
    // MARK: -
    
    func testImmediateWritePublisher() throws {
        guard #available(OSX 10.15, iOS 13, tvOS 13, watchOS 6, *) else {
            throw XCTSkip("Combine is not available")
        }
        
        func setUp<Writer: DatabaseWriter>(_ writer: Writer) throws -> Writer {
            try writer.write(Player.createTable)
            return writer
        }
        
        func test(writer: some DatabaseWriter) throws {
            try XCTAssertEqual(writer.read(Player.fetchCount), 0)
            let publisher = writer.immediateWritePublisher(updates: { db in
                try Player(id: 1, name: "Arthur", score: 1000).insert(db)
            })
            let recorder = publisher.record()
            try recorder.single.get()
            try XCTAssertEqual(writer.read(Player.fetchCount), 1)
        }
        
        try Test(test).run { try setUp(DatabaseQueue()) }
        try Test(test).runAtTemporaryDatabasePath { try setUp(DatabaseQueue(path: $0)) }
        try Test(test).runAtTemporaryDatabasePath { try setUp(DatabasePool(path: $0)) }
    }
    
    // MARK: -
    
    func testImmediateWritePublisherValue() throws {
        guard #available(OSX 10.15, iOS 13, tvOS 13, watchOS 6, *) else {
            throw XCTSkip("Combine is not available")
        }
        
        func setUp<Writer: DatabaseWriter>(_ writer: Writer) throws -> Writer {
            try writer.write(Player.createTable)
            return writer
        }
        
        func test(writer: some DatabaseWriter) throws {
            let publisher = writer.immediateWritePublisher(updates: { db -> Int in
                try Player(id: 1, name: "Arthur", score: 1000).insert(db)
                return try Player.fetchCount(db)
            })
            let recorder = publisher.record()
            let count = try recorder.single.get()
            XCTAssertEqual(count, 1)
        }
        
        try Test(test).run { try setUp(DatabaseQueue()) }
        try Test(test).runAtTemporaryDatabasePath { try setUp(DatabaseQueue(path: $0)) }
        try Test(test).runAtTemporaryDatabasePath { try setUp(DatabasePool(path: $0)) }
    }
    
    // MARK: -
    
    func testImmediateWritePublisherError() throws {
        guard #available(OSX 10.15, iOS 13, tvOS 13, watchOS 6, *) else {
            throw XCTSkip("Combine is not available")
        }
        
        func test(writer: some DatabaseWriter) throws {
            let publisher = writer.immediateWritePublisher(updates: { db in
                try db.execute(sql: "THIS IS NOT SQL")
            })
            let recorder = publisher.record()
            let recording = try recorder.recording.get()
            XCTAssertTrue(recording.output.isEmpty)
            assertFailure(recording.completion) { (error: DatabaseError) in
                XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
                XCTAssertEqual(error.sql, "THIS IS NOT SQL")
            }
        }
        
        try Test(test).run { try DatabaseQueue() }
        try Test(test).runAtTemporaryDatabasePath { try DatabaseQueue(path: $0) }
        try Test(test).runAtTemporaryDatabasePath { try DatabasePool(path: $0) }
    }
    
    func testImmediateWritePublisherErrorRollbacksTransaction() throws {
        guard #available(OSX 10.15, iOS 13, tvOS 13, watchOS 6, *) else {
            throw XCTSkip("Combine is not available")
        }
        
        func setUp<Writer: DatabaseWriter>(_ writer: Writer) throws -> Writer {
            try writer.write(Player.createTable)
            return writer
        }
        
        func test(writer: some DatabaseWriter) throws {
            let publisher = writer.immediateWritePublisher(updates: { db in
                try Player(id: 1, name: "Arthur", score: 1000).insert(db)
                try db.execute(sql: "THIS IS NOT SQL")
            })
            let recorder = publisher.record()
            let recording = try recorder.recording.get()
            XCTAssertTrue(recording.output.isEmpty)
            assertFailure(recording.completion) { (error: DatabaseError) in
                XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
                XCTAssertEqual(error.sql, "THIS IS NOT SQL")
            }
            let count = try writer.read(Player.fetchCount)
            XCTAssertEqual(count, 0)
        }
        
        try Test(test).run { try setUp(DatabaseQueue()) }
        try Test(test).runAtTemporaryDatabasePath { try setUp(DatabaseQueue(path: $0)) }
        try Test(test).runAtTemporaryDatabasePath { try setUp(DatabasePool(path: $0)) }
    }
    
    // MARK: - Regression tests
    
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
                .map { score in
                    writer.immediateWritePublisher { db -> Int in
                        try Player(id: 1, name: "Arthur", score: score).insert(db)
                        return try Player.fetchCount(db)
                    }
                }
                .switchToLatest()
                .prefix(1)
            let recorder = publisher.record()
            scoreSubject.send(0)
            let count = try recorder.single.get()
            XCTAssertEqual(count, 1)
        }
        
        try Test(repeatCount: 100, test).run { try setUp(DatabaseQueue()) }
        try Test(repeatCount: 100, test).runAtTemporaryDatabasePath { try setUp(DatabaseQueue(path: $0)) }
        try Test(repeatCount: 100, test).runAtTemporaryDatabasePath { try setUp(DatabasePool(path: $0)) }
    }
}
#endif

