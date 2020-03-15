// Inspired by https://github.com/groue/CombineExpectations
import XCTest
#if GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

public class ValueObservationRecorder<Element> {
    private struct RecorderExpectation {
        var expectation: XCTestExpectation
        var remainingCount: Int? // nil for error expectation
    }
    
    /// The recorder state
    private struct State {
        var elements: [Element]
        var error: Error?
        var recorderExpectation: RecorderExpectation?
        var observer: TransactionObserver?
    }
    
    private let lock = NSLock()
    private var state = State(elements: [], recorderExpectation: nil, observer: nil)
    private var consumedCount = 0
    
    /// The elements recorded so far.
    var elementsAndError: ([Element], Error?) {
        synchronized {
            (state.elements, state.error)
        }
    }
    
    /// Internal for testability. Use ValueObservation.record(in:) instead.
    init() { }
    
    private func synchronized<T>(_ execute: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try execute()
    }
    
    // MARK: - PublisherExpectation API
    
    /// Registers the expectation so that it gets fulfilled when publisher
    /// publishes elements or completes.
    ///
    /// - parameter expectation: An XCTestExpectation.
    /// - parameter includingConsumed: This flag controls how elements that were
    ///   already published at the time this method is called fulfill the
    ///   expectation. If true, all published elements fulfill the expectation.
    ///   If false, only published elements that are not consumed yet fulfill
    ///   the expectation. For example, the Prefix expectation uses true, but
    ///   the NextOne expectation uses false.
    func fulfillOnValue(_ expectation: XCTestExpectation, includingConsumed: Bool) {
        synchronized {
            preconditionCanFulfillExpectation()
            
            let expectedFulfillmentCount = expectation.expectedFulfillmentCount
            
            if state.error != nil {
                expectation.fulfill(count: expectedFulfillmentCount)
                return
            }
            
            let elements = state.elements
            let maxFulfillmentCount = includingConsumed
                ? elements.count
                : elements.count - consumedCount
            let fulfillmentCount = min(expectedFulfillmentCount, maxFulfillmentCount)
            expectation.fulfill(count: fulfillmentCount)
            
            let remainingCount = expectedFulfillmentCount - fulfillmentCount
            if remainingCount > 0 {
                state.recorderExpectation = RecorderExpectation(expectation: expectation, remainingCount: remainingCount)
            }
        }
    }
    
    /// Registers the expectation so that it gets fulfilled when
    /// publisher completes.
    func fulfillOnError(_ expectation: XCTestExpectation) {
        synchronized {
            preconditionCanFulfillExpectation()
            
            if state.error != nil {
                expectation.fulfill()
                return
            }
            
            state.recorderExpectation = RecorderExpectation(expectation: expectation, remainingCount: nil)
        }
    }
    
    /// Returns a value based on the recorded state of the publisher.
    ///
    /// - parameter value: A function which returns the value, given the
    ///   recorded state of the publisher.
    /// - parameter elements: All recorded elements.
    /// - parameter remainingElements: The elements that were not consumed yet.
    /// - parameter consume: A function which consumes elements.
    /// - parameter count: The number of consumed elements.
    /// - returns: The value
    func value<T>(_ value: (
        _ elements: [Element],
        _ error: Error?,
        _ remainingElements: ArraySlice<Element>,
        _ consume: (_ count: Int) -> ()) throws -> T)
        rethrows -> T
    {
        try synchronized {
            let elements = state.elements
            let remainingElements = elements[consumedCount...]
            return try value(elements, state.error, remainingElements, { count in
                precondition(count >= 0)
                precondition(count <= remainingElements.count)
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
    
    fileprivate func receive(_ observer: TransactionObserver) {
        synchronized {
            if state.observer != nil {
                XCTFail("Publisher recorder is already subscribed")
            }
            state.observer = observer
        }
    }
    
    /// Internal for testability.
    func onChange(_ element: Element) {
        return synchronized {
            if state.error != nil {
                XCTFail("Publisher recorder got unexpected element after completion: \(String(reflecting: element))")
            }
            
            state.elements.append(element)
            
            if let exp = state.recorderExpectation, let remainingCount = exp.remainingCount {
                assert(remainingCount > 0)
                exp.expectation.fulfill()
                if remainingCount > 1 {
                    state.recorderExpectation = RecorderExpectation(expectation: exp.expectation, remainingCount: remainingCount - 1)
                } else {
                    state.recorderExpectation = nil
                }
            }
        }
    }
    
    /// Internal for testability.
    func onError(_ error: Error) {
        return synchronized {
            if state.error != nil {
                XCTFail("Publisher recorder got unexpected completion after completion: \(String(describing: error))")
            }
                        
            if let exp = state.recorderExpectation {
                exp.expectation.fulfill(count: exp.remainingCount ?? 1)
                state.recorderExpectation = nil
            }
            state.error = error
        }
    }
}

// MARK: - Publisher Expectations

extension ValueObservationRecorder {
    public func failure() -> ValueObservationExpectations.Failure<Element> {
        ValueObservationExpectations.Failure(recorder: self)
    }
    
    public func next() -> ValueObservationExpectations.NextOne<Element> {
        ValueObservationExpectations.NextOne(recorder: self)
    }
    
    public func next(_ count: Int) -> ValueObservationExpectations.Next<Element> {
        ValueObservationExpectations.Next(recorder: self, count: count)
    }
    
    public func prefix(_ maxLength: Int) -> ValueObservationExpectations.Prefix<Element> {
        ValueObservationExpectations.Prefix(recorder: self, maxLength: maxLength)
    }
}

// MARK: - ValueObservation + ValueObservationRecorder

extension ValueObservation {
    public func record(in reader: DatabaseReader) -> ValueObservationRecorder<Reducer.Value> {
        let recorder = ValueObservationRecorder<Reducer.Value>()
        let observer = start(
            in: reader,
            onError: recorder.onError,
            onChange: recorder.onChange)
        recorder.receive(observer)
        return recorder
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
