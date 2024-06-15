import Dispatch
import Foundation

extension ValueObservationSchedulers {
    /// A scheduler that asynchronously notifies fresh value of a `DispatchQueue`.
    public struct AsyncDispatchQueue: ValueObservationScheduler {
        var queue: DispatchQueue
        
        public init(queue: DispatchQueue) {
            self.queue = queue
        }
        
        public func immediateInitialValue() -> Bool { false }
        
        public func schedule(_ action: sending @escaping () -> Void) {
            // DispatchQueue does not accept a sending closure yet, as
            // discussed at <https://forums.swift.org/t/how-can-i-use-region-based-isolation/71426/5>.
            // So let's wrap the closure in a Sendable wrapper.
            let action = UncheckedSendableWrapper(value: action)
            
            queue.async {
                action.value()
            }
        }
    }
}

extension ValueObservationScheduler where Self == ValueObservationSchedulers.AsyncDispatchQueue {
    /// A scheduler that asynchronously notifies fresh value of the
    /// given `DispatchQueue`.
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
    ///     scheduling: .async(onQueue: .main),
    ///     onError: { error in ... },
    ///     onChange: { (players: [Player]) in
    ///         print("fresh players: \(players)")
    ///     })
    /// ```
    ///
    /// - warning: Make sure you provide a serial queue, because a
    ///   concurrent one such as `DispachQueue.global(qos: .default)` would
    ///   mess with the ordering of fresh value notifications.
    public static func async(onQueue queue: DispatchQueue) -> Self {
        ValueObservationSchedulers.AsyncDispatchQueue(queue: queue)
    }
}
