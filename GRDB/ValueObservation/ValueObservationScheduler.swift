import Dispatch

/// ValueObservationScheduler determines how ValueObservation notifies its
/// fresh values.
public class ValueObservationScheduler {
    let impl: ValueObservationSchedulerImpl
    
    init(impl: ValueObservationSchedulerImpl) {
        self.impl = impl
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
    ///     let observer = try observation.start(
    ///         in: dbQueue,
    ///         scheduler: .async(onQueue: .main),
    ///         onError: { error in ... },
    ///         onChange: { players: [Player] in
    ///             print("fresh players: \(players)")
    ///         })
    public static func async(onQueue queue: DispatchQueue) -> ValueObservationScheduler {
        return ValueObservationScheduler(impl: queue)
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
    ///     let observer = try observation.start(
    ///         in: dbQueue,
    ///         scheduler: .immediate,
    ///         onError: { error in ... },
    ///         onChange: { players: [Player] in
    ///             print("fresh players: \(players)")
    ///         })
    ///     // <- here "fresh players" is already printed.
    ///
    /// - important: this scheduler requires that the observation is started
    ///  from the main queue. A fatal error is raised otherwise.
    public static let immediate = ValueObservationScheduler(impl: ImmediateImpl())
}

protocol ValueObservationSchedulerImpl {
    func schedule(_ action: @escaping () -> Void)
    func fetchOnStart() -> Bool
}

struct ImmediateImpl: ValueObservationSchedulerImpl {
    func schedule(_ action: @escaping () -> Void) {
        DispatchQueue.main.async(execute: action)
    }
    
    func fetchOnStart() -> Bool {
        GRDBPrecondition(
            DispatchQueue.isMain,
            "ValueObservation must be started from the main Dispatch queue.")
        return true
    }
}

extension DispatchQueue: ValueObservationSchedulerImpl {
    func schedule(_ action: @escaping () -> Void) {
        async(execute: action)
    }
    
    func fetchOnStart() -> Bool {
        false
    }
}
