// Inspired by https://github.com/groue/CombineExpectations
import XCTest
@testable import GRDB

// MARK: - ValueObservationRecorder

public class ValueObservationRecorder<Value> {
    private struct RecorderExpectation {
        var expectation: XCTestExpectation
        var remainingCount: Int? // nil for error expectation
        var isIncluded: ((Value) -> Bool)? // nil for error expectation
    }
    
    /// The recorder state
    private struct State {
        var values: [Value]
        var error: Error?
        var recorderExpectation: RecorderExpectation?
        var cancellable: AnyDatabaseCancellable?
    }
    
    private let lock = NSLock()
    private var state = State(values: [], recorderExpectation: nil, cancellable: nil)
    private var consumedCount = 0
    
    /// Internal for testability. Use ValueObservation.record(in:) instead.
    init() { }
    
    private func synchronized<T>(_ execute: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try execute()
    }
    
    // MARK: ValueObservation API
    
    // Internal for testability.
    func onChange(_ value: Value) {
        return synchronized {
            if state.error != nil {
                // This is possible with ValueObservation, but not supported by ValueObservationRecorder
                XCTFail("ValueObservationRecorder got unexpected value after error: \(String(reflecting: value))")
            }
            
            state.values.append(value)
            
            if let exp = state.recorderExpectation,
                let remainingCount = exp.remainingCount,
                let isIncluded = exp.isIncluded
            {
                assert(remainingCount > 0)
                if isIncluded(value) {
                    exp.expectation.fulfill()
                    if remainingCount > 1 {
                        state.recorderExpectation = RecorderExpectation(
                            expectation: exp.expectation,
                            remainingCount: remainingCount - 1,
                            isIncluded: isIncluded)
                    } else {
                        state.recorderExpectation = nil
                    }
                }
            }
        }
    }
    
    // Internal for testability.
    func onError(_ error: Error) {
        return synchronized {
            if state.error != nil {
                // This is possible with ValueObservation, but not supported by ValueObservationRecorder
                XCTFail("f got unexpected error after error: \(String(describing: error))")
            }
            
            if let exp = state.recorderExpectation {
                exp.expectation.fulfill(count: exp.remainingCount ?? 1)
                state.recorderExpectation = nil
            }
            state.error = error
        }
    }
    
    // MARK: ValueObservationExpectation API
    
    func fulfillOnValue(_ expectation: XCTestExpectation, includingConsumed: Bool, isIncluded: @escaping (Value) -> Bool) {
        synchronized {
            preconditionCanFulfillExpectation()
            
            let expectedFulfillmentCount = expectation.expectedFulfillmentCount
            
            if state.error != nil {
                expectation.fulfill(count: expectedFulfillmentCount)
                return
            }
            
            let values = state.values.filter(isIncluded)
            let consumedValues = state.values[0..<consumedCount].filter(isIncluded)
            let maxFulfillmentCount = includingConsumed
                ? values.count
                : values.count - consumedValues.count
            let fulfillmentCount = min(expectedFulfillmentCount, maxFulfillmentCount)
            expectation.fulfill(count: fulfillmentCount)
            
            let remainingCount = expectedFulfillmentCount - fulfillmentCount
            if remainingCount > 0 {
                state.recorderExpectation = RecorderExpectation(
                    expectation: expectation,
                    remainingCount: remainingCount,
                    isIncluded: isIncluded)
            } else {
                state.recorderExpectation = nil
            }
        }
    }
    
    func fulfillOnError(_ expectation: XCTestExpectation) {
        synchronized {
            preconditionCanFulfillExpectation()
            
            if state.error != nil {
                expectation.fulfill()
                return
            }
            
            state.recorderExpectation = RecorderExpectation(
                expectation: expectation,
                remainingCount: nil,
                isIncluded: nil)
        }
    }
    
    /// Returns a value based on the recorded state.
    ///
    /// - parameter value: A function which returns the value, given the
    ///   recorded state.
    /// - parameter values: All recorded values.
    /// - parameter remainingValues: The values that were not consumed yet.
    /// - parameter consume: A function which consumes values.
    /// - parameter count: The number of consumed values.
    /// - returns: The value
    func value<T>(_ value: (
        _ values: [Value],
        _ error: Error?,
        _ remainingValues: ArraySlice<Value>,
        _ consume: (_ count: Int) -> ()) throws -> T)
        rethrows -> T
    {
        try synchronized {
            let values = state.values
            let remainingValues = values[consumedCount...]
            return try value(values, state.error, remainingValues, { count in
                precondition(count >= 0)
                precondition(count <= remainingValues.count)
                consumedCount += count
            })
        }
    }
    
    /// Checks that recorder can fulfill an expectation.
    ///
    /// The reason this method exists is that a recorder can fulfill a single
    /// expectation at a given time. It is a programmer error to wait for two
    /// expectations concurrently.
    ///
    /// This method MUST be called within a synchronized block.
    private func preconditionCanFulfillExpectation() {
        if let exp = state.recorderExpectation {
            // We are already waiting for an expectation! Is it a programmer
            // error? Recorder drops references to non-inverted expectations
            // when they are fulfilled. But inverted expectations are not
            // fulfilled, and thus not dropped. We can't quite know if an
            // inverted expectations has expired yet, so just let it go.
            precondition(exp.expectation.isInverted, "Already waiting for an expectation")
        }
    }
    
    fileprivate func receive(_ cancellable: DatabaseCancellable) {
        synchronized {
            if state.cancellable != nil {
                XCTFail("ValueObservationRecorder is already observing")
            }
            state.cancellable = AnyDatabaseCancellable(cancellable)
        }
    }
}

// MARK: - ValueObservationRecorder + Expectations

extension ValueObservationRecorder {
    public func failure() -> ValueObservationExpectations.Failure<Value> {
        ValueObservationExpectations.Failure(recorder: self)
    }
    
    public func next() -> ValueObservationExpectations.NextOne<Value> {
        ValueObservationExpectations.NextOne(recorder: self)
    }
    
    public func next(_ count: Int) -> ValueObservationExpectations.Next<Value> {
        ValueObservationExpectations.Next(recorder: self, count: count)
    }
    
    public func prefix(_ maxLength: Int) -> ValueObservationExpectations.Prefix<Value> {
        ValueObservationExpectations.Prefix(
            recorder: self,
            expectedFulfillmentCount: maxLength,
            isIncluded: { _ in true })
    }
    
    public func prefix(until predicate: @escaping (Value) -> Bool) -> ValueObservationExpectations.Prefix<Value> {
        ValueObservationExpectations.Prefix(
            recorder: self,
            expectedFulfillmentCount: 1,
            isIncluded: predicate)
    }
}

// MARK: - ValueObservation + ValueObservationRecorder

extension ValueObservation {
    public func record(
        in reader: DatabaseReader,
        scheduling scheduler: ValueObservationScheduler = .async(onQueue: .main),
        onError: ((Error) -> Void)? = nil,
        onChange: ((Reducer.Value) -> Void)? = nil)
        -> ValueObservationRecorder<Reducer.Value>
    {
        let recorder = ValueObservationRecorder<Reducer.Value>()
        let cancellable = start(
            in: reader,
            scheduling: scheduler,
            onError: {
                onError?($0)
                recorder.onError($0)
        },
            onChange: {
                onChange?($0)
                recorder.onChange($0)
        })
        recorder.receive(cancellable)
        return recorder
    }
}

// MARK: - ValueObservationExpectation

public enum ValueRecordingError: Error {
    case notEnoughValues
    case notFailed
}

extension ValueRecordingError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .notEnoughValues:
            return "ValueRecordingError.notEnoughValues"
        case .notFailed:
            return "ValueRecordingError.notFailed"
        }
    }
}

public protocol _ValueObservationExpectationBase {
    func _setup(_ expectation: XCTestExpectation)
}

public protocol ValueObservationExpectation: _ValueObservationExpectationBase {
    associatedtype Output
    func get() throws -> Output
}

// MARK: - XCTestCase + ValueObservationExpectation

extension XCTestCase {
    public func wait<E: ValueObservationExpectation>(
        for valueObservationExpectation: E,
        timeout: TimeInterval,
        description: String = "")
        throws -> E.Output
    {
        let expectation = self.expectation(description: description)
        valueObservationExpectation._setup(expectation)
        wait(for: [expectation], timeout: timeout)
        return try valueObservationExpectation.get()
    }
    
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
    public func assertValueObservationRecordingMatch<Value>(
        recorded recordedValues: [Value],
        expected expectedValues: [Value],
        _ message: @autoclosure () -> String = "",
        file: StaticString = #filePath,
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
        file: StaticString,
        line: UInt)
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
                XCTFail("missing expected value \(value) - \(message()) in \(recordedValues)", file: file, line: line)
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

// MARK: - GRDBTestCase + ValueObservationExpectation

extension GRDBTestCase {
    func _assertValueObservation<Reducer: ValueReducer>(
        _ observation: ValueObservation<Reducer>,
        records expectedValues: [Reducer.Value],
        setup: (Database) throws -> Void,
        recordedUpdates: @escaping (Database) throws -> Void,
        file: StaticString,
        line: UInt)
        throws
        where Reducer.Value: Equatable
    {
        #if SQLITE_HAS_CODEC || GRDBCUSTOMSQLITE
        // debug SQLite builds can be *very* slow
        let timeout: TimeInterval = 4
        #else
        let timeout: TimeInterval = 1
        #endif
        
        func test(
            observation: ValueObservation<Reducer>,
            scheduling scheduler: ValueObservationScheduler,
            testValueDispatching: @escaping () -> Void) throws
        {
            func testRecordingEqualWhenWriteAfterStart(writer: DatabaseWriter) throws {
                try writer.write(setup)
                
                var value: Reducer.Value?
                let recorder = observation.record(
                    in: writer,
                    scheduling: scheduler,
                    onChange: {
                        testValueDispatching()
                        value = $0
                })
                
                // Test that initial value is set when scheduler is immediate
                if scheduler.immediateInitialValue() {
                    XCTAssertNotNil(value)
                }
                
                // Perform writes after start
                try writer.writeWithoutTransaction(recordedUpdates)
                
                let expectation = recorder.next(expectedValues.count)
                let values = try wait(for: expectation, timeout: timeout)
                XCTAssertEqual(
                    values, expectedValues,
                    "\(#function), \(writer), \(scheduler)", file: file, line: line)
            }
            
            func testRecordingEqualWhenWriteAfterFirstValue(writer: DatabaseWriter) throws {
                try writer.write(setup)
                
                var valueCount = 0
                var value: Reducer.Value?
                let recorder = observation.record(
                    in: writer,
                    scheduling: scheduler,
                    onChange: { [unowned writer] in
                        testValueDispatching()
                        valueCount += 1
                        if valueCount == 1 {
                            // Perform writes after initial value
                            try! writer.writeWithoutTransaction(recordedUpdates)
                        }
                        value = $0
                })
                
                // Test that initial value is set when scheduler is immediate
                if scheduler.immediateInitialValue() {
                    XCTAssertNotNil(value)
                }
                
                let expectation = recorder.next(expectedValues.count)
                let values = try wait(for: expectation, timeout: timeout)
                XCTAssertEqual(
                    values, expectedValues,
                    "\(#function), \(writer), \(scheduler)", file: file, line: line)
            }
            
            func testRecordingMatchWhenWriteAfterStart(writer: DatabaseWriter) throws {
                try writer.write(setup)
                
                var value: Reducer.Value?
                let recorder = observation.record(
                    in: writer,
                    scheduling: scheduler,
                    onChange: {
                        testValueDispatching()
                        value = $0
                })
                
                // Test that initial value is set when scheduler is immediate
                if scheduler.immediateInitialValue() {
                    XCTAssertNotNil(value)
                }
                
                try writer.writeWithoutTransaction(recordedUpdates)
                
                let recordedValues: [Reducer.Value]
                let lastExpectedValue = expectedValues.last!
                let waitForLast = expectedValues.firstIndex(of: lastExpectedValue) == expectedValues.count - 1
                if waitForLast {
                    // Optimization!
                    let expectation = recorder.prefix(until: { $0 == lastExpectedValue } )
                    recordedValues = try wait(for: expectation, timeout: timeout)
                } else {
                    // Slow!
                    assertionFailure("Please rewrite your test, because it is too slow: make sure the last expected value is unique.")
                    let expectation = recorder
                        .prefix(expectedValues.count + 2 /* pool may perform double initial fetch */)
                        .inverted
                    recordedValues = try wait(for: expectation, timeout: timeout)
                }
                
                if scheduler.immediateInitialValue() {
                    XCTAssertEqual(recordedValues.first, expectedValues.first)
                }
                
                assertValueObservationRecordingMatch(
                    recorded: recordedValues,
                    expected: expectedValues,
                    "\(#function), \(writer), \(scheduler)", file: file, line: line)
            }
            
            func testRecordingMatchWhenWriteAfterFirstValue(writer: DatabaseWriter) throws {
                try writer.write(setup)
                
                var valueCount = 0
                var value: Reducer.Value?
                let recorder = observation.record(
                    in: writer,
                    scheduling: scheduler,
                    onChange: { [unowned writer] in
                        testValueDispatching()
                        valueCount += 1
                        if valueCount == 1 {
                            // Perform writes after initial value
                            try! writer.writeWithoutTransaction(recordedUpdates)
                        }
                        value = $0
                })
                
                // Test that initial value is set when scheduler is immediate
                if scheduler.immediateInitialValue() {
                    XCTAssertNotNil(value)
                }
                
                let recordedValues: [Reducer.Value]
                let lastExpectedValue = expectedValues.last!
                let waitForLast = expectedValues.firstIndex(of: lastExpectedValue) == expectedValues.count - 1
                if waitForLast {
                    // Optimization!
                    let expectation = recorder.prefix(until: { $0 == lastExpectedValue } )
                    recordedValues = try wait(for: expectation, timeout: timeout)
                } else {
                    // Slow!
                    assertionFailure("Please rewrite your test, because it is too slow: make sure the last expected value is unique.")
                    let expectation = recorder
                        .prefix(expectedValues.count + 2 /* pool may perform double initial fetch */)
                        .inverted
                    recordedValues = try wait(for: expectation, timeout: timeout)
                }
                
                XCTAssertEqual(recordedValues.first, expectedValues.first)
                
                assertValueObservationRecordingMatch(
                    recorded: recordedValues,
                    expected: expectedValues,
                    "\(#function), \(writer), \(scheduler)", file: file, line: line)
            }
            
            try testRecordingEqualWhenWriteAfterStart(writer: DatabaseQueue())
            try testRecordingEqualWhenWriteAfterFirstValue(writer: DatabaseQueue())
            
            try testRecordingEqualWhenWriteAfterStart(writer: makeDatabaseQueue())
            try testRecordingEqualWhenWriteAfterFirstValue(writer: makeDatabaseQueue())
            
            if observation.requiresWriteAccess {
                try testRecordingEqualWhenWriteAfterStart(writer: makeDatabasePool())
                try testRecordingEqualWhenWriteAfterFirstValue(writer: makeDatabasePool())
            } else {
                // DatabasePool may miss some changes
                try testRecordingMatchWhenWriteAfterStart(writer: makeDatabasePool())
                try testRecordingMatchWhenWriteAfterFirstValue(writer: makeDatabasePool())
            }
        }
        
        do {
            let key = DispatchSpecificKey<()>()
            DispatchQueue.main.setSpecific(key: key, value: ())
            
            try test(
                observation: observation,
                scheduling: .immediate,
                testValueDispatching: { XCTAssertNotNil(DispatchQueue.getSpecific(key: key)) })
        }
        
        do {
            let key = DispatchSpecificKey<()>()
            DispatchQueue.main.setSpecific(key: key, value: ())
            
            try test(
                observation: observation,
                scheduling: .async(onQueue: .main),
                testValueDispatching: { XCTAssertNotNil(DispatchQueue.getSpecific(key: key)) })
        }
        
        do {
            let queue = DispatchQueue(label: "custom")
            let key = DispatchSpecificKey<()>()
            queue.setSpecific(key: key, value: ())
            
            try test(
                observation: observation,
                scheduling: .async(onQueue: queue),
                testValueDispatching: { XCTAssertNotNil(DispatchQueue.getSpecific(key: key)) })
        }
    }
    
    func _assertValueObservation<Reducer: ValueReducer, Failure: Error>(
        _ observation: ValueObservation<Reducer>,
        fails testFailure: (Failure, DatabaseWriter) throws -> Void,
        setup: (Database) throws -> Void,
        file: StaticString,
        line: UInt)
        throws
    {
        #if SQLITE_HAS_CODEC || GRDBCUSTOMSQLITE
        // debug SQLite builds can be *very* slow
        let timeout: TimeInterval = 2
        #else
        let timeout: TimeInterval = 1
        #endif
        
        func test(
            observation: ValueObservation<Reducer>,
            scheduling scheduler: ValueObservationScheduler,
            testErrorDispatching: @escaping () -> Void) throws
        {
            func test(writer: DatabaseWriter) throws {
                try writer.write(setup)
                
                let recorder = observation.record(
                    in: writer,
                    scheduling: scheduler,
                    onError: { _ in testErrorDispatching() })
                
                let (_, error) = try wait(for: recorder.failure(), timeout: timeout)
                if let error = error as? Failure {
                    try testFailure(error, writer)
                } else {
                    throw error
                }
            }
            
            try test(writer: DatabaseQueue())
            try test(writer: makeDatabaseQueue())
            try test(writer: makeDatabasePool())
        }
        
        do {
            let key = DispatchSpecificKey<()>()
            DispatchQueue.main.setSpecific(key: key, value: ())
            
            try test(
                observation: observation,
                scheduling: .immediate,
                testErrorDispatching: { XCTAssertNotNil(DispatchQueue.getSpecific(key: key)) })
        }
        
        do {
            let key = DispatchSpecificKey<()>()
            DispatchQueue.main.setSpecific(key: key, value: ())
            
            try test(
                observation: observation,
                scheduling: .async(onQueue: .main),
                testErrorDispatching: { XCTAssertNotNil(DispatchQueue.getSpecific(key: key)) })
        }
        
        do {
            let queue = DispatchQueue(label: "custom")
            let key = DispatchSpecificKey<()>()
            queue.setSpecific(key: key, value: ())
            
            try test(
                observation: observation,
                scheduling: .async(onQueue: queue),
                testErrorDispatching: { XCTAssertNotNil(DispatchQueue.getSpecific(key: key)) })
        }
    }
    
    func assertValueObservation<Reducer: _ValueReducer>(
        _ observation: ValueObservation<Reducer>,
        records expectedValues: [Reducer.Value],
        setup: (Database) throws -> Void,
        recordedUpdates: @escaping (Database) throws -> Void,
        file: StaticString = #filePath,
        line: UInt = #line)
        throws
        where Reducer.Value: Equatable
    {
        try _assertValueObservation(
            observation,
            records: expectedValues,
            setup: setup,
            recordedUpdates: recordedUpdates,
            file: file, line: line)
    }
    
    func assertValueObservation<Reducer: _ValueReducer, Failure: Error>(
        _ observation: ValueObservation<Reducer>,
        fails testFailure: (Failure, DatabaseWriter) throws -> Void,
        setup: (Database) throws -> Void,
        file: StaticString = #filePath,
        line: UInt = #line)
        throws
    {
        try _assertValueObservation(observation, fails: testFailure, setup: setup, file: file, line: line)
    }
}

// MARK: - ValueObservationExpectations

public enum ValueObservationExpectations { }

extension ValueObservationExpectations {
    
    // MARK: Inverted
    
    public struct Inverted<Base: ValueObservationExpectation>: ValueObservationExpectation {
        let base: Base
        
        public func _setup(_ expectation: XCTestExpectation) {
            base._setup(expectation)
            expectation.isInverted.toggle()
        }
        
        public func get() throws -> Base.Output {
            try base.get()
        }
    }
    
    // MARK: NextOne
    
    public struct NextOne<Value>: ValueObservationExpectation {
        let recorder: ValueObservationRecorder<Value>
        
        public func _setup(_ expectation: XCTestExpectation) {
            recorder.fulfillOnValue(expectation, includingConsumed: false, isIncluded: { _ in true })
        }
        
        public func get() throws -> Value {
            try recorder.value { (_, error, remainingValues, consume) in
                if let next = remainingValues.first {
                    consume(1)
                    return next
                }
                if let error = error {
                    throw error
                } else {
                    throw ValueRecordingError.notEnoughValues
                }
            }
        }
        
        public var inverted: NextOneInverted<Value> {
            return NextOneInverted(recorder: recorder)
        }
    }
    
    // MARK: NextOneInverted
    
    public struct NextOneInverted<Value>: ValueObservationExpectation {
        let recorder: ValueObservationRecorder<Value>
        
        public func _setup(_ expectation: XCTestExpectation) {
            expectation.isInverted = true
            recorder.fulfillOnValue(expectation, includingConsumed: false, isIncluded: { _ in true })
        }
        
        public func get() throws {
            try recorder.value { (_, error, remainingValues, consume) in
                if remainingValues.isEmpty == false {
                    return
                }
                if let error = error {
                    throw error
                }
            }
        }
    }
    
    // MARK: Next
    
    public struct Next<Value>: ValueObservationExpectation {
        let recorder: ValueObservationRecorder<Value>
        let count: Int
        
        init(recorder: ValueObservationRecorder<Value>, count: Int) {
            precondition(count >= 0, "Invalid negative count")
            self.recorder = recorder
            self.count = count
        }
        
        public func _setup(_ expectation: XCTestExpectation) {
            if count == 0 {
                // Such an expectation is immediately fulfilled, by essence.
                expectation.expectedFulfillmentCount = 1
                expectation.fulfill()
            } else {
                expectation.expectedFulfillmentCount = count
                recorder.fulfillOnValue(expectation, includingConsumed: false, isIncluded: { _ in true })
            }
        }
        
        public func get() throws -> [Value] {
            try recorder.value { (_, error, remainingValues, consume) in
                if remainingValues.count >= count {
                    consume(count)
                    return Array(remainingValues.prefix(count))
                }
                if let error = error {
                    throw error
                } else {
                    throw ValueRecordingError.notEnoughValues
                }
            }
        }
    }
    
    // MARK: Prefix
    
    public struct Prefix<Value>: ValueObservationExpectation {
        let recorder: ValueObservationRecorder<Value>
        let expectedFulfillmentCount: Int
        let isIncluded: (Value) -> Bool
        
        init(recorder: ValueObservationRecorder<Value>, expectedFulfillmentCount: Int, isIncluded: @escaping (Value) -> Bool) {
            precondition(expectedFulfillmentCount >= 0, "Invalid negative count")
            self.recorder = recorder
            self.expectedFulfillmentCount = expectedFulfillmentCount
            self.isIncluded = isIncluded
        }
        
        public func _setup(_ expectation: XCTestExpectation) {
            if expectedFulfillmentCount == 0 {
                // Such an expectation is immediately fulfilled, by essence.
                expectation.expectedFulfillmentCount = 1
                expectation.fulfill()
            } else {
                expectation.expectedFulfillmentCount = expectedFulfillmentCount
                recorder.fulfillOnValue(expectation, includingConsumed: true, isIncluded: isIncluded)
            }
        }
        
        public func get() throws -> [Value] {
            if expectedFulfillmentCount == 0 {
                return []
            }
            
            return try recorder.value { (values, error, remainingValues, consume) in
                let includedValues = values.filter(isIncluded)
                if includedValues.count >= expectedFulfillmentCount {
                    let matchedCount = values
                        .indices
                        .filter { isIncluded(values[$0]) }
                        .prefix(expectedFulfillmentCount)
                        .last! + 1
                    let extraCount = max(matchedCount + remainingValues.count - values.count, 0)
                    consume(extraCount)
                    return Array(values.prefix(matchedCount))
                }
                if let error = error {
                    throw error
                }
                consume(remainingValues.count)
                return values
            }
        }
        
        public var inverted: Inverted<Self> {
            return Inverted(base: self)
        }
    }
    
    // MARK: Failure
    
    public struct Failure<Value>: ValueObservationExpectation {
        let recorder: ValueObservationRecorder<Value>
        
        public func _setup(_ expectation: XCTestExpectation) {
            recorder.fulfillOnError(expectation)
        }
        
        public func get() throws -> (values: [Value], error: Error) {
            try recorder.value { (values, error, remainingValues, consume) in
                if let error = error {
                    consume(remainingValues.count)
                    return (values: values, error: error)
                } else {
                    throw ValueRecordingError.notFailed
                }
            }
        }
    }
}

// MARK: - Convenience

extension XCTestExpectation {
    fileprivate func fulfill(count: Int) {
        for _ in 0..<count {
            fulfill()
        }
    }
}
