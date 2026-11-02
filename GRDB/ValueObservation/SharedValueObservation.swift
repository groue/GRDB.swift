import Foundation

/// The extent of the shared subscription to a ``SharedValueObservation``.
public enum SharedValueObservationExtent: Sendable {
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
    /// Returns a shared value observation that saves database resources by
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
    /// let cancellable = sharedObservation.start { error in
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
    /// For example, the ``ValueObservationMainActorScheduler/immediate``
    /// scheduler notifies all values on the main dispatch queue, and
    /// notifies the first one immediately when the
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
    /// let cancellable = sharedObservation.start { error in
    ///     // handle error
    /// } onChange: { (players: [Player]) in
    ///     print("Fresh players: \(players)")
    /// }
    /// // <- here "Fresh players" is already printed.
    /// ```
    ///
    /// - parameter reader: A DatabaseReader.
    /// - parameter scheduler: A Scheduler. By default, fresh values are
    ///   dispatched asynchronously on the main queue.
    /// - parameter extent: The extent of the shared database observation.
    /// - returns: A `SharedValueObservation`
    public func shared(
        in reader: any DatabaseReader,
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

/// A shared value observation saves database resources by sharing a single
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
/// let cancellable = sharedObservation.start { error in
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
public final class SharedValueObservation<Element: Sendable>: @unchecked Sendable {
    // @unchecked Sendable because state is protected by `lock`.
    private let scheduler: any ValueObservationScheduler
    private let extent: SharedValueObservationExtent
    private let startObservation: ValueObservationStart<Element>
    // Clients are notified outside of the lock, so that a client can be
    // cancelled from any thread during a notification without deadlock.
    private let lock = NSLock()
    
    // protected by lock
    private var clients: [Client]
    private var currentSubscription: ValueObservationSubscription? // nil when not observing
    private var lastResult: Result<Element, Error>?
    
    /// A subscription to the upstream ValueObservation.
    ///
    /// Events and cancellables of a subscription that is no longer
    /// the current one are ignored.
    private final class ValueObservationSubscription: @unchecked Sendable {
        // @unchecked Sendable because state is protected by
        // the lock of SharedValueObservation.
        var cancellable: AnyDatabaseCancellable?
    }
    
    private final class Client: Sendable {
        private let onError: @Sendable (Error) -> Void
        private let onChange: @Sendable (Element) -> Void
        private let stateMutex = Mutex(State())
        
        private struct State {
            var isCancelled = false
            /// True when a ValueObservation event was notified, and we must
            /// not notify the last result of the shared observation as the
            /// initial event.
            var shouldDiscardInitialResult = false
        }
        
        init(
            onError: @escaping @Sendable (Error) -> Void,
            onChange: @escaping @Sendable (Element) -> Void
        ) {
            self.onError = onError
            self.onChange = onChange
        }
        
        /// Notifies the last result of the shared observation as the initial
        /// value, unless a ValueObservation event was already notified.
        func notifyInitial(_ result: Result<Element, Error>) {
            guard shouldNotifyInitialResult() else { return }
            switch result {
            case let .failure(error):
                onError(error)
            case let .success(value):
                onChange(value)
            }
        }
        
        /// Notifies a ValueObservation event.
        func notifyChange(_ value: Element) {
            guard shouldNotifyValueObservationEvent() else { return }
            onChange(value)
        }
        
        /// Notifies a ValueObservation event.
        func notifyError(_ error: Error) {
            guard shouldNotifyValueObservationEvent() else { return }
            onError(error)
        }
        
        /// After this method returns, no new notification starts.
        func cancel() {
            stateMutex.withLock { $0.isCancelled = true }
        }
        
        /// Returns whether a ValueObservation event should be notified.
        private func shouldNotifyValueObservationEvent() -> Bool {
            stateMutex.withLock { state in
                if state.isCancelled { return false }
                // After a ValueObservation event, we must ignore the
                // initial result.
                state.shouldDiscardInitialResult = true
                return true
            }
        }
        
        /// Returns whether the initial result should be notified: the client
        /// is not cancelled, and the initial result should not be discarded.
        private func shouldNotifyInitialResult() -> Bool {
            stateMutex.withLock { state in
                !state.isCancelled && !state.shouldDiscardInitialResult
            }
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
    /// let cancellable = sharedObservation.start { error in
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
    @preconcurrency public func start(
        onError: @escaping @Sendable (Error) -> Void,
        onChange: @escaping @Sendable (Element) -> Void)
    -> AnyDatabaseCancellable
    {
        let client = Client(onError: onError, onChange: onChange)
        let (newSubscription, lastResult) = lock.withLock {
            // State change
            clients.append(client)
            
            // Support for reentrancy: a shared immediate observation is
            // started from the first value notification of that same shared
            // immediate observation. Yeah, users are nasty.
            // In this case, self.currentSubscription has no cancellable yet,
            // because we are still waiting for the upstream ValueObservation
            // to start. But we must not start another one.
            if currentSubscription != nil {
                return (ValueObservationSubscription?.none, self.lastResult)
            }
            let newSubscription = ValueObservationSubscription()
            currentSubscription = newSubscription
            return (newSubscription, nil)
        }
        
        // Side effect
        if let newSubscription {
            // Self retains the subscription and its cancellable, so don't have
            // the cancellable retain self or the subscription.
            let cancellable = startObservation(
                // onError
                { [weak self, weak newSubscription] error in
                    guard let newSubscription else { return }
                    self?.handleError(error, from: newSubscription)
                },
                // onChange
                { [weak self, weak newSubscription] element in
                    guard let newSubscription else { return }
                    self?.handleChange(element, from: newSubscription)
                })
            
            // The upstream observation may have been stopped, and maybe
            // replaced, while it was starting (for example, if the initial
            // fetch fails). In this case, discard its cancellable.
            let discardedCancellable: AnyDatabaseCancellable? = lock.withLock {
                guard currentSubscription === newSubscription else {
                    return cancellable
                }
                newSubscription.cancellable = cancellable
                return nil
            }
            discardedCancellable?.cancel()
        } else if let lastResult {
            // Notify last result as an initial value. A fresher result may
            // have been scheduled before, and already delivered to the
            // client: in this case, the last result is not notified.
            scheduler.scheduleInitial {
                client.notifyInitial(lastResult)
            }
        }
        
        return AnyDatabaseCancellable {
            // Retain shared observation (self) until client cancels
            self.handleCancel(client)
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
    public func publisher() -> DatabasePublishers.Value<Element> {
        DatabasePublishers.Value { onError, onChange in
            self.start(onError: onError, onChange: onChange)
        }
    }
#endif
    
    private func handleError(_ error: Error, from source: ValueObservationSubscription) {
        let (notifiedClients, stoppedCancellable) = lock.withLock {
            guard source === currentSubscription else {
                return ([Client](), AnyDatabaseCancellable?.none)
            }
            
            // State change
            let notifiedClients = clients
            var stoppedCancellable: AnyDatabaseCancellable?
            clients = []
            if extent == .whileObserved {
                stoppedCancellable = stopObservation()
            } else {
                lastResult = .failure(error)
            }
            
            return (notifiedClients, stoppedCancellable)
        }
        
        // Side effects
        stoppedCancellable?.cancel()
        for client in notifiedClients {
            client.notifyError(error)
        }
    }
    
    private func handleChange(_ value: Element, from source: ValueObservationSubscription) {
        let notifiedClients = lock.withLock {
            guard source === currentSubscription else {
                return [Client]()
            }
            
            // State change
            lastResult = .success(value)
            return clients
        }
        
        // Side effect
        for client in notifiedClients {
            client.notifyChange(value)
        }
    }
    
    private func handleCancel(_ client: Client) {
        // Prevent the client from being notified, even if a notification
        // is currently in progress.
        client.cancel()
        
        let stoppedCancellable = lock.withLock {
            // State change
            clients.removeFirst(where: { $0 === client })
            if clients.isEmpty && extent == .whileObserved {
                return stopObservation()
            }
            return nil
        }
        
        // Side effect
        stoppedCancellable?.cancel()
    }
    
    /// Stops the current upstream observation, and returns its cancellable,
    /// so that it can be cancelled outside of the lock.
    ///
    /// Must be called with the lock held.
    private func stopObservation() -> AnyDatabaseCancellable? {
        let stoppedCancellable = currentSubscription?.cancellable
        currentSubscription = nil
        lastResult = nil
        return stoppedCancellable
    }
}

extension SharedValueObservation {
    // MARK: - Asynchronous Observation
    /// Returns an asynchronous sequence of observed values.
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
    public func values(bufferingPolicy: AsyncValueObservation<Element>.BufferingPolicy = .unbounded)
    -> AsyncValueObservation<Element>
    {
        AsyncValueObservation(bufferingPolicy: bufferingPolicy) { onError, onChange in
            self.start(onError: onError, onChange: onChange)
        }
    }
}
