#if canImport(Combine)
import XCTest

// The Finished expectation waits for the publisher to complete, and throws an
// error if and only if the publisher fails with an error.
//
// It is not derived from the Recording expectation, because Finished does not
// throw RecordingError.notCompleted if the publisher does not complete on time.
// It only triggers a timeout test failure.
//
// This allows to write tests for publishers that should not complete:
//
//      // SUCCESS: no timeout, no error
//      func testPassthroughSubjectDoesNotFinish() throws {
//          let publisher = PassthroughSubject<String, Never>()
//          let recorder = publisher.record()
//          try wait(for: recorder.finished.inverted, timeout: 1)
//      }

extension PublisherExpectations {
    /// A publisher expectation which waits for the recorded publisher
    /// to complete.
    ///
    /// When waiting for this expectation, the publisher error is thrown if the
    /// publisher fails.
    ///
    /// For example:
    ///
    ///     // SUCCESS: no timeout, no error
    ///     func testArrayPublisherFinishesWithoutError() throws {
    ///         let publisher = ["foo", "bar", "baz"].publisher
    ///         let recorder = publisher.record()
    ///         try wait(for: recorder.finished, timeout: 1)
    ///     }
    ///
    /// This publisher expectation can be inverted:
    ///
    ///     // SUCCESS: no timeout, no error
    ///     func testPassthroughSubjectDoesNotFinish() throws {
    ///         let publisher = PassthroughSubject<String, Never>()
    ///         let recorder = publisher.record()
    ///         try wait(for: recorder.finished.inverted, timeout: 1)
    ///     }
    public struct Finished<Input, Failure: Error>: PublisherExpectation {
        let recorder: Recorder<Input, Failure>
        
        public func _setup(_ expectation: XCTestExpectation) {
            recorder.fulfillOnCompletion(expectation)
        }
        
        /// Returns the expected output, or throws an error if the
        /// expectation fails.
        ///
        /// For example:
        ///
        ///     // SUCCESS: no error
        ///     func testArrayPublisherSynchronouslyFinishesWithoutError() throws {
        ///         let publisher = ["foo", "bar", "baz"].publisher
        ///         let recorder = publisher.record()
        ///         try recorder.finished.get()
        ///     }
        public func get() throws {
            try recorder.value { (_, completion, remainingElements, consume) in
                guard let completion else {
                    consume(remainingElements.count)
                    return
                }
                if case let .failure(error) = completion {
                    throw error
                }
            }
        }
        
        /// Returns an inverted publisher expectation which waits for a
        /// publisher to complete successfully.
        ///
        /// When waiting for this expectation, an error is thrown if the
        /// publisher fails with an error.
        ///
        /// For example:
        ///
        ///     // SUCCESS: no timeout, no error
        ///     func testPassthroughSubjectDoesNotFinish() throws {
        ///         let publisher = PassthroughSubject<String, Never>()
        ///         let recorder = publisher.record()
        ///         try wait(for: recorder.finished.inverted, timeout: 1)
        ///     }
        public var inverted: Inverted<Self> {
            return Inverted(base: self)
        }
    }
}
#endif
