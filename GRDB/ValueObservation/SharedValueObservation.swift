import Foundation

/// Controls the extent of the shared database observation
/// of `SharedValueObservation`.
public enum SharedValueObservationExtent {
    /// The `SharedValueObservation` starts a single database observation, which
    /// ends when the `SharedValueObservation` is deallocated and all
    /// subscriptions terminated.
    ///
    /// This extent prevents the shared observation from recovering from
    /// database errors. To recover from database errors, create a new shared
    /// `SharedValueObservation` instance.
    case observationLifetime
    
    /// The `SharedValueObservation` ends database observation when the number
    /// of subscriptions drops down to zero. The database observation restarts
    /// on the next subscription.
    ///
    /// Database errors can be recovered by resubscribing to the
    /// shared observation.
    case whileObserved
}

extension ValueObservation {
    /// Returns a shared value observation that shares a single underlying
    /// database observation for all subscriptions, and thus spares
    /// database resources.
    ///
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    /// 
    /// For example:
    ///
    ///     let sharedObservation = ValueObservation
    ///         .tracking { db in try Player.fetchAll(db) }
    ///         .shared(in: dbQueue)
    ///
    /// The sharing only applies if you start observing the database from the
    /// same `SharedValueObservation` instance:
    ///
    ///     // NOT shared
    ///     let cancellable1 = ValueObservation.tracking { db in ... }.shared(in: dbQueue).start(...)
    ///     let cancellable2 = ValueObservation.tracking { db in ... }.shared(in: dbQueue).start(...)
    ///
    ///     // Shared
    ///     let sharedObservation = ValueObservation.tracking { db in ... }.shared(in: dbQueue)
    ///     let cancellable1 = sharedObservation.start(...)
    ///     let cancellable2 = sharedObservation.start(...)
    ///
    /// By default, fresh values are dispatched asynchronously on the
    /// main queue. You can change this behavior by providing a scheduler.
    /// For example, `.immediate` notifies all values on the main queue as well,
    /// and the first one is immediately notified when the start() method
    /// is called:
    ///
    ///     let sharedObservation = ValueObservation
    ///         .tracking { db in try Player.fetchAll(db) }
    ///         .shared(
    ///             in: dbQueue,
    ///             scheduling: .immediate) // <-
    ///
    ///     let cancellable = try sharedObservation.start(
    ///         onError: { error in ... },
    ///         onChange: { players: [Player] in
    ///             print("fresh players: \(players)")
    ///         })
    ///     // <- here "fresh players" is already printed.
    ///
    /// Note that the `.immediate` scheduler requires that the observation is
    /// subscribed from the main thread. It raises a fatal error otherwise.
    ///
    /// A shared observation starts observing the database as soon as it is
    /// subscribed. You can choose if database observation should stop, or not,
    /// when its number of subscriptions drops down to zero, with the `extent`
    /// parameter. See `SharedValueObservationExtent` for available options.
    ///
    /// - parameter reader: A DatabaseReader.
    /// - parameter scheduler: A Scheduler. By default, fresh values are
    ///   dispatched asynchronously on the main queue.
    /// - parameter extent: The extent of the shared database observation.
    /// - returns: A `SharedValueObservation`
    public func shared(
        in reader: DatabaseReader,
        scheduling scheduler: ValueObservationScheduler = .async(onQueue: .main),
        extent: SharedValueObservationExtent = .whileObserved)
    -> SharedValueObservation<Reducer.Value>
    {
        SharedValueObservation(scheduling: scheduler, extent: extent) { onError, onChange in
            self.start(in: reader, scheduling: scheduler, onError: onError, onChange: onChange)
        }
    }
}

/// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
///
/// A shared value observation that shares a single underlying database
/// observation for all subscriptions, and thus spares database resources.
///
/// For example:
///
///     let sharedObservation = ValueObservation
///         .tracking { db in try Player.fetchAll(db) }
///         .shared(in: dbQueue)
///
///     let cancellable = try sharedObservation.start(
///         onError: { error in ... },
///         onChange: { players: [Player] in
///             print("Players have changed.")
///         })
///
/// The sharing only applies if you start observing the database from the
/// same `SharedValueObservation` instance:
///
///     // NOT shared
///     let cancellable1 = ValueObservation.tracking { db in ... }.shared(in: dbQueue).start(...)
///     let cancellable2 = ValueObservation.tracking { db in ... }.shared(in: dbQueue).start(...)
///
///     // Shared
///     let sharedObservation = ValueObservation.tracking { db in ... }.shared(in: dbQueue)
///     let cancellable1 = sharedObservation.start(...)
///     let cancellable2 = sharedObservation.start(...)
public final class SharedValueObservation<Element> {
    private let scheduler: ValueObservationScheduler
    private let extent: SharedValueObservationExtent
    private let startObservation: ValueObservationStart<Element>
    private let lock = NSRecursiveLock() // support synchronous observation events
    
    // protected by lock
    private var clients: [Client]
    private var isObserving = false
    private var cancellable: AnyDatabaseCancellable?
    private var lastResult: Result<Element, Error>?
    
    private final class Client {
        var onError: (Error) -> Void
        var onChange: (Element) -> Void
        
        init(onError: @escaping (Error) -> Void, onChange: @escaping (Element) -> Void) {
            self.onError = onError
            self.onChange = onChange
        }
    }
    
    fileprivate init(
        scheduling scheduler: ValueObservationScheduler,
        extent: SharedValueObservationExtent,
        startObservation: @escaping ValueObservationStart<Element>)
    {
        self.scheduler = scheduler
        self.extent = extent
        self.startObservation = startObservation
        self.clients = []
    }
    
    /// Starts observing the database.
    ///
    /// The observation lasts until the returned cancellable is cancelled
    /// or deallocated.
    ///
    /// For example:
    ///
    ///     let sharedObservation = ValueObservation
    ///         .tracking { db in try Player.fetchAll(db) }
    ///         .shared(in: dbQueue)
    ///
    ///     let cancellable = try sharedObservation.start(
    ///         onError: { error in ... },
    ///         onChange: { players: [Player] in
    ///             print("fresh players: \(players)")
    ///         })
    ///
    /// - parameter onError: A closure that is provided eventual errors that
    ///   happen during observation
    /// - parameter onChange: A closure that is provided fresh values
    /// - returns: a DatabaseCancellable
    public func start(
        onError: @escaping (Error) -> Void,
        onChange: @escaping (Element) -> Void)
    -> DatabaseCancellable
    {
        synchronized {
            // Support for reentrancy: a shared immediate observation is
            // started from the first value notification of that same shared
            // immediate observation. Yeah, users are nasty.
            // In this case, self.cancellable is still nil, because we are
            // still waiting for the upstream ValueObservation to start.
            // But we must not start another one.
            let needsStart = !isObserving
            
            // State change
            let client = Client(onError: onError, onChange: onChange)
            clients.append(client)
            isObserving = true
            
            // Side effect
            if needsStart {
                // Self retains the cancellable, so don't have the cancellable retain self.
                cancellable = AnyDatabaseCancellable(startObservation(
                    // onError
                    { [weak self] error in
                        self?.handleError(error)
                    },
                    // onChange
                    { [weak self] element in
                        self?.handleChange(element)
                    }))
            } else if let result = lastResult {
                // Notify last result as an initial value
                scheduler.scheduleInitial {
                    switch result {
                    case let .failure(error):
                        onError(error)
                    case let .success(value):
                        onChange(value)
                    }
                }
            }
            
            return AnyDatabaseCancellable {
                // Retain shared observation (self) until client cancels
                self.handleCancel(client)
            }
        }
    }
    
#if canImport(Combine)
    /// Creates a publisher which tracks changes in database values.
    ///
    /// For example:
    ///
    ///     let publisher = ValueObservation
    ///         .tracking { db in try Player.fetchAll(db) }
    ///         .shared(in: dbQueue)
    ///         .publisher()
    ///
    ///     let cancellable = publisher.sink(
    ///         receiveCompletion: { completion in ... },
    ///         receiveValue: { players: [Player] in
    ///             print("fresh players: \(players)")
    ///         })
    ///
    /// - returns: A Combine publisher
    @available(OSX 10.15, iOS 13, tvOS 13, watchOS 6, *)
    public func publisher() -> DatabasePublishers.Value<Element> {
        DatabasePublishers.Value { onError, onChange in
            self.start(onError: onError, onChange: onChange)
        }
    }
#endif
    
    private func handleError(_ error: Error) {
        synchronized {
            let notifiedClients = clients
            
            // State change
            clients = []
            if extent == .whileObserved {
                isObserving = false
                cancellable = nil
                lastResult = nil
            } else {
                lastResult = .failure(error)
            }
            
            // Side effect
            for client in notifiedClients {
                client.onError(error)
            }
        }
    }
    
    private func handleChange(_ value: Element) {
        synchronized {
            // State change
            lastResult = .success(value)
            
            // Side effect
            for client in clients {
                client.onChange(value)
            }
        }
    }
    
    private func handleCancel(_ client: Client) {
        synchronized {
            // State change
            clients.removeFirst(where: { $0 === client })
            if clients.isEmpty && extent == .whileObserved {
                isObserving = false
                cancellable = nil
                lastResult = nil
            }
        }
    }
    
    private func synchronized<T>(_ execute: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try execute()
    }
}

extension SharedValueObservation {
    // MARK: - Asynchronous Observation
    /// The database observation, as an asynchronous sequence of
    /// database changes.
    ///
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    public func values(bufferingPolicy: AsyncValueObservation<Element>.BufferingPolicy = .unbounded)
    -> AsyncValueObservation<Element>
    {
        AsyncValueObservation(bufferingPolicy: bufferingPolicy) { onError, onChange in
            self.start(onError: onError, onChange: onChange)
        }
    }
}
