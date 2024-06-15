/// A type that determines when `ValueObservation` notifies its fresh values.
///
/// ## Topics
///
/// ### Built-In Schedulers
///
/// - ``async(onQueue:)``
/// - ``immediate``
///
/// ### Supporting Types
///
/// - ``ValueObservationSchedulers``
public protocol ValueObservationScheduler: Sendable {
    /// Returns whether the initial value should be immediately notified.
    ///
    /// If the result is true, then this method was called on the main thread.
    func immediateInitialValue() -> Bool
    
    func schedule(_ action: sending @escaping () -> Void)
}

extension ValueObservationScheduler {
    func scheduleInitial(_ action: sending @escaping () -> Void) {
        if immediateInitialValue() {
            action()
        } else {
            schedule(action)
        }
    }
}

/// A namespace for concrete types that adopt the ``ValueObservationScheduler`` protocol.
public enum ValueObservationSchedulers { }
