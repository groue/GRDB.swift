#if canImport(Combine)
import XCTest

@available(OSX 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension PublisherExpectations {
    /// A publisher expectation which waits for the recorded publisher to emit
    /// one element, or to complete.
    ///
    /// When waiting for this expectation, a `RecordingError.notEnoughElements`
    /// is thrown if the publisher does not publish one element after last
    /// waited expectation. The publisher error is thrown if the publisher fails
    /// before publishing the next element.
    ///
    /// Otherwise, the next published element is returned.
    ///
    /// For example:
    ///
    ///     // SUCCESS: no timeout, no error
    ///     func testArrayOfTwoElementsPublishesElementsInOrder() throws {
    ///         let publisher = ["foo", "bar"].publisher
    ///         let recorder = publisher.record()
    ///
    ///         var element = try wait(for: recorder.next(), timeout: 1)
    ///         XCTAssertEqual(element, "foo")
    ///
    ///         element = try wait(for: recorder.next(), timeout: 1)
    ///         XCTAssertEqual(element, "bar")
    ///     }
    public struct NextOne<Input, Failure: Error>: PublisherExpectation {
        let recorder: Recorder<Input, Failure>
        
        public func _setup(_ expectation: XCTestExpectation) {
            recorder.fulfillOnInput(expectation, includingConsumed: false)
        }
        
        /// Returns the expected output, or throws an error if the
        /// expectation fails.
        ///
        /// For example:
        ///
        ///     // SUCCESS: no error
        ///     func testArrayOfTwoElementsSynchronouslyPublishesElementsInOrder() throws {
        ///         let publisher = ["foo", "bar"].publisher
        ///         let recorder = publisher.record()
        ///
        ///         var element = try recorder.next().get()
        ///         XCTAssertEqual(element, "foo")
        ///
        ///         element = try recorder.next().get()
        ///         XCTAssertEqual(element, "bar")
        ///     }
        public func get() throws -> Input {
            try recorder.value { (_, completion, remainingElements, consume) in
                if let next = remainingElements.first {
                    consume(1)
                    return next
                }
                if case let .failure(error) = completion {
                    throw error
                } else {
                    throw RecordingError.notEnoughElements
                }
            }
        }
        
        /// Returns an inverted publisher expectation which waits for the
        /// recorded publisher to emit one element, or to complete.
        ///
        /// When waiting for this expectation, a RecordingError is thrown if the
        /// publisher does not publish one element after last waited
        /// expectation. The publisher error is thrown if the publisher fails
        /// before publishing one element.
        ///
        /// For example:
        ///
        ///     // SUCCESS: no timeout, no error
        ///     func testPassthroughSubjectDoesNotPublishAnyElement() throws {
        ///         let publisher = PassthroughSubject<String, Never>()
        ///         let recorder = publisher.record()
        ///         try wait(for: recorder.next().inverted, timeout: 1)
        ///     }
        public var inverted: NextOneInverted<Input, Failure> {
            return NextOneInverted(recorder: recorder)
        }
    }
    
    /// An inverted publisher expectation which waits for the recorded publisher
    /// to emit one element, or to complete.
    ///
    /// When waiting for this expectation, a RecordingError is thrown if the
    /// publisher does not publish one element after last waited expectation.
    /// The publisher error is thrown if the publisher fails before
    /// publishing one element.
    ///
    /// For example:
    ///
    ///     // SUCCESS: no timeout, no error
    ///     func testPassthroughSubjectDoesNotPublishAnyElement() throws {
    ///         let publisher = PassthroughSubject<String, Never>()
    ///         let recorder = publisher.record()
    ///         try wait(for: recorder.next().inverted, timeout: 1)
    ///     }
    public struct NextOneInverted<Input, Failure: Error>: PublisherExpectation {
        let recorder: Recorder<Input, Failure>
        
        public func _setup(_ expectation: XCTestExpectation) {
            expectation.isInverted = true
            recorder.fulfillOnInput(expectation, includingConsumed: false)
        }
        
        public func get() throws {
            try recorder.value { (_, completion, remainingElements, consume) in
                if remainingElements.isEmpty == false {
                    return
                }
                if case let .failure(error) = completion {
                    throw error
                }
            }
        }
    }
}
#endif
