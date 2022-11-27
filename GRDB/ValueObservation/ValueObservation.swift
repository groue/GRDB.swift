#if canImport(Combine)
import Combine
#endif
import Dispatch
import Foundation

/// `ValueObservation` tracks changes in the results of database requests, and
/// notifies fresh values whenever the database changes.
///
/// ## Overview
///
/// Tracked changes are insertions, updates, and deletions that impact the
/// tracked value, whether performed with raw SQL, or <doc:QueryInterface>.
/// This includes indirect changes triggered by
/// [foreign keys actions](https://www.sqlite.org/foreignkeys.html#fk_actions)
/// or [SQL triggers](https://www.sqlite.org/lang_createtrigger.html).
///
/// Changes to internal system tables (such as `sqlite_master`) and changes to
/// [`WITHOUT ROWID`](https://www.sqlite.org/withoutrowid.html) tables are
/// not notified.
///
/// ## ValueObservation Usage
///
/// 1. Make sure that a unique database connection, ``DatabaseQueue`` or
/// ``DatabasePool``, is kept open during the whole duration of
/// the observation.
///
///     `ValueObservation` does not notify changes performed by
///     external connections.
///     See <doc:DatabaseSharing#How-to-perform-cross-process-database-observation>
///     for more information.
///
/// 2. Create a `ValueObservation` with a closure that fetches the
/// observed value:
///
///     ```swift
///     let observation = ValueObservation.tracking { db in
///         // Fetch and return the observed value
///     }
///
///     // For example, an observation of [Player], which tracks all players:
///     let observation = ValueObservation.tracking { db in
///         try Player.fetchAll(db)
///     }
///
///     // The same observation, using shorthand notation:
///     let observation = ValueObservation.tracking(Player.fetchAll)
///     ```
///
///     There is no limit on the values that can be observed. An observation
///     can perform multiple requests, from multiple database tables, and use
///     raw SQL. See ``tracking(_:)`` for some examples.
///
/// 3. Start the observation in order to be notified of changes:
///
///     ```swift
///     let cancellable = observation.start(in: dbQueue) { error in
///         // Handle error
///     } onChange: { (players: [Player]) in
///         print("Fresh players", players)
///     }
///     ```
///
/// 4. Stop the observation by calling the ``DatabaseCancellable/cancel()``
/// method on the object returned by the `start` method. Cancellation is
/// automatic when the cancellable is deallocated:
///
///     ```swift
///     cancellable.cancel()
///     ```
///
/// `ValueObservation` can also be turned into an async sequence, a Combine
/// publisher, or an RxSwift observable (see the companion library
/// [RxGRDB](https://github.com/RxSwiftCommunity/RxGRDB)):
///
/// - Async sequence:
///
///     ```swift
///     do {
///         for try await players in observation.values(in: dbQueue) {
///             print("Fresh players", players)
///         }
///     } catch {
///         // Handle error
///     }
///     ```
///
/// - Combine Publisher:
///
///     ```swift
///     let cancellable = observation.publisher(in: dbQueue).sink { completion in
///         // Handle completion
///     } receiveValue: { (players: [Player]) in
///         print("Fresh players", players)
///     }
///     ```
///
/// ## ValueObservation Behavior
///
/// `ValueObservation` notifies an initial value before the eventual changes.
///
/// `ValueObservation` only notifies changes committed to disk.
///
/// By default, `ValueObservation` notifies a fresh value whenever any component
/// of its fetched value is modified (any fetched column, row, etc.). This can
/// be configured:
/// see <doc:ValueObservation#Specifying-the-Tracked-Region>.
///
/// By default, `ValueObservation` notifies the initial value, as well as
/// eventual changes and errors, on the main dispatch queue, asynchronously.
/// This can be configured:
/// see <doc:ValueObservation#ValueObservation-Scheduling>.
///
/// `ValueObservation` may coalesce subsequent changes into a
/// single notification.
///
/// `ValueObservation` may notify consecutive identical values. You can filter
/// out the undesired duplicates with the ``removeDuplicates()`` method.
///
/// Starting an observation retains the database connection, until it is
/// stopped. As long as the observation is active, the database connection
/// won't be deallocated.
///
/// The database observation stops when the cancellable returned by the `start`
/// method is cancelled or deallocated, or if an error occurs.
///
/// Take care that there are use cases that `ValueObservation` is unfit for.
/// For example, an application may need to process absolutely all changes,
/// and avoid any coalescing. An application may also need to process changes
/// before any further modifications could be performed in the database file. In
/// those cases, the application needs to track *individual transactions*, not
/// values: use ``DatabaseRegionObservation``. If you need to process
/// changes before they are committed to disk, use ``TransactionObserver``.
///
/// ## ValueObservation Scheduling
///
/// By default, `ValueObservation` notifies the initial value, as well as
/// eventual changes and errors, on the main dispatch queue, asynchronously:
///
/// ```swift
/// // The default scheduling
/// let cancellable = observation.start(in: dbQueue) { error in
///     // Called asynchronously on the main dispatch queue
/// } onChange: { value in
///     // Called asynchronously on the main dispatch queue
///     print("Fresh value", value)
/// }
/// ```
///
/// You can change this behavior by adding a `scheduling` argument to the
/// `start()` method.
///
/// For example, the ``ValueObservationScheduler/immediate`` scheduler
/// notifies all values on the main dispatch queue, and notifies the first
/// one immediately when the observation starts.
///
/// It is very useful in graphic applications, because you can configure views
/// right away, without waiting for the initial value to be fetched eventually.
/// You don't have to implement any empty or loading screen, or to prevent some
/// undesired initial animation.
///
/// The `immediate` scheduling requires that the observation starts from the
/// main dispatch queue (a fatal error is raised otherwise):
///
/// ```swift
/// let cancellable = observation.start(in: dbQueue, scheduling: .immediate) { error in
///     // Called on the main dispatch queue
/// } onChange: { value in
///     // Called on the main dispatch queue
///     print("Fresh value", value)
/// }
/// // <- Here "Fresh value" has already been printed.
/// ```
///
/// The other built-in scheduler ``ValueObservationScheduler/async(onQueue:)``
/// asynchronously schedules values and errors on the dispatch queue of
/// your choice.
///
/// ## ValueObservation Sharing
///
/// Sharing a `ValueObservation` spares database resources. When a database
/// change happens, a fresh value is fetched only once, and then notified to
/// all clients of the shared observation.
///
/// You build a shared observation with ``shared(in:scheduling:extent:)``:
///
/// ```swift
/// // SharedValueObservation<[Player]>
/// let sharedObservation = ValueObservation
///     .tracking { db in try Player.fetchAll(db) }
///     .shared(in: dbQueue)
/// ```
///
/// `ValueObservation` and `SharedValueObservation` are nearly identical, but
/// the latter has no operator such as `map`. As a replacement, you may
/// for example use Combine apis:
///
/// ```swift
/// let cancellable = try sharedObservation
///     .publisher() // Turn shared observation into a Combine Publisher
///     .map { ... } // The map operator from Combine
///     .sink(...)
/// ```
///
///
/// ## Specifying the Tracked Region
///
/// While the standard ``tracking(_:)`` method lets you track changes to a
/// fetched value and receive any changes to it, sometimes your use case might
/// require more granular control.
///
/// Consider a scenario where you'd like to get a specific Player's row, but
/// only when their `score` column changes. You can use
/// ``tracking(region:fetch:)`` to do just that:
///
/// ```swift
/// let observation = ValueObservation.tracking(
///     // Define what database region constitutes a "change"
///     region: Player.select(Column("score")).filter(id: 1),
///     // Define what to fetch upon such change
///     fetch: { db in try Player.fetchOne(db, id: 1) }
/// )
/// ```
///
/// This overload of `ValueObservation` lets you entirely separate the
/// **observed region** from the **fetched value** itself, providing utmost
/// flexibility. See ``DatabaseRegionConvertible`` for more information about
/// the regions that can be tracked.
///
/// ## ValueObservation Performance
///
/// This section further describes runtime aspects of `ValueObservation`, and
/// provides some optimization tips for demanding applications.
///
/// **`ValueObservation` is triggered by database transactions that may modify
/// the tracked value.**
///
/// Precisely speaking, `ValueObservation` tracks changes in a
/// ``DatabaseRegion``, not changes in values.
///
/// For example, if you track the maximum score of players, all transactions
/// that impact the `score` column of the `player` database table (any update,
/// insertion, or deletion) trigger the observation, even if the maximum score
/// itself is not changed.
///
/// You can filter out undesired duplicate notifications with the
/// ``removeDuplicates()`` method.
///
/// **ValueObservation can create database contention.** In other words, active
/// observations take a toll on the constrained database resources. When
/// triggered by impactful transactions, observations fetch fresh values, and
/// can delay read and write database accesses of other application components.
///
/// When needed, you can help GRDB optimize observations and reduce
/// database contention:
///
/// > Tip: Stop observations when possible.
/// >
/// > For example, if a `UIViewController` needs to display database values, it
/// > can start the observation in `viewWillAppear`, and stop it in
/// > `viewWillDisappear`.
/// >
/// > In a SwiftUI application, you can profit from the
/// > [GRDBQuery](https://github.com/groue/GRDBQuery) companion library, and its
/// > [`View.queryObservation(_:)`](https://swiftpackageindex.com/groue/grdbquery/documentation/grdbquery/queryobservation)
/// > method.
///
/// > Tip: Share observations when possible.
/// >
/// > Each call to `ValueObservation.start` method triggers independent values
/// > refreshes. When several components of your app are interested in the same
/// > value, consider sharing the observation
/// > with ``shared(in:scheduling:extent:)``.
///
/// > Tip: Use a ``DatabasePool``, because it can perform multi-threaded
/// > database accesses.
///
/// > Tip: When the observation processes some raw fetched values, use the
/// > ``map(_:)`` operator:
/// >
/// > ```swift
/// > // Plain observation
/// > let observation = ValueObservation.tracking { db -> MyValue in
/// >     let players = try Player.fetchAll(db)
/// >     return computeMyValue(players)
/// > }
/// >
/// > // Optimized observation
/// > let observation = ValueObservation
/// >     .tracking { db try Player.fetchAll(db) }
/// >     .map { players in computeMyValue(players) }
/// > ```
/// >
/// > The `map` operator helps reducing database contention because it performs
/// > its job without blocking database accesses.
///
/// > Tip: When the observation tracks a constant database region, create an
/// > optimized observation with the ``trackingConstantRegion(_:)`` method. See
/// > the documentation of this method for more information about what
/// > constitutes a "constant region", and the nature of the optimization.
///
/// ## Topics
///
/// ### Creating a ValueObservation
///
/// - ``tracking(_:)``
/// - ``trackingConstantRegion(_:)``
/// - ``tracking(region:fetch:)``
/// - ``tracking(regions:fetch:)``
///
/// ### Creating a Shared Observation
///
/// - ``shared(in:scheduling:extent:)``
/// - ``SharedValueObservationExtent``
///
/// ### Accessing Observed Values
///
/// - ``publisher(in:scheduling:)``
/// - ``start(in:scheduling:onError:onChange:)``
/// - ``values(in:scheduling:bufferingPolicy:)``
/// - ``DatabaseCancellable``
/// - ``ValueObservationScheduler``
///
/// ### Mapping Values
///
/// - ``map(_:)``
///
/// ### Filtering Values
///
/// - ``removeDuplicates()``
/// - ``removeDuplicates(by:)``
///
/// ### Requiring Write Access
///
/// - ``requiresWriteAccess``
///
/// ### Debugging
///
/// - ``handleEvents(willStart:willFetch:willTrackRegion:databaseDidChange:didReceiveValue:didFail:didCancel:)``
/// - ``print(_:to:)``
///
/// ### Support
///
/// - ``ValueReducer``
public struct ValueObservation<Reducer: _ValueReducer> {
    var events = ValueObservationEvents()
    
    /// A boolean value indicating whether the observation requires write access
    /// when it fetches fresh values.
    ///
    /// The `requiresWriteAccess` property is false by default. When true, a
    /// `ValueObservation` has a write access to the database, and its fetches
    /// are automatically wrapped in a savepoint:
    ///
    /// ```swift
    /// var observation = ValueObservation.tracking { db in
    ///     // write access allowed
    ///     ...
    /// }
    /// observation.requiresWriteAccess = true
    /// ```
    ///
    /// Setting the `requiresWriteAccess` flag can disable scheduling
    /// optimizations when the observation is started in a ``DatabasePool``.
    public var requiresWriteAccess = false
    
    var trackingMode: ValueObservationTrackingMode
    
    /// The reducer is created when observation starts, and is triggered upon
    /// each database change.
    var makeReducer: () -> Reducer
    
    /// Returns a ValueObservation with a transformed reducer.
    func mapReducer<R>(_ transform: @escaping (Reducer) -> R) -> ValueObservation<R> {
        let makeReducer = self.makeReducer
        return ValueObservation<R>(
            events: events,
            requiresWriteAccess: requiresWriteAccess,
            trackingMode: trackingMode,
            makeReducer: { transform(makeReducer()) })
    }
}

/// Configures the tracked region
enum ValueObservationTrackingMode {
    /// The tracked region is constant and explicit.
    ///
    /// Use case:
    ///
    ///     // Tracked Region is always the full player table
    ///     ValueObservation.trackingConstantRegion(Player.all()) { db in ... }
    case constantRegion([any DatabaseRegionConvertible])
    
    /// The tracked region is constant and inferred from the fetched values.
    ///
    /// Use case:
    ///
    ///     // Tracked Region is always the full player table
    ///     ValueObservation.trackingConstantRegion { db in Player.fetchAll(db) }
    case constantRegionRecordedFromSelection
    
    /// The tracked region is not constant, and inferred from the fetched values.
    ///
    /// Use case:
    ///
    ///     // Tracked Region is the one row of the table, and it changes on
    ///     // each fetch.
    ///     ValueObservation.tracking { db in
    ///         try Player.fetchOne(db, id: Int.random(in: 1.1000))
    ///     }
    case nonConstantRegionRecordedFromSelection
}

struct ValueObservationEvents: Refinable {
    var willStart: (() -> Void)?
    var willTrackRegion: ((DatabaseRegion) -> Void)?
    var databaseDidChange: (() -> Void)?
    var didFail: ((Error) -> Void)?
    var didCancel: (() -> Void)?
}

typealias ValueObservationStart<T> = (
    _ onError: @escaping (Error) -> Void,
    _ onChange: @escaping (T) -> Void)
-> AnyDatabaseCancellable

extension ValueObservation: Refinable {
    
    // MARK: - Starting Observation
    
    /// Starts observing the database.
    ///
    /// The observation lasts until the returned cancellable is cancelled
    /// or deallocated.
    ///
    /// For example:
    ///
    /// ```swift
    /// let observation = ValueObservation.tracking { db in
    ///     try Player.fetchAll(db)
    /// }
    ///
    /// let cancellable = try observation.start(in: dbQueue) { error in
    ///     // handle error
    /// } onChange: { (players: [Player]) in
    ///     print("Fresh players: \(players)")
    /// }
    /// ```
    ///
    /// By default, fresh values are dispatched asynchronously on the
    /// main dispatch queue. You can change this behavior by providing a
    /// scheduler.
    ///
    /// For example, the ``ValueObservationScheduler/immediate`` scheduler
    /// notifies all values on the main dispatch queue, and notifies the first
    /// one immediately when the observation starts. The `immediate` scheduling
    /// requires that the observation starts from the main dispatch queue (a
    /// fatal error is raised otherwise):
    ///
    /// ```swift
    /// let cancellable = try observation.start(in: dbQueue, scheduling: .immediate) { error in
    ///     // handle error
    /// } onChange: { (players: [Player]) in
    ///     print("Fresh players: \(players)")
    /// }
    /// // <- here "Fresh players" is already printed.
    /// ```
    ///
    /// - parameter reader: A DatabaseReader.
    /// - parameter scheduler: A ValueObservationScheduler. By default, fresh
    ///   values are dispatched asynchronously on the main queue.
    /// - parameter onError: The closure to execute when the observation fails.
    /// - parameter onChange: The closure to execute on receipt of a
    ///   fresh value.
    /// - returns: A DatabaseCancellable that can stop the observation.
    public func start(
        in reader: some DatabaseReader,
        scheduling scheduler: ValueObservationScheduler = .async(onQueue: .main),
        onError: @escaping (Error) -> Void,
        onChange: @escaping (Reducer.Value) -> Void)
    -> AnyDatabaseCancellable
    where Reducer: ValueReducer
    {
        let observation = self.with {
            $0.events.didFail = concat($0.events.didFail, onError)
        }
        observation.events.willStart?()
        return reader._add(
            observation: observation,
            scheduling: scheduler,
            onChange: onChange)
    }
    
    // MARK: - Debugging
    
    /// Performs the specified closures when observation events occur.
    ///
    /// All closures run on unspecified dispatch queues: don't make
    /// any assumption.
    ///
    /// - parameters:
    ///     - willStart: The closure to execute when the observation starts.
    ///     - willFetch: The closure to execute when the observed value is
    ///       about to be fetched.
    ///     - willTrackRegion: The closure to execute when the observation
    ///       starts tracking a database region.
    ///     - databaseDidChange: The closure to execute after the observation
    ///       was impacted by a database change.
    ///     - didReceiveValue: The closure to execute on fresh values.
    ///     - didFail: The closure to execute when the observation fails.
    ///     - didCancel: The closure to execute when the observation is
    ///       cancelled.
    /// - returns: A `ValueObservation` that performs the specified closures
    ///   when ValueObservation events occur.
    public func handleEvents(
        willStart: (() -> Void)? = nil,
        willFetch: (() -> Void)? = nil,
        willTrackRegion: ((DatabaseRegion) -> Void)? = nil,
        databaseDidChange: (() -> Void)? = nil,
        didReceiveValue: ((Reducer.Value) -> Void)? = nil,
        didFail: ((Error) -> Void)? = nil,
        didCancel: (() -> Void)? = nil)
    -> ValueObservation<ValueReducers.Trace<Reducer>>
    {
        self
            .mapReducer { reducer in
                ValueReducers.Trace(
                    base: reducer,
                    // Adding the willFetch handler to the reducer is handy: we
                    // are sure not to miss any fetch.
                    willFetch: willFetch ?? { },
                    // Adding the didReceiveValue handler to the reducer is necessary:
                    // the type of the value may change with the `map` operator.
                    didReceiveValue: didReceiveValue ?? { _ in })
            }
            .with {
                $0.events.willStart = concat($0.events.willStart, willStart)
                $0.events.willTrackRegion = concat($0.events.willTrackRegion, willTrackRegion)
                $0.events.databaseDidChange = concat($0.events.databaseDidChange, databaseDidChange)
                $0.events.didFail = concat($0.events.didFail, didFail)
                $0.events.didCancel = concat($0.events.didCancel, didCancel)
            }
    }
    
    /// Prints log messages for all observation events.
    ///
    /// For example:
    ///
    /// ```swift
    /// let cancellable = ValueObservation
    ///     .tracking(Player.fetchCount)
    ///     .print("Observe player count")
    ///     .start(in: dbQueue, onError: { _ in }, onChange: { _ in })
    ///
    /// // Prints:
    /// // Observe player count: start
    /// // Observe player count: fetch
    /// // Observe player count: tracked region: player(*)
    /// // Observe player count: value: 0
    /// // Observe player count: database did change
    /// // Observe player count: fetch
    /// // Observe player count: value: 1
    /// ```
    ///
    /// - parameter prefix: A string —- which defaults to empty -— with which to
    ///   prefix all log messages.
    /// - parameter stream: A stream for text output that receives messages, and
    ///   which directs output to the console by default. A custom stream can be
    ///   used to log messages to other destinations.
    public func print(
        _ prefix: String = "",
        to stream: TextOutputStream? = nil)
    -> ValueObservation<ValueReducers.Trace<Reducer>>
    {
        let lock = NSLock()
        let prefix = prefix.isEmpty ? "" : "\(prefix): "
        var stream = stream ?? PrintOutputStream()
        return handleEvents(
            willStart: {
                lock.lock(); defer { lock.unlock() }
                stream.write("\(prefix)start") },
            willFetch: {
                lock.lock(); defer { lock.unlock() }
                stream.write("\(prefix)fetch") },
            willTrackRegion: {
                lock.lock(); defer { lock.unlock() }
                stream.write("\(prefix)tracked region: \($0)") },
            databaseDidChange: {
                lock.lock(); defer { lock.unlock() }
                stream.write("\(prefix)database did change") },
            didReceiveValue: {
                lock.lock(); defer { lock.unlock() }
                stream.write("\(prefix)value: \($0)") },
            didFail: {
                lock.lock(); defer { lock.unlock() }
                stream.write("\(prefix)failure: \($0)") },
            didCancel: {
                lock.lock(); defer { lock.unlock() }
                stream.write("\(prefix)cancel") })
    }
    
    // MARK: - Fetching Values
    
    /// Fetches the initial value.
    func fetchInitialValue(_ db: Database) throws -> Reducer.Value
    where Reducer: ValueReducer
    {
        var reducer = makeReducer()
        guard let value = try reducer._value(reducer._fetch(db)) else {
            fatalError("Broken contract: reducer has no initial value")
        }
        return value
    }
}

extension ValueObservation {
    // MARK: - Asynchronous Observation
    /// Returns an asynchronous sequence of observed values.
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
    /// for try await players in observation.values(in: dbQueue) {
    ///     print("Fresh players: \(players)")
    /// }
    /// ```
    ///
    /// - parameter reader: A DatabaseReader.
    /// - parameter scheduler: A ValueObservationScheduler. By default, fresh
    ///   values are dispatched asynchronously on the main dispatch queue.
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    public func values(
        in reader: some DatabaseReader,
        scheduling scheduler: ValueObservationScheduler = .async(onQueue: .main),
        bufferingPolicy: AsyncValueObservation<Reducer.Value>.BufferingPolicy = .unbounded)
    -> AsyncValueObservation<Reducer.Value>
    where Reducer: ValueReducer
    {
        AsyncValueObservation(bufferingPolicy: bufferingPolicy) { onError, onChange in
            self.start(in: reader, scheduling: scheduler, onError: onError, onChange: onChange)
        }
    }
}

/// An asynchronous sequence of values observed by a ``ValueObservation``.
///
/// - note: [**🔥 EXPERIMENTAL**](https://github.com/groue/GRDB.swift/blob/master/README.md#what-are-experimental-features)
///
/// An `AsyncValueObservation` sequence produces a fresh value whenever the
/// results of database requests change.
///
/// For example:
///
/// ```swift
/// let observation = ValueObservation.tracking { db in
///     try Player.fetchAll(db)
/// }
///
/// for try await players in observation.values(in: dbQueue) {
///     print("Fresh players: \(players)")
/// }
/// ```
///
/// You build an `AsyncValueObservation` from ``ValueObservation`` or
/// ``SharedValueObservation``.
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public struct AsyncValueObservation<Element>: AsyncSequence {
    public typealias BufferingPolicy = AsyncThrowingStream<Element, Error>.Continuation.BufferingPolicy
    public typealias AsyncIterator = Iterator
    
    var bufferingPolicy: BufferingPolicy
    var start: ValueObservationStart<Element>
    
    public func makeAsyncIterator() -> Iterator {
        // This cancellable will be retained by the Iterator, which itself will
        // be retained by the Swift async runtime.
        //
        // We must not retain this cancellable in any other way, in order to
        // cancel the observation when the Swift async runtime releases
        // the iterator.
        var cancellable: AnyDatabaseCancellable?
        let stream = AsyncThrowingStream(Element.self, bufferingPolicy: bufferingPolicy) { continuation in
            cancellable = start(
                // onError
                { error in
                    continuation.finish(throwing: error)
                },
                // onChange
                { [weak cancellable] element in
                    if case .terminated = continuation.yield(element) {
                        // TODO: I could never see this code running. Is it needed?
                        cancellable?.cancel()
                    }
                })
            continuation.onTermination = { @Sendable [weak cancellable] _ in
                cancellable?.cancel()
            }
        }
        
        let iterator = stream.makeAsyncIterator()
        if let cancellable = cancellable {
            return Iterator(
                iterator: iterator,
                cancellable: cancellable)
        } else {
            // GRDB bug: there is no point throwing any error.
            fatalError("Expected AsyncThrowingStream to have started the observation already")
        }
    }
    
    public struct Iterator: AsyncIteratorProtocol {
        var iterator: AsyncThrowingStream<Element, Error>.AsyncIterator
        let cancellable: AnyDatabaseCancellable
        
        public mutating func next() async throws -> Element? {
            try await iterator.next()
        }
    }
}

#if canImport(Combine)
extension ValueObservation {
    // MARK: - Publishing Observed Values
    
    /// Returns a publisher of observed values.
    ///
    /// For example:
    ///
    /// ```swift
    /// let observation = ValueObservation.tracking { db in
    ///     try Player.fetchAll(db)
    /// }
    ///
    /// let publisher = observation.publisher(in: dbQueue)
    ///
    /// let cancellable = publisher.sink { completion in
    ///     // handle completion
    /// } receiveValue: { (players: [Player]) in
    ///     print("Fresh players: \(players)")
    /// }
    /// ```
    ///
    /// By default, fresh values are dispatched asynchronously on the
    /// main dispatch queue. You can change this behavior by providing a
    /// scheduler.
    ///
    /// For example, the ``ValueObservationScheduler/immediate`` scheduler
    /// notifies all values on the main dispatch queue, and notifies the first
    /// one immediately when the observation starts. The `immediate` scheduling
    /// requires that the observation starts from the main dispatch queue (a
    /// fatal error is raised otherwise):
    ///
    /// ```swift
    /// let publisher = observation.publisher(in: dbQueue, scheduling: .immediate)
    ///
    /// let cancellable = publisher.sink { completion in
    ///     // handle completion
    /// } receiveValue: { (players: [Player]) in
    ///     print("Fresh players: \(players)")
    /// }
    /// // <- here "Fresh players" is already printed.
    /// ```
    ///
    /// - parameter reader: A DatabaseReader.
    /// - parameter scheduler: A ValueObservationScheduler. By default, fresh
    ///   values are dispatched asynchronously on the main dispatch queue.
    /// - returns: A Combine publisher
    @available(OSX 10.15, iOS 13, tvOS 13, watchOS 6, *)
    public func publisher(
        in reader: some DatabaseReader,
        scheduling scheduler: ValueObservationScheduler = .async(onQueue: .main))
    -> DatabasePublishers.Value<Reducer.Value>
    where Reducer: ValueReducer
    {
        DatabasePublishers.Value { (onError, onChange) in
            self.start(
                in: reader,
                scheduling: scheduler,
                onError: onError,
                onChange: onChange)
        }
    }
}

@available(OSX 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension DatabasePublishers {
    /// A publisher that publishes the values of a ``ValueObservation``.
    ///
    /// You build such a publisher from ``ValueObservation``
    /// or ``SharedValueObservation``.
    public struct Value<Output>: Publisher {
        public typealias Failure = Error
        private let start: ValueObservationStart<Output>
        
        init(start: @escaping ValueObservationStart<Output>) {
            self.start = start
        }
        
        public func receive<S>(subscriber: S) where S: Subscriber, Failure == S.Failure, Output == S.Input {
            let subscription = ValueSubscription(
                start: start,
                downstream: subscriber)
            subscriber.receive(subscription: subscription)
        }
    }
    
    private class ValueSubscription<Downstream: Subscriber>: Subscription
    where Downstream.Failure == Error
    {
        private struct WaitingForDemand {
            let downstream: Downstream
            let start: ValueObservationStart<Downstream.Input>
        }
        
        private struct Observing {
            let downstream: Downstream
            var remainingDemand: Subscribers.Demand
        }
        
        private enum State {
            /// Waiting for demand, not observing the database.
            case waitingForDemand(WaitingForDemand)
            
            /// Observing the database. Self.observer is not nil.
            case observing(Observing)
            
            /// Completed or cancelled, not observing the database.
            case finished
        }
        
        // Cancellable is not stored in self.state because we must enter the
        // .observing state *before* the observation starts, so that the user
        // can change the state even before the cancellable is known.
        private var cancellable: AnyDatabaseCancellable?
        private var state: State
        private var lock = NSRecursiveLock() // Allow re-entrancy
        
        init(
            start: @escaping ValueObservationStart<Downstream.Input>,
            downstream: Downstream)
        {
            state = .waitingForDemand(WaitingForDemand(
                downstream: downstream,
                start: start))
        }
        
        func request(_ demand: Subscribers.Demand) {
            lock.synchronized {
                switch state {
                case let .waitingForDemand(info):
                    guard demand > 0 else {
                        return
                    }
                    state = .observing(Observing(
                        downstream: info.downstream,
                        remainingDemand: demand))
                    let cancellable = info.start(
                        { [weak self] error in self?.receiveCompletion(.failure(error)) },
                        { [weak self] value in self?.receive(value) })
                    
                    // State may have been altered (error or cancellation)
                    switch state {
                    case .waitingForDemand:
                        preconditionFailure()
                    case .observing:
                        self.cancellable = cancellable
                    case .finished:
                        cancellable.cancel()
                    }
                    
                case var .observing(info):
                    info.remainingDemand += demand
                    state = .observing(info)
                    
                case .finished:
                    break
                }
            }
        }
        
        func cancel() {
            lock.synchronized { sideEffect in
                let cancellable = self.cancellable
                self.cancellable = nil
                self.state = .finished
                sideEffect = {
                    cancellable?.cancel()
                }
            }
        }
        
        private func receive(_ value: Downstream.Input) {
            lock.synchronized {
                if case let .observing(info) = state,
                   info.remainingDemand > .none
                {
                    let additionalDemand = info.downstream.receive(value)
                    if case var .observing(info) = state {
                        info.remainingDemand += additionalDemand
                        info.remainingDemand -= 1
                        state = .observing(info)
                    }
                }
            }
        }
        
        private func receiveCompletion(_ completion: Subscribers.Completion<Error>) {
            lock.synchronized { sideEffect in
                if case let .observing(info) = state {
                    cancellable = nil
                    state = .finished
                    sideEffect = {
                        info.downstream.receive(completion: completion)
                    }
                }
            }
        }
    }
}
#endif

extension ValueObservation {
    
    // MARK: - Creating ValueObservation
    
    /// Creates an optimized `ValueObservation` that notifies the fetched value
    /// whenever it changes.
    ///
    /// The optimization reduces database contention by not blocking database
    /// writes when the fresh value is fetched.
    ///
    /// The optimization is only applied when the observation is started from a
    /// ``DatabasePool``. You can start such an observation from a
    /// ``DatabaseQueue``, but the optimization will not be applied.
    ///
    /// **Precondition**: The `fetch` function must perform requests that fetch
    /// from a single and constant database region. This region is made of
    /// tables, columns, and rowids of individual rows. All changes that happen
    /// outside of this region are not notified.
    ///
    /// For example, the observations below track a constant region and can
    /// be optimized:
    ///
    /// ```swift
    /// // Tracks the full 'player' table
    /// let observation = ValueObservation.trackingConstantRegion { db -> [Player] in
    ///     try Player.fetchAll(db)
    /// }
    ///
    /// // Tracks the row with id 42 in the 'player' table
    /// let observation = ValueObservation.trackingConstantRegion { db -> Player? in
    ///     try Player.fetchOne(db, key: 42)
    /// }
    ///
    /// // Tracks the 'score' column in the 'player' table
    /// let observation = ValueObservation.trackingConstantRegion { db -> Int? in
    ///     try Player.select(max(Column("score"))).fetchOne(db)
    /// }
    ///
    /// // Tracks both the 'player' and 'team' tables
    /// let observation = ValueObservation.trackingConstantRegion { db -> ([Team], [Player]) in
    ///     let teams = try Team.fetchAll(db)
    ///     let players = try Player.fetchAll(db)
    ///     return (teams, players)
    /// }
    /// ```
    ///
    /// Observations that do not track a constant region must not use this
    /// method. Use ``tracking(_:)`` instead, or else some changes will not
    /// be notified.
    ///
    /// For example, the observations below do not track a constant region, and
    /// must not be optimized:
    ///
    /// ```swift
    /// // Does not always track the same row in the player table.
    /// let observation = ValueObservation.tracking { db -> Player? in
    ///     let pref = try Preference.fetchOne(db) ?? .default
    ///     return try Player.fetchOne(db, id: pref.favoritePlayerId)
    /// }
    ///
    /// // Does not always track the 'user' table.
    /// let observation = ValueObservation.tracking { db -> [User] in
    ///     let pref = try Preference.fetchOne(db) ?? .default
    ///     let playerIds: [Int64] = pref.favoritePlayerIds // may be empty
    ///     return try Player.fetchAll(db, ids: playerIds)
    /// }
    ///
    /// // Sometimes tracks the 'food' table, and sometimes the 'beverage' table.
    /// let observation = ValueObservation.tracking { db -> Int in
    ///     let pref = try Preference.fetchOne(db) ?? .default
    ///     switch pref.selection {
    ///     case .food: return try Food.fetchCount(db)
    ///     case .beverage: return try Beverage.fetchCount(db)
    ///     }
    /// }
    /// ```
    ///
    /// You can turn them into optimized observations of a constant region with
    /// the ``Database/registerAccess(to:)`` method:
    ///
    /// ```swift
    /// let observation = ValueObservation.trackingConstantRegion { db -> Player? in
    ///     // Track all players so that the observed region does not depend on
    ///     // the rowid of the favorite player.
    ///     try db.registerAccess(to: Player.all())
    ///
    ///     let pref = try Preference.fetchOne(db) ?? .default
    ///     return try Player.fetchOne(db, id: pref.favoritePlayerId)
    /// }
    ///
    /// let observation = ValueObservation.trackingConstantRegion { db -> [User] in
    ///     // Track all players so that the observed region does not change
    ///     // even if there is no favorite player at all.
    ///     try db.registerAccess(to: Player.all())
    ///
    ///     let pref = try Preference.fetchOne(db) ?? .default
    ///     let playerIds: [Int64] = pref.favoritePlayerIds // may be empty
    ///     return try Player.fetchAll(db, ids: playerIds)
    /// }
    ///
    /// let observation = ValueObservation.trackingConstantRegion { db -> Int in
    ///     // Track foods and beverages so that the observed region does not
    ///     // depend on preferences.
    ///     try db.registerAccess(to: Food.all())
    ///     try db.registerAccess(to: Beverage.all())
    ///
    ///     let pref = try Preference.fetchOne(db) ?? .default
    ///     switch pref.selection {
    ///     case .food: return try Food.fetchCount(db)
    ///     case .beverage: return try Beverage.fetchCount(db)
    ///     }
    /// }
    /// ```
    ///
    /// - parameter fetch: The closure that fetches the observed value.
    public static func trackingConstantRegion<Value>(
        _ fetch: @escaping (Database) throws -> Value)
    -> Self
    where Reducer == ValueReducers.Fetch<Value>
    {
        .init(
            trackingMode: .constantRegionRecordedFromSelection,
            makeReducer: { ValueReducers.Fetch(fetch: fetch) })
    }
    
    /// Creates a `ValueObservation` that notifies the fetched value whenever
    /// the provided regions are modified.
    ///
    /// Only database transactions that impact the provided regions trigger the
    /// notification of fresh values.
    ///
    /// For example:
    ///
    /// ```swift
    /// // Tracks the full database
    /// let observation = ValueObservation.tracking
    ///     region: .fullDatabase,
    ///     fetch: { db in ... })
    ///
    /// // Tracks the full 'player' table
    /// let observation = ValueObservation.tracking
    ///     region: Player.all(),
    ///     fetch: { db in ... })
    ///
    /// // Tracks the full 'player' table
    /// let observation = ValueObservation.tracking
    ///     region: Table("player"),
    ///     fetch: { db in ... })
    ///
    /// // Tracks the row with id 42 in the 'player' table
    /// let observation = ValueObservation.tracking
    ///     region: Player.filter(id: 42),
    ///     fetch: { db in ... })
    ///
    /// // Tracks the 'score' column in the 'player' table
    /// let observation = ValueObservation.tracking
    ///     region: Player.select(Column("score"),
    ///     fetch: { db in ... })
    ///
    /// // Tracks the 'score' column in the 'player' table
    /// let observation = ValueObservation.tracking
    ///     region: SQLRequest("SELECT score FROM player"),
    ///     fetch: { db in ... })
    ///
    /// // Tracks both the 'player' and 'team' tables
    /// let observation = ValueObservation.tracking
    ///     region: Player.all(), Team.all(),
    ///     fetch: { db in ... })
    /// ```
    ///
    /// - parameter region: A list of observed regions.
    /// - parameter fetch: The closure that fetches the observed value.
    public static func tracking<Value>(
        region: any DatabaseRegionConvertible...,
        fetch: @escaping (Database) throws -> Value)
    -> Self
    where Reducer == ValueReducers.Fetch<Value>
    {
        tracking(regions: region, fetch: fetch)
    }
    
    /// Creates a `ValueObservation` that notifies the fetched value whenever
    /// the provided regions are modified.
    ///
    /// Only database transactions that impact the provided regions trigger the
    /// notification of fresh values.
    ///
    /// For example:
    ///
    /// ```swift
    /// // Tracks the full database
    /// let observation = ValueObservation.tracking
    ///     regions: [.fullDatabase],
    ///     fetch: { db in ... })
    ///
    /// // Tracks the full 'player' table
    /// let observation = ValueObservation.tracking
    ///     regions: [Player.all()],
    ///     fetch: { db in ... })
    ///
    /// // Tracks the full 'player' table
    /// let observation = ValueObservation.tracking
    ///     regions: [Table("player")],
    ///     fetch: { db in ... })
    ///
    /// // Tracks the row with id 42 in the 'player' table
    /// let observation = ValueObservation.tracking
    ///     regions: [Player.filter(id: 42)],
    ///     fetch: { db in ... })
    ///
    /// // Tracks the 'score' column in the 'player' table
    /// let observation = ValueObservation.tracking
    ///     regions: [Player.select(Column("score")],
    ///     fetch: { db in ... })
    ///
    /// // Tracks the 'score' column in the 'player' table
    /// let observation = ValueObservation.tracking
    ///     regions: [SQLRequest("SELECT score FROM player")],
    ///     fetch: { db in ... })
    ///
    /// // Tracks both the 'player' and 'team' tables
    /// let observation = ValueObservation.tracking
    ///     regions: [Player.all(), Team.all()],
    ///     fetch: { db in ... })
    /// ```
    ///
    /// - parameter regions: An array of observed regions.
    /// - parameter fetch: The closure that fetches the observed value.
    public static func tracking<Value>(
        regions: [any DatabaseRegionConvertible],
        fetch: @escaping (Database) throws -> Value)
    -> Self
    where Reducer == ValueReducers.Fetch<Value>
    {
        .init(
            trackingMode: .constantRegion(regions),
            makeReducer: { ValueReducers.Fetch(fetch: fetch) })
    }
    
    /// Creates a `ValueObservation` that notifies the fetched values whenever
    /// it changes.
    ///
    /// For example:
    ///
    /// ```swift
    /// let observation = ValueObservation.tracking { db in
    ///     try Player.fetchAll(db)
    /// }
    ///
    /// let cancellable = try observation.start(in: dbQueue) { error in
    ///     // handle error
    /// } onChange: { (players: [Player]) in
    ///     print("Players have changed")
    /// }
    /// ```
    ///
    /// An observation can perform multiple requests, from multiple database
    /// tables, and even use raw SQL:
    ///
    /// ```swift
    /// struct HallOfFame {
    ///     var totalPlayerCount: Int
    ///     var bestPlayers: [Player]
    /// }
    ///
    /// // An observation of HallOfFame
    /// let observation = ValueObservation.tracking { db -> HallOfFame in
    ///     let totalPlayerCount = try Player.fetchCount(db)
    ///
    ///     let bestPlayers = try Player
    ///         .order(Column("score").desc)
    ///         .limit(10)
    ///         .fetchAll(db)
    ///
    ///     return HallOfFame(
    ///         totalPlayerCount: totalPlayerCount,
    ///         bestPlayers: bestPlayers)
    /// }
    ///
    /// // An observation of the maximum score
    /// let observation = ValueObservation.tracking { db in
    ///     try Int.fetchOne(db, sql: "SELECT MAX(score) FROM player")
    /// }
    /// ```
    ///
    /// - parameter fetch: The closure that fetches the observed value.
    public static func tracking<Value>(
        _ fetch: @escaping (Database) throws -> Value)
    -> Self
    where Reducer == ValueReducers.Fetch<Value>
    {
        .init(
            trackingMode: .nonConstantRegionRecordedFromSelection,
            makeReducer: { ValueReducers.Fetch(fetch: fetch) })
    }
}
