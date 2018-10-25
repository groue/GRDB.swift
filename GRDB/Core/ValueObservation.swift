//
//  ValueObservation.swift
//  GRDB
//
//  Created by Gwendal Roué on 23/10/2018.
//  Copyright © 2018 Gwendal Roué. All rights reserved.
//

/// InitialDispatch controls how initial values are dispatched when one starts
/// observing database values.
public enum InitialDispatch {
    /// Initial values are not fetched, and not notified.
    case none
    
    /// Initial values are immediately fetched, and notified on the current dispatch queue.
    case immediateOnCurrentQueue
    
    /// Initial values are immediately fetched, and asynchronously notified.
    case asynchronous
}

/// The database transaction observer, generic on the type of fetched values.
private class ValuesObserver<T>: TransactionObserver {
    private let region: DatabaseRegion
    private let future: () -> Future<T>
    private let queue: DispatchQueue
    private let onChange: (T) -> Void
    private let onError: ((Error) -> Void)?
    private let notificationQueue = DispatchQueue(label: "ValuesObserver")
    private var changed = false
    
    init(
        region: DatabaseRegion,
        future: @escaping () -> Future<T>,
        queue: DispatchQueue,
        onError: ((Error) -> Void)?,
        onChange: @escaping (T) -> Void)
    {
        self.region = region
        self.future = future
        self.queue = queue
        self.onChange = onChange
        self.onError = onError
    }
    
    func observes(eventsOfKind eventKind: DatabaseEventKind) -> Bool {
        return region.isModified(byEventsOfKind: eventKind)
    }
    
    func databaseDidChange(with event: DatabaseEvent) {
        if region.isModified(by: event) {
            changed = true
            stopObservingDatabaseChangesUntilNextTransaction()
        }
    }
    
    func databaseDidCommit(_ db: Database) {
        guard changed else {
            return
        }
        
        changed = false
        
        // Fetch future results now...
        let future = self.future()
        
        // ...but wait for them in notificationQueue, which guarantees
        // that notifications have the same ordering as transactions.
        notificationQueue.async { [weak self] in
            guard let strongSelf = self else { return }
            
            do {
                // block notificationQueue until the concurrent fetch is done
                let result = try future.wait()
                strongSelf.queue.async {
                    guard let strongSelf = self else { return }
                    strongSelf.onChange(result)
                }
            } catch {
                strongSelf.queue.async {
                    guard let strongSelf = self else { return }
                    strongSelf.onError?(error)
                }
            }
        }
    }
    
    func databaseDidRollback(_ db: Database) {
        changed = false
    }
}

extension DatabaseWriter {
    /// TODO
    public func add<Value>(observation: ValueObservation<Value>) throws -> TransactionObserver {
        // Will be set and notified on the caller queue if initialDispatch is .immediateOnCurrentQueue
        var immediateValue: Value? = nil
        defer {
            if let immediateValue = immediateValue {
                observation.onChange(immediateValue)
            }
        }
        
        // Enter database in order to start observation, and fetch initial
        // value if needed.
        //
        // We use an unsafe reentrant method so that this initializer can be
        // called from a database queue.
        return try unsafeReentrantWrite { db in
            // Start observing the database (take care of future transactions
            // that change the observed region).
            //
            // Observation stops when transactionObserver is deallocated,
            // which happens when self is deallocated.
            let transactionObserver = try ValuesObserver(
                region: observation.observedRegion(db),
                future: { [unowned self] in self.concurrentRead { try observation.fetch($0) } },
                queue: observation.queue,
                onError: observation.onError,
                onChange: observation.onChange)
            db.add(transactionObserver: transactionObserver, extent: observation.extent)
            
            switch observation.initialDispatch {
            case .none:
                break
            case .immediateOnCurrentQueue:
                immediateValue = try observation.fetch(db)
            case .asynchronous:
                let initialValue = try observation.fetch(db)
                // We're still on the database writer queue. Let's dispatch
                // initial value now, before any future transaction has any
                // opportunity to trigger a change notification.
                observation.queue.async {
                    observation.onChange(initialValue)
                }
            }
            
            return transactionObserver
        }
    }
}

/// TODO
public struct ValueObservation<Value> {
    /// A closure that is evaluated when the observation startst, and returns
    /// the observed database region.
    var observedRegion: (Database) throws -> DatabaseRegion
    
    /// The extent of the database observation. The default is
    /// `.observerLifetime`: once started, the observation lasts until the
    /// observer is deallocated.
    var extent = Database.TransactionObservationExtent.observerLifetime
    
    /// A closure that fetches fresh results whenever the database changes.
    var fetch: (Database) throws -> Value
    
    /// The dispatch queue where change callbacks are called. Default is the
    /// main queue.
    ///
    /// Note that when *initialDispatch* is `.immediateOnCurrentQueue`, the
    /// first values are dispatched on the dispatch queue which starts the
    /// observation, regardless of this property.
    var queue = DispatchQueue.main
    
    /// `initialDispatch` controls how initial values are dispatched when
    /// observation starts.
    ///
    /// - When `.immediateOnCurrentQueue` (the default), initial values are
    /// fetched right away, and the *onChange* callback is called
    /// synchronously, on the dispatch queue which starts the observation.
    ///
    /// - When `.asynchronous`, initial values are fetched right away, and
    /// the *onChange* callback is called asynchronously, on *queue*.
    ///
    /// - When `.none`, initial values are not fetched and not notified.
    var initialDispatch = InitialDispatch.immediateOnCurrentQueue
    
    /// This callback is called when fresh results could not be fetched.
    var onError: ((Error) -> Void)? = nil
    
    /// This callback is called with fresh results whenever the observed
    /// database region is impacted by a database transaction.
    var onChange: (Value) -> Void
    
    /// Creates a ValueObservation which observes *region*, and notifies the
    /// *onChange* callback with the values returned by the *fetch* closure
    /// whenever the observed region is impacted by a database transaction.
    ///
    /// For example:
    ///
    ///     let observation = ValueObservation(
    ///         observing: { db in try Player.all().databaseRegion(db) },
    ///         fetch: { db in try Player.fetchAll(db) },
    ///         onChange: { player: [Player] in print("players have changed") })
    ///     let observer = dbQueue.add(observation: observation)
    ///     // prints "players have changed"
    ///
    /// Unless further configured:
    ///
    /// - The observation notifies fresh values on the main queue.
    /// - When started with the `add(observation:)` method, fresh values are
    /// immediately notified, on the dispatch queue which starts
    /// the observation.
    /// - The observation lasts until the returned observer is deallocated.
    ///
    /// See ValueObservation for more information.
    ///
    /// - parameter region: a closure that returns the observed region.
    /// - parameter fetch: a closure that fetches fresh results.
    /// - parameter onChange: called with fresh results.
    public init(
        observing region: @escaping (Database) throws -> DatabaseRegion,
        fetch: @escaping (Database) throws -> Value,
        onChange: @escaping (Value) -> Void)
    {
        self.observedRegion = region
        self.fetch = fetch
        self.onChange = onChange
    }
}

// MARK: - DatabaseRegionConvertible Observation

extension ValueObservation {
    /// Creates a ValueObservation which observes *regions*, and notifies the
    /// *onChange* callback with the values returned by the *fetch* closure
    /// whenever one of the observed region is impacted by a
    /// database transaction.
    ///
    /// For example:
    ///
    ///     let observation = ValueObservation(
    ///         observing: Player.all(),
    ///         fetch: { db in return try Player.fetchAll(db) },
    ///         onChange: { player: [Player] in print("players have changed") })
    ///     let observer = dbQueue.add(observation: observation)
    ///     // prints "players have changed"
    ///
    /// Unless further configured:
    ///
    /// - The observation notifies fresh values on the main queue.
    /// - When started with the `add(observation:)` method, fresh values are
    /// immediately notified, on the dispatch queue which starts
    /// the observation.
    /// - The observation lasts until the returned observer is deallocated.
    ///
    /// See ValueObservation for more information.
    ///
    /// - parameter regions: one or more observed requests.
    /// - parameter fetch: a closure that fetches fresh results.
    /// - parameter onChange: called with fresh results.
    public init(
        observing regions: DatabaseRegionConvertible...,
        fetch: @escaping (Database) throws -> Value,
        onChange: @escaping (Value) -> Void)
    {
        func region(_ db: Database) throws -> DatabaseRegion {
            return try regions.reduce(into: DatabaseRegion()) { union, region in
                try union.formUnion(region.databaseRegion(db))
            }
        }
        
        self.init(observing: region, fetch: fetch, onChange: onChange)
    }
}

// MARK: - FetchRequest Observation

extension ValueObservation where Value == Int {
    /// Creates a ValueObservation which observes *request*, and notifies the
    /// *onChange* callback with the number of fetched values whenever the
    /// request is impacted by a database transaction.
    ///
    /// For example:
    ///
    ///     let request = Player.all()
    ///     let observation = ValueObservation(count: request) { count: Int in
    ///         print("number of players has changed")
    ///     }
    ///     let observer = dbQueue.add(observation: observation)
    ///     // prints "number of players has changed"
    ///
    /// Unless further configured:
    ///
    /// - The observation notifies fresh values on the main queue.
    /// - When started with the `add(observation:)` method, fresh values are
    /// immediately notified, on the dispatch queue which starts
    /// the observation.
    /// - The observation lasts until the returned observer is deallocated.
    ///
    /// See ValueObservation for more information.
    ///
    /// - parameter request: the observed request.
    /// - parameter onChange: called with fresh results.
    /// - returns: a new ValueObservation<Int>.
    init<Request: FetchRequest>(count request: Request, onChange: @escaping (Int) -> Void) {
        self.init(
            observing: request,
            fetch: { try request.fetchCount($0) },
            onChange: onChange)
    }
}

extension FetchRequest {
    /// Creates a ValueObservation which observes *self*, and notifies the
    /// *onChange* callback with the number of fetched values whenever the
    /// request is impacted by a database transaction.
    ///
    /// For example:
    ///
    ///     let request = Player.all()
    ///     let observation = request.observeCount { count: Int in
    ///         print("number of players has changed")
    ///     }
    ///     let observer = dbQueue.add(observation: observation)
    ///     // prints "number of players has changed"
    ///
    /// Unless further configured:
    ///
    /// - The observation notifies fresh values on the main queue.
    /// - When started with the `add(observation:)` method, fresh values are
    /// immediately notified, on the dispatch queue which starts
    /// the observation.
    /// - The observation lasts until the returned observer is deallocated.
    ///
    /// See ValueObservation for more information.
    ///
    /// - parameter request: the observed request.
    /// - parameter onChange: called with fresh results.
    /// - returns: a new ValueObservation<Int>.
    func observeCount(onChange: @escaping (Int) -> Void) -> ValueObservation<Int> {
        return ValueObservation(
            observing: self,
            fetch: { try self.fetchCount($0) },
            onChange: onChange)
    }
}

// MARK: - Row Observation

extension ValueObservation where Value == [Row] {
    /// Creates a ValueObservation which observes *request*, and notifies the
    /// *onChange* callback with fetched rows whenever the request is impacted
    /// by a database transaction.
    ///
    /// For example:
    ///
    ///     let request = SQLRequest<Row>("SELECT * FROM player")
    ///     let observation = ValueObservation(all: request) { rows: [Row] in
    ///         print("players have changed")
    ///     }
    ///     let observer = dbQueue.add(observation: observation)
    ///     // prints "players have changed"
    ///
    /// Unless further configured:
    ///
    /// - The observation notifies fresh values on the main queue.
    /// - When started with the `add(observation:)` method, fresh values are
    /// immediately notified, on the dispatch queue which starts
    /// the observation.
    /// - The observation lasts until the returned observer is deallocated.
    ///
    /// See ValueObservation for more information.
    ///
    /// - parameter request: the observed request.
    /// - parameter onChange: called with fresh results.
    /// - returns: a new ValueObservation<Int>.
    init<Request: FetchRequest>(all request: Request, onChange: @escaping ([Row]) -> Void) where Request.RowDecoder == Row {
        self.init(
            observing: request,
            fetch: { try request.fetchAll($0) },
            onChange: onChange)
    }
}

extension ValueObservation where Value == Row? {
    /// Creates a ValueObservation which observes *request*, and notifies the
    /// *onChange* callback with fetched rows whenever the request is impacted
    /// by a database transaction.
    ///
    /// For example:
    ///
    ///     let request = SQLRequest<Row>("SELECT * FROM player WHERE id = ?", arguments: [1])
    ///     let observation = ValueObservation(one: request) { row: Row? in
    ///         print("players have changed")
    ///     }
    ///     let observer = dbQueue.add(observation: observation)
    ///     // prints "players have changed"
    ///
    /// Unless further configured:
    ///
    /// - The observation notifies fresh values on the main queue.
    /// - When started with the `add(observation:)` method, fresh values are
    /// immediately notified, on the dispatch queue which starts
    /// the observation.
    /// - The observation lasts until the returned observer is deallocated.
    ///
    /// See ValueObservation for more information.
    ///
    /// - parameter request: the observed request.
    /// - parameter onChange: called with fresh results.
    /// - returns: a new ValueObservation<Int>.
    init<Request: FetchRequest>(one request: Request, onChange: @escaping (Row?) -> Void) where Request.RowDecoder == Row {
        self.init(
            observing: request,
            fetch: { try request.fetchOne($0) },
            onChange: onChange)
    }
}

extension FetchRequest where RowDecoder == Row {
    /// Creates a ValueObservation which observes *self*, and notifies the
    /// *onChange* callback with fetched rows whenever the request is impacted
    /// by a database transaction.
    ///
    /// For example:
    ///
    ///     let request = SQLRequest<Row>("SELECT * FROM player")
    ///     let observation = request.observeAll { rows: [Row] in
    ///         print("players have changed")
    ///     }
    ///     let observer = dbQueue.add(observation: observation)
    ///     // prints "players have changed"
    ///
    /// Unless further configured:
    ///
    /// - The observation notifies fresh values on the main queue.
    /// - When started with the `add(observation:)` method, fresh values are
    /// immediately notified, on the dispatch queue which starts
    /// the observation.
    /// - The observation lasts until the returned observer is deallocated.
    ///
    /// See ValueObservation for more information.
    ///
    /// - parameter request: the observed request.
    /// - parameter onChange: called with fresh results.
    /// - returns: a new ValueObservation<Int>.
    func observeAll(onChange: @escaping ([Row]) -> Void) -> ValueObservation<[Row]> {
        return ValueObservation(
            observing: self,
            fetch: { try self.fetchAll($0) },
            onChange: onChange)
    }
    
    /// Creates a ValueObservation which observes *self*, and notifies the
    /// *onChange* callback with a fetched row whenever the request is impacted
    /// by a database transaction.
    ///
    /// For example:
    ///
    ///     let request = SQLRequest<Row>("SELECT * FROM player WHERE id = ?", arguments: [1])
    ///     let observation = request.observeOne { row: Row? in
    ///         print("player has changed")
    ///     }
    ///     let observer = dbQueue.add(observation: observation)
    ///     // prints "player has changed"
    ///
    /// Unless further configured:
    ///
    /// - The observation notifies fresh values on the main queue.
    /// - When started with the `add(observation:)` method, fresh values are
    /// immediately notified, on the dispatch queue which starts
    /// the observation.
    /// - The observation lasts until the returned observer is deallocated.
    ///
    /// See ValueObservation for more information.
    ///
    /// - parameter request: the observed request.
    /// - parameter onChange: called with fresh results.
    /// - returns: a new ValueObservation<Int>.
    func observeOne(onChange: @escaping (Row?) -> Void) -> ValueObservation<Row?> {
        return ValueObservation(
            observing: self,
            fetch: { try self.fetchOne($0) },
            onChange: onChange)
    }
}

// MARK: - FetchableRecord Observation

extension DatabaseWriter {
    /// Observe *request*: calls a closure with fresh results each time the
    /// database has been modified.
    ///
    /// Database observation lasts until the returned observer is deallocated.
    ///
    /// For example:
    ///
    ///     let observer = try dbQueue.observeAll(
    ///         from: Player.all(),
    ///         onChange: { players: [Player] in
    ///             print("players have changed: \(players)")
    ///         })
    ///
    /// - parameters:
    ///     - request: The request to observe.
    ///     - onChange: called with fresh results.
    /// - returns: A new `TransactionObserver`
    /// - throws: A DatabaseError whenever an SQLite error occurs.
    public func observeAll<Request>(
        from request: Request,
        extent: Database.TransactionObservationExtent = .observerLifetime,
        queue: DispatchQueue = DispatchQueue.main,
        initialDispatch: InitialDispatch = .immediateOnCurrentQueue,
        onError: ((Error) -> Void)? = nil,
        onChange: @escaping ([Request.RowDecoder]) -> Void)
        throws -> TransactionObserver
        where Request: FetchRequest, Request.RowDecoder: FetchableRecord
    {
        var observation = ValueObservation(
            observing: { try request.databaseRegion($0) },
            fetch: { try request.fetchAll($0) },
            onChange: onChange)
        observation.extent = extent
        observation.queue = queue
        observation.initialDispatch = initialDispatch
        observation.onError = onError
        return try add(observation: observation)
    }
    
    /// Observe *request*: calls a closure with fresh results each time the
    /// database has been modified.
    ///
    /// Database observation lasts until the returned observer is deallocated.
    ///
    /// For example:
    ///
    ///     let observer = try dbQueue.observeOne(
    ///         from: Player.filter(key: 1),
    ///         onChange: { player: Player? in
    ///             print("player has changed: \(player)")
    ///         })
    ///
    /// - parameters:
    ///     - request: The request to observe.
    ///     - onChange: called with fresh results.
    /// - returns: A new `TransactionObserver`
    /// - throws: A DatabaseError whenever an SQLite error occurs.
    public func observeOne<Request>(
        from request: Request,
        extent: Database.TransactionObservationExtent = .observerLifetime,
        queue: DispatchQueue = DispatchQueue.main,
        initialDispatch: InitialDispatch = .immediateOnCurrentQueue,
        onError: ((Error) -> Void)? = nil,
        onChange: @escaping (Request.RowDecoder?) -> Void)
        throws -> TransactionObserver
        where Request: FetchRequest, Request.RowDecoder: FetchableRecord
    {
        var observation = ValueObservation(
            observing: { try request.databaseRegion($0) },
            fetch: { try request.fetchOne($0) },
            onChange: onChange)
        observation.extent = extent
        observation.queue = queue
        observation.initialDispatch = initialDispatch
        observation.onError = onError
        return try add(observation: observation)
    }
}

// MARK: - DatabaseValueConvertible Observation

extension DatabaseWriter {
    /// Observe *request*: calls a closure with fresh results each time the
    /// database has been modified.
    ///
    /// Database observation lasts until the returned observer is deallocated.
    ///
    /// For example:
    ///
    ///     let request = Player.select(Column("name"), as: String.self)
    ///     let observer = try dbQueue.observeAll(
    ///         from: request,
    ///         onChange: { names: [String] in
    ///             print("player names have changed: \(names)")
    ///         })
    ///
    /// - parameters:
    ///     - request: The request to observe.
    ///     - onChange: called with fresh results.
    /// - returns: A new `TransactionObserver`
    /// - throws: A DatabaseError whenever an SQLite error occurs.
    public func observeAll<Request>(
        from request: Request,
        extent: Database.TransactionObservationExtent = .observerLifetime,
        queue: DispatchQueue = DispatchQueue.main,
        initialDispatch: InitialDispatch = .immediateOnCurrentQueue,
        onError: ((Error) -> Void)? = nil,
        onChange: @escaping ([Request.RowDecoder]) -> Void)
        throws -> TransactionObserver
        where Request: FetchRequest, Request.RowDecoder: DatabaseValueConvertible
    {
        var observation = ValueObservation(
            observing: { try request.databaseRegion($0) },
            fetch: { try request.fetchAll($0) },
            onChange: onChange)
        observation.extent = extent
        observation.queue = queue
        observation.initialDispatch = initialDispatch
        observation.onError = onError
        return try add(observation: observation)
    }
    
    /// Observe *request*: calls a closure with fresh results each time the
    /// database has been modified.
    ///
    /// Database observation lasts until the returned observer is deallocated.
    ///
    /// For example:
    ///
    ///     let request = Player
    ///         .filter(key: 1)
    ///         .select(Column("name"), as: String.self)
    ///     let observer = try dbQueue.observeOne(
    ///         from: request,
    ///         onChange: { name: String? in
    ///             print("player's name has changed: \(name)")
    ///         })
    ///
    /// - parameters:
    ///     - request: The request to observe.
    ///     - onChange: called with fresh results.
    /// - returns: A new `TransactionObserver`
    /// - throws: A DatabaseError whenever an SQLite error occurs.
    public func observeOne<Request>(
        from request: Request,
        extent: Database.TransactionObservationExtent = .observerLifetime,
        queue: DispatchQueue = DispatchQueue.main,
        initialDispatch: InitialDispatch = .immediateOnCurrentQueue,
        onError: ((Error) -> Void)? = nil,
        onChange: @escaping (Request.RowDecoder?) -> Void)
        throws -> TransactionObserver
        where Request: FetchRequest, Request.RowDecoder: DatabaseValueConvertible
    {
        var observation = ValueObservation(
            observing: { try request.databaseRegion($0) },
            fetch: { try request.fetchOne($0) },
            onChange: onChange)
        observation.extent = extent
        observation.queue = queue
        observation.initialDispatch = initialDispatch
        observation.onError = onError
        return try add(observation: observation)
    }
}

// MARK: - Optional DatabaseValueConvertible Observation

extension DatabaseWriter {
    /// Observe *request*: calls a closure with fresh results each time the
    /// database has been modified.
    ///
    /// Database observation lasts until the returned observer is deallocated.
    ///
    /// For example:
    ///
    ///     let request = Player.select(Column("email"), as: Optional<String>.self)
    ///     let observer = try dbQueue.observeAll(
    ///         from: request,
    ///         onChange: { emails: [String?] in
    ///             print("player emails have changed: \(names)")
    ///         })
    ///
    /// - parameters:
    ///     - request: The request to observe.
    ///     - onChange: called with fresh results.
    /// - returns: A new `TransactionObserver`
    /// - throws: A DatabaseError whenever an SQLite error occurs.
    public func observeAll<Request>(
        from request: Request,
        extent: Database.TransactionObservationExtent = .observerLifetime,
        queue: DispatchQueue = DispatchQueue.main,
        initialDispatch: InitialDispatch = .immediateOnCurrentQueue,
        onError: ((Error) -> Void)? = nil,
        onChange: @escaping ([Request.RowDecoder._Wrapped?]) -> Void)
        throws -> TransactionObserver
        where Request: FetchRequest, Request.RowDecoder: _OptionalProtocol, Request.RowDecoder._Wrapped: DatabaseValueConvertible
    {
        var observation = ValueObservation(
            observing: { try request.databaseRegion($0) },
            fetch: { try request.fetchAll($0) },
            onChange: onChange)
        observation.extent = extent
        observation.queue = queue
        observation.initialDispatch = initialDispatch
        observation.onError = onError
        return try add(observation: observation)
    }
}
