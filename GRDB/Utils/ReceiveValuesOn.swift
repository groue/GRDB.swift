#if canImport(Combine)
import Combine
import Foundation

/// A publisher that delivers values to its downstream subscriber on a
/// specific scheduler.
///
/// Unlike Combine's Publishers.ReceiveOn, ReceiveValuesOn only re-schedule
/// values and completion. It does not re-schedule subscription.
///
/// This scheduling guarantee is used by GRDB in order to be able
/// to make promises on the scheduling of database values without surprising
/// the users as in <https://forums.swift.org/t/28631>.
@available(OSX 10.15, iOS 13, tvOS 13, watchOS 6, *)
struct ReceiveValuesOn<Upstream: Publisher, Context: Scheduler>: Publisher {
    typealias Output = Upstream.Output
    typealias Failure = Upstream.Failure
    
    fileprivate let upstream: Upstream
    fileprivate let context: Context
    fileprivate let options: Context.SchedulerOptions?
    
    func receive<S>(subscriber: S) where S: Subscriber, Failure == S.Failure, Output == S.Input {
        let subscription = ReceiveValuesOnSubscription(
            upstream: upstream,
            context: context,
            options: options,
            downstream: subscriber)
        subscriber.receive(subscription: subscription)
    }
}

@available(OSX 10.15, iOS 13, tvOS 13, watchOS 6, *)
private class ReceiveValuesOnSubscription<Upstream, Context, Downstream>: Subscription, Subscriber
where
    Upstream: Publisher,
    Context: Scheduler,
    Downstream: Subscriber,
    Upstream.Failure == Downstream.Failure,
    Upstream.Output == Downstream.Input
{
    private struct Target {
        let context: Context
        let options: Context.SchedulerOptions?
        let downstream: Downstream
    }
    
    private enum State {
        case waitingForRequest(Upstream, Target)
        case waitingForSubscription(Target, Subscribers.Demand)
        case subscribed(Target, Subscription)
        case finished
    }
    
    private var state: State
    private let lock = NSRecursiveLock()
    
    init(
        upstream: Upstream,
        context: Context,
        options: Context.SchedulerOptions?,
        downstream: Downstream)
    {
        let target = Target(context: context, options: options, downstream: downstream)
        self.state = .waitingForRequest(upstream, target)
    }
    
    // MARK: Subscription
    
    func request(_ demand: Subscribers.Demand) {
        lock.synchronized { sideEffect in
            switch state {
            case let .waitingForRequest(upstream, target):
                state = .waitingForSubscription(target, demand)
                sideEffect = {
                    upstream.receive(subscriber: self)
                }
                
            case let .waitingForSubscription(target, currentDemand):
                state = .waitingForSubscription(target, demand + currentDemand)
                
            case let .subscribed(_, subcription):
                sideEffect = {
                    subcription.request(demand)
                }
                
            case .finished:
                break
            }
        }
    }
    
    func cancel() {
        lock.synchronized { sideEffect in
            switch state {
            case .waitingForRequest, .waitingForSubscription:
                state = .finished
                
            case let .subscribed(_, subcription):
                state = .finished
                sideEffect = {
                    subcription.cancel()
                }
                
            case .finished:
                break
            }
        }
    }
    
    // MARK: Subscriber
    
    func receive(subscription: Subscription) {
        lock.synchronized { sideEffect in
            switch state {
            case let .waitingForSubscription(target, currentDemand):
                state = .subscribed(target, subscription)
                sideEffect = {
                    subscription.request(currentDemand)
                }
                
            case .waitingForRequest, .subscribed:
                preconditionFailure()
                
            case .finished:
                // We receive the upstream subscription requested by
                // `upstream.receive(subscriber: self)` above.
                //
                // But self has been cancelled since, so let's cancel this
                // upstream subscription that has turned purposeless.
                //
                // This cancellation avoids the bug described in
                // https://github.com/groue/GRDB.swift/pull/932
                // TODO: write a regression test.
                sideEffect = {
                    subscription.cancel()
                }
            }
        }
    }
    
    func receive(_ input: Upstream.Output) -> Subscribers.Demand {
        lock.synchronized { sideEffect in
            switch state {
            case let .subscribed(target, _):
                sideEffect = {
                    target.context.schedule(options: target.options) {
                        self._receive(input)
                    }
                }
            case .waitingForRequest, .waitingForSubscription, .finished:
                break
            }
        }
        
        // TODO: what problem are we creating by returning .unlimited and
        // ignoring downstream's result?
        //
        // `Publisher.receive(on:options:)` does not document its behavior
        // regarding backpressure.
        return .unlimited
    }
    
    func receive(completion: Subscribers.Completion<Upstream.Failure>) {
        lock.synchronized { sideEffect in
            switch state {
            case .waitingForRequest, .waitingForSubscription:
                break
            case let .subscribed(target, _):
                sideEffect = {
                    target.context.schedule(options: target.options) {
                        self._receive(completion: completion)
                    }
                }
            case .finished:
                break
            }
        }
    }
    
    private func _receive(_ input: Upstream.Output) {
        lock.synchronized { sideEffect in
            switch state {
            case .waitingForRequest, .waitingForSubscription:
                break
            case let .subscribed(target, _):
                // TODO: don't ignore demand
                sideEffect = {
                    _ = target.downstream.receive(input)
                }
            case .finished:
                break
            }
        }
    }
    
    private func _receive(completion: Subscribers.Completion<Upstream.Failure>) {
        lock.synchronized { sideEffect in
            switch state {
            case .waitingForRequest, .waitingForSubscription:
                break
            case let .subscribed(target, _):
                state = .finished
                sideEffect = {
                    target.downstream.receive(completion: completion)
                }
            case .finished:
                break
            }
        }
    }
}

@available(OSX 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension Publisher {
    /// Specifies the scheduler on which to receive values from the publisher
    ///
    /// The difference with the stock `receive(on:options:)` Combine method is
    /// that only values and completion are re-scheduled. Subscriptions are not.
    func receiveValues<S: Scheduler>(on scheduler: S, options: S.SchedulerOptions? = nil) -> ReceiveValuesOn<Self, S> {
        ReceiveValuesOn(upstream: self, context: scheduler, options: options)
    }
}
#endif
