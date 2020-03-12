import Dispatch

// MARK: - ValueScheduling

/// ValueObservationScheduling controls how ValueObservation schedules the
/// fresh values to your application.
public enum ValueObservationScheduling {
    /// All values are notified on the main queue.
    ///
    /// If the observation starts on the main queue, the initial value is
    /// notified right upon subscription, synchronously:
    ///
    ///     // On main queue
    ///     let observation = Player.observationForAll()
    ///     let observer = try observation.start(in: dbQueue) { players: [Player] in
    ///         print("fresh players: \(players)")
    ///     }
    ///     // <- here "fresh players" is already printed.
    ///
    /// If the observation does not start on the main queue, the initial value
    /// is also notified on the main queue, but asynchronously:
    ///
    ///     // Not on the main queue: "fresh players" is eventually printed
    ///     // on the main queue.
    ///     let observation = Player.observationForAll()
    ///     let observer = try observation.start(in: dbQueue) { players: [Player] in
    ///         print("fresh players: \(players)")
    ///     }
    ///
    /// When the database changes, fresh values are asynchronously notified on
    /// the main queue:
    ///
    ///     // Eventually prints "fresh players" on the main queue
    ///     try dbQueue.write { db in
    ///         try Player(...).insert(db)
    ///     }
    case mainQueue
    
    /// All values are asychronously notified on the specified queue.
    case async(onQueue: DispatchQueue)
    
    /// Values are not all notified on the same dispatch queue.
    ///
    /// The initial value is notified right upon subscription, synchronously, on
    /// the dispatch queue which starts the observation.
    ///
    ///     // On any queue
    ///     var observation = Player.observationForAll()
    ///     observation.scheduling = .unsafe
    ///     let observer = try observation.start(in: dbQueue) { players: [Player] in
    ///         print("fresh players: \(players)")
    ///     }
    ///     // <- here "fresh players" is already printed.
    ///
    /// When the database changes, other values are notified on
    /// unspecified queues.
    case unsafe
}

// MARK: - ValueObservation

/// ValueObservation tracks changes in the results of database requests, and
/// notifies fresh values whenever the database changes.
///
/// For example:
///
///     let observation = Player.observationForAll()
///     let observer = try observation.start(in: dbQueue) { players: [Player] in
///         print("Players have changed.")
///     }
public struct ValueObservation<Reducer: _ValueReducer> {
    // TODO: all calls to this closure are followed by ignoringViews().
    // We should embed this ignoringViews() call.
    /// A closure that is evaluated when the observation starts, and returns
    /// a "base" observed database region.
    ///
    /// See also `observesSelectedRegion`
    var baseRegion: (Database) throws -> DatabaseRegion
    
    /// If true, the region selected by the reducer is observed as well
    /// as `baseRegion`.
    var observesSelectedRegion: Bool = false

    /// The reducer is created when observation starts, and is triggered upon
    /// each database change in *observedRegion*.
    var makeReducer: () -> Reducer
    
    /// Default is false. Set this property to true when the observation
    /// requires write access in order to fetch fresh values. Fetches are then
    /// wrapped inside a savepoint.
    ///
    /// Don't set this flag to true unless you really need it. A read/write
    /// observation is less efficient than a read-only observation.
    public var requiresWriteAccess: Bool = false
    
    /// `scheduling` controls how fresh values are notified. Default
    /// is `.mainQueue`.
    public var scheduling: ValueObservationScheduling = .mainQueue
}

extension ValueObservation {
    
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
    
    /// Fetches the observed value.
    ///
    /// - parameter db: A database connection.
    public func fetchValue(_ db: Database) throws -> Reducer.Value {
        var reducer = makeReducer()
        let fetchedValue = try reducer.fetch(db, requiringWriteAccess: requiresWriteAccess)
        guard let value = reducer.value(fetchedValue) else {
            fatalError("Contract broken: reducer has no initial value")
        }
        return value
    }
}

extension ValueObservation where Reducer == Never {
    
    // MARK: - Creating ValueObservation from Fetch Closures
    
    /// Creates a ValueObservation which notifies the values returned by the
    /// *fetch* closure whenever a database transaction changes them.
    ///
    /// For example:
    ///
    ///     let observation = ValueObservation.tracking { db in
    ///         try Player.fetchAll(db)
    ///     }
    ///
    ///     let observer = try observation.start(in: dbQueue) { players: [Player] in
    ///         print("Players have changed")
    ///     }
    ///
    /// - parameter value: A closure that fetches a value.
    public static func tracking<Value>(
        value: @escaping (Database) throws -> Value)
        -> ValueObservation<ValueReducers.Fetch<Value>>
    {
        return ValueObservation<ValueReducers.Fetch<Value>>(
            baseRegion: { _ in DatabaseRegion() },
            observesSelectedRegion: true,
            makeReducer: { ValueReducers.Fetch(value) })
    }
    
    /// Creates a ValueObservation which observes *regions*, and notifies the
    /// values returned by the *fetch* closure whenever one of the observed
    /// regions is modified by a database transaction.
    ///
    /// For example:
    ///
    ///     let observation = ValueObservation.tracking(
    ///         Player.all(),
    ///         fetch: { db in return try Player.fetchAll(db) })
    ///
    ///     let observer = try observation.start(in: dbQueue) { players: [Player] in
    ///         print("Players have changed")
    ///     }
    ///
    /// - parameter regions: A list of observed regions.
    /// - parameter fetch: A closure that fetches a value.
    public static func tracking<Value>(
        _ regions: DatabaseRegionConvertible...,
        fetch: @escaping (Database) throws -> Value)
        -> ValueObservation<ValueReducers.Fetch<Value>>
    {
        return ValueObservation.tracking(regions, fetch: fetch)
    }
    
    /// Creates a ValueObservation which observes *regions*, and notifies the
    /// values returned by the *fetch* closure whenever one of the observed
    /// regions is modified by a database transaction.
    ///
    /// For example:
    ///
    ///     let observation = ValueObservation.tracking(
    ///         [Player.all()],
    ///         fetch: { db in return try Player.fetchAll(db) })
    ///
    ///     let observer = try observation.start(in: dbQueue) { players: [Player] in
    ///         print("Players have changed")
    ///     }
    ///
    /// - parameter regions: A list of observed regions.
    /// - parameter fetch: A closure that fetches a value.
    public static func tracking<Value>(
        _ regions: [DatabaseRegionConvertible],
        fetch: @escaping (Database) throws -> Value)
        -> ValueObservation<ValueReducers.Fetch<Value>>
    {
        return ValueObservation<ValueReducers.Fetch<Value>>(
            baseRegion: DatabaseRegion.union(regions),
            makeReducer: { ValueReducers.Fetch(fetch) })
    }
}
