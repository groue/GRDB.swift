import Dispatch

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
    private class Item {
        let element: T
        var available: Bool
        
        init(element: T, available: Bool) {
            self.element = element
            self.available = available
        }
    }
    
    private let makeElement: () throws -> T
    private var items: ReadWriteBox<[Item]> = ReadWriteBox([])
    private let semaphore: DispatchSemaphore // limits the number of elements
    
    init(maximumCount: Int, makeElement: @escaping () throws -> T) {
        GRDBPrecondition(maximumCount > 0, "Pool size must be at least 1")
        self.makeElement = makeElement
        self.semaphore = DispatchSemaphore(value: maximumCount)
    }
    
    /// Returns a tuple (element, release)
    /// Client MUST call release() after the element has been used.
    func get() throws -> (T, () -> ()) {
        _ = semaphore.wait(timeout: .distantFuture)
        var item: Item! = nil
        do {
            try items.write { items in
                if let availableItem = items.first(where: { $0.available }) {
                    item = availableItem
                    item.available = false
                } else {
                    let element = try makeElement()
                    item = Item(element: element, available: false)
                    items.append(item)
                }
            }
        } catch {
            semaphore.signal()
            throw error
        }
        let release = {
            self.items.write { _ in
                // This is why Item is a class, not a struct: so that we can
                // release it without having to find in it the items array.
                item.available = true
            }
            self.semaphore.signal()
        }
        return (item.element, release)
    }
    
    /// Performs a synchronous block with an element. The element turns
    /// available after the block has executed.
    func get<U>(block: (T) throws -> U) throws -> U {
        let (element, release) = try get()
        defer { release() }
        return try block(element)
    }
    
    /// Performs a block on each pool element, available or not.
    /// The block is run is some arbitrary dispatch queue.
    func forEach(_ body: (T) throws -> ()) rethrows {
        try items.read { items in
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
        try items.write { items in
            items.removeAll()
            try block()
        }
    }
}
