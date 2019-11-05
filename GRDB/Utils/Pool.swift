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
        var isAvailable: Bool
        
        init(element: T, isAvailable: Bool) {
            self.element = element
            self.isAvailable = isAvailable
        }
    }
    
    private let makeElement: () throws -> T
    private var items: ReadWriteBox<[Item]> = ReadWriteBox(value: [])
    private let itemsSemaphore: DispatchSemaphore // limits the number of elements
    private let itemsGroup: DispatchGroup         // knows when no element is used
    private let barrierQueue: DispatchQueue
    
    init(maximumCount: Int, makeElement: @escaping () throws -> T) {
        GRDBPrecondition(maximumCount > 0, "Pool size must be at least 1")
        self.makeElement = makeElement
        self.itemsSemaphore = DispatchSemaphore(value: maximumCount)
        self.itemsGroup = DispatchGroup()
        self.barrierQueue = DispatchQueue(label: "GRDB.Pool.barrier", attributes: [.concurrent])
    }
    
    /// Returns a tuple (element, release)
    /// Client must call release(), only once, after the element has been used.
    func get() throws -> (element: T, release: () -> Void) {
        return try barrierQueue.sync {
            itemsSemaphore.wait()
            itemsGroup.enter()
            do {
                let item = try items.write { items -> Item in
                    if let item = items.first(where: { $0.isAvailable }) {
                        item.isAvailable = false
                        return item
                    } else {
                        let element = try makeElement()
                        let item = Item(element: element, isAvailable: false)
                        items.append(item)
                        return item
                    }
                }
                return (element: item.element, release: { self.release(item) })
            } catch {
                itemsSemaphore.signal()
                itemsGroup.leave()
                throw error
            }
        }
    }
    
    /// Performs a synchronous block with an element. The element turns
    /// available after the block has executed.
    func get<U>(block: (T) throws -> U) throws -> U {
        let (element, release) = try get()
        defer { release() }
        return try block(element)
    }
    
    private func release(_ item: Item) {
        items.write { _ in
            // This is why Item is a class, not a struct: so that we can
            // release it without having to find in it the items array.
            item.isAvailable = true
        }
        itemsSemaphore.signal()
        itemsGroup.leave()
    }
    
    /// Performs a block on each pool element, available or not.
    /// The block is run is some arbitrary dispatch queue.
    func forEach(_ body: (T) throws -> Void) rethrows {
        try items.read { items in
            for item in items {
                try body(item.element)
            }
        }
    }
    
    /// Removes all elements from the pool.
    /// Currently used elements won't be reused.
    func removeAll() {
        items.write {
            $0.removeAll()
        }
    }
    
    /// Blocks until no element is used, and runs the `barrier` function before
    /// any other element is dequeued.
    func barrier<T>(execute barrier: () throws -> T) rethrows -> T {
        return try barrierQueue.sync(flags: [.barrier]) {
            itemsGroup.wait()
            return try barrier()
        }
    }
}
