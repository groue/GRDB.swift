/// A protocol indicating that an activity or action supports cancellation.
public protocol DatabaseCancellable {
    /// Cancel the activity.
    func cancel()
}

/// A type-erasing cancellable object that executes a provided closure
/// when canceled.
///
/// An AnyDatabaseCancellable instance automatically calls cancel()
///  when deinitialized.
class AnyDatabaseCancellable: DatabaseCancellable {
    private var _cancel: (() -> Void)?
    
    /// Initializes the cancellable object with the given cancel-time closure.
    init(cancel: @escaping () -> Void) {
        _cancel = cancel
    }
    
    convenience init(_ cancellable: DatabaseCancellable) {
        self.init(cancel: cancellable.cancel)
    }

    deinit {
        _cancel?()
    }
    
    func cancel() {
        // Don't prevent multiple concurrent calls to _cancel, because it is
        // pointless. But release memory!
        _cancel?()
        _cancel = nil
    }
}
