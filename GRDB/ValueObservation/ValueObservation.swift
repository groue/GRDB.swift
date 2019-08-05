import Dispatch

// MARK: - ValueScheduling

/// ValueScheduling controls how ValueObservation schedules the notifications
/// of fresh values to your application.
public enum ValueScheduling {
    /// All values are notified on the main queue.
    ///
    /// If the observation starts on the main queue, an initial value is
    /// notified right upon subscription, synchronously:
    ///
    ///     // On main queue
    ///     let observation = Player.observationForAll()
    ///     let observer = try observation.start(in: dbQueue) { players: [Player] in
    ///         print("fresh players: \(players)")
    ///     }
    ///     // <- here "fresh players" is already printed.
    ///
    /// If the observation does not start on the main queue, an initial value
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
    ///
    /// An initial value is fetched and notified if `startImmediately`
    /// is true.
    case async(onQueue: DispatchQueue, startImmediately: Bool)
    
    /// Values are not all notified on the same dispatch queue.
    ///
    /// If `startImmediately` is true, an initial value is notified right upon
    /// subscription, synchronously, on the dispatch queue which starts
    /// the observation.
    ///
    ///     // On any queue
    ///     var observation = Player.observationForAll()
    ///     observation.scheduling = .unsafe(startImmediately: true)
    ///     let observer = try observation.start(in: dbQueue) { players: [Player] in
    ///         print("fresh players: \(players)")
    ///     }
    ///     // <- here "fresh players" is already printed.
    ///
    /// When the database changes, other values are notified on
    /// unspecified queues.
    case unsafe(startImmediately: Bool)
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
public struct ValueObservation<Reducer> {
    /// A closure that is evaluated when the observation starts, and returns
    /// a "base" observed database region.
    ///
    /// See also `observesSelectedRegion`
    var baseRegion: (Database) throws -> DatabaseRegion
    
    /// If true, the region selected by the reducer is observed as well
    /// as `baseRegion`.
    var observesSelectedRegion: Bool

    /// The reducer is created when observation starts, and is triggered upon
    /// each database change in *observedRegion*.
    var makeReducer: (Database) throws -> Reducer
    
    /// Default is false. Set this property to true when the observation
    /// requires write access in order to fetch fresh values. Fetches are then
    /// wrapped inside a savepoint.
    ///
    /// Don't set this flag to true unless you really need it. A read/write
    /// observation is less efficient than a read-only observation.
    public var requiresWriteAccess: Bool
    
    /// `scheduling` controls how fresh values are notified. Default
    /// is `.mainQueue`.
    ///
    /// - `.mainQueue`: all values are notified on the main queue.
    ///
    ///     If the observation starts on the main queue, an initial value is
    ///     notified right upon subscription, synchronously::
    ///
    ///         // On main queue
    ///         let observation = Player.observationForAll()
    ///         let observer = try observation.start(in: dbQueue) { players: [Player] in
    ///             print("fresh players: \(players)")
    ///         }
    ///         // <- here "fresh players" is already printed.
    ///
    ///     If the observation does not start on the main queue, an initial
    ///     value is also notified on the main queue, but asynchronously:
    ///
    ///         // Not on the main queue: "fresh players" is eventually printed
    ///         // on the main queue.
    ///         let observation = Player.observationForAll()
    ///         let observer = try observation.start(in: dbQueue) { players: [Player] in
    ///             print("fresh players: \(players)")
    ///         }
    ///
    ///     When the database changes, fresh values are asynchronously notified:
    ///
    ///         // Eventually prints "fresh players" on the main queue
    ///         try dbQueue.write { db in
    ///             try Player(...).insert(db)
    ///         }
    ///
    /// - `.onQueue(_:startImmediately:)`: all values are asychronously notified
    /// on the specified queue.
    ///
    ///     An initial value is fetched and notified if `startImmediately`
    ///     is true.
    ///
    /// - `unsafe(startImmediately:)`: values are not all notified on the same
    /// dispatch queue.
    ///
    ///     If `startImmediately` is true, an initial value is notified right
    ///     upon subscription, synchronously, on the dispatch queue which starts
    ///     the observation.
    ///
    ///         // On any queue
    ///         var observation = Player.observationForAll()
    ///         observation.scheduling = .unsafe(startImmediately: true)
    ///         let observer = try observation.start(in: dbQueue) { players: [Player] in
    ///             print("fresh players: \(players)")
    ///         }
    ///         // <- here "fresh players" is already printed.
    ///
    ///     When the database changes, other values are notified on
    ///     unspecified queues.
    public var scheduling: ValueScheduling
}

extension ValueObservation where Reducer: ValueReducer {
    
    // MARK: - Starting Observation
    
    /// Starts the value observation in the provided database reader (such as
    /// a database queue or database pool), and returns a transaction observer.
    ///
    /// - parameter reader: A DatabaseReader.
    /// - parameter onChange: A closure that is provided fresh values
    /// - returns: a TransactionObserver
    public func start(
        in reader: DatabaseReader,
        onChange: @escaping (Reducer.Value) -> Void) throws -> TransactionObserver
    {
        // ErrorCatcher is a workaround this aging API.
        // We catch the eventual error synchronously sent to the onError
        // handler and rethrow it.
        let errorCatcher = ErrorCatcher()
        let observer = reader.add(
            observation: self,
            onError: { [weak errorCatcher] in errorCatcher?.error = $0 },
            onChange: onChange)
        if let error = errorCatcher.error {
            throw error
        }
        return observer
    }
    
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
    
    /// Returns the observed value.
    ///
    /// This method returns nil if observation would not notify any
    /// initial value.
    ///
    /// For example, the observation below notifies changes to a player if and
    /// only if it exists:
    ///
    ///     let observation = Player.filter(key: 42)
    ///         .observationForFirst()
    ///         .compactMap { $0 } // filters out missing player
    ///
    /// The `fetchFirst` method thus returns nil if player does not exist:
    ///
    ///     let player: Player? = try dbQueue.read { db in
    ///         try observation.fetchFirst(db)
    ///     }
    func fetchFirst(_ db: Database) throws -> Reducer.Value? {
        var reducer = try makeReducer(db)
        return try reducer.value(reducer.fetch(db, requiringWriteAccess: requiresWriteAccess))
    }
}

// TODO: remove when not needed any longer
private class ErrorCatcher {
    var error: Error?
}

extension ValueObservation where Reducer: ValueReducer {
    
    // MARK: - Creating ValueObservation from ValueReducer
    
    /// Returns a ValueObservation which observes *regions*, and notifies the
    /// values returned by the *reducer* whenever one of the observed
    /// regions is modified by a database transaction.
    ///
    /// This method is the most fundamental way to create a ValueObservation.
    ///
    /// For example, this observation counts the number of a times the player
    /// table is modified:
    ///
    ///     var count = 0
    ///     let reducer = AnyValueReducer(
    ///         fetch: { _ in /* don't fetch anything */ },
    ///         value: { _ -> Int? in
    ///             defer { count += 1 }
    ///             return count })
    ///     let observation = ValueObservation.tracking(Player.all(), reducer: { db in reducer })
    ///     let observer = observation.start(in: dbQueue) { count: Int in
    ///         print("Players have been modified \(count) times.")
    ///     }
    ///
    /// The returned observation has the default configuration:
    ///
    /// - When started with the `start(in:onError:onChange:)` method, a fresh
    /// value is immediately notified on the main queue.
    /// - Upon subsequent database changes, fresh values are notified on the
    /// main queue.
    /// - The observation lasts until the observer returned by
    /// `start` is deallocated.
    ///
    /// - parameter regions: A list of observed regions.
    /// - parameter reducer: A reducer that turns database changes in the
    /// modified regions into fresh values. Currently only reducers that adopt
    /// the ValueReducer protocol are supported.
    public static func tracking(
        _ regions: DatabaseRegionConvertible...,
        reducer: @escaping (Database) throws -> Reducer)
        -> ValueObservation
    {
        return ValueObservation.tracking(regions, reducer: reducer)
    }
    
    /// Returns a ValueObservation which observes *regions*, and notifies the
    /// values returned by the *reducer* whenever one of the observed
    /// regions is modified by a database transaction.
    ///
    /// This method is the most fundamental way to create a ValueObservation.
    ///
    /// For example, this observation counts the number of a times the player
    /// table is modified:
    ///
    ///     var count = 0
    ///     let reducer = AnyValueReducer(
    ///         fetch: { _ in /* don't fetch anything */ },
    ///         value: { _ -> Int? in
    ///             defer { count += 1 }
    ///             return count })
    ///     let observation = ValueObservation.tracking([Player.all()], reducer: { db in reducer })
    ///     let observer = observation.start(in: dbQueue) { count: Int in
    ///         print("Players have been modified \(count) times.")
    ///     }
    ///
    /// The returned observation has the default configuration:
    ///
    /// - When started with the `start(in:onError:onChange:)` method, a fresh
    /// value is immediately notified on the main queue.
    /// - Upon subsequent database changes, fresh values are notified on the
    /// main queue.
    /// - The observation lasts until the observer returned by
    /// `start` is deallocated.
    ///
    /// - parameter regions: A list of observed regions.
    /// - parameter reducer: A reducer that turns database changes in the
    /// modified regions into fresh values. Currently only reducers that adopt
    /// the ValueReducer protocol are supported.
    public static func tracking(
        _ regions: [DatabaseRegionConvertible],
        reducer: @escaping (Database) throws -> Reducer)
        -> ValueObservation
    {
        return ValueObservation(
            baseRegion: DatabaseRegion.union(regions),
            observesSelectedRegion: false,
            makeReducer: reducer,
            requiresWriteAccess: false,
            scheduling: .mainQueue)
    }
}

extension ValueObservation where Reducer == Void {
    
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
    /// The returned observation has the default configuration:
    ///
    /// - When started with the `start(in:onError:onChange:)` method, a fresh
    /// value is immediately notified on the main queue.
    /// - Upon subsequent database changes, fresh values are notified on the
    /// main queue.
    /// - The observation lasts until the observer returned by
    /// `start` is deallocated.
    ///
    /// - parameter value: A closure that fetches a value.
    public static func tracking<Value>(
        value: @escaping (Database) throws -> Value)
        -> ValueObservation<ValueReducers.Fetch<Value>>
    {
        return ValueObservation<ValueReducers.Fetch<Value>>(
            baseRegion: { _ in DatabaseRegion() },
            observesSelectedRegion: true,
            makeReducer: { _ in ValueReducers.Fetch(value) },
            requiresWriteAccess: false,
            scheduling: .mainQueue)
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
    /// The returned observation has the default configuration:
    ///
    /// - When started with the `start(in:onError:onChange:)` method, a fresh
    /// value is immediately notified on the main queue.
    /// - Upon subsequent database changes, fresh values are notified on the
    /// main queue.
    /// - The observation lasts until the observer returned by
    /// `start` is deallocated.
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
    /// The returned observation has the default configuration:
    ///
    /// - When started with the `start(in:onError:onChange:)` method, a fresh
    /// value is immediately notified on the main queue.
    /// - Upon subsequent database changes, fresh values are notified on the
    /// main queue.
    /// - The observation lasts until the observer returned by
    /// `start` is deallocated.
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
            observesSelectedRegion: false,
            makeReducer: { _ in ValueReducers.Fetch(fetch) },
            requiresWriteAccess: false,
            scheduling: .mainQueue)
    }
}
