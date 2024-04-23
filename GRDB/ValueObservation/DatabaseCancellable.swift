import Foundation

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
public final class AnyDatabaseCancellable: DatabaseCancellable, @unchecked Sendable {
    // @unchecked Sendable due to `_cancel`, which is protected by `lock`.
    private let lock = NSLock()
    private var _cancel: (@Sendable () -> Void)?
    
    var isCancelled: Bool {
        lock.withLock { _cancel == nil }
    }
    
    convenience init() {
        self.init(cancel: { })
    }
    
    /// Initializes the cancellable object with the given cancel-time closure.
    public init(cancel: @escaping @Sendable () -> Void) {
        _cancel = cancel
    }
    
    /// Creates a cancellable object that forwards cancellation to `base`.
    public convenience init(_ base: some DatabaseCancellable & Sendable) {
        self.init {
            base.cancel()
        }
    }
    
    deinit {
        cancel()
    }
    
    public func cancel() {
        lock.lock()
        let cancel = _cancel
        _cancel = nil
        lock.unlock()
        cancel?()
    }
}
