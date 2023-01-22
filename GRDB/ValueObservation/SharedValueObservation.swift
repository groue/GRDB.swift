import Foundation

/// The extent of the shared subscription to a ``SharedValueObservation``.
public enum SharedValueObservationExtent {
    /// The ``SharedValueObservation`` starts a single database observation,
    /// which stops when the `SharedValueObservation` is deallocated and all
    /// subscriptions terminated.
    ///
    /// This extent prevents the shared observation from recovering from
    /// database errors. To recover from database errors, you must create a new
    /// shared `SharedValueObservation` instance.
    case observationLifetime
    
    /// The ``SharedValueObservation`` stops database observation when the
    /// number of subscriptions drops down to zero. Database observation
    /// restarts on the next subscription.
    ///
    /// Database errors can be recovered by resubscribing to the
    /// shared observation.
    case whileObserved
}

extension ValueObservation {
    /// Returns a shared value observation that spares database resources by
    /// sharing a single underlying ``ValueObservation`` subscription.
    ///
    /// - note: [**🔥 EXPERIMENTAL**](https://github.com/groue/GRDB.swift/blob/master/README.md#what-are-experimental-features)
    ///
    /// For example:
    ///
    /// ```swift
    /// let observation = ValueObservation.tracking { db in
    ///     try Player.fetchAll(db)
    /// }
    ///
    /// let sharedObservation = observation.shared(in: dbQueue)
    ///
    /// let cancellable = try sharedObservation.start { error in
    ///     // handle error
    /// } onChange: { (players: [Player]) in
    ///     print("Fresh players: \(players)")
    /// }
    /// ```
    ///
    /// The underlying subscription is shared if and only if you start observing
    /// the database from the same `SharedValueObservation` instance:
    ///
    /// ```swift
    /// // Shared
    /// let sharedObservation = ValueObservation.tracking { db in ... }.shared(in: dbQueue)
    /// let cancellable1 = sharedObservation.start(...)
    /// let cancellable2 = sharedObservation.start(...)
    ///
    /// // NOT shared
    /// let cancellable1 = ValueObservation.tracking { db in ... }.shared(in: dbQueue).start(...)
    /// let cancellable2 = ValueObservation.tracking { db in ... }.shared(in: dbQueue).start(...)
    /// ```
    ///
    /// A shared observation starts observing the database as soon as it is
    /// subscribed. You can choose if database observation should stop, or not,
    /// when its number of subscriptions drops down to zero, with the `extent`
    /// parameter:
    ///
    /// ```swift
    /// // The default: stops observing the database when the number of
    /// // subscriptions drops down to zero, and restart database observation
    /// // on the next subscription.
    /// //
    /// // Database errors can be recovered by resubscribing to the
    /// // shared observation.
    /// let sharedObservation = ValueObservation
    ///     .tracking { db in try Player.fetchAll(db) }
    ///     .shared(in: dbQueue, extent: .whileObserved)
    ///
    /// // Only stops observing the database when the shared observation
    /// // is deinitialized, and all subscriptions are cancelled.
    /// //
    /// // This extent prevents the shared observation from recovering
    /// // from database errors. To recover from database errors, create a new
    /// // shared SharedValueObservation instance.
    /// let sharedObservation = ValueObservation
    ///     .tracking { db in try Player.fetchAll(db) }
    ///     .shared(in: dbQueue, extent: .observationLifetime)
    /// ```
    ///
    /// By default, fresh values are dispatched asynchronously on the
    /// main dispatch queue. You can change this behavior by providing a
    /// scheduler.
    ///
    /// For example, the ``ValueObservationScheduler/immediate`` scheduler
    /// notifies all values on the main dispatch queue, and notifies the first
    /// one immediately when the
    /// ``SharedValueObservation/start(onError:onChange:)`` method is called.
    /// The `immediate` scheduling requires that the observation starts from the
    /// main thread (a fatal error is raised otherwise):
    ///
    /// ```swift
    /// let observation = ValueObservation.tracking { db in
    ///     try Player.fetchAll(db)
    /// }
    ///
    /// let sharedObservation = observation.shared(
    ///     in: dbQueue,
    ///     scheduling: .immediate)
    ///
    /// let cancellable = try sharedObservation.start { error in
    ///     // handle error
    /// } onChange: { (players: [Player]) in
    ///     print("Fresh players: \(players)")
    /// }
    /// // <- here "Fresh players" is already printed.
    /// ```
    ///
    /// Note that the `.immediate` scheduler requires that the observation is
    /// subscribed from the main thread. It raises a fatal error otherwise.
    ///
    /// - parameter reader: A DatabaseReader.
    /// - parameter scheduler: A Scheduler. By default, fresh values are
    ///   dispatched asynchronously on the main queue.
    /// - parameter extent: The extent of the shared database observation.
    /// - returns: A `SharedValueObservation`
    public func shared(
        in reader: some DatabaseReader,
        scheduling scheduler: some ValueObservationScheduler = .async(onQueue: .main),
        extent: SharedValueObservationExtent = .whileObserved)
    -> SharedValueObservation<Reducer.Value>
    where Reducer: ValueReducer
    {
        SharedValueObservation(scheduling: scheduler, extent: extent) { onError, onChange in
            self.start(in: reader, scheduling: scheduler, onError: onError, onChange: onChange)
        }
    }
}

/// A shared value observation spares database resources by sharing a single
/// underlying ``ValueObservation`` subscription.
///
/// - note: [**🔥 EXPERIMENTAL**](https://github.com/groue/GRDB.swift/blob/master/README.md#what-are-experimental-features)
///
/// You build a `SharedValueObservation` with the ``ValueObservation`` method
/// ``ValueObservation/shared(in:scheduling:extent:)``. For example:
///
/// ```swift
/// let observation = ValueObservation.tracking { db in
///     try Player.fetchAll(db)
/// }
///
/// let sharedObservation = observation.shared(in: dbQueue)
///
/// let cancellable = try sharedObservation.start { error in
///     // handle error
/// } onChange: { (players: [Player]) in
///     print("Fresh players: \(players)")
/// }
/// ```
///
/// The underlying subscription is shared if and only if you start observing
/// the database from the same `SharedValueObservation` instance:
///
/// ```swift
/// // Shared
/// let sharedObservation = ValueObservation.tracking { db in ... }.shared(in: dbQueue)
/// let cancellable1 = sharedObservation.start(...)
/// let cancellable2 = sharedObservation.start(...)
///
/// // NOT shared
/// let cancellable1 = ValueObservation.tracking { db in ... }.shared(in: dbQueue).start(...)
/// let cancellable2 = ValueObservation.tracking { db in ... }.shared(in: dbQueue).start(...)
/// ```
public final class SharedValueObservation<Element> {
    private let scheduler: any ValueObservationScheduler
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
        scheduling scheduler: some ValueObservationScheduler,
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
    /// ```swift
    /// let sharedObservation = ValueObservation
    ///     .tracking { db in try Player.fetchAll(db) }
    ///     .shared(in: dbQueue)
    ///
    /// let cancellable = try sharedObservation.start { error in
    ///     // handle error
    /// } onChange: { (players: [Player]) in
    ///     print("fresh players: \(players)")
    /// }
    /// ```
    ///
    /// - parameter onError: The closure to execute when the observation fails.
    /// - parameter onChange: The closure to execute on receipt of a
    ///   fresh value.
    /// - returns: A DatabaseCancellable that can stop the observation.
    public func start(
        onError: @escaping (Error) -> Void,
        onChange: @escaping (Element) -> Void)
    -> AnyDatabaseCancellable
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
                cancellable = startObservation(
                    // onError
                    { [weak self] error in
                        self?.handleError(error)
                    },
                    // onChange
                    { [weak self] element in
                        self?.handleChange(element)
                    })
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
    /// Returns a publisher of observed values.
    ///
    /// For example:
    ///
    /// ```swift
    /// let observation = ValueObservation
    ///     .tracking { db in try Player.fetchAll(db) }
    ///     .shared(in: dbQueue)
    ///
    /// let publisher = observation.publisher()
    ///
    /// let cancellable = publisher.sink { completion in
    ///     // handle completion
    /// } receiveValue: { (players: [Player]) in
    ///     print("fresh players: \(players)")
    /// }
    /// ```
    @available(iOS 13, macOS 10.15, tvOS 13, watchOS 6, *)
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
    /// Returns an asynchronous sequence of observed values.
    ///
    /// - note: [**🔥 EXPERIMENTAL**](https://github.com/groue/GRDB.swift/blob/master/README.md#what-are-experimental-features)
    ///
    /// For example:
    ///
    /// ```swift
    /// let sharedObservation = ValueObservation
    ///     .tracking { db in try Player.fetchAll(db) }
    ///     .shared(in: dbQueue)
    ///
    /// for try await players in sharedObservation.values() {
    ///     print("Fresh players: \(players)")
    /// }
    /// ```
    @available(iOS 13, macOS 10.15, tvOS 13, watchOS 6, *)
    public func values(bufferingPolicy: AsyncValueObservation<Element>.BufferingPolicy = .unbounded)
    -> AsyncValueObservation<Element>
    {
        AsyncValueObservation(bufferingPolicy: bufferingPolicy) { onError, onChange in
            self.start(onError: onError, onChange: onChange)
        }
    }
}
