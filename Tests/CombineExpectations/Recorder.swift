#if canImport(Combine)
import Combine
import XCTest

/// A Combine subscriber which records all events published by a publisher.
///
/// You create a Recorder with the `Publisher.record()` method:
///
///     let publisher = ["foo", "bar", "baz"].publisher
///     let recorder = publisher.record()
///
/// You can build publisher expectations from the Recorder. For example:
///
///     let elements = try wait(for: recorder.elements, timeout: 1)
///     XCTAssertEqual(elements, ["foo", "bar", "baz"])
public class Recorder<Input, Failure: Error>: Subscriber {
    public typealias Input = Input
    public typealias Failure = Failure
    
    private enum RecorderExpectation {
        case onInput(XCTestExpectation, remainingCount: Int)
        case onCompletion(XCTestExpectation)
        
        var expectation: XCTestExpectation {
            switch self {
            case let .onCompletion(expectation):
                return expectation
            case let .onInput(expectation, remainingCount: _):
                return expectation
            }
        }
    }
    
    /// The recorder state
    private enum State {
        /// Publisher is not subscribed yet. The recorder may have an
        /// expectation to fulfill.
        case waitingForSubscription(RecorderExpectation?)
        
        /// Publisher is subscribed. The recorder may have an expectation to
        /// fulfill. It keeps track of all published elements.
        case subscribed(Subscription, RecorderExpectation?, [Input])
        
        /// Publisher is completed. The recorder keeps track of all published
        /// elements and completion.
        case completed([Input], Subscribers.Completion<Failure>)
        
        var elementsAndCompletion: (elements: [Input], completion: Subscribers.Completion<Failure>?) {
            switch self {
            case .waitingForSubscription:
                return (elements: [], completion: nil)
            case let .subscribed(_, _, elements):
                return (elements: elements, completion: nil)
            case let .completed(elements, completion):
                return (elements: elements, completion: completion)
            }
        }
        
        var recorderExpectation: RecorderExpectation? {
            switch self {
            case let .waitingForSubscription(exp), let .subscribed(_, exp, _):
                return exp
            case .completed:
                return nil
            }
        }
    }
    
    private let lock = NSLock()
    private var state = State.waitingForSubscription(nil)
    private var consumedCount = 0
    
    /// The elements and completion recorded so far.
    var elementsAndCompletion: (elements: [Input], completion: Subscribers.Completion<Failure>?) {
        synchronized {
            state.elementsAndCompletion
        }
    }
    
    /// Use Publisher.record()
    fileprivate init() { }
    
    deinit {
        if case let .subscribed(subscription, _, _) = state {
            subscription.cancel()
        }
    }
    
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
    func fulfillOnInput(_ expectation: XCTestExpectation, includingConsumed: Bool) {
        lock.lock()
        
        preconditionCanFulfillExpectation()
        
        let expectedFulfillmentCount = expectation.expectedFulfillmentCount
        
        switch state {
        case .waitingForSubscription:
            let exp = RecorderExpectation.onInput(expectation, remainingCount: expectedFulfillmentCount)
            state = .waitingForSubscription(exp)
            lock.unlock()
            
        case let .subscribed(subscription, _, elements):
            let maxFulfillmentCount = includingConsumed
            ? elements.count
            : elements.count - consumedCount
            let fulfillmentCount = min(expectedFulfillmentCount, maxFulfillmentCount)
            
            let remainingCount = expectedFulfillmentCount - fulfillmentCount
            if remainingCount > 0 {
                let exp = RecorderExpectation.onInput(expectation, remainingCount: remainingCount)
                state = .subscribed(subscription, exp, elements)
            }
            lock.unlock()
            expectation.fulfill(count: fulfillmentCount)
            
        case .completed:
            lock.unlock()
            expectation.fulfill(count: expectedFulfillmentCount)
        }
    }
    
    /// Registers the expectation so that it gets fulfilled when
    /// publisher completes.
    func fulfillOnCompletion(_ expectation: XCTestExpectation) {
        lock.lock()
        
        preconditionCanFulfillExpectation()
        
        switch state {
        case .waitingForSubscription:
            let exp = RecorderExpectation.onCompletion(expectation)
            state = .waitingForSubscription(exp)
            lock.unlock()
            
        case let .subscribed(subscription, _, elements):
            let exp = RecorderExpectation.onCompletion(expectation)
            state = .subscribed(subscription, exp, elements)
            lock.unlock()
            
        case .completed:
            lock.unlock()
            expectation.fulfill()
        }
    }
    
    /// Returns a value based on the recorded state of the publisher.
    ///
    /// - parameter value: A function which returns the value, given the
    ///   recorded state of the publisher.
    /// - parameter elements: All recorded elements.
    /// - parameter completion: The eventual publisher completion.
    /// - parameter remainingElements: The elements that were not consumed yet.
    /// - parameter consume: A function which consumes elements.
    /// - parameter count: The number of consumed elements.
    /// - returns: The value
    func value<T>(_ value: (
        _ elements: [Input],
        _ completion: Subscribers.Completion<Failure>?,
        _ remainingElements: ArraySlice<Input>,
        _ consume: (_ count: Int) -> ()) throws -> T)
    rethrows -> T
    {
        try synchronized {
            let (elements, completion) = state.elementsAndCompletion
            let remainingElements = elements[consumedCount...]
            return try value(elements, completion, remainingElements, { count in
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
    
    // MARK: - Subscriber
    
    public func receive(subscription: Subscription) {
        synchronized {
            switch state {
            case let .waitingForSubscription(exp):
                state = .subscribed(subscription, exp, [])
            default:
                XCTFail("Publisher recorder is already subscribed")
            }
        }
        subscription.request(.unlimited)
    }
    
    public func receive(_ input: Input) -> Subscribers.Demand {
        lock.lock()
        
        switch state {
        case let .subscribed(subscription, exp, elements):
            var elements = elements
            elements.append(input)
            
            if case let .onInput(expectation, remainingCount: remainingCount) = exp {
                assert(remainingCount > 0)
                expectation.fulfill()
                if remainingCount > 1 {
                    let exp = RecorderExpectation.onInput(expectation, remainingCount: remainingCount - 1)
                    state = .subscribed(subscription, exp, elements)
                } else {
                    state = .subscribed(subscription, nil, elements)
                }
            } else {
                state = .subscribed(subscription, exp, elements)
            }
            
            lock.unlock()
            return .unlimited
            
        case .waitingForSubscription:
            lock.unlock()
            XCTFail("Publisher recorder got unexpected input before subscription: \(String(reflecting: input))")
            return .none
            
        case .completed:
            lock.unlock()
            XCTFail("Publisher recorder got unexpected input after completion: \(String(reflecting: input))")
            return .none
        }
    }
    
    public func receive(completion: Subscribers.Completion<Failure>) {
        lock.lock()
        
        switch state {
        case let .subscribed(_, exp, elements):
            if let exp {
                switch exp {
                case let .onCompletion(expectation):
                    expectation.fulfill()
                case let .onInput(expectation, remainingCount: remainingCount):
                    expectation.fulfill(count: remainingCount)
                }
            }
            state = .completed(elements, completion)
            lock.unlock()
            
        case .waitingForSubscription:
            lock.unlock()
            XCTFail("Publisher recorder got unexpected completion before subscription: \(String(describing: completion))")
            
        case .completed:
            lock.unlock()
            XCTFail("Publisher recorder got unexpected completion after completion: \(String(describing: completion))")
        }
    }
}

// MARK: - Publisher Expectations

extension PublisherExpectations {
    /// The type of the publisher expectation returned by `Recorder.completion`.
    public typealias Completion<Input, Failure: Error> = Map<Recording<Input, Failure>, Subscribers.Completion<Failure>>
    
    /// The type of the publisher expectation returned by `Recorder.elements`.
    public typealias Elements<Input, Failure: Error> = Map<Recording<Input, Failure>, [Input]>
    
    /// The type of the publisher expectation returned by `Recorder.last`.
    public typealias Last<Input, Failure: Error> = Map<Elements<Input, Failure>, Input?>
    
    /// The type of the publisher expectation returned by `Recorder.single`.
    public typealias Single<Input, Failure: Error> = Map<Elements<Input, Failure>, Input>
}

extension Recorder {
    /// Returns a publisher expectation which waits for the timeout to expire,
    /// or the recorded publisher to complete.
    ///
    /// When waiting for this expectation, the publisher error is thrown if
    /// the publisher fails before the expectation has expired.
    ///
    /// Otherwise, an array of all elements published before the expectation
    /// has expired is returned.
    ///
    /// Unlike other expectations, `availableElements` does not make a test fail
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
    public var availableElements: PublisherExpectations.AvailableElements<Input, Failure> {
        PublisherExpectations.AvailableElements(recorder: self)
    }
    
    /// Returns a publisher expectation which waits for the recorded publisher
    /// to complete.
    ///
    /// When waiting for this expectation, a RecordingError.notCompleted is
    /// thrown if the publisher does not complete on time.
    ///
    /// Otherwise, a [Subscribers.Completion](https://developer.apple.com/documentation/combine/subscribers/completion)
    /// is returned.
    ///
    /// For example:
    ///
    ///     // SUCCESS: no timeout, no error
    ///     func testArrayPublisherCompletesWithSuccess() throws {
    ///         let publisher = ["foo", "bar", "baz"].publisher
    ///         let recorder = publisher.record()
    ///         let completion = try wait(for: recorder.completion, timeout: 1)
    ///         if case let .failure(error) = completion {
    ///             XCTFail("Unexpected error \(error)")
    ///         }
    ///     }
    public var completion: PublisherExpectations.Completion<Input, Failure> {
        recording.map { $0.completion }
    }
    
    /// Returns a publisher expectation which waits for the recorded publisher
    /// to complete.
    ///
    /// When waiting for this expectation, a RecordingError.notCompleted is
    /// thrown if the publisher does not complete on time, and the publisher
    /// error is thrown if the publisher fails.
    ///
    /// Otherwise, an array of published elements is returned.
    ///
    /// For example:
    ///
    ///     // SUCCESS: no timeout, no error
    ///     func testArrayPublisherPublishesArrayElements() throws {
    ///         let publisher = ["foo", "bar", "baz"].publisher
    ///         let recorder = publisher.record()
    ///         let elements = try wait(for: recorder.elements, timeout: 1)
    ///         XCTAssertEqual(elements, ["foo", "bar", "baz"])
    ///     }
    public var elements: PublisherExpectations.Elements<Input, Failure> {
        recording.map { recording in
            if case let .failure(error) = recording.completion {
                throw error
            }
            return recording.output
        }
    }
    
    /// Returns a publisher expectation which waits for the recorded publisher
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
    public var finished: PublisherExpectations.Finished<Input, Failure> {
        PublisherExpectations.Finished(recorder: self)
    }
    
    /// Returns a publisher expectation which waits for the recorded publisher
    /// to complete.
    ///
    /// When waiting for this expectation, a RecordingError.notCompleted is
    /// thrown if the publisher does not complete on time, and the publisher
    /// error is thrown if the publisher fails.
    ///
    /// Otherwise, the last published element is returned, or nil if the publisher
    /// completes before it publishes any element.
    ///
    /// For example:
    ///
    ///     // SUCCESS: no timeout, no error
    ///     func testArrayPublisherPublishesLastElementLast() throws {
    ///         let publisher = ["foo", "bar", "baz"].publisher
    ///         let recorder = publisher.record()
    ///         if let element = try wait(for: recorder.last, timeout: 1) {
    ///             XCTAssertEqual(element, "baz")
    ///         } else {
    ///             XCTFail("Expected one element")
    ///         }
    ///     }
    public var last: PublisherExpectations.Last<Input, Failure> {
        elements.map { $0.last }
    }
    
    /// Returns a publisher expectation which waits for the recorded publisher
    /// to emit one element, or to complete.
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
    public func next() -> PublisherExpectations.NextOne<Input, Failure> {
        PublisherExpectations.NextOne(recorder: self)
    }
    
    /// Returns a publisher expectation which waits for the recorded publisher
    /// to emit `count` elements, or to complete.
    ///
    /// When waiting for this expectation, a `RecordingError.notEnoughElements`
    /// is thrown if the publisher does not publish `count` elements after last
    /// waited expectation. The publisher error is thrown if the publisher fails
    /// before publishing the next `count` elements.
    ///
    /// Otherwise, an array of exactly `count` elements is returned.
    ///
    /// For example:
    ///
    ///     // SUCCESS: no timeout, no error
    ///     func testArrayOfThreeElementsPublishesTwoThenOneElement() throws {
    ///         let publisher = ["foo", "bar", "baz"].publisher
    ///         let recorder = publisher.record()
    ///
    ///         var elements = try wait(for: recorder.next(2), timeout: 1)
    ///         XCTAssertEqual(elements, ["foo", "bar"])
    ///
    ///         elements = try wait(for: recorder.next(1), timeout: 1)
    ///         XCTAssertEqual(elements, ["baz"])
    ///     }
    ///
    /// - parameter count: The number of elements.
    public func next(_ count: Int) -> PublisherExpectations.Next<Input, Failure> {
        PublisherExpectations.Next(recorder: self, count: count)
    }
    
    /// Returns a publisher expectation which waits for the recorded publisher
    /// to emit `maxLength` elements, or to complete.
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
    ///
    /// - parameter maxLength: The maximum number of elements.
    public func prefix(_ maxLength: Int) -> PublisherExpectations.Prefix<Input, Failure> {
        PublisherExpectations.Prefix(recorder: self, maxLength: maxLength)
    }
    
    /// Returns a publisher expectation which waits for the recorded publisher
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
    public var recording: PublisherExpectations.Recording<Input, Failure> {
        PublisherExpectations.Recording(recorder: self)
    }
    
    /// Returns a publisher expectation which waits for the recorded publisher
    /// to complete.
    ///
    /// When waiting for this expectation, a RecordingError is thrown if the
    /// publisher does not complete on time, or does not publish exactly one
    /// element before it completes. The publisher error is thrown if the
    /// publisher fails.
    ///
    /// Otherwise, the single published element is returned.
    ///
    /// For example:
    ///
    ///     // SUCCESS: no timeout, no error
    ///     func testJustPublishesExactlyOneElement() throws {
    ///         let publisher = Just("foo")
    ///         let recorder = publisher.record()
    ///         let element = try wait(for: recorder.single, timeout: 1)
    ///         XCTAssertEqual(element, "foo")
    ///     }
    public var single: PublisherExpectations.Single<Input, Failure> {
        elements.map { elements in
            guard let element = elements.first else {
                throw RecordingError.notEnoughElements
            }
            if elements.count > 1 {
                throw RecordingError.tooManyElements
            }
            return element
        }
    }
}

// MARK: - Publisher + Recorder

extension Publisher {
    /// Returns a subscribed Recorder.
    ///
    /// For example:
    ///
    ///     let publisher = ["foo", "bar", "baz"].publisher
    ///     let recorder = publisher.record()
    ///
    /// You can build publisher expectations from the Recorder. For example:
    ///
    ///     let elements = try wait(for: recorder.elements, timeout: 1)
    ///     XCTAssertEqual(elements, ["foo", "bar", "baz"])
    public func record() -> Recorder<Output, Failure> {
        let recorder = Recorder<Output, Failure>()
        subscribe(recorder)
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
#endif

