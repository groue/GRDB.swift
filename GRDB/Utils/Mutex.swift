import Foundation

/// A Mutex protects a value with an NSLock.
@propertyWrapper
final class Mutex<T> {
    private var _wrappedValue: T
    private var lock = NSLock()
    
    var wrappedValue: T {
        get { withLock { $0 } }
        set { withLock { $0 = newValue } }
    }
    
    var projectedValue: Mutex<T> { self }
    
    init(wrappedValue: T) {
        _wrappedValue = wrappedValue
    }
    
    init(_ value: T) {
        _wrappedValue = value
    }

    /// Runs the provided closure while holding a lock on the value.
    ///
    /// For example:
    ///
    ///     // Prints "1"
    ///     @Mutex var count = 0
    ///     $count.withLock { $0 += 1 }
    ///     print(count)
    ///
    /// - parameter block: A closure that can modify the value.
    func withLock<U>(_ body: (inout T) throws -> U) rethrows -> U {
        lock.lock()
        defer { lock.unlock() }
        return try body(&_wrappedValue)
    }
}

extension Mutex where T: Numeric {
    @discardableResult
    func increment() -> T {
        withLock { n in
            n += 1
            return n
        }
    }
    
    @discardableResult
    func decrement() -> T {
        withLock { n in
            n -= 1
            return n
        }
    }
}

extension Mutex: @unchecked Sendable where T: Sendable { }
