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
    case deferred
}

/// TODO
public struct ValueObservation<Value> {
    /// A closure that is evaluated when the observation startst, and returns
    /// the observed database region.
    var observedRegion: (Database) throws -> DatabaseRegion
    
    /// A closure that fetches fresh results whenever the database changes.
    var read: (Database) throws -> Value
    
    /// The extent of the database observation. The default is
    /// `.observerLifetime`: once started, the observation lasts until the
    /// observer is deallocated.
    public var extent = Database.TransactionObservationExtent.observerLifetime
    
    /// The dispatch queue where change callbacks are called. Default is the
    /// main queue.
    ///
    /// Note that when *initialDispatch* is `.immediateOnCurrentQueue`, the
    /// first values are dispatched on the dispatch queue which starts the
    /// observation, regardless of this property.
    public var queue = DispatchQueue.main
    
    /// `initialDispatch` controls how initial values are dispatched when
    /// observation starts with the `add(observation:)` method:
    ///
    /// - When `.immediateOnCurrentQueue` (the default), initial values are
    /// fetched right away, and notified synchronously, on the dispatch queue
    /// which starts the observation.
    ///
    /// - When `.deferred`, initial values are fetched right away, and
    /// notified asynchronously, on *queue*.
    ///
    /// - When `.none`, initial values are not fetched and not notified.
    public var initialDispatch = InitialDispatch.immediateOnCurrentQueue
    
    /// Creates a ValueObservation which observes *region*, and notifies the
    /// values returned by the *fetch* closure whenever the observed region is
    /// impacted by a database transaction.
    ///
    /// For example:
    ///
    ///     let observation = ValueObservation(
    ///         observing: { db in try Player.all().databaseRegion(db) },
    ///         read: { db in try Player.fetchAll(db) })
    ///
    ///     let observer = dbQueue.add(observation: observation) { player: [Player] in
    ///         print("players have changed")
    ///     }
    ///     // prints "players have changed"
    ///
    /// The returned observation has the default configuration:
    ///
    /// - When started with the `add(observation:)` method, fresh values are
    /// immediately notified on the dispatch queue which starts the observation.
    /// - When database eventually changes, fresh values are notified on the
    /// main queue.
    /// - The observation lasts until the returned observer is deallocated.
    ///
    /// See ValueObservation for more information.
    ///
    /// - parameter region: a closure that returns the observed region.
    /// - parameter read: a closure that fetches fresh results.
    public init(
        observing region: @escaping (Database) throws -> DatabaseRegion,
        read: @escaping (Database) throws -> Value)
    {
        self.observedRegion = region
        self.read = read
    }
}

// MARK: - DatabaseRegionConvertible Observation

extension ValueObservation {
    /// Creates a ValueObservation which observes *regions*, and notifies the
    /// values returned by the *read* closure whenever one of the observed
    /// regions is impacted by a database transaction.
    ///
    /// For example:
    ///
    ///     let observation = ValueObservation(
    ///         observing: Player.all(),
    ///         read: { db in return try Player.fetchAll(db) })
    ///
    ///     let observer = dbQueue.add(observation: observation) { player: [Player] in
    ///         print("players have changed")
    ///     }
    ///     // prints "players have changed"
    ///
    /// The returned observation has the default configuration:
    ///
    /// - When started with the `add(observation:)` method, fresh values are
    /// immediately notified on the dispatch queue which starts the observation.
    /// - When database eventually changes, fresh values are notified on the
    /// main queue.
    /// - The observation lasts until the returned observer is deallocated.
    ///
    /// See ValueObservation for more information.
    ///
    /// - parameter regions: one or more observed requests.
    /// - parameter read: a closure that fetches fresh results.
    public init(
        observing regions: DatabaseRegionConvertible...,
        read: @escaping (Database) throws -> Value)
    {
        func region(_ db: Database) throws -> DatabaseRegion {
            return try regions.reduce(into: DatabaseRegion()) { union, region in
                try union.formUnion(region.databaseRegion(db))
            }
        }
        
        self.init(observing: region, read: read)
    }
}

// MARK: - FetchRequest Observation

extension ValueObservation where Value == Int {
    /// Creates a ValueObservation which observes *request*, and notifies the
    /// number of fetched values whenever the request is impacted by a
    /// database transaction.
    ///
    /// For example:
    ///
    ///     let request = Player.all()
    ///     let observation = ValueObservation(count: request)
    ///
    ///     let observer = dbQueue.add(observation: observation) { count: Int in
    ///         print("number of players has changed")
    ///     }
    ///     // prints "number of players has changed"
    ///
    /// The returned observation has the default configuration:
    ///
    /// - When started with the `add(observation:)` method, fresh values are
    /// immediately notified on the dispatch queue which starts the observation.
    /// - When database eventually changes, fresh values are notified on the
    /// main queue.
    /// - The observation lasts until the returned observer is deallocated.
    ///
    /// See ValueObservation for more information.
    ///
    /// - parameter request: the observed request.
    /// - returns: a new ValueObservation<Int>.
    init<Request: FetchRequest>(count request: Request) {
        self.init(observing: request, read: { try request.fetchCount($0) })
    }
}

extension FetchRequest {
    /// Creates a ValueObservation which observes *self*, and notifies the
    /// number of fetched values whenever the request is impacted by a
    /// database transaction.
    ///
    /// For example:
    ///
    ///     let request = Player.all()
    ///     let observation = request.observeCount()
    ///
    ///     let observer = dbQueue.add(observation: observation) { count: Int in
    ///         print("number of players has changed")
    ///     }
    ///     // prints "number of players has changed"
    ///
    /// The returned observation has the default configuration:
    ///
    /// - When started with the `add(observation:)` method, fresh values are
    /// immediately notified on the dispatch queue which starts the observation.
    /// - When database eventually changes, fresh values are notified on the
    /// main queue.
    /// - The observation lasts until the returned observer is deallocated.
    ///
    /// See ValueObservation for more information.
    ///
    /// - parameter request: the observed request.
    /// - returns: a new ValueObservation<Int>.
    func observeCount() -> ValueObservation<Int> {
        return ValueObservation(observing: self, read: { try self.fetchCount($0) })
    }
}

// MARK: - Row Observation

extension ValueObservation where Value == [Row] {
    /// Creates a ValueObservation which observes *request*, and notifies the
    /// fetched rows whenever the request is impacted by a database transaction.
    ///
    /// For example:
    ///
    ///     let request = SQLRequest<Row>("SELECT * FROM player")
    ///     let observation = ValueObservation(all: request)
    ///
    ///     let observer = dbQueue.add(observation: observation) { rows: [Row] in
    ///         print("players have changed")
    ///     }
    ///     // prints "players have changed"
    ///
    /// The returned observation has the default configuration:
    ///
    /// - When started with the `add(observation:)` method, fresh values are
    /// immediately notified on the dispatch queue which starts the observation.
    /// - When database eventually changes, fresh values are notified on the
    /// main queue.
    /// - The observation lasts until the returned observer is deallocated.
    ///
    /// See ValueObservation for more information.
    ///
    /// - parameter request: the observed request.
    /// - returns: a new ValueObservation<Int>.
    init<Request: FetchRequest>(all request: Request) where Request.RowDecoder == Row {
        self.init(observing: request, read: { try request.fetchAll($0) })
    }
}

extension ValueObservation where Value == Row? {
    /// Creates a ValueObservation which observes *request*, and notifies the
    /// fetched rows whenever the request is impacted by a database transaction.
    ///
    /// For example:
    ///
    ///     let request = SQLRequest<Row>("SELECT * FROM player WHERE id = ?", arguments: [1])
    ///     let observation = ValueObservation(one: request)
    ///
    ///     let observer = dbQueue.add(observation: observation) { row: Row? in
    ///         print("players have changed")
    ///     }
    ///     // prints "players have changed"
    ///
    /// The returned observation has the default configuration:
    ///
    /// - When started with the `add(observation:)` method, fresh values are
    /// immediately notified on the dispatch queue which starts the observation.
    /// - When database eventually changes, fresh values are notified on the
    /// main queue.
    /// - The observation lasts until the returned observer is deallocated.
    ///
    /// See ValueObservation for more information.
    ///
    /// - parameter request: the observed request.
    /// - returns: a new ValueObservation<Int>.
    init<Request: FetchRequest>(one request: Request) where Request.RowDecoder == Row {
        self.init(observing: request, read: { try request.fetchOne($0) })
    }
}

extension FetchRequest where RowDecoder == Row {
    /// Creates a ValueObservation which observes *self*, and notifies the
    /// fetched rows whenever the request is impacted by a database transaction.
    ///
    /// For example:
    ///
    ///     let request = SQLRequest<Row>("SELECT * FROM player")
    ///     let observation = request.observeAll()
    ///
    ///     let observer = dbQueue.add(observation: observation) { rows: [Row] in
    ///         print("players have changed")
    ///     }
    ///     // prints "players have changed"
    ///
    /// The returned observation has the default configuration:
    ///
    /// - When started with the `add(observation:)` method, fresh values are
    /// immediately notified on the dispatch queue which starts the observation.
    /// - When database eventually changes, fresh values are notified on the
    /// main queue.
    /// - The observation lasts until the returned observer is deallocated.
    ///
    /// See ValueObservation for more information.
    ///
    /// - parameter request: the observed request.
    /// - returns: a new ValueObservation<Int>.
    func observeAll() -> ValueObservation<[Row]> {
        return ValueObservation(observing: self, read: { try self.fetchAll($0) })
    }
    
    /// Creates a ValueObservation which observes *self*, and notifies the
    /// fetched row whenever the request is impacted by a database transaction.
    ///
    /// For example:
    ///
    ///     let request = SQLRequest<Row>("SELECT * FROM player WHERE id = ?", arguments: [1])
    ///     let observation = request.observeOne()
    ///
    ///     let observer = dbQueue.add(observation: observation) { row: Row? in
    ///         print("player has changed")
    ///     }
    ///     // prints "player has changed"
    ///
    /// The returned observation has the default configuration:
    ///
    /// - When started with the `add(observation:)` method, fresh values are
    /// immediately notified on the dispatch queue which starts the observation.
    /// - When database eventually changes, fresh values are notified on the
    /// main queue.
    /// - The observation lasts until the returned observer is deallocated.
    ///
    /// See ValueObservation for more information.
    ///
    /// - parameter request: the observed request.
    /// - returns: a new ValueObservation<Int>.
    func observeOne() -> ValueObservation<Row?> {
        return ValueObservation(observing: self, read: { try self.fetchOne($0) })
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
            read: { try request.fetchAll($0) })
        observation.extent = extent
        observation.queue = queue
        observation.initialDispatch = initialDispatch
        return try add(observation: observation, onError: onError, onChange: onChange)
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
            read: { try request.fetchOne($0) })
        observation.extent = extent
        observation.queue = queue
        observation.initialDispatch = initialDispatch
        return try add(observation: observation, onError: onError, onChange: onChange)
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
            read: { try request.fetchAll($0) })
        observation.extent = extent
        observation.queue = queue
        observation.initialDispatch = initialDispatch
        return try add(observation: observation, onError: onError, onChange: onChange)
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
            read: { try request.fetchOne($0) })
        observation.extent = extent
        observation.queue = queue
        observation.initialDispatch = initialDispatch
        return try add(observation: observation, onError: onError, onChange: onChange)
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
            read: { try request.fetchAll($0) })
        observation.extent = extent
        observation.queue = queue
        observation.initialDispatch = initialDispatch
        return try add(observation: observation, onError: onError, onChange: onChange)
    }
}
