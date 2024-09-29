/// A protocol indicating that an activity or action supports cancellation.
///
/// ## Topics
///
/// ### Supporting Types
///
/// - ``AnyDatabaseCancellable``
public protocol DatabaseCancellable: Sendable {
    /// Cancel the activity.
    func cancel()
}

/// A type-erasing cancellable object that executes a provided closure
/// when canceled.
///
/// An `AnyDatabaseCancellable` instance automatically calls ``cancel()``
///  when deinitialized.
public final class AnyDatabaseCancellable: DatabaseCancellable {
    private let cancelMutex: Mutex<(@Sendable () -> Void)?>
    
    var isCancelled: Bool {
        cancelMutex.withLock { $0 == nil }
    }
    
    convenience init() {
        self.init(cancel: { })
    }
    
    /// Initializes the cancellable object with the given cancel-time closure.
    public init(cancel: @escaping @Sendable () -> Void) {
        cancelMutex = Mutex(cancel)
    }
    
    /// Creates a cancellable object that forwards cancellation to `base`.
    public convenience init(_ base: some DatabaseCancellable) {
        self.init {
            base.cancel()
        }
    }
    
    deinit {
        cancel()
    }
    
    public func cancel() {
        let cancel = cancelMutex.withLock {
            let cancel = $0
            $0 = nil
            return cancel
        }
        cancel?()
    }
}
