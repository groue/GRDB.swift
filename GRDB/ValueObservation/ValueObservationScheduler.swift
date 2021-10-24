import Dispatch
import Foundation

/// ValueObservationScheduler determines how `ValueObservation` notifies its
/// fresh values.
public class ValueObservationScheduler {
    private let impl: ValueObservationSchedulerImpl
    
    private init(impl: ValueObservationSchedulerImpl) {
        self.impl = impl
    }
    
    func schedule(_ action: @escaping () -> Void) {
        impl.schedule(action)
    }
    
    func immediateInitialValue() -> Bool {
        impl.immediateInitialValue()
    }
    
    /// A scheduler which asynchronously notifies fresh value of the
    /// given DispatchQueue.
    ///
    /// For example:
    ///
    ///     let observation = ValueObservation.tracking { db in
    ///         try Player.fetchAll(db)
    ///     }
    ///
    ///     let cancellable = try observation.start(
    ///         in: dbQueue,
    ///         scheduling: .async(onQueue: .main),
    ///         onError: { error in ... },
    ///         onChange: { players: [Player] in
    ///             print("fresh players: \(players)")
    ///         })
    public static func async(onQueue queue: DispatchQueue) -> ValueObservationScheduler {
        ValueObservationScheduler(impl: queue)
    }
    
    /// A scheduler which notifies all values on the main queue. The first one
    /// is immediately notified when the start() method is called.
    ///
    /// For example:
    ///
    ///     let observation = ValueObservation.tracking { db in
    ///         try Player.fetchAll(db)
    ///     }
    ///
    ///     let cancellable = try observation.start(
    ///         in: dbQueue,
    ///         scheduling: .immediate,
    ///         onError: { error in ... },
    ///         onChange: { players: [Player] in
    ///             print("fresh players: \(players)")
    ///         })
    ///     // <- here "fresh players" is already printed.
    ///
    /// - important: this scheduler requires that the observation is started
    ///  from the main queue. A fatal error is raised otherwise.
    public static let immediate = ValueObservationScheduler(impl: ImmediateImpl())
    
    func scheduleInitial(_ action: @escaping () -> Void) {
        if immediateInitialValue() {
            action()
        } else {
            schedule(action)
        }
    }
}

private protocol ValueObservationSchedulerImpl {
    func schedule(_ action: @escaping () -> Void)
    func immediateInitialValue() -> Bool
}

private struct ImmediateImpl: ValueObservationSchedulerImpl {
    func schedule(_ action: @escaping () -> Void) {
        DispatchQueue.main.async(execute: action)
    }
    
    func immediateInitialValue() -> Bool {
        GRDBPrecondition(
            Thread.isMainThread,
            "ValueObservation must be started from the main thread.")
        return true
    }
}

extension DispatchQueue: ValueObservationSchedulerImpl {
    func schedule(_ action: @escaping () -> Void) {
        async(execute: action)
    }
    
    func immediateInitialValue() -> Bool {
        false
    }
}
