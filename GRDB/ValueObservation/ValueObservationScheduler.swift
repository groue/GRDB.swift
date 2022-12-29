import Dispatch
import Foundation

/// A type that determines when `ValueObservation` notifies its fresh values.
///
/// ## Topics
///
/// ### Built-In Schedulers
///
/// - ``async(onQueue:)``
/// - ``immediate``
/// - ``AsyncValueObservationScheduler``
/// - ``ImmediateValueObservationScheduler``
public protocol ValueObservationScheduler {
    /// Returns whether the initial value should be immediately notified.
    ///
    /// If the result is true, then this method was called on the main thread.
    func immediateInitialValue() -> Bool
    
    func schedule(_ action: @escaping () -> Void)
}

extension ValueObservationScheduler {
    func scheduleInitial(_ action: @escaping () -> Void) {
        if immediateInitialValue() {
            action()
        } else {
            schedule(action)
        }
    }
}

// MARK: - AsyncValueObservationScheduler

/// A scheduler that asynchronously notifies fresh value of a `DispatchQueue`.
public struct AsyncValueObservationScheduler: ValueObservationScheduler {
    var queue: DispatchQueue
    
    public init(queue: DispatchQueue) {
        self.queue = queue
    }
    
    public func immediateInitialValue() -> Bool { false }
    
    public func schedule(_ action: @escaping () -> Void) {
        queue.async(execute: action)
    }
}

extension ValueObservationScheduler where Self == AsyncValueObservationScheduler {
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
    public static func async(onQueue queue: DispatchQueue) -> AsyncValueObservationScheduler {
        AsyncValueObservationScheduler(queue: queue)
    }
}

// MARK: - ImmediateValueObservationScheduler

/// A scheduler that notifies all values on the main `DispatchQueue`. The
/// first value is immediately notified when the `ValueObservation`
/// is started.
public struct ImmediateValueObservationScheduler: ValueObservationScheduler {
    public init() { }
    
    public func immediateInitialValue() -> Bool {
        GRDBPrecondition(
            Thread.isMainThread,
            "ValueObservation must be started from the main thread.")
        return true
    }
    
    public func schedule(_ action: @escaping () -> Void) {
        DispatchQueue.main.async(execute: action)
    }
}

extension ValueObservationScheduler where Self == ImmediateValueObservationScheduler {
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
    public static var immediate: ImmediateValueObservationScheduler {
        ImmediateValueObservationScheduler()
    }
}
