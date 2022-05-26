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
    @ReadWriteBox private var items: [Item] = []
    private let itemsSemaphore: DispatchSemaphore // limits the number of elements
    private let itemsGroup: DispatchGroup         // knows when no element is used
    private let barrierQueue: DispatchQueue
    private let semaphoreWaitingQueue: DispatchQueue // Inspired by https://khanlou.com/2016/04/the-GCD-handbook/
    
    /// Creates a Pool.
    ///
    /// - parameters:
    ///     - maximumCount: The maximum number of elements.
    ///     - qos: The quality of service of asynchronous accesses.
    ///     - makeElement: A function that creates an element. It is called
    ///       on demand.
    init(
        maximumCount: Int,
        qos: DispatchQoS = .unspecified,
        makeElement: @escaping () throws -> T)
    {
        GRDBPrecondition(maximumCount > 0, "Pool size must be at least 1")
        self.makeElement = makeElement
        self.itemsSemaphore = DispatchSemaphore(value: maximumCount)
        self.itemsGroup = DispatchGroup()
        self.barrierQueue = DispatchQueue(label: "GRDB.Pool.barrier", qos: qos, attributes: [.concurrent])
        self.semaphoreWaitingQueue = DispatchQueue(label: "GRDB.Pool.wait", qos: qos)
    }
    
    /// Returns a tuple (element, release)
    /// Client must call release(), only once, after the element has been used.
    func get() throws -> (element: T, release: () -> Void) {
        try barrierQueue.sync {
            itemsSemaphore.wait()
            itemsGroup.enter()
            do {
                let item = try $items.update { items -> Item in
                    if let item = items.first(where: \.isAvailable) {
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
    
    /// Eventually produces a tuple (element, release), where element is
    /// intended to be used asynchronously.
    ///
    /// Client must call release(), only once, after the element has been used.
    ///
    /// - important: The `execute` argument is executed in a serial dispatch
    ///   queue, so make sure you use the element asynchronously.
    func asyncGet(_ execute: @escaping (Result<(element: T, release: () -> Void), Error>) -> Void) {
        // Inspired by https://khanlou.com/2016/04/the-GCD-handbook/
        // > We wait on the semaphore in the serial queue, which means that
        // > we’ll have at most one blocked thread when we reach maximum
        // > executing blocks on the concurrent queue. Any other tasks the user
        // > enqueues will sit inertly on the serial queue waiting to be
        // > executed, and won’t cause new threads to be started.
        semaphoreWaitingQueue.async {
            execute(Result { try self.get() })
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
        $items.update { _ in
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
        try $items.read { items in
            for item in items {
                try body(item.element)
            }
        }
    }
    
    /// Removes all elements from the pool.
    /// Currently used elements won't be reused.
    func removeAll() {
        items = []
    }
    
    /// Blocks until no element is used, and runs the `barrier` function before
    /// any other element is dequeued.
    func barrier<T>(execute barrier: () throws -> T) rethrows -> T {
        try barrierQueue.sync(flags: [.barrier]) {
            itemsGroup.wait()
            return try barrier()
        }
    }
    
    /// Asynchronously runs the `barrier` function when no element is used, and
    /// before any other element is dequeued.
    func asyncBarrier(execute barrier: @escaping () -> Void) {
        barrierQueue.async(flags: [.barrier]) {
            self.itemsGroup.wait()
            barrier()
        }
    }
}
