import Dispatch

/// A ReadWriteBox grants multiple readers and single-writer guarantees on a
/// value. It is backed by a concurrent DispatchQueue.
@propertyWrapper
final class ReadWriteBox<T> {
    private var _wrappedValue: T
    private var queue: DispatchQueue
    
    var wrappedValue: T {
        get { read { $0 } }
        set { update { $0 = newValue } }
    }
    
    var projectedValue: ReadWriteBox<T> { self }
    
    init(wrappedValue: T) {
        _wrappedValue = wrappedValue
        queue = DispatchQueue(label: "GRDB.ReadWriteBox", attributes: [.concurrent])
    }
    
    func read<U>(_ block: (T) throws -> U) rethrows -> U {
        try queue.sync {
            try block(_wrappedValue)
        }
    }
    
    func update<U>(_ block: (inout T) throws -> U) rethrows -> U {
        try queue.sync(flags: [.barrier]) {
            try block(&_wrappedValue)
        }
    }
}

extension ReadWriteBox where T: Numeric {
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
