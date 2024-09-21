#if canImport(Combine)
import XCTest

extension PublisherExpectations {
    /// A publisher expectation which waits for the timeout to expire, or
    /// the recorded publisher to complete.
    ///
    /// When waiting for this expectation, the publisher error is thrown if
    /// the publisher fails before the expectation has expired.
    ///
    /// Otherwise, an array of all elements published before the expectation
    /// has expired is returned.
    ///
    /// Unlike other expectations, `AvailableElements` does not make a test fail
    /// on timeout expiration. It just returns the elements published so far.
    ///
    /// For example:
    ///
    ///     // SUCCESS: no timeout, no error
    ///     func testTimerPublishesIncreasingDates() throws {
    ///         let publisher = Timer.publish(every: 0.01, on: .main, in: .common).autoconnect()
    ///         let recorder = publisher.record()
    ///         let dates = try wait(for: recorder.availableElements, timeout: ...)
    ///         XCTAssertEqual(dates.sorted(), dates)
    ///     }
    public struct AvailableElements<Input, Failure: Error>: PublisherExpectation {
        let recorder: Recorder<Input, Failure>
        
        public func _makeWaiter() -> XCTWaiter? { Waiter() }
        
        public func _setup(_ expectation: XCTestExpectation) {
            recorder.fulfillOnCompletion(expectation)
        }
        
        /// Returns all elements published so far, or throws an error if the
        /// publisher has failed.
        public func get() throws -> [Input] {
            try recorder.value { (elements, completion, remainingElements, consume) in
                if case let .failure(error) = completion {
                    throw error
                }
                consume(remainingElements.count)
                return elements
            }
        }
        
        /// A waiter that waits but never fails
        private class Waiter: XCTWaiter, XCTWaiterDelegate, @unchecked Sendable {
            init() {
                super.init(delegate: nil)
                delegate = self
            }
            
            func waiter(_ waiter: XCTWaiter, didTimeoutWithUnfulfilledExpectations unfulfilledExpectations: [XCTestExpectation]) { }
            func waiter(_ waiter: XCTWaiter, fulfillmentDidViolateOrderingConstraintsFor expectation: XCTestExpectation, requiredExpectation: XCTestExpectation) { }
            func waiter(_ waiter: XCTWaiter, didFulfillInvertedExpectation expectation: XCTestExpectation) { }
            func nestedWaiter(_ waiter: XCTWaiter, wasInterruptedByTimedOutWaiter outerWaiter: XCTWaiter) { }
        }
    }
}
#endif
