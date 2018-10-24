//
//  DatabaseWriter+Observation.swift
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
    /// Observe *region*: fetch fresh results each time the database has been
    /// modified, and notify them through to the *onChange* closure.
    ///
    /// - parameters:
    ///     - region: The database region to observe.
    ///     - fetch: A closure that fetches results.
    ///     - queue: The dispatch queue where change callbacks are called.
    ///       Default is the main queue.
    ///     - initialDispatch: When `.immediateOnCurrentQueue` (the default),
    ///       initial values are fetched right away, and the *onChange* callback
    ///       is called synchronously, on the current dispatch queue.
    ///
    ///       When `.asynchronous`, initial values are fetched right away, and
    ///       the *onChange* callback is called asynchronously, on *queue*.
    ///
    ///       When `.none`, initial values are not fetched and not notified.
    ///     - onError: called when results could not be fetched.
    ///     - onChange: called with fetched results.
    func makeValuesObserver<Result>(
        observing region: (Database) throws -> DatabaseRegion,
        extent: Database.TransactionObservationExtent/* = .observerLifetime*/,
        fetch: @escaping (Database) throws -> Result,
        queue: DispatchQueue = DispatchQueue.main,
        initialDispatch: InitialDispatch = .immediateOnCurrentQueue,
        onError: ((Error) -> Void)? = nil,
        onChange: @escaping (Result) -> Void) throws -> TransactionObserver
    {
        // Will be set and notified on the caller queue if initialDispatch is .immediateOnCurrentQueue
        var immediateValue: Result? = nil
        defer {
            if let immediateValue = immediateValue {
                onChange(immediateValue)
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
                region: region(db),
                future: { [unowned self] in self.concurrentRead { try fetch($0) } },
                queue: queue,
                onError: onError,
                onChange: onChange)
            db.add(transactionObserver: transactionObserver, extent: extent)
            
            switch initialDispatch {
            case .none:
                break
            case .immediateOnCurrentQueue:
                immediateValue = try fetch(db)
            case .asynchronous:
                let initialValue = try fetch(db)
                // We're still on the database writer queue. Let's dispatch
                // initial value now, before any future transaction has any
                // opportunity to trigger a change notification.
                queue.async {
                    onChange(initialValue)
                }
            }
            
            return transactionObserver
        }
    }
}

// MARK: - DatabaseRegionConvertible Observation

extension DatabaseWriter {
    /// Observe *regions*: fetch fresh results each time the database has been
    /// modified, and notify them through to the *onChange* closure.
    ///
    /// Database observation lasts until the returned observer is deallocated.
    ///
    /// For example:
    ///
    ///     let observer = try dbQueue.observe(
    ///         region: Player.all(),
    ///         andFetch: { db in return try Player.fetchAll(db) },
    ///         onChange: { players: [Player] in
    ///             print("players have changed: \(players)")
    ///         })
    ///
    /// - parameters:
    ///     - regions: one or more requests.
    ///     - fetch: block to execute to fetch the data
    ///     - queue: The dispatch queue where change callbacks are called.
    ///       Default is the main queue.
    ///     - initialDispatch: When `.immediateOnCurrentQueue` (the default),
    ///       initial values are fetched right away, and the *onChange* callback
    ///       is called synchronously, on the current dispatch queue.
    ///
    ///       When `.asynchronous`, initial values are fetched right away, and
    ///       the *onChange* callback is called asynchronously, on *queue*.
    ///
    ///       When `.none`, initial values are not fetched and not notified.
    ///     - onError: called when results could not be fetched.
    ///     - onChange: called with fetched results.
    /// - returns: A new `TransactionObserver`
    /// - throws: A DatabaseError whenever an SQLite error occurs.
    public func observe<Result>(
        region regions: DatabaseRegionConvertible...,
        extent: Database.TransactionObservationExtent = .observerLifetime,
        andFetch fetch: @escaping (Database) throws -> Result,
        queue: DispatchQueue = DispatchQueue.main,
        initialDispatch: InitialDispatch = .immediateOnCurrentQueue,
        onError: ((Error) -> Void)? = nil,
        onChange: @escaping (Result) -> Void)
        throws -> TransactionObserver
    {
        func region(_ db: Database) throws -> DatabaseRegion {
            return try regions.reduce(into: DatabaseRegion()) { union, region in
                try union.formUnion(region.databaseRegion(db))
            }
        }
        
        return try makeValuesObserver(
            observing: region,
            extent: extent,
            fetch: fetch,
            queue: queue,
            initialDispatch: initialDispatch,
            onError: onError,
            onChange: onChange)
    }
}

// MARK: - FetchRequest Observation

extension DatabaseWriter {
    /// Observe *request*: calls a closure with fresh results each time the
    /// database has been modified.
    ///
    /// Database observation lasts until the returned observer is deallocated.
    ///
    /// For example:
    ///
    ///     let observer = try dbQueue.observeCount(
    ///         from: Player.all(),
    ///         onChange: { count: Int in
    ///             print("Number of players have changed: \(count)")
    ///         })
    ///
    /// - parameters:
    ///     - request: The request to observe.
    ///     - queue: The dispatch queue where change callbacks are called.
    ///       Default is the main queue.
    ///     - initialDispatch: When `.immediateOnCurrentQueue` (the default),
    ///       initial values are fetched right away, and the *onChange* callback
    ///       is called synchronously, on the current dispatch queue.
    ///
    ///       When `.asynchronous`, initial values are fetched right away, and
    ///       the *onChange* callback is called asynchronously, on *queue*.
    ///
    ///       When `.none`, initial values are not fetched and not notified.
    ///     - onError: called when results could not be fetched.
    ///     - onChange: called with fetched results.
    /// - returns: A new `TransactionObserver`
    /// - throws: A DatabaseError whenever an SQLite error occurs.
    public func observeCount<Request>(
        from request: Request,
        extent: Database.TransactionObservationExtent = .observerLifetime,
        queue: DispatchQueue = DispatchQueue.main,
        initialDispatch: InitialDispatch = .immediateOnCurrentQueue,
        onError: ((Error) -> Void)? = nil,
        onChange: @escaping (Int) -> Void)
        throws -> TransactionObserver
        where Request: FetchRequest
    {
        return try makeValuesObserver(
            observing: { try request.databaseRegion($0) },
            extent: extent,
            fetch: { try request.fetchCount($0) },
            queue: queue,
            initialDispatch: initialDispatch,
            onError: onError,
            onChange: onChange)
    }
}

// MARK: - Row Observation

extension DatabaseWriter {
    /// Observe *request*: calls a closure with fresh results each time the
    /// database has been modified.
    ///
    /// Database observation lasts until the returned observer is deallocated.
    ///
    /// For example:
    ///
    ///     let observer = try dbQueue.observeAll(
    ///         from: SQLRequest<Row>("SELECT * FROM player"),
    ///         onChange: { rows: [Row] in
    ///             print("players have changed: \(rows)")
    ///         })
    ///
    /// - parameters:
    ///     - request: The request to observe.
    ///     - queue: The dispatch queue where change callbacks are called.
    ///       Default is the main queue.
    ///     - initialDispatch: When `.immediateOnCurrentQueue` (the default),
    ///       initial values are fetched right away, and the *onChange* callback
    ///       is called synchronously, on the current dispatch queue.
    ///
    ///       When `.asynchronous`, initial values are fetched right away, and
    ///       the *onChange* callback is called asynchronously, on *queue*.
    ///
    ///       When `.none`, initial values are not fetched and not notified.
    ///     - onError: called when results could not be fetched.
    ///     - onChange: called with fetched results.
    /// - returns: A new `TransactionObserver`
    /// - throws: A DatabaseError whenever an SQLite error occurs.
    public func observeAll<Request>(
        from request: Request,
        extent: Database.TransactionObservationExtent = .observerLifetime,
        queue: DispatchQueue = DispatchQueue.main,
        initialDispatch: InitialDispatch = .immediateOnCurrentQueue,
        onError: ((Error) -> Void)? = nil,
        onChange: @escaping ([Row]) -> Void)
        throws -> TransactionObserver
        where Request: FetchRequest, Request.RowDecoder == Row
    {
        return try makeValuesObserver(
            observing: { try request.databaseRegion($0) },
            extent: extent,
            fetch: { try request.fetchAll($0) },
            queue: queue,
            initialDispatch: initialDispatch,
            onError: onError,
            onChange: onChange)
    }
    
    /// Observe *request*: calls a closure with fresh results each time the
    /// database has been modified.
    ///
    /// Database observation lasts until the returned observer is deallocated.
    ///
    /// For example:
    ///
    ///     let observer = try dbQueue.observeOne(
    ///         from: SQLRequest<Row>("SELECT * FROM player WHERE id = 1"),
    ///         onChange: { row: Row? in
    ///             print("player has changed: \(row)")
    ///         })
    ///
    /// - parameters:
    ///     - request: The request to observe.
    ///     - queue: The dispatch queue where change callbacks are called.
    ///       Default is the main queue.
    ///     - initialDispatch: When `.immediateOnCurrentQueue` (the default),
    ///       initial values are fetched right away, and the *onChange* callback
    ///       is called synchronously, on the current dispatch queue.
    ///
    ///       When `.asynchronous`, initial values are fetched right away, and
    ///       the *onChange* callback is called asynchronously, on *queue*.
    ///
    ///       When `.none`, initial values are not fetched and not notified.
    ///     - onError: called when results could not be fetched.
    ///     - onChange: called with fetched results.
    /// - returns: A new `TransactionObserver`
    /// - throws: A DatabaseError whenever an SQLite error occurs.
    public func observeOne<Request>(
        from request: Request,
        extent: Database.TransactionObservationExtent = .observerLifetime,
        queue: DispatchQueue = DispatchQueue.main,
        initialDispatch: InitialDispatch = .immediateOnCurrentQueue,
        onError: ((Error) -> Void)? = nil,
        onChange: @escaping (Row?) -> Void)
        throws -> TransactionObserver
        where Request: FetchRequest, Request.RowDecoder == Row
    {
        return try makeValuesObserver(
            observing: { try request.databaseRegion($0) },
            extent: extent,
            fetch: { try request.fetchOne($0) },
            queue: queue,
            initialDispatch: initialDispatch,
            onError: onError,
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
    ///     - queue: The dispatch queue where change callbacks are called.
    ///       Default is the main queue.
    ///     - initialDispatch: When `.immediateOnCurrentQueue` (the default),
    ///       initial values are fetched right away, and the *onChange* callback
    ///       is called synchronously, on the current dispatch queue.
    ///
    ///       When `.asynchronous`, initial values are fetched right away, and
    ///       the *onChange* callback is called asynchronously, on *queue*.
    ///
    ///       When `.none`, initial values are not fetched and not notified.
    ///     - onError: called when results could not be fetched.
    ///     - onChange: called with fetched results.
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
        return try makeValuesObserver(
            observing: { try request.databaseRegion($0) },
            extent: extent,
            fetch: { try request.fetchAll($0) },
            queue: queue,
            initialDispatch: initialDispatch,
            onError: onError,
            onChange: onChange)
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
    ///     - queue: The dispatch queue where change callbacks are called.
    ///       Default is the main queue.
    ///     - initialDispatch: When `.immediateOnCurrentQueue` (the default),
    ///       initial values are fetched right away, and the *onChange* callback
    ///       is called synchronously, on the current dispatch queue.
    ///
    ///       When `.asynchronous`, initial values are fetched right away, and
    ///       the *onChange* callback is called asynchronously, on *queue*.
    ///
    ///       When `.none`, initial values are not fetched and not notified.
    ///     - onError: called when results could not be fetched.
    ///     - onChange: called with fetched results.
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
        return try makeValuesObserver(
            observing: { try request.databaseRegion($0) },
            extent: extent,
            fetch: { try request.fetchOne($0) },
            queue: queue,
            initialDispatch: initialDispatch,
            onError: onError,
            onChange: onChange)
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
    ///     - queue: The dispatch queue where change callbacks are called.
    ///       Default is the main queue.
    ///     - initialDispatch: When `.immediateOnCurrentQueue` (the default),
    ///       initial values are fetched right away, and the *onChange* callback
    ///       is called synchronously, on the current dispatch queue.
    ///
    ///       When `.asynchronous`, initial values are fetched right away, and
    ///       the *onChange* callback is called asynchronously, on *queue*.
    ///
    ///       When `.none`, initial values are not fetched and not notified.
    ///     - onError: called when results could not be fetched.
    ///     - onChange: called with fetched results.
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
        return try makeValuesObserver(
            observing: { try request.databaseRegion($0) },
            extent: extent,
            fetch: { try request.fetchAll($0) },
            queue: queue,
            initialDispatch: initialDispatch,
            onError: onError,
            onChange: onChange)
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
    ///     - queue: The dispatch queue where change callbacks are called.
    ///       Default is the main queue.
    ///     - initialDispatch: When `.immediateOnCurrentQueue` (the default),
    ///       initial values are fetched right away, and the *onChange* callback
    ///       is called synchronously, on the current dispatch queue.
    ///
    ///       When `.asynchronous`, initial values are fetched right away, and
    ///       the *onChange* callback is called asynchronously, on *queue*.
    ///
    ///       When `.none`, initial values are not fetched and not notified.
    ///     - onError: called when results could not be fetched.
    ///     - onChange: called with fetched results.
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
        return try makeValuesObserver(
            observing: { try request.databaseRegion($0) },
            extent: extent,
            fetch: { try request.fetchOne($0) },
            queue: queue,
            initialDispatch: initialDispatch,
            onError: onError,
            onChange: onChange)
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
    ///     - queue: The dispatch queue where change callbacks are called.
    ///       Default is the main queue.
    ///     - initialDispatch: When `.immediateOnCurrentQueue` (the default),
    ///       initial values are fetched right away, and the *onChange* callback
    ///       is called synchronously, on the current dispatch queue.
    ///
    ///       When `.asynchronous`, initial values are fetched right away, and
    ///       the *onChange* callback is called asynchronously, on *queue*.
    ///
    ///       When `.none`, initial values are not fetched and not notified.
    ///     - onError: called when results could not be fetched.
    ///     - onChange: called with fetched results.
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
        return try makeValuesObserver(
            observing: { try request.databaseRegion($0) },
            extent: extent,
            fetch: { try request.fetchAll($0) },
            queue: queue,
            initialDispatch: initialDispatch,
            onError: onError,
            onChange: onChange)
    }
}
