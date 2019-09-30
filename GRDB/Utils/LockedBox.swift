import Foundation

/// A LockedBox protects a value with an NSLock.
final class LockedBox<T> {
    private var _value: T
    private var lock = NSLock()
    
    var value: T {
        get { return read { $0 } }
        set { write { $0 = newValue } }
    }
    
    init(value: T) {
        _value = value
    }
    
    func read<U>(_ block: (T) throws -> U) rethrows -> U {
        lock.lock()
        defer { lock.unlock() }
        return try block(_value)
    }
    
    func write<U>(_ block: (inout T) throws -> U) rethrows -> U {
        lock.lock()
        defer { lock.unlock() }
        return try block(&_value)
    }
}

extension LockedBox where T: Numeric {
    @discardableResult
    func increment() -> T {
        return write { n in
            n += 1
            return n
        }
    }

    @discardableResult
    func decrement() -> T {
        return write { n in
            n -= 1
            return n
        }
    }
}
