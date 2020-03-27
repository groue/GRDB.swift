import Dispatch

// MARK: - ValueScheduling

/// ValueObservationScheduling controls how ValueObservation schedules the
/// fresh values to your application.
enum ValueObservationScheduling {
    /// All values are asychronously notified on the main queue, but the initial
    /// one which is notified immediately when the start() method is called.
    case fetchWhenStarted
    
    /// All values are asychronously notified on the specified queue.
    case async(onDispatchQueue: DispatchQueue)
    
    var notificationQueue: DispatchQueue {
        switch self {
        case .fetchWhenStarted:
            return DispatchQueue.main
        case let .async(onDispatchQueue: queue):
            return queue
        }
    }
}

// MARK: - ValueObservation

/// ValueObservation tracks changes in the results of database requests, and
/// notifies fresh values whenever the database changes.
///
/// For example:
///
///     let observation = ValueObservation.tracking(Player.fetchAll)
///     let observer = try observation.start(
///         in: dbQueue,
///         onError: { error in ... },
///         onChange: { players: [Player] in
///             print("Players have changed.")
///         })
public struct ValueObservation<Reducer: _ValueReducer> {
    /// The reducer is created when observation starts, and is triggered upon
    /// each database change in *observedRegion*.
    var makeReducer: () -> Reducer
    
    /// `scheduling` controls how fresh values are notified. Default
    /// is `ValueObservationScheduling.async(onDispatchQueue: .main)`.
    var _scheduling = ValueObservationScheduling.async(onDispatchQueue: .main)
    
    /// Default is false. Set this property to true when the observation
    /// requires write access in order to fetch fresh values. Fetches are then
    /// wrapped inside a savepoint.
    ///
    /// Don't set this flag to true unless you really need it. A read/write
    /// observation is less efficient than a read-only observation.
    public var requiresWriteAccess: Bool = false
}

extension ValueObservation: KeyPathRefining {
    
    // MARK: - Scheduling
    
    /// Returns a ValueObservation which notifies fresh values on the given
    /// dispatch queue, asynchronously.
    ///
    /// For example:
    ///
    ///     let observation = ValueObservation
    ///         .tracking(Player.fetchAll)
    ///         .notify(onDispatchQueue: .main)
    ///
    /// Note that by default, ValueObservation notifies fresh values on the main
    /// dispatch queue, asynchronously.
    public func notify(onDispatchQueue queue: DispatchQueue) -> Self {
        with(\._scheduling, .async(onDispatchQueue: queue))
    }
    
    /// Returns a ValueObservation which notifies fresh values on the main
    /// dispatch queue. The initial value is notified immediately when the
    /// `start()` method is called. Subsequent values are
    /// notified asynchronously.
    ///
    /// For example:
    ///
    ///     let observation = ValueObservation
    ///         .tracking(Player.fetchAll)
    ///         .fetchWhenStarted()
    ///
    ///     let observer = try observation.start(
    ///         in: dbQueue,
    ///         onError: { error in ... },
    ///         onChange: { players: [Player] in
    ///             print("fresh players: \(players)")
    ///         })
    ///     // <- here "fresh players" is already printed.
    ///
    /// - important: Such an observation must be started from the main thread.
    ///   A fatal error is raised otherwise.
    public func fetchWhenStarted() -> Self {
        with(\._scheduling, .fetchWhenStarted)
    }
    
    // MARK: - Starting Observation
    
    /// Starts the value observation in the provided database reader (such as
    /// a database queue or database pool), and returns a transaction observer.
    ///
    /// - parameter reader: A DatabaseReader.
    /// - parameter onError: A closure that is provided eventual errors that
    /// happen during observation
    /// - parameter onChange: A closure that is provided fresh values
    /// - returns: a TransactionObserver
    public func start(
        in reader: DatabaseReader,
        onError: @escaping (Error) -> Void,
        onChange: @escaping (Reducer.Value) -> Void) -> TransactionObserver
    {
        return reader.add(observation: self, onError: onError, onChange: onChange)
    }
    
    // MARK: - Fetching Values
    
    // TODO: make public if it helps fetching an initial value before starting
    // the observation, in order to avoid waiting for long write transactions to
    // complete.
    /// Returns the value.
    func fetchValue(_ db: Database) throws -> Reducer.Value {
        var reducer = makeReducer()
        guard let value = try reducer.fetchAndReduce(db, requiringWriteAccess: requiresWriteAccess) else {
            fatalError("Contract broken: reducer has no initial value")
        }
        return value
    }
}

extension ValueObservation where Reducer == ValueReducers.Auto {
    
    // MARK: - Creating ValueObservation
    
    /// Creates a ValueObservation which notifies the values returned by the
    /// *fetch* function whenever a database transaction changes them.
    ///
    /// The *fetch* function must always performs the same database requests.
    /// The stability of the observed database region allows optimizations.
    ///
    /// When you want to observe a varying database region, use the
    /// `ValueObservation.trackingVaryingRegion(_:)` method instead.
    ///
    /// For example:
    ///
    ///     let observation = ValueObservation.tracking { db in
    ///         try Player.fetchAll(db)
    ///     }
    ///
    ///     let observer = try observation.start(
    ///         in: dbQueue,
    ///         onError: { error in ... },
    ///         onChange:) { players: [Player] in
    ///             print("Players have changed")
    ///         })
    ///
    /// - parameter fetch: A function that fetches the observed value from
    ///   the database.
    public static func tracking<Value>(
        _ fetch: @escaping (Database) throws -> Value)
        -> ValueObservation<ValueReducers.Fetch<Value>>
    {
        return ValueObservation<ValueReducers.Fetch<Value>>(makeReducer: {
            ValueReducers.Fetch(isObservedRegionDeterministic: true, fetch: fetch)
        })
    }
    
    /// Creates a ValueObservation which notifies the values returned by the
    /// *fetch* function whenever a database transaction changes them.
    ///
    /// - parameter fetch: A function that fetches the observed value from
    ///   the database.
    public static func trackingVaryingRegion<Value>(
        _ fetch: @escaping (Database) throws -> Value)
        -> ValueObservation<ValueReducers.Fetch<Value>>
    {
        return ValueObservation<ValueReducers.Fetch<Value>>(makeReducer: {
            ValueReducers.Fetch(isObservedRegionDeterministic: false, fetch: fetch)
        })
    }
}
