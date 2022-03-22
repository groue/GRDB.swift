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
public class AnyDatabaseCancellable: DatabaseCancellable {
    private var _cancel: (() -> Void)?
    
    /// Initializes the cancellable object with the given cancel-time closure.
    public init(cancel: @escaping () -> Void) {
        _cancel = cancel
    }
    
    /// Creates a cancellable object that forwards cancellation to the
    /// provided cancellable.
    public convenience init(_ cancellable: DatabaseCancellable) {
        var cancellable: DatabaseCancellable? = cancellable
        self.init {
            cancellable?.cancel()
            cancellable = nil // Release memory
        }
    }
    
    deinit {
        _cancel?()
    }
    
    public func cancel() {
        // Don't prevent multiple concurrent calls to _cancel, because it is
        // pointless. But release memory!
        _cancel?()
        _cancel = nil
    }
}
