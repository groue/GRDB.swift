#if canImport(Combine)
import Combine
import XCTest

@available(OSX 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension PublisherExpectations {
    /// A publisher expectation which waits for the recorded publisher
    /// to complete.
    ///
    /// When waiting for this expectation, a RecordingError.notCompleted is
    /// thrown if the publisher does not complete on time.
    ///
    /// Otherwise, a [Record.Recording](https://developer.apple.com/documentation/combine/record/recording)
    /// is returned.
    ///
    /// For example:
    ///
    ///     // SUCCESS: no timeout, no error
    ///     func testArrayPublisherRecording() throws {
    ///         let publisher = ["foo", "bar", "baz"].publisher
    ///         let recorder = publisher.record()
    ///         let recording = try wait(for: recorder.recording, timeout: 1)
    ///         XCTAssertEqual(recording.output, ["foo", "bar", "baz"])
    ///         if case let .failure(error) = recording.completion {
    ///             XCTFail("Unexpected error \(error)")
    ///         }
    ///     }
    public struct Recording<Input, Failure: Error>: PublisherExpectation {
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
        ///     func testArrayPublisherSynchronousRecording() throws {
        ///         let publisher = ["foo", "bar", "baz"].publisher
        ///         let recorder = publisher.record()
        ///         let recording = try recorder.recording.get()
        ///         XCTAssertEqual(recording.output, ["foo", "bar", "baz"])
        ///         if case let .failure(error) = recording.completion {
        ///             XCTFail("Unexpected error \(error)")
        ///         }
        ///     }
        public func get() throws -> Record<Input, Failure>.Recording {
            try recorder.value { (elements, completion, remainingElements, consume) in
                if let completion = completion {
                    consume(remainingElements.count)
                    return Record<Input, Failure>.Recording(output: elements, completion: completion)
                } else {
                    throw RecordingError.notCompleted
                }
            }
        }
    }
}
#endif
