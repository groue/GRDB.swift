import Foundation

#if !USING_BUILTIN_SQLITE
    #if os(OSX)
        import SQLiteMacOSX
    #elseif os(iOS)
        #if (arch(i386) || arch(x86_64))
            import SQLiteiPhoneSimulator
        #else
            import SQLiteiPhoneOS
        #endif
    #elseif os(watchOS)
        #if (arch(i386) || arch(x86_64))
            import SQLiteWatchSimulator
        #else
            import SQLiteWatchOS
        #endif
    #endif
#endif


// MARK: - Public

extension String {
    /// Returns the receiver, quoted for safe insertion as an identifier in an
    /// SQL query.
    ///
    ///     db.execute("SELECT * FROM \(tableName.quotedDatabaseIdentifier)")
    public var quotedDatabaseIdentifier: String {
        // See https://www.sqlite.org/lang_keywords.html
        return "\"" + self + "\""
    }
}

/// Return as many question marks separated with commas as the *count* argument.
///
///     databaseQuestionMarks(count: 3) // "?,?,?"
public func databaseQuestionMarks(count: Int) -> String {
    return Array(repeating: "?", count: count).joined(separator: ",")
}


// MARK: - Internal

let SQLITE_TRANSIENT = unsafeBitCast(OpaquePointer(bitPattern: -1), to: sqlite3_destructor_type.self)

/// Custom precondition function which aims at solving
/// https://bugs.swift.org/browse/SR-905 and
/// https://github.com/groue/GRDB.swift/issues/37
///
/// TODO: remove this function when https://bugs.swift.org/browse/SR-905 is solved.
func GRDBPrecondition(_ condition: @autoclosure() -> Bool, _ message: @autoclosure() -> String = "", file: StaticString = #file, line: UInt = #line) {
    if !condition() {
        fatalError(message, file: file, line: line)
    }
}

// Workaround Swift inconvenience around factory methods of non-final classes
func cast<T, U>(_ value: T) -> U? {
    return value as? U
}

extension Array {
    /// Removes the first object that matches *predicate*.
    mutating func removeFirst(_ predicate: (Element) throws -> Bool) rethrows {
        if let index = try index(where: predicate) {
            remove(at: index)
        }
    }
}

extension Dictionary {
    
    /// Create a dictionary with the keys and values in the given sequence.
    init<Sequence: Swift.Sequence>(keyValueSequence: Sequence) where Sequence.Iterator.Element == (Key, Value) {
        self.init(minimumCapacity: keyValueSequence.underestimatedCount)
        for (key, value) in keyValueSequence {
            self[key] = value
        }
    }
    
    /// Create a dictionary from keys and a value builder.
    init<Sequence: Swift.Sequence>(keys: Sequence, value: (Key) -> Value) where Sequence.Iterator.Element == Key {
        self.init(minimumCapacity: keys.underestimatedCount)
        for key in keys {
            self[key] = value(key)
        }
    }
}

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

/// A Pool maintains a set of elements that are built them on demand. A pool has
/// a maximum number of elements.
///
///     // A pool of 3 integers
///     var number = 0
///     let pool = Pool<Int>(maximumCount: 3, makeElement: {
///         number = number + 1
///         return number
///     })
///
/// The function get() dequeues an available element and gives this element to
/// the block argument. During the block execution, the element is not
/// available. When the block is ended, the element is available again.
///
///     // got 1
///     pool.get { n in
///         print("got \(n)")
///     }
///
/// If there is no available element, the pool builds a new element, unless the
/// maximum number of elements is reached. In this case, the get() method
/// blocks the current thread, until an element eventually turns available again.
///
///     DispatchQueue.concurrentPerform(iterations: 6) { _ in
///         pool.get { n in
///             print("got \(n)")
///         }
///     }
///
///     got 1
///     got 2
///     got 3
///     got 2
///     got 1
///     got 3
final class Pool<T> {
    var makeElement: (() throws -> T)?
    private var items: [PoolItem<T>] = []
    private let queue: DispatchQueue         // protects items
    private let semaphore: DispatchSemaphore // limits the number of elements
    
    init(maximumCount: Int, makeElement: (() throws -> T)? = nil) {
        GRDBPrecondition(maximumCount > 0, "Pool size must be at least 1")
        self.makeElement = makeElement
        self.queue = DispatchQueue(label: "GRDB.Pool")
        self.semaphore = DispatchSemaphore(value: maximumCount)
    }
    
    /// Returns a tuple (element, releaseElement())
    /// Client MUST call releaseElement() after the element has been used.
    func get() throws -> (T, () -> ()) {
        let item = try lockItem()
        return (item.element, { self.unlockItem(item) })
    }
    
    /// Performs a synchronous block with an element. The element turns
    /// available after the block has executed.
    func get<U>(block: (T) throws -> U) throws -> U {
        let (element, release) = try get()
        defer { release() }
        return try block(element)
    }
    
    /// Performs a block on each pool element, available or not.
    /// The block is run is some arbitrary queue.
    func forEach(_ body: (T) throws -> ()) rethrows {
        try queue.sync {
            for item in items {
                try body(item.element)
            }
        }
    }
    
    /// Empty the pool. Currently used items won't be reused.
    func clear() {
        clear {}
    }
    
    /// Empty the pool. Currently used items won't be reused.
    /// Eventual block is executed before any other element is dequeued.
    func clear(andThen block: () throws -> ()) rethrows {
        try queue.sync {
            items = []
            try block()
        }
    }
    
    private func lockItem() throws -> PoolItem<T> {
        var item: PoolItem<T>! = nil
        _ = semaphore.wait(timeout: .distantFuture)
        try queue.sync {
            if let availableItem = self.items.first(where: { $0.available }) {
                item = availableItem
                item.available = false
            } else {
                item = try PoolItem(element: self.makeElement!(), available: false)
                self.items.append(item)
            }
        }
        return item
    }
    
    private func unlockItem(_ item: PoolItem<T>) {
        queue.sync {
            item.available = true
        }
        semaphore.signal()
    }
}

private class PoolItem<T> {
    let element: T
    var available: Bool
    
    init(element: T, available: Bool) {
        self.element = element
        self.available = available
    }
}
