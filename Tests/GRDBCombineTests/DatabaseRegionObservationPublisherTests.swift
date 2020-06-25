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

class DatabaseRegionObservationPublisherTests : XCTestCase {
    
    func testChangesNotifications() throws {
        guard #available(OSX 10.15, iOS 13, tvOS 13, watchOS 6, *) else {
            throw XCTSkip("Combine is not available")
        }
        
        func setUp<Writer: DatabaseWriter>(_ writer: Writer) throws -> Writer {
            try writer.write(Player.createTable)
            return writer
        }
        
        func test(writer: DatabaseWriter) throws {
            let publisher = DatabaseRegionObservation(tracking: Player.all())
                .publisher(in: writer)
                .tryMap(Player.fetchCount)
            let recorder = publisher.record()
            
            try writer.writeWithoutTransaction { db in
                try Player(id: 1, name: "Arthur", score: 1000).insert(db)
                
                try db.inTransaction {
                    try Player(id: 2, name: "Barbara", score: 750).insert(db)
                    try Player(id: 3, name: "Craig", score: 500).insert(db)
                    return .commit
                }
            }
            
            let elements = try wait(for: recorder.next(2), timeout: 1)
            XCTAssertEqual(elements, [1, 3])
        }
        
        try Test(test)
            .run { try setUp(DatabaseQueue()) }
            .runAtTemporaryDatabasePath { try setUp(DatabaseQueue(path: $0)) }
            .runAtTemporaryDatabasePath { try setUp(DatabasePool(path: $0)) }
    }
    
    // This is an usage test. Do the available APIs allow to prepend a
    // database connection synchronously, with the guarantee that no race can
    // have the subscriber miss an impactful change?
    //
    // TODO: do the same, but asynchronously. If this is too hard, update the
    // public API so that users can easily do it.
    func testPrependInitialDatabaseSync() throws {
        guard #available(OSX 10.15, iOS 13, tvOS 13, watchOS 6, *) else {
            throw XCTSkip("Combine is not available")
        }
        
        func setUp<Writer: DatabaseWriter>(_ writer: Writer) throws -> Writer {
            try writer.write(Player.createTable)
            return writer
        }
        
        func test(writer: DatabaseWriter) throws {
            let expectation = self.expectation(description: "")
            let testSubject = PassthroughSubject<Database, Error>()
            let testCancellable = testSubject
                .tryMap(Player.fetchCount)
                .collect(3)
                .sink(
                    receiveCompletion: { completion in
                        assertNoFailure(completion)
                },
                    receiveValue: { value in
                        XCTAssertEqual(value, [0, 1, 3])
                        expectation.fulfill()
                })
            
            let observationCancellable = try writer.write { db in
                DatabaseRegionObservation(tracking: Player.all())
                    .publisher(in: writer)
                    .prepend(db)
                    .subscribe(testSubject)
            }
            
            try writer.writeWithoutTransaction { db in
                try Player(id: 1, name: "Arthur", score: 1000).insert(db)
                
                try db.inTransaction {
                    try Player(id: 2, name: "Barbara", score: 750).insert(db)
                    try Player(id: 3, name: "Craig", score: 500).insert(db)
                    return .commit
                }
            }
            
            waitForExpectations(timeout: 1, handler: nil)
            testCancellable.cancel()
            observationCancellable.cancel()
        }
        
        try Test(test)
            .run { try setUp(DatabaseQueue()) }
            .runAtTemporaryDatabasePath { try setUp(DatabaseQueue(path: $0)) }
            .runAtTemporaryDatabasePath { try setUp(DatabasePool(path: $0)) }
    }
}
#endif

