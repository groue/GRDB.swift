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
    ///     let observer = try observation.start(
    ///         in: dbQueue,
    ///         onError: { error in ... },
    ///         onChange: { players: [Player] in
    ///             print("fresh players: \(players)")
    ///         })
    ///     // <- here "fresh players" is already printed.
    ///
    /// If the observation does not start on the main queue, the initial value
    /// is also notified on the main queue, but asynchronously:
    ///
    ///     // Not on the main queue: "fresh players" is eventually printed
    ///     // on the main queue.
    ///     let observation = Player.observationForAll()
    ///     let observer = try observation.start(
    ///         in: dbQueue,
    ///         onError: { error in ... },
    ///         onChange: { players: [Player] in
    ///             print("fresh players: \(players)")
    ///         })
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
    ///     let observer = try observation.start(
    ///         in: dbQueue,
    ///         onError: { error in ... },
    ///         onChange: { players: [Player] in
    ///           print("fresh players: \(players)")
    ///        })
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
