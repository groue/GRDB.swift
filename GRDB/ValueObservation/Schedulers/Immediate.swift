import Dispatch
import Foundation

extension ValueObservationSchedulers {
    /// A scheduler that notifies all values on the main `DispatchQueue`. The
    /// first value is immediately notified when the `ValueObservation`
    /// is started.
    public struct Immediate: ValueObservationScheduler, Sendable {
        public init() { }
        
        public func immediateInitialValue() -> Bool {
            GRDBPrecondition(
                Thread.isMainThread,
                "ValueObservation must be started from the main thread.")
            return true
        }
        
        public func schedule(_ action: sending @escaping () -> Void) {
            // DispatchQueue does not accept a sending closure yet, as
            // discussed at <https://forums.swift.org/t/how-can-i-use-region-based-isolation/71426/5>.
            // So let's wrap the closure in a Sendable wrapper.
            let action = UncheckedSendableWrapper(value: action)
            
            DispatchQueue.main.async {
                action.value()
            }
        }
    }
}

extension ValueObservationScheduler where Self == ValueObservationSchedulers.Immediate {
    /// A scheduler that notifies all values on the main `DispatchQueue`. The
    /// first value is immediately notified when the `ValueObservation`
    /// is started.
    ///
    /// For example:
    ///
    /// ```swift
    /// let observation = ValueObservation.tracking { db in
    ///     try Player.fetchAll(db)
    /// }
    ///
    /// let cancellable = try observation.start(
    ///     in: dbQueue,
    ///     scheduling: .immediate,
    ///     onError: { error in ... },
    ///     onChange: { (players: [Player]) in
    ///         print("fresh players: \(players)")
    ///     })
    /// // <- here "fresh players" is already printed.
    /// ```
    ///
    /// - important: this scheduler requires that the observation is started
    ///  from the main queue. A fatal error is raised otherwise.
    public static var immediate: Self {
        ValueObservationSchedulers.Immediate()
    }
}
