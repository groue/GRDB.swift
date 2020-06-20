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
    var events = ValueObservationEvents<Reducer.Value>()
    
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

struct ValueObservationEvents<Value>: Refinable {
    var onStart: (() -> Void)?
    var onTrackedRegion: ((DatabaseRegion) -> Void)?
    var onDatabaseChange: (() -> Void)?
    var onValue: ((Value) -> Void)?
    var onError: ((Error) -> Void)?
    var onCancel: (() -> Void)?
}

extension ValueObservation: Refinable {
    
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
        let observation = map(\.events) { eventHandler in
            eventHandler
                .map(\.onValue, appendHandler(onChange))
                .map(\.onError, appendHandler(onError))
        }
        observation.events.onStart?()
        return reader._add(observation: observation, scheduling: scheduler)
    }
    
    // MARK: - Debugging
    
    /// Performs the specified closures when ValueObservation events occur.
    ///
    /// - parameters:
    ///     - onStart: A closure that executes when the observation starts.
    ///       Defaults to `nil`.
    ///     - onTrackedRegion: A closure that executes when the observation
    ///       starts tracking a database region. Defaults to `nil`.
    ///     - onDatabaseChange: A closure that executes after the observation
    ///       was impacted by a database change. Defaults to `nil`.
    ///     - onFetch: A closure that executes when the observed value is
    ///       fetched. Defaults to `nil`.
    ///     - onValue: A closure that executes when the observation notifies a
    ///       fresh value. Defaults to `nil`.
    ///     - onError: A closure that executes when the observation fails.
    ///       Defaults to `nil`.
    ///     - onCancel: A closure that executes when the observation is
    ///       cancelled. Defaults to `nil`.
    /// - returns: A `ValueObservation` that performs the specified closures
    ///   when ValueObservation events occur.
    public func handleEvents(
        onStart: (() -> Void)? = nil,
        onTrackedRegion: ((DatabaseRegion) -> Void)? = nil,
        onDatabaseChange: (() -> Void)? = nil,
        onFetch: (() -> Void)? = nil,
        onValue: ((Reducer.Value) -> Void)? = nil,
        onError: ((Error) -> Void)? = nil,
        onCancel: (() -> Void)? = nil)
        -> ValueObservation<ValueReducers.Trace<Reducer>>
    {
        self
            .mapReducer { ValueReducers.Trace(base: $0, onFetch: onFetch ?? { }) }
            .map(\.events) { eventHandler in
                eventHandler
                    .map(\.onStart, appendHandler(onStart))
                    .map(\.onTrackedRegion, appendHandler(onTrackedRegion))
                    .map(\.onDatabaseChange, appendHandler(onDatabaseChange))
                    .map(\.onValue, appendHandler(onValue))
                    .map(\.onError, appendHandler(onError))
                    .map(\.onCancel, appendHandler(onCancel))
        }
    }
    
    /// Prints log messages for all ValueObservation events.
    public func print(
        _ prefix: String = "",
        to stream: TextOutputStream? = nil)
        -> ValueObservation<ValueReducers.Trace<Reducer>>
    {
        let prefix = prefix.isEmpty ? "" : "\(prefix): "
        var stream = stream ?? PrintOutputStream()
        return handleEvents(
            onStart: { stream.write("\(prefix)start") },
            onTrackedRegion: { stream.write("\(prefix)tracked region: \($0)") },
            onDatabaseChange: { stream.write("\(prefix)database did change") },
            onFetch: { stream.write("\(prefix)fetch") },
            onValue: { stream.write("\(prefix)value: \($0)") },
            onError: { stream.write("\(prefix)error: \($0)") },
            onCancel: { stream.write("\(prefix)cancel") })
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
        .init(makeReducer: { .init(isSelectedRegionDeterministic: true, fetch: fetch) })
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
        .init(makeReducer: { .init(isSelectedRegionDeterministic: false, fetch: fetch) })
    }
}
