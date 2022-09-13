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

class DatabaseReaderImmediateReadPublisherTests : XCTestCase {
    
    // MARK: -
    
    func testImmediateReadPublisher() throws {
        guard #available(OSX 10.15, iOS 13, tvOS 13, watchOS 6, *) else {
            throw XCTSkip("Combine is not available")
        }
        
        func setUp<Writer: DatabaseWriter>(_ writer: Writer) throws -> Writer {
            try writer.write(Player.createTable)
            return writer
        }
        
        func test(reader: some DatabaseReader) throws {
            let publisher = reader.immediateReadPublisher(value: { db in
                try Player.fetchCount(db)
            })
            let recorder = publisher.record()
            let value = try recorder.single.get()
            XCTAssertEqual(value, 0)
        }
        
        try Test(test).run { try setUp(DatabaseQueue()) }
        try Test(test).runAtTemporaryDatabasePath { try setUp(DatabaseQueue(path: $0)) }
        try Test(test).runAtTemporaryDatabasePath { try setUp(DatabasePool(path: $0)) }
        try Test(test).runAtTemporaryDatabasePath { try setUp(DatabasePool(path: $0)).makeSnapshot() }
    }
    
    // MARK: -
    
    func testImmediateReadPublisherError() throws {
        guard #available(OSX 10.15, iOS 13, tvOS 13, watchOS 6, *) else {
            throw XCTSkip("Combine is not available")
        }
        
        func test(reader: some DatabaseReader) throws {
            let publisher = reader.immediateReadPublisher(value: { db in
                try Row.fetchAll(db, sql: "THIS IS NOT SQL")
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
        try Test(test).runAtTemporaryDatabasePath { try DatabasePool(path: $0).makeSnapshot() }
    }
    
    // MARK: -
    
    func testImmediateReadPublisherIsReadonly() throws {
        guard #available(OSX 10.15, iOS 13, tvOS 13, watchOS 6, *) else {
            throw XCTSkip("Combine is not available")
        }
        
        func test(reader: some DatabaseReader) throws {
            let publisher = reader.immediateReadPublisher(value: { db in
                try Player.createTable(db)
            })
            let recorder = publisher.record()
            let recording = try recorder.recording.get()
            XCTAssertTrue(recording.output.isEmpty)
            assertFailure(recording.completion) { (error: DatabaseError) in
                XCTAssertEqual(error.resultCode, .SQLITE_READONLY)
            }
        }
        
        try Test(test).run { try DatabaseQueue() }
        try Test(test).runAtTemporaryDatabasePath { try DatabaseQueue(path: $0) }
        try Test(test).runAtTemporaryDatabasePath { try DatabasePool(path: $0) }
        try Test(test).runAtTemporaryDatabasePath { try DatabasePool(path: $0).makeSnapshot() }
    }
}
#endif
