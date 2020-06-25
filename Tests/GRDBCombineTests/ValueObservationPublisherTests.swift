import Combine
import CombineExpectations
import GRDB
import GRDBCombine
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
        func setUp<Writer: DatabaseWriter>(_ writer: Writer) throws -> Writer {
            try writer.write(Player.createTable)
            return writer
        }
        
        func test(writer: DatabaseWriter) throws {
            let publisher = ValueObservation
                .tracking(Player.fetchCount)
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
        func setUp<Writer: DatabaseWriter>(_ writer: Writer) throws -> Writer {
            try writer.write(Player.createTable)
            return writer
        }
        
        func test(writer: DatabaseWriter) throws {
            let expectation = self.expectation(description: "")
            let semaphore = DispatchSemaphore(value: 0)
            let cancellable = ValueObservation
                .tracking(Player.fetchCount)
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
        func test(writer: DatabaseWriter) throws {
            let publisher = ValueObservation
                .tracking { try $0.execute(sql: "THIS IS NOT SQL") }
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
            .run { DatabaseQueue() }
            .runAtTemporaryDatabasePath { try DatabaseQueue(path: $0) }
            .runAtTemporaryDatabasePath { try DatabasePool(path: $0) }
    }
    
    // MARK: - Immediate Scheduler
    
    func testImmediateSchedulerChangesNotifications() throws {
        func setUp<Writer: DatabaseWriter>(_ writer: Writer) throws -> Writer {
            try writer.write(Player.createTable)
            return writer
        }
        
        func test(writer: DatabaseWriter) throws {
            let publisher = ValueObservation
                .tracking(Player.fetchCount)
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
                .tracking(Player.fetchCount)
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
        func test(writer: DatabaseWriter) throws {
            let publisher = ValueObservation
                .tracking { try $0.execute(sql: "THIS IS NOT SQL") }
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
            .run { DatabaseQueue() }
            .runAtTemporaryDatabasePath { try DatabaseQueue(path: $0) }
            .runAtTemporaryDatabasePath { try DatabasePool(path: $0) }
    }
    
    // MARK: - Demand
    
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
                .tracking(Player.fetchCount)
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
                .tracking(Player.fetchCount)
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
                .tracking(Player.fetchCount)
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
                .tracking(Player.fetchCount)
                .publisher(in: writer, scheduling: .immediate /* make sure we get two db states */)
                .print()
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
    
    // MARK: - Utils
    
    /// This test checks the fundamental promise of ValueObservation by
    /// comparing recorded values with expected values.
    ///
    /// Recorded values match the expected values if and only if:
    ///
    /// - The last recorded value is the last expected value
    /// - Recorded values are in the same order as expected values
    ///
    /// However, both missing and repeated values are allowed - with the only
    /// exception of the last expected value which can not be missed.
    ///
    /// For example, if the expected values are [0, 1], then the following
    /// recorded values match:
    ///
    /// - `[0, 1]` (identical values)
    /// - `[1]` (missing value but the last one)
    /// - `[0, 0, 1, 1]` (repeated value)
    ///
    /// However the following recorded values don't match, and fail the test:
    ///
    /// - `[1, 0]` (wrong order)
    /// - `[0]` (missing last value)
    /// - `[]` (missing last value)
    /// - `[0, 1, 2]` (unexpected value)
    /// - `[1, 0, 1]` (unexpected value)
    func assertValueObservationRecordingMatch<Value>(
        recorded recordedValues: [Value],
        expected expectedValues: [Value],
        _ message: @autoclosure () -> String = "",
        file: StaticString = #file,
        line: UInt = #line)
        where Value: Equatable
    {
        _assertValueObservationRecordingMatch(
            recorded: recordedValues,
            expected: expectedValues,
            // Last value can't be missed
            allowMissingLastValue: false,
            message(), file: file, line: line)
    }
    
    private func _assertValueObservationRecordingMatch<R, E>(
        recorded recordedValues: R,
        expected expectedValues: E,
        allowMissingLastValue: Bool,
        _ message: @autoclosure () -> String = "",
        file: StaticString = #file,
        line: UInt = #line)
        where
        R: BidirectionalCollection,
        E: BidirectionalCollection,
        R.Element == E.Element,
        R.Element: Equatable
    {
        guard let value = expectedValues.last else {
            if !recordedValues.isEmpty {
                XCTFail("unexpected recorded prefix \(Array(recordedValues)) - \(message())", file: file, line: line)
            }
            return
        }
        
        let recordedSuffix = recordedValues.reversed().prefix(while: { $0 == value })
        let expectedSuffix = expectedValues.reversed().prefix(while: { $0 == value })
        if !allowMissingLastValue {
            // Both missing and repeated values are allowed in the recorded values.
            // This is because of asynchronous DatabasePool observations.
            if recordedSuffix.isEmpty {
                XCTFail("missing expected value \(value) - \(message())", file: file, line: line)
            }
        }
        
        let remainingRecordedValues = recordedValues.prefix(recordedValues.count - recordedSuffix.count)
        let remainingExpectedValues = expectedValues.prefix(expectedValues.count - expectedSuffix.count)
        _assertValueObservationRecordingMatch(
            recorded: remainingRecordedValues,
            expected: remainingExpectedValues,
            // Other values can be missed
            allowMissingLastValue: true,
            message(), file: file, line: line)
    }
}
