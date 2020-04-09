import Dispatch

/// ValueObservation tracks changes in the results of database requests, and
/// notifies fresh values whenever the database changes.
///
/// For example:
///
///     let observation = ValueObservation.tracking { db in
///         try Player.fetchAll(db)
///     }
///
///     let cancellable = try observation.start(
///         in: dbQueue,
///         onError: { error in ... },
///         onChange: { players: [Player] in
///             print("Players have changed.")
///         })
public struct ValueObservation<Reducer: _ValueReducer> {
    /// The reducer is created when observation starts, and is triggered upon
    /// each database change.
    var makeReducer: () -> Reducer
    
    /// Default is false. Set this property to true when the observation
    /// requires write access in order to fetch fresh values. Fetches are then
    /// wrapped inside a savepoint.
    ///
    /// Don't set this flag to true unless you really need it. A read/write
    /// observation is less efficient than a read-only observation.
    public var requiresWriteAccess: Bool = false
    
    /// Returns a ValueObservation with a transformed reducer.
    func mapReducer<R>(_ transform: @escaping (Reducer) -> R) -> ValueObservation<R> {
        let makeReducer = self.makeReducer
        return ValueObservation<R>(
            makeReducer: { transform(makeReducer()) },
            requiresWriteAccess: requiresWriteAccess)
    }
}

extension ValueObservation {
    
    // MARK: - Starting Observation
    
    /// Starts the value observation in the provided database reader (such as
    /// a database queue or database pool).
    ///
    /// The observation lasts until the returned cancellable is cancelled
    /// or deallocated.
    ///
    /// For example:
    ///
    ///     let observation = ValueObservation.tracking { db in
    ///         try Player.fetchAll(db)
    ///     }
    ///
    ///     let cancellable = try observation.start(
    ///         in: dbQueue,
    ///         onError: { error in ... },
    ///         onChange: { players: [Player] in
    ///             print("fresh players: \(players)")
    ///         })
    ///
    /// By default, fresh values are dispatched asynchronously on the
    /// main queue. You can change this behavior by providing a scheduler.
    /// For example, `.immediate` notifies all values on the main queue as well,
    /// and the first one is immediately notified when the start() method
    /// is called:
    ///
    ///     let cancellable = try observation.start(
    ///         in: dbQueue,
    ///         scheduling: .immediate, // <-
    ///         onError: { error in ... },
    ///         onChange: { players: [Player] in
    ///             print("fresh players: \(players)")
    ///         })
    ///     // <- here "fresh players" is already printed.
    ///
    /// - parameter reader: A DatabaseReader.
    /// - parameter scheduler: A Scheduler. By default, fresh values are
    ///   dispatched asynchronously on the main queue.
    /// - parameter onError: A closure that is provided eventual errors that
    ///   happen during observation
    /// - parameter onChange: A closure that is provided fresh values
    /// - returns: a DatabaseCancellable
    public func start(
        in reader: DatabaseReader,
        scheduling scheduler: ValueObservationScheduler = .async(onQueue: .main),
        onError: @escaping (Error) -> Void,
        onChange: @escaping (Reducer.Value) -> Void) -> DatabaseCancellable
    {
        reader._add(observation: self, scheduling: scheduler, onError: onError, onChange: onChange)
    }
    
    // MARK: - Fetching Values
    
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
    ///     let cancellable = try observation.start(
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
        ValueObservation<ValueReducers.Fetch<Value>>(makeReducer: {
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
        ValueObservation<ValueReducers.Fetch<Value>>(makeReducer: {
            ValueReducers.Fetch(isObservedRegionDeterministic: false, fetch: fetch)
        })
    }
}
