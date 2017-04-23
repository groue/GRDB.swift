import Dispatch

/// A ReadWriteBox grants multiple readers and single-writer guarantees on a value.
final class ReadWriteBox<T> {
    var value: T {
        get { return read { $0 } }
        set { write { $0 = newValue } }
    }
    
    init(_ value: T) {
        self._value = value
        self.queue = DispatchQueue(label: "GRDB.ReadWriteBox", attributes: [.concurrent])
    }
    
    func read<U>(_ block: (T) -> U) -> U {
        var result: U? = nil
        queue.sync {
            result = block(self._value)
        }
        return result!
    }
    
    func write(_ block: (inout T) -> Void) {
        queue.sync(flags: [.barrier]) {
            block(&self._value)
        }
    }
    
    private var _value: T
    private var queue: DispatchQueue
}
