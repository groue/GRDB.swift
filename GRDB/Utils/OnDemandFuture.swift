#if canImport(Combine)
import Combine
import Foundation

/// A publisher that eventually produces one value and then finishes or fails.
///
/// Like a Combine.Future wrapped in Combine.Deferred, OnDemandFuture starts
/// producing its value on demand.
///
/// Unlike Combine.Future wrapped in Combine.Deferred, OnDemandFuture guarantees
/// that it starts producing its value on demand, **synchronously**, and that
/// it produces its value on promise completion, **synchronously**.
///
/// Both two extra scheduling guarantees are used by GRDB in order to be
/// able to spawn concurrent database reads right from the database writer
/// queue, and fulfill GRDB preconditions.
///
/// OnDemandFuture also adds Sendable requirements that avoid
/// compiler warnings.
struct OnDemandFuture<Output, Failure: Error>: Publisher {
    typealias Promise = @Sendable (Result<Output, Failure>) -> Void
    typealias Output = Output
    typealias Failure = Failure
    fileprivate let attemptToFulfill: @Sendable (@escaping Promise) -> Void
    
    init(_ attemptToFulfill: @escaping @Sendable (@escaping Promise) -> Void) {
        self.attemptToFulfill = attemptToFulfill
    }
    
    func receive<S>(subscriber: S) where S: Subscriber & SendableMetatype, Failure == S.Failure, Output == S.Input {
        let subscription = OnDemandFutureSubscription(
            attemptToFulfill: attemptToFulfill,
            downstream: subscriber)
        subscriber.receive(subscription: subscription)
    }
}

private class OnDemandFutureSubscription<Downstream: Subscriber & SendableMetatype>: Subscription, @unchecked Sendable {
    // @unchecked because `state` is protected with `lock`.
    typealias Promise = @Sendable (Result<Downstream.Input, Downstream.Failure>) -> Void
    
    private enum State {
        case waitingForDemand(downstream: Downstream, attemptToFulfill: (@escaping Promise) -> Void)
        case waitingForFulfillment(downstream: Downstream)
        case finished
    }
    
    private var state: State
    private let lock = NSRecursiveLock() // Allow re-entrancy
    
    init(
        attemptToFulfill: @escaping @Sendable (@escaping Promise) -> Void,
        downstream: Downstream)
    {
        self.state = .waitingForDemand(downstream: downstream, attemptToFulfill: attemptToFulfill)
    }
    
    func request(_ demand: Subscribers.Demand) {
        lock.synchronized {
            switch state {
            case let .waitingForDemand(downstream: downstream, attemptToFulfill: attemptToFulfill):
                guard demand > 0 else {
                    return
                }
                state = .waitingForFulfillment(downstream: downstream)
                attemptToFulfill { result in
                    switch result {
                    case let .success(value):
                        self.receive(value)
                    case let .failure(error):
                        self.receive(completion: .failure(error))
                    }
                }
                
            case .waitingForFulfillment, .finished:
                break
            }
        }
    }
    
    func cancel() {
        lock.synchronized {
            state = .finished
        }
    }
    
    private func receive(_ value: Downstream.Input) {
        lock.synchronized { sideEffect in
            switch state {
            case let .waitingForFulfillment(downstream: downstream):
                state = .finished
                sideEffect = {
                    _ = downstream.receive(value)
                    downstream.receive(completion: .finished)
                }
                
            case .waitingForDemand, .finished:
                break
            }
        }
    }
    
    private func receive(completion: Subscribers.Completion<Downstream.Failure>) {
        lock.synchronized { sideEffect in
            switch state {
            case let .waitingForFulfillment(downstream: downstream):
                state = .finished
                sideEffect = {
                    downstream.receive(completion: completion)
                }
                
            case .waitingForDemand, .finished:
                break
            }
        }
    }
}
#endif
