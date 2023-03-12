import Foundation

/// A LockedBox protects a value with an NSLock.
@propertyWrapper
final class LockedBox<T> {
    private var _wrappedValue: T
    private var lock = NSLock()
    
    var wrappedValue: T {
        get { read { $0 } }
        set { update { $0 = newValue } }
    }
    
    var projectedValue: LockedBox<T> { self }
    
    init(wrappedValue: T) {
        _wrappedValue = wrappedValue
    }
    
    /// Runs the provided closure while holding a lock on the value.
    ///
    /// For example:
    ///
    ///     // Prints "0"
    ///     @LockedBox var count = 0
    ///     $count.read { print($0) }
    ///
    /// - parameter block: A closure that accepts the value.
    @inline(__always)
    @usableFromInline
    func read<U>(_ block: (T) throws -> U) rethrows -> U {
        lock.lock()
        defer { lock.unlock() }
        return try block(_wrappedValue)
    }
    
    /// Runs the provided closure while holding a lock on the value.
    ///
    /// For example:
    ///
    ///     // Prints "1"
    ///     @LockedBox var count = 0
    ///     $count.update { $0 += 1 }
    ///     print(count)
    ///
    /// - parameter block: A closure that can modify the value.
    func update<U>(_ block: (inout T) throws -> U) rethrows -> U {
        lock.lock()
        defer { lock.unlock() }
        return try block(&_wrappedValue)
    }
}

extension LockedBox where T: Numeric {
    @discardableResult
    func increment() -> T {
        update { n in
            n += 1
            return n
        }
    }
    
    @discardableResult
    func decrement() -> T {
        update { n in
            n -= 1
            return n
        }
    }
}

extension LockedBox: @unchecked Sendable where T: Sendable { }
