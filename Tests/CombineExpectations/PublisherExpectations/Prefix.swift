#if canImport(Combine)
import XCTest

@available(OSX 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension PublisherExpectations {
    /// A publisher expectation which waits for the recorded publisher to emit
    /// `maxLength` elements, or to complete.
    ///
    /// When waiting for this expectation, the publisher error is thrown if the
    /// publisher fails before `maxLength` elements are published.
    ///
    /// Otherwise, an array of received elements is returned, containing at
    /// most `maxLength` elements, or less if the publisher completes early.
    ///
    /// For example:
    ///
    ///     // SUCCESS: no timeout, no error
    ///     func testArrayOfThreeElementsPublishesTwoFirstElementsWithoutError() throws {
    ///         let publisher = ["foo", "bar", "baz"].publisher
    ///         let recorder = publisher.record()
    ///         let elements = try wait(for: recorder.prefix(2), timeout: 1)
    ///         XCTAssertEqual(elements, ["foo", "bar"])
    ///     }
    ///
    /// This publisher expectation can be inverted:
    ///
    ///     // SUCCESS: no timeout, no error
    ///     func testPassthroughSubjectPublishesNoMoreThanSentValues() throws {
    ///         let publisher = PassthroughSubject<String, Never>()
    ///         let recorder = publisher.record()
    ///         publisher.send("foo")
    ///         publisher.send("bar")
    ///         let elements = try wait(for: recorder.prefix(3).inverted, timeout: 1)
    ///         XCTAssertEqual(elements, ["foo", "bar"])
    ///     }
    public struct Prefix<Input, Failure: Error>: PublisherExpectation {
        let recorder: Recorder<Input, Failure>
        let maxLength: Int
        
        init(recorder: Recorder<Input, Failure>, maxLength: Int) {
            precondition(maxLength >= 0, "Can't take a prefix of negative length")
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
                recorder.fulfillOnInput(expectation, includingConsumed: true)
            }
        }
        
        /// Returns the expected output, or throws an error if the
        /// expectation fails.
        ///
        /// For example:
        ///
        ///     // SUCCESS: no error
        ///     func testArrayOfThreeElementsSynchronouslyPublishesTwoFirstElementsWithoutError() throws {
        ///         let publisher = ["foo", "bar", "baz"].publisher
        ///         let recorder = publisher.record()
        ///         let elements = try recorder.prefix(2).get()
        ///         XCTAssertEqual(elements, ["foo", "bar"])
        ///     }
        public func get() throws -> [Input] {
            try recorder.value { (elements, completion, remainingElements, consume) in
                if elements.count >= maxLength {
                    let extraCount = max(maxLength + remainingElements.count - elements.count, 0)
                    consume(extraCount)
                    return Array(elements.prefix(maxLength))
                }
                if case let .failure(error) = completion {
                    throw error
                }
                consume(remainingElements.count)
                return elements
            }
        }
        
        /// Returns an inverted publisher expectation which waits for a
        /// publisher to emit `maxLength` elements, or to complete.
        ///
        /// When waiting for this expectation, the publisher error is thrown
        /// if the publisher fails before `maxLength` elements are published.
        ///
        /// Otherwise, an array of received elements is returned, containing at
        /// most `maxLength` elements, or less if the publisher completes early.
        ///
        /// For example:
        ///
        ///     // SUCCESS: no timeout, no error
        ///     func testPassthroughSubjectPublishesNoMoreThanSentValues() throws {
        ///         let publisher = PassthroughSubject<String, Never>()
        ///         let recorder = publisher.record()
        ///         publisher.send("foo")
        ///         publisher.send("bar")
        ///         let elements = try wait(for: recorder.prefix(3).inverted, timeout: 1)
        ///         XCTAssertEqual(elements, ["foo", "bar"])
        ///     }
        public var inverted: Inverted<Self> {
            return Inverted(base: self)
        }
    }
}
#endif

