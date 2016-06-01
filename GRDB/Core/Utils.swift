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
public func databaseQuestionMarks(count count: Int) -> String {
    return Array(count: count, repeatedValue: "?").joinWithSeparator(",")
}


// MARK: - Internal

let SQLITE_TRANSIENT = unsafeBitCast(COpaquePointer(bitPattern: -1), sqlite3_destructor_type.self)

/// Custom precondition function which aims at solving
/// https://bugs.swift.org/browse/SR-905 and
/// https://github.com/groue/GRDB.swift/issues/37
///
/// TODO: remove this function when https://bugs.swift.org/browse/SR-905 is solved.
func GRDBPrecondition(@autoclosure condition: () -> Bool, @autoclosure _ message: () -> String = "", file: StaticString = #file, line: UInt = #line) {
    if !condition() {
        fatalError(message, file: file, line: line)
    }
}

/// A function declared as rethrows that synchronously executes a throwing
/// block in a dispatch_queue.
func dispatchSync<T>(queue: dispatch_queue_t, _ block: () throws -> T) rethrows -> T {
    func impl(queue: dispatch_queue_t, block: () throws -> T, onError: (ErrorType) throws -> ()) rethrows -> T {
        var result: T? = nil
        var blockError: ErrorType? = nil
        dispatch_sync(queue) {
            do {
                result = try block()
            } catch {
                blockError = error
            }
        }
        if let blockError = blockError {
            try onError(blockError)
        }
        return result!
    }
    return try impl(queue, block: block, onError: { throw $0 })
}

extension Array {
    /// Removes the first object that matches *predicate*.
    mutating func removeFirst(@noescape predicate: (Element) throws -> Bool) rethrows {
        if let index = try indexOf(predicate) {
            removeAtIndex(index)
        }
    }
}

extension Dictionary {
    
    /// Create a dictionary with the keys and values in the given sequence.
    init<Sequence: SequenceType where Sequence.Generator.Element == Generator.Element>(keyValueSequence: Sequence) {
        self.init(minimumCapacity: keyValueSequence.underestimateCount())
        for (key, value) in keyValueSequence {
            self[key] = value
        }
    }
    
    /// Create a dictionary from keys and a value builder.
    init<Sequence: SequenceType where Sequence.Generator.Element == Key>(keys: Sequence, value: Key -> Value) {
        self.init(minimumCapacity: keys.underestimateCount())
        for key in keys {
            self[key] = value(key)
        }
    }
}

extension SequenceType where Generator.Element: Equatable {
    
    /// Filter out elements contained in *removedElements*.
    func removingElementsOf<S : SequenceType where S.Generator.Element == Self.Generator.Element>(removedElements: S) -> [Self.Generator.Element] {
        return filter { element in !removedElements.contains(element) }
    }
}

extension SequenceType {
    /// Return true if one element matches the predicate
    func any(predicate: (Generator.Element -> Bool)) -> Bool {
        for element in self where predicate(element) { return true }
        return false
    }
    
    func all(predicate: (Generator.Element -> Bool)) -> Bool {
        for element in self where !predicate(element) { return false }
        return true
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
        self.queue = dispatch_queue_create("GRDB.ReadWriteBox", DISPATCH_QUEUE_CONCURRENT)
    }
    
    func read<U>(block: (T) -> U) -> U {
        var result: U? = nil
        dispatch_sync(queue) {
            result = block(self._value)
        }
        return result!
    }
    
    func write(block: (inout T) -> Void) {
        dispatch_barrier_sync(queue) {
            block(&self._value)
        }
    }

    private var _value: T
    private var queue: dispatch_queue_t
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
///     let queue = dispatch_queue_create(nil, DISPATCH_QUEUE_CONCURRENT)
///     dispatch_apply(6, queue) { _ in
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
    var makeElement: (() -> T)?
    private var items: [PoolItem<T>] = []
    private let queue: dispatch_queue_t         // protects items
    private let semaphore: dispatch_semaphore_t // limits the number of elements
    
    init(maximumCount: Int, makeElement: (() -> T)? = nil) {
        GRDBPrecondition(maximumCount > 0, "Pool size must be at least 1")
        self.makeElement = makeElement
        self.queue = dispatch_queue_create("GRDB.Pool", nil)
        self.semaphore = dispatch_semaphore_create(maximumCount)
    }
    
    /// Returns a tuple (element, releaseElement())
    /// Client MUST call releaseElement() after the element has been used.
    func get() -> (T, () -> ()) {
        let item = lockItem()
        return (item.element, { self.unlockItem(item) })
    }
    
    /// Performs a synchronous block with an element. The element turns
    /// available after the block has executed.
    func get<U>(@noescape block: (T) throws -> U) rethrows -> U {
        let (element, release) = get()
        defer { release() }
        return try block(element)
    }
    
    /// Performs a block on each pool element, available or not.
    /// The block is run is some arbitrary queue.
    func forEach(block: (T) throws -> ()) rethrows {
        try dispatchSync(queue) {
            for item in self.items {
                try block(item.element)
            }
        }
    }
    
    /// Empty the pool. Currently used items won't be reused.
    func clear() {
        clear {}
    }
    
    /// Empty the pool. Currently used items won't be reused.
    /// Eventual block is executed before any other element is dequeued.
    func clear(block: () throws -> ()) rethrows {
        try dispatchSync(queue) {
            self.items = []
            try block()
        }
    }
    
    private func lockItem() -> PoolItem<T> {
        var item: PoolItem<T>! = nil
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)
        dispatch_sync(queue) {
            if let index = self.items.indexOf({ $0.available }) {
                item = self.items[index]
                item.available = false
            } else {
                item = PoolItem(element: self.makeElement!(), available: false)
                self.items.append(item)
            }
        }
        return item
    }
    
    private func unlockItem(item: PoolItem<T>) {
        dispatch_sync(queue) {
            item.available = true
        }
        dispatch_semaphore_signal(semaphore)
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
