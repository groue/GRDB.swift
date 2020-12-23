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
    
    func read<U>(_ block: (T) throws -> U) rethrows -> U {
        lock.lock()
        defer { lock.unlock() }
        return try block(_wrappedValue)
    }
    
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
