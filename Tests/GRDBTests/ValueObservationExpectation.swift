// Inspired by https://github.com/groue/CombineExpectations
import Foundation
import XCTest
#if GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

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
}

public enum ValueObservationExpectations { }

extension ValueObservationExpectations {
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
    
    public struct NextOne<Value>: ValueObservationExpectation {
        let recorder: ValueObservationRecorder<Value>
        
        public func _setup(_ expectation: XCTestExpectation) {
            recorder.fulfillOnValue(expectation, includingConsumed: false)
        }
        
        public func get() throws -> Value {
            try recorder.value { (_, error, remainingElements, consume) in
                if let next = remainingElements.first {
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
    
    public struct NextOneInverted<Value>: ValueObservationExpectation {
        let recorder: ValueObservationRecorder<Value>

        public func _setup(_ expectation: XCTestExpectation) {
            expectation.isInverted = true
            recorder.fulfillOnValue(expectation, includingConsumed: false)
        }
        
        public func get() throws {
            try recorder.value { (_, error, remainingElements, consume) in
                if remainingElements.isEmpty == false {
                    return
                }
                if let error = error {
                    throw error
                }
            }
        }
    }
    
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
                recorder.fulfillOnValue(expectation, includingConsumed: false)
            }
        }
        
        public func get() throws -> [Value] {
            try recorder.value { (_, error, remainingElements, consume) in
                if remainingElements.count >= count {
                    consume(count)
                    return Array(remainingElements.prefix(count))
                }
                if let error = error {
                    throw error
                } else {
                    throw ValueRecordingError.notEnoughValues
                }
            }
        }
    }
    
    public struct Prefix<Value>: ValueObservationExpectation {
        let recorder: ValueObservationRecorder<Value>
        let maxLength: Int
        
        init(recorder: ValueObservationRecorder<Value>, maxLength: Int) {
            precondition(maxLength >= 0, "Invalid negative count")
            self.recorder = recorder
            self.maxLength = maxLength
        }
        
        public func _setup(_ expectation: XCTestExpectation) {
            if maxLength == 0 {
                // Such an expectation is immediately fulfilled, by essence.
                expectation.expectedFulfillmentCount = 1
                expectation.fulfill()
            } else {
                expectation.expectedFulfillmentCount = maxLength
                recorder.fulfillOnValue(expectation, includingConsumed: true)
            }
        }
        
        public func get() throws -> [Value] {
            try recorder.value { (elements, error, remainingElements, consume) in
                if elements.count >= maxLength {
                    let extraCount = max(maxLength + remainingElements.count - elements.count, 0)
                    consume(extraCount)
                    return Array(elements.prefix(maxLength))
                }
                if let error = error {
                    throw error
                }
                consume(remainingElements.count)
                return elements
            }
        }
        
        public var inverted: Inverted<Self> {
            return Inverted(base: self)
        }
    }
    
    public struct Failure<Value>: ValueObservationExpectation {
        let recorder: ValueObservationRecorder<Value>
        
        public func _setup(_ expectation: XCTestExpectation) {
            recorder.fulfillOnError(expectation)
        }
        
        /// Returns the expected output, or throws an error if the
        /// expectation fails.
        ///
        /// For example:
        ///
        ///     // SUCCESS: no error
        ///     func testArrayPublisherSynchronousRecording() throws {
        ///         let publisher = ["foo", "bar", "baz"].publisher
        ///         let recorder = publisher.record()
        ///         let recording = try recorder.recording.get()
        ///         XCTAssertEqual(recording.output, ["foo", "bar", "baz"])
        ///         if case let .failure(error) = recording.completion {
        ///             XCTFail("Unexpected error \(error)")
        ///         }
        ///     }
        public func get() throws -> (values: [Value], error: Error) {
            try recorder.value { (elements, error, remainingElements, consume) in
                if let error = error {
                    consume(remainingElements.count)
                    return (values: elements, error: error)
                } else {
                    throw ValueRecordingError.notFailed
                }
            }
        }
    }
}
