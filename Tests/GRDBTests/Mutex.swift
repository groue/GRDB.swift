import Foundation

/// A Mutex protects a value with an NSLock.
final class Mutex<T> {
    private var _value: T
    private var lock = NSLock()
    
    init(_ value: T) {
        _value = value
    }

    /// Runs the provided closure while holding a lock on the value.
    ///
    /// - parameter body: A closure that can modify the value.
    func withLock<U>(_ body: (inout T) throws -> U) rethrows -> U {
        lock.lock()
        defer { lock.unlock() }
        return try body(&_value)
    }
}

// Inspired by <https://forums.swift.org/t/se-0433-synchronous-mutual-exclusion-lock/71174/58>
extension Mutex {
    func load() -> T {
        withLock { $0 }
    }
    
    func store(_ value: T) {
        withLock { $0 = value }
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

extension Mutex where T == Bool {
    /// Sets the flag to false, and returns whether it was true.
    ///
    /// For example:
    ///
    /// ```swift
    /// let needsStuffMutex = Mutex(true)
    ///
    /// if needsStuffMutex.wasNeeded {
    ///     // do stuff
    /// }
    /// ```
    var wasNeeded: Bool {
        withLock { bool in
            let wasNeeded = bool
            bool = false
            return wasNeeded
        }
    }
}

extension Mutex: @unchecked Sendable where T: Sendable { }
