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

class ValueObservationPublisherTests : XCTestCase {
    
    // MARK: - Default Scheduler
    
    func testDefaultSchedulerChangesNotifications() throws {
        guard #available(OSX 10.15, iOS 13, tvOS 13, watchOS 6, *) else {
            throw XCTSkip("Combine is not available")
        }
        
        func setUp<Writer: DatabaseWriter>(_ writer: Writer) throws -> Writer {
            try writer.write(Player.createTable)
            return writer
        }
        
        func test(writer: DatabaseWriter) throws {
            let publisher = ValueObservation
                .trackingConstantRegion(Player.fetchCount)
                .publisher(in: writer)
            let recorder = publisher.record()
            
            try writer.writeWithoutTransaction { db in
                try Player(id: 1, name: "Arthur", score: 1000).insert(db)
                
                try db.inTransaction {
                    try Player(id: 2, name: "Barbara", score: 750).insert(db)
                    try Player(id: 3, name: "Craig", score: 500).insert(db)
                    return .commit
                }
            }
            
            let expectedElements = [0, 1, 3]
            if writer is DatabaseQueue {
                let elements = try wait(for: recorder.next(expectedElements.count), timeout: 1)
                XCTAssertEqual(elements, expectedElements)
            } else {
                // TODO: prefix(until:)
                let elements = try wait(for: recorder.prefix(expectedElements.count + 2).inverted, timeout: 1)
                assertValueObservationRecordingMatch(recorded: elements, expected: expectedElements)
            }
        }
        
        try Test(test)
            .run { try setUp(DatabaseQueue()) }
            .runAtTemporaryDatabasePath { try setUp(DatabaseQueue(path: $0)) }
            .runAtTemporaryDatabasePath { try setUp(DatabasePool(path: $0)) }
    }
    
    func testDefaultSchedulerFirstValueIsEmittedAsynchronously() throws {
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
            let cancellable = ValueObservation
                .trackingConstantRegion(Player.fetchCount)
                .publisher(in: writer)
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
    
    func testDefaultSchedulerError() throws {
        guard #available(OSX 10.15, iOS 13, tvOS 13, watchOS 6, *) else {
            throw XCTSkip("Combine is not available")
        }
        
        func test(writer: DatabaseWriter) throws {
            let publisher = ValueObservation
                .trackingConstantRegion { try $0.execute(sql: "THIS IS NOT SQL") }
                .publisher(in: writer)
            let recorder = publisher.record()
            let completion = try wait(for: recorder.completion, timeout: 1)
            switch completion {
            case let .failure(error):
                XCTAssertNotNil(error as? DatabaseError)
            case .finished:
                XCTFail("Expected error")
            }
        }
        
        try Test(test)
            .run { try DatabaseQueue() }
            .runAtTemporaryDatabasePath { try DatabaseQueue(path: $0) }
            .runAtTemporaryDatabasePath { try DatabasePool(path: $0) }
    }
    
    // MARK: - Immediate Scheduler
    
    func testImmediateSchedulerChangesNotifications() throws {
        guard #available(OSX 10.15, iOS 13, tvOS 13, watchOS 6, *) else {
            throw XCTSkip("Combine is not available")
        }
        
        func setUp<Writer: DatabaseWriter>(_ writer: Writer) throws -> Writer {
            try writer.write(Player.createTable)
            return writer
        }
        
        func test(writer: DatabaseWriter) throws {
            let publisher = ValueObservation
                .trackingConstantRegion(Player.fetchCount)
                .publisher(in: writer, scheduling: .immediate)
            let recorder = publisher.record()
            
            try writer.writeWithoutTransaction { db in
                try Player(id: 1, name: "Arthur", score: 1000).insert(db)
                
                try db.inTransaction {
                    try Player(id: 2, name: "Barbara", score: 750).insert(db)
                    try Player(id: 3, name: "Craig", score: 500).insert(db)
                    return .commit
                }
            }
            
            let expectedElements = [0, 1, 3]
            if writer is DatabaseQueue {
                let elements = try wait(for: recorder.next(expectedElements.count), timeout: 1)
                XCTAssertEqual(elements, expectedElements)
            } else {
                // TODO: prefix(until:)
                let elements = try wait(for: recorder.prefix(expectedElements.count + 2).inverted, timeout: 1)
                assertValueObservationRecordingMatch(recorded: elements, expected: expectedElements)
            }
        }
        
        try Test(test)
            .run { try setUp(DatabaseQueue()) }
            .runAtTemporaryDatabasePath { try setUp(DatabaseQueue(path: $0)) }
            .runAtTemporaryDatabasePath { try setUp(DatabasePool(path: $0)) }
    }
    
    func testImmediateSchedulerEmitsFirstValueSynchronously() throws {
        guard #available(OSX 10.15, iOS 13, tvOS 13, watchOS 6, *) else {
            throw XCTSkip("Combine is not available")
        }
        
        func setUp<Writer: DatabaseWriter>(_ writer: Writer) throws -> Writer {
            try writer.write(Player.createTable)
            return writer
        }
        
        func test(writer: DatabaseWriter) throws {
            let semaphore = DispatchSemaphore(value: 0)
            let testSubject = PassthroughSubject<Int, Error>()
            let testCancellable = testSubject
                .sink(
                    receiveCompletion: { _ in },
                    receiveValue: { _ in
                        dispatchPrecondition(condition: .onQueue(.main))
                        semaphore.signal()
                })
            
            let observationCancellable = ValueObservation
                .trackingConstantRegion(Player.fetchCount)
                .publisher(in: writer, scheduling: .immediate)
                .subscribe(testSubject)
            
            semaphore.wait()
            testCancellable.cancel()
            observationCancellable.cancel()
        }
        
        try Test(test)
            .run { try setUp(DatabaseQueue()) }
            .runAtTemporaryDatabasePath { try setUp(DatabaseQueue(path: $0)) }
            .runAtTemporaryDatabasePath { try setUp(DatabasePool(path: $0)) }
    }
    
    func testImmediateSchedulerError() throws {
        guard #available(OSX 10.15, iOS 13, tvOS 13, watchOS 6, *) else {
            throw XCTSkip("Combine is not available")
        }
        
        func test(writer: DatabaseWriter) throws {
            let publisher = ValueObservation
                .trackingConstantRegion { try $0.execute(sql: "THIS IS NOT SQL") }
                .publisher(in: writer, scheduling: .immediate)
            let recorder = publisher.record()
            let completion = try recorder.completion.get()
            switch completion {
            case let .failure(error):
                XCTAssertNotNil(error as? DatabaseError)
            case .finished:
                XCTFail("Expected error")
            }
        }
        
        try Test(test)
            .run { try DatabaseQueue() }
            .runAtTemporaryDatabasePath { try DatabaseQueue(path: $0) }
            .runAtTemporaryDatabasePath { try DatabasePool(path: $0) }
    }
    
    // MARK: - Demand
    
    @available(OSX 10.15, iOS 13, tvOS 13, watchOS 6, *)
    private class DemandSubscriber<Input, Failure: Error>: Subscriber {
        private var subscription: Subscription?
        let subject = PassthroughSubject<Input, Failure>()
        deinit {
            subscription?.cancel()
        }
        
        func cancel() {
            subscription!.cancel()
        }
        
        func request(_ demand: Subscribers.Demand) {
            subscription!.request(demand)
        }
        
        func receive(subscription: Subscription) {
            self.subscription = subscription
        }
        
        func receive(_ input: Input) -> Subscribers.Demand {
            subject.send(input)
            return .none
        }
        
        func receive(completion: Subscribers.Completion<Failure>) {
            subject.send(completion: completion)
        }
    }
    
    func testDemandNoneReceivesNoElement() throws {
        guard #available(OSX 10.15, iOS 13, tvOS 13, watchOS 6, *) else {
            throw XCTSkip("Combine is not available")
        }
        
        func setUp<Writer: DatabaseWriter>(_ writer: Writer) throws -> Writer {
            try writer.write(Player.createTable)
            return writer
        }
        
        func test(writer: DatabaseWriter) throws {
            let subscriber = DemandSubscriber<Int, Error>()
            
            let expectation = self.expectation(description: "")
            expectation.isInverted = true
            let testCancellable = subscriber.subject
                .sink(
                    receiveCompletion: { _ in XCTFail("Unexpected completion") },
                    receiveValue: { _ in expectation.fulfill() })
            
            ValueObservation
                .trackingConstantRegion(Player.fetchCount)
                .publisher(in: writer)
                .subscribe(subscriber)
            
            waitForExpectations(timeout: 1, handler: nil)
            testCancellable.cancel()
            subscriber.cancel()
        }
        
        try Test(test)
            .run { try setUp(DatabaseQueue()) }
            .runAtTemporaryDatabasePath { try setUp(DatabaseQueue(path: $0)) }
            .runAtTemporaryDatabasePath { try setUp(DatabasePool(path: $0)) }
    }
    
    func testDemandOneReceivesOneElement() throws {
        guard #available(OSX 10.15, iOS 13, tvOS 13, watchOS 6, *) else {
            throw XCTSkip("Combine is not available")
        }
        
        func setUp<Writer: DatabaseWriter>(_ writer: Writer) throws -> Writer {
            try writer.write(Player.createTable)
            return writer
        }
        
        func test(writer: DatabaseWriter) throws {
            let subscriber = DemandSubscriber<Int, Error>()
            let expectation = self.expectation(description: "")
            
            let testCancellable = subscriber.subject.sink(
                receiveCompletion: { _ in XCTFail("Unexpected completion") },
                receiveValue: { value in
                    XCTAssertEqual(value, 0)
                    expectation.fulfill()
            })
            
            ValueObservation
                .trackingConstantRegion(Player.fetchCount)
                .publisher(in: writer)
                .subscribe(subscriber)
            
            subscriber.request(.max(1))
            
            waitForExpectations(timeout: 1, handler: nil)
            testCancellable.cancel()
            subscriber.cancel()
        }
        
        try Test(test)
            .run { try setUp(DatabaseQueue()) }
            .runAtTemporaryDatabasePath { try setUp(DatabaseQueue(path: $0)) }
            .runAtTemporaryDatabasePath { try setUp(DatabasePool(path: $0)) }
    }
    
    func testDemandOneDoesNotReceiveTwoElements() throws {
        guard #available(OSX 10.15, iOS 13, tvOS 13, watchOS 6, *) else {
            throw XCTSkip("Combine is not available")
        }
        
        func setUp<Writer: DatabaseWriter>(_ writer: Writer) throws -> Writer {
            try writer.write(Player.createTable)
            return writer
        }
        
        func test(writer: DatabaseWriter) throws {
            let subscriber = DemandSubscriber<Int, Error>()
            let expectation = self.expectation(description: "")
            expectation.isInverted = true
            
            let testCancellable = subscriber.subject
                .collect(2)
                .sink(
                    receiveCompletion: { _ in XCTFail("Unexpected completion") },
                    receiveValue: { _ in expectation.fulfill() })
            
            ValueObservation
                .trackingConstantRegion(Player.fetchCount)
                .publisher(in: writer, scheduling: .immediate /* make sure we get the initial db state */)
                .subscribe(subscriber)
            
            subscriber.request(.max(1))
            
            try writer.writeWithoutTransaction { db in
                try Player(id: 1, name: "Arthur", score: 1000).insert(db)
            }
            
            waitForExpectations(timeout: 1, handler: nil)
            testCancellable.cancel()
            subscriber.cancel()
        }
        
        try Test(test)
            .run { try setUp(DatabaseQueue()) }
            .runAtTemporaryDatabasePath { try setUp(DatabaseQueue(path: $0)) }
            .runAtTemporaryDatabasePath { try setUp(DatabasePool(path: $0)) }
    }
    
    func testDemandTwoReceivesTwoElements() throws {
        guard #available(OSX 10.15, iOS 13, tvOS 13, watchOS 6, *) else {
            throw XCTSkip("Combine is not available")
        }
        
        func setUp<Writer: DatabaseWriter>(_ writer: Writer) throws -> Writer {
            try writer.write(Player.createTable)
            return writer
        }
        
        func test(writer: DatabaseWriter) throws {
            let subscriber = DemandSubscriber<Int, Error>()
            let expectation = self.expectation(description: "")
            
            let testCancellable = subscriber.subject
                .collect(2)
                .sink(
                    receiveCompletion: { _ in XCTFail("Unexpected completion") },
                    receiveValue: { values in
                        expectation.fulfill()
                })
            
            ValueObservation
                .trackingConstantRegion(Player.fetchCount)
                .publisher(in: writer, scheduling: .immediate /* make sure we get two db states */)
                .subscribe(subscriber)
            
            subscriber.request(.max(2))
            
            try writer.writeWithoutTransaction { db in
                try Player(id: 1, name: "Arthur", score: 1000).insert(db)
            }
            
            waitForExpectations(timeout: 1, handler: nil)
            testCancellable.cancel()
            subscriber.cancel()
        }
        
        try Test(test)
            .run { try setUp(DatabaseQueue()) }
            .runAtTemporaryDatabasePath { try setUp(DatabaseQueue(path: $0)) }
            .runAtTemporaryDatabasePath { try setUp(DatabasePool(path: $0)) }
    }
    
    // MARK: - Regression Tests
    
    /// Regression test for https://github.com/groue/GRDB.swift/issues/1194
    func testIssue1194() throws {
        guard #available(OSX 10.15, iOS 13, tvOS 13, watchOS 6, *) else {
            throw XCTSkip("Combine is not available")
        }
        
        struct Record: Codable, FetchableRecord, PersistableRecord {
            var id: Int64
        }
        
        var configuration = Configuration()
        configuration.targetQueue = DispatchQueue(label: "crash.test", qos: .userInitiated)
        
        let database = try DatabaseQueue(configuration: configuration)
        
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1") { (db) in
            try db.create(table: Record.databaseTableName) { (t) in
                t.autoIncrementedPrimaryKey("id")
            }
        }
        
        try migrator.migrate(database)
        
        let observation = ValueObservation.tracking { (db) in
            try Record.fetchCount(db)
        }
        
        let exp = expectation(description: "")
        let cancellable = observation.publisher(in: database, scheduling: .immediate)
            .map { _ in
                database.readPublisher { (db) in
                    try Record.fetchCount(db)
                }
            }
            .switchToLatest()
            .sink(receiveCompletion: { _ in },
                  receiveValue: { (value) in
                exp.fulfill()
            })
        
        withExtendedLifetime(cancellable) {
            waitForExpectations(timeout: 1)
        }
    }
}
#endif
