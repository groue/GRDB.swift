//
//  ValueObservation.swift
//  GRDB
//
//  Created by Gwendal Roué on 23/10/2018.
//  Copyright © 2018 Gwendal Roué. All rights reserved.
//

import Dispatch

/// InitialDispatch controls how initial value is dispatched when one starts
/// observing the database. See ValueObservation.
public enum InitialDispatch {
    /// Initial value is not fetched, and not notified.
    case none
    
    /// Initial value is immediately fetched, and notified on the current dispatch queue.
    case immediateOnCurrentQueue
    
    /// Initial value is immediately fetched, and asynchronously notified.
    case deferred
}

/// TODO: doc
public protocol ValueReducer {
    associatedtype Fetched
    associatedtype Value
    func fetch(_ db: Database) throws -> Fetched
    mutating func value(_ fetched: Fetched) -> Value?
}

/// TODO: doc
/// TODO: refresh region after each fetch
public struct ValueObservation<Reducer> {
    /// A closure that is evaluated when the observation starts, and returns
    /// the observed database region.
    var observedRegion: (Database) throws -> DatabaseRegion
    
    /// A closure that fetches a value from the database. It is called upon
    /// each database change, and also when the observatioin starts, depending
    /// on the *initialDispatch* property.
    ///
    /// When this closure needs to write in the database, set the *readonly*
    /// flag to false.
    var reducer: Reducer
    
    /// Default is true. Set this property to false when the *fetch* closure
    /// requires write access, and should be executed inside a savepoint.
    var readonly: Bool = true
    
    /// The extent of the database observation. The default is
    /// `.observerLifetime`: once started, the observation lasts until the
    /// observer is deallocated.
    public var extent = Database.TransactionObservationExtent.observerLifetime
    
    /// The dispatch queue where change callbacks are called. Default is the
    /// main queue.
    ///
    /// When *initialDispatch* is `.immediateOnCurrentQueue`, the first value is
    /// dispatched on the dispatch queue which starts the observation,
    /// regardless of this property.
    public var queue = DispatchQueue.main
    
    /// The quality of service.
    public var qos: DispatchQoS
    
    /// `initialDispatch` controls how initial value is dispatched when
    /// observation starts with the `add(observation:)` method:
    ///
    /// - When `.immediateOnCurrentQueue` (the default), initial value is
    /// fetched right away, and notified synchronously, on the dispatch queue
    /// which starts the observation.
    ///
    /// - When `.deferred`, initial value is fetched right away, and
    /// notified asynchronously, on *queue*.
    ///
    /// - When `.none`, initial value is not fetched, and not notified.
    public var initialDispatch = InitialDispatch.immediateOnCurrentQueue
    
    /// Creates a ValueObservation which observes *region*, and notifies the
    /// values returned by the *fetch* closure whenever the observed region is
    /// impacted by a database transaction.
    ///
    /// For example:
    ///
    ///     let observation = ValueObservation(
    ///         observing: { db in try Player.all().databaseRegion(db) },
    ///         fetch: { db in try Player.fetchAll(db) })
    ///
    ///     let observer = dbQueue.add(observation: observation) { player: [Player] in
    ///         print("players have changed")
    ///     }
    ///
    /// The returned observation has the default configuration:
    ///
    /// - When started with the `add(observation:)` method, a fresh value is
    /// immediately notified on the dispatch queue which starts the observation.
    /// - Upon subsequent database changes, fresh values are notified on the
    /// main queue.
    /// - The observation lasts until the observer returned by
    /// `add(observation:)` is deallocated.
    ///
    /// See ValueObservation for more information.
    ///
    /// - parameter region: a closure that returns the observed region.
    /// - parameter fetch: a closure that fetches a value.
    public init(
        observing region: @escaping (Database) throws -> DatabaseRegion,
        reducer: Reducer)
    {
        self.observedRegion = region
        self.reducer = reducer
        if #available(OSXApplicationExtension 10.10, *) {
            self.qos = .default
        } else {
            self.qos = .unspecified
        }
    }
}

// MARK: - Reducers

public enum ValueReducers {
    /// TODO
    public struct Raw<Value>: ValueReducer {
        let _fetch: (Database) throws -> Value
        
        /// TODO
        public init(_ fetch: @escaping (Database) throws -> Value) {
            self._fetch = fetch
        }
        
        /// :nodoc:
        public func fetch(_ db: Database) throws -> Value {
            return try _fetch(db)
        }
        
        /// :nodoc:
        public func value(_ fetched: Value) -> Value? {
            return fetched
        }
    }
    
    public struct Unique<Value: Equatable>: ValueReducer {
        let _fetch: (Database) throws -> Value
        var value: Value??
        
        /// TODO
        public init(_ fetch: @escaping (Database) throws -> Value) {
            self._fetch = fetch
        }
        
        /// :nodoc:
        public func fetch(_ db: Database) throws -> Value {
            return try _fetch(db)
        }
        
        /// :nodoc:
        public mutating func value(_ newValue: Value) -> Value? {
            if let value = value, value == newValue {
                return nil
            }
            self.value = newValue
            return newValue
        }
    }
    
    public struct UniqueRecords<Record: FetchableRecord>: ValueReducer {
        let _fetch: (Database) throws -> [Row]
        var rows: [Row]?
        
        /// TODO
        public init(_ fetch: @escaping (Database) throws -> [Row]) {
            self._fetch = fetch
        }
        
        /// :nodoc:
        public func fetch(_ db: Database) throws -> [Row] {
            return try _fetch(db)
        }
        
        /// :nodoc:
        public mutating func value(_ newRows: [Row]) -> [Record]? {
            if let rows = rows, rows == newRows {
                return nil
            }
            self.rows = newRows
            return newRows.map(Record.init(row:))
        }
    }
    
    public struct UniqueRecord<Record: FetchableRecord>: ValueReducer {
        let _fetch: (Database) throws -> Row?
        var row: Row??
        
        /// TODO
        public init(_ fetch: @escaping (Database) throws -> Row?) {
            self._fetch = fetch
        }
        
        /// :nodoc:
        public func fetch(_ db: Database) throws -> Row? {
            return try _fetch(db)
        }
        
        /// :nodoc:
        public mutating func value(_ newRow: Row?) -> Record? {
            if let row = row, row == newRow {
                return nil
            }
            self.row = newRow
            return newRow.map(Record.init(row:))
        }
    }
}

// MARK: - DatabaseRegionConvertible Observation

extension ValueObservation where Reducer == Void {
    /// Creates a ValueObservation which observes *regions*, and notifies the
    /// values returned by the *fetch* closure whenever one of the observed
    /// regions is impacted by a database transaction.
    ///
    /// For example:
    ///
    ///     let observation = ValueObservation.observing(
    ///         Player.all(),
    ///         fetch: { db in return try Player.fetchAll(db) })
    ///
    ///     let observer = dbQueue.add(observation: observation) { player: [Player] in
    ///         print("players have changed")
    ///     }
    ///
    /// The returned observation has the default configuration:
    ///
    /// - When started with the `add(observation:)` method, a fresh value is
    /// immediately notified on the dispatch queue which starts the observation.
    /// - Upon subsequent database changes, fresh values are notified on the
    /// main queue.
    /// - The observation lasts until the observer returned by
    /// `add(observation:)` is deallocated.
    ///
    /// See ValueObservation for more information.
    ///
    /// - parameter regions: one or more observed requests.
    /// - parameter fetch: a closure that fetches a value.
    public static func observing<Value>(
        _ regions: DatabaseRegionConvertible...,
        fetch: @escaping (Database) throws -> Value)
        -> ValueObservation<ValueReducers.Raw<Value>>
    {
        func region(_ db: Database) throws -> DatabaseRegion {
            return try regions.reduce(into: DatabaseRegion()) { union, region in
                try union.formUnion(region.databaseRegion(db))
            }
        }
        
        return ValueObservation<ValueReducers.Raw<Value>>(
            observing: region,
            reducer: ValueReducers.Raw(fetch))
    }
    
    /// Creates a ValueObservation which observes *regions*, and notifies the
    /// values returned by the *fetch* closure whenever one of the observed
    /// regions is impacted by a database transaction.
    ///
    /// For example:
    ///
    ///     let observation = ValueObservation.observing(
    ///         withUniquing: Player.all(),
    ///         fetch: { db in return try Player.fetchAll(db) })
    ///
    ///     let observer = dbQueue.add(observation: observation) { player: [Player] in
    ///         print("players have changed")
    ///     }
    ///
    /// The returned observation has the default configuration:
    ///
    /// - When started with the `add(observation:)` method, a fresh value is
    /// immediately notified on the dispatch queue which starts the observation.
    /// - Upon subsequent database changes, fresh values are notified on the
    /// main queue.
    /// - The observation lasts until the observer returned by
    /// `add(observation:)` is deallocated.
    ///
    /// See ValueObservation for more information.
    ///
    /// - parameter regions: one or more observed requests.
    /// - parameter fetch: a closure that fetches a value.
    public static func observing<Value>(
        withUniquing regions: DatabaseRegionConvertible...,
        fetch: @escaping (Database) throws -> Value)
        -> ValueObservation<ValueReducers.Unique<Value>>
        where Value: Equatable
    {
        func region(_ db: Database) throws -> DatabaseRegion {
            return try regions.reduce(into: DatabaseRegion()) { union, region in
                try union.formUnion(region.databaseRegion(db))
            }
        }
        
        return ValueObservation<ValueReducers.Unique<Value>>(
            observing: region,
            reducer: ValueReducers.Unique(fetch))
    }
}

// MARK: - FetchRequest Observation

extension ValueObservation where Reducer == Void {
    /// Creates a ValueObservation which observes *request*, and notifies a
    /// fresh count whenever the request is impacted by a database transaction.
    ///
    /// For example:
    ///
    ///     let request = Player.all()
    ///     let observation = ValueObservation.forCount(request)
    ///
    ///     let observer = dbQueue.add(observation: observation) { count: Int in
    ///         print("number of players has changed")
    ///     }
    ///
    /// The returned observation has the default configuration:
    ///
    /// - When started with the `add(observation:)` method, a fresh value is
    /// immediately notified on the dispatch queue which starts the observation.
    /// - Upon subsequent database changes, fresh values are notified on the
    /// main queue.
    /// - The observation lasts until the observer returned by
    /// `add(observation:)` is deallocated.
    ///
    /// See ValueObservation for more information.
    ///
    /// - parameter request: the observed request.
    /// - returns: a ValueObservation.
    public static func forCount<Request: FetchRequest>(_ request: Request)
        -> ValueObservation<ValueReducers.Raw<Int>>
    {
        return ValueObservation<ValueReducers.Raw<Int>>(
            observing: request.databaseRegion,
            reducer: ValueReducers.Raw(request.fetchCount))
    }
    
    /// Creates a ValueObservation which observes *request*, and notifies a
    /// fresh count whenever the request is impacted by a database transaction.
    ///
    /// For example:
    ///
    ///     let request = Player.all()
    ///     let observation = ValueObservation.forCount(withUniquing: request)
    ///
    ///     let observer = dbQueue.add(observation: observation) { count: Int in
    ///         print("number of players has changed")
    ///     }
    ///
    /// The returned observation has the default configuration:
    ///
    /// - When started with the `add(observation:)` method, a fresh value is
    /// immediately notified on the dispatch queue which starts the observation.
    /// - Upon subsequent database changes, fresh values are notified on the
    /// main queue.
    /// - The observation lasts until the observer returned by
    /// `add(observation:)` is deallocated.
    ///
    /// See ValueObservation for more information.
    ///
    /// - parameter request: the observed request.
    /// - returns: a ValueObservation.
    public static func forCount<Request: FetchRequest>(withUniquing request: Request)
        -> ValueObservation<ValueReducers.Unique<Int>>
    {
        return ValueObservation<ValueReducers.Unique<Int>>(
            observing: request.databaseRegion,
            reducer: ValueReducers.Unique(request.fetchCount))
    }
}

// MARK: - Row Observation

extension ValueObservation where Reducer == Void {
    /// Creates a ValueObservation which observes *request*, and notifies
    /// fresh rows whenever the request is impacted by a database transaction.
    ///
    /// For example:
    ///
    ///     let request = SQLRequest<Row>("SELECT * FROM player")
    ///     let observation = ValueObservation.forAll(request)
    ///
    ///     let observer = dbQueue.add(observation: observation) { rows: [Row] in
    ///         print("players have changed")
    ///     }
    ///
    /// The returned observation has the default configuration:
    ///
    /// - When started with the `add(observation:)` method, a fresh value is
    /// immediately notified on the dispatch queue which starts the observation.
    /// - Upon subsequent database changes, fresh values are notified on the
    /// main queue.
    /// - The observation lasts until the observer returned by
    /// `add(observation:)` is deallocated.
    ///
    /// See ValueObservation for more information.
    ///
    /// - parameter request: the observed request.
    /// - returns: a ValueObservation.
    public static func forAll<Request: FetchRequest>(_ request: Request)
        -> ValueObservation<ValueReducers.Raw<[Row]>>
        where Request.RowDecoder == Row
    {
        return ValueObservation<ValueReducers.Raw<[Row]>>(
            observing: request.databaseRegion,
            reducer: ValueReducers.Raw(request.fetchAll))
    }

    /// Creates a ValueObservation which observes *request*, and notifies
    /// fresh rows whenever the request is impacted by a database transaction.
    ///
    /// For example:
    ///
    ///     let request = SQLRequest<Row>("SELECT * FROM player")
    ///     let observation = ValueObservation.forAll(withUniquing: request)
    ///
    ///     let observer = dbQueue.add(observation: observation) { rows: [Row] in
    ///         print("players have changed")
    ///     }
    ///
    /// The returned observation has the default configuration:
    ///
    /// - When started with the `add(observation:)` method, a fresh value is
    /// immediately notified on the dispatch queue which starts the observation.
    /// - Upon subsequent database changes, fresh values are notified on the
    /// main queue.
    /// - The observation lasts until the observer returned by
    /// `add(observation:)` is deallocated.
    ///
    /// See ValueObservation for more information.
    ///
    /// - parameter request: the observed request.
    /// - returns: a ValueObservation.
    public static func forAll<Request: FetchRequest>(withUniquing request: Request)
        -> ValueObservation<ValueReducers.Unique<[Row]>>
        where Request.RowDecoder == Row
    {
        return ValueObservation<ValueReducers.Unique<[Row]>>(
            observing: request.databaseRegion,
            reducer: ValueReducers.Unique(request.fetchAll))
    }
    
    /// Creates a ValueObservation which observes *request*, and notifies a
    /// fresh row whenever the request is impacted by a database transaction.
    ///
    /// For example:
    ///
    ///     let request = SQLRequest<Row>("SELECT * FROM player WHERE id = ?", arguments: [1])
    ///     let observation = ValueObservation.forOne(request)
    ///
    ///     let observer = dbQueue.add(observation: observation) { row: Row? in
    ///         print("players have changed")
    ///     }
    ///
    /// The returned observation has the default configuration:
    ///
    /// - When started with the `add(observation:)` method, a fresh value is
    /// immediately notified on the dispatch queue which starts the observation.
    /// - Upon subsequent database changes, fresh values are notified on the
    /// main queue.
    /// - The observation lasts until the observer returned by
    /// `add(observation:)` is deallocated.
    ///
    /// See ValueObservation for more information.
    ///
    /// - parameter request: the observed request.
    /// - returns: a new ValueObservation<Int>.
    public static func forOne<Request: FetchRequest>(_ request: Request)
        -> ValueObservation<ValueReducers.Raw<Row?>>
        where Request.RowDecoder == Row
    {
        return ValueObservation<ValueReducers.Raw<Row?>>(
            observing: request.databaseRegion,
            reducer: ValueReducers.Raw(request.fetchOne))
    }

    /// Creates a ValueObservation which observes *request*, and notifies a
    /// fresh row whenever the request is impacted by a database transaction.
    ///
    /// For example:
    ///
    ///     let request = SQLRequest<Row>("SELECT * FROM player WHERE id = ?", arguments: [1])
    ///     let observation = ValueObservation.forOne(withUniquing: request)
    ///
    ///     let observer = dbQueue.add(observation: observation) { row: Row? in
    ///         print("players have changed")
    ///     }
    ///
    /// The returned observation has the default configuration:
    ///
    /// - When started with the `add(observation:)` method, a fresh value is
    /// immediately notified on the dispatch queue which starts the observation.
    /// - Upon subsequent database changes, fresh values are notified on the
    /// main queue.
    /// - The observation lasts until the observer returned by
    /// `add(observation:)` is deallocated.
    ///
    /// See ValueObservation for more information.
    ///
    /// - parameter request: the observed request.
    /// - returns: a new ValueObservation<Int>.
    public static func forOne<Request: FetchRequest>(withUniquing request: Request)
        -> ValueObservation<ValueReducers.Unique<Row?>>
        where Request.RowDecoder == Row
    {
        return ValueObservation<ValueReducers.Unique<Row?>>(
            observing: request.databaseRegion,
            reducer: ValueReducers.Unique(request.fetchOne))
    }
}

// MARK: - FetchableRecord Observation

extension ValueObservation where Reducer == Void {
    /// Creates a ValueObservation which observes *request*, and notifies
    /// fresh records whenever the request is impacted by a
    /// database transaction.
    ///
    /// For example:
    ///
    ///     let request = Player.all()
    ///     let observation = ValueObservation.forAll(request)
    ///
    ///     let observer = dbQueue.add(observation: observation) { players: [Player] in
    ///         print("players have changed")
    ///     }
    ///
    /// The returned observation has the default configuration:
    ///
    /// - When started with the `add(observation:)` method, a fresh value is
    /// immediately notified on the dispatch queue which starts the observation.
    /// - Upon subsequent database changes, fresh values are notified on the
    /// main queue.
    /// - The observation lasts until the observer returned by
    /// `add(observation:)` is deallocated.
    ///
    /// See ValueObservation for more information.
    ///
    /// - parameter request: the observed request.
    /// - returns: a ValueObservation.
    public static func forAll<Request: FetchRequest>(_ request: Request)
        -> ValueObservation<ValueReducers.Raw<[Request.RowDecoder]>>
        where Request.RowDecoder: FetchableRecord
    {
        return ValueObservation<ValueReducers.Raw<[Request.RowDecoder]>>(
            observing: request.databaseRegion,
            reducer: ValueReducers.Raw(request.fetchAll))
    }
    
    /// Creates a ValueObservation which observes *request*, and notifies
    /// fresh records whenever the request is impacted by a
    /// database transaction.
    ///
    /// For example:
    ///
    ///     let request = Player.all()
    ///     let observation = ValueObservation.forAll(withUniquing: request)
    ///
    ///     let observer = dbQueue.add(observation: observation) { players: [Player] in
    ///         print("players have changed")
    ///     }
    ///
    /// The returned observation has the default configuration:
    ///
    /// - When started with the `add(observation:)` method, a fresh value is
    /// immediately notified on the dispatch queue which starts the observation.
    /// - Upon subsequent database changes, fresh values are notified on the
    /// main queue.
    /// - The observation lasts until the observer returned by
    /// `add(observation:)` is deallocated.
    ///
    /// See ValueObservation for more information.
    ///
    /// - parameter request: the observed request.
    /// - returns: a ValueObservation.
    public static func forAll<Request: FetchRequest>(withUniquing request: Request)
        -> ValueObservation<ValueReducers.UniqueRecords<Request.RowDecoder>>
        where Request.RowDecoder: FetchableRecord
    {
        return ValueObservation<ValueReducers.UniqueRecords<Request.RowDecoder>>(
            observing: request.databaseRegion,
            reducer: ValueReducers.UniqueRecords { try Row.fetchAll($0, request) })
    }
    
    /// Creates a ValueObservation which observes *request*, and notifies a
    /// fresh record whenever the request is impacted by a database transaction.
    ///
    /// For example:
    ///
    ///     let request = Player.filter(key: 1)
    ///     let observation = ValueObservation.forOne(request)
    ///
    ///     let observer = dbQueue.add(observation: observation) { player: Player? in
    ///         print("player has changed")
    ///     }
    ///
    /// The returned observation has the default configuration:
    ///
    /// - When started with the `add(observation:)` method, a fresh value is
    /// immediately notified on the dispatch queue which starts the observation.
    /// - Upon subsequent database changes, fresh values are notified on the
    /// main queue.
    /// - The observation lasts until the observer returned by
    /// `add(observation:)` is deallocated.
    ///
    /// See ValueObservation for more information.
    ///
    /// - parameter request: the observed request.
    /// - returns: a ValueObservation.
    public static func forOne<Request: FetchRequest>(_ request: Request) ->
        ValueObservation<ValueReducers.Raw<Request.RowDecoder?>>
        where Request.RowDecoder: FetchableRecord
    {
        return ValueObservation<ValueReducers.Raw<Request.RowDecoder?>>(
            observing: request.databaseRegion,
            reducer: ValueReducers.Raw(request.fetchOne))
    }
    
    /// Creates a ValueObservation which observes *request*, and notifies a
    /// fresh record whenever the request is impacted by a database transaction.
    ///
    /// For example:
    ///
    ///     let request = Player.filter(key: 1)
    ///     let observation = ValueObservation.forOne(withUniquing: request)
    ///
    ///     let observer = dbQueue.add(observation: observation) { player: Player? in
    ///         print("player has changed")
    ///     }
    ///
    /// The returned observation has the default configuration:
    ///
    /// - When started with the `add(observation:)` method, a fresh value is
    /// immediately notified on the dispatch queue which starts the observation.
    /// - Upon subsequent database changes, fresh values are notified on the
    /// main queue.
    /// - The observation lasts until the observer returned by
    /// `add(observation:)` is deallocated.
    ///
    /// See ValueObservation for more information.
    ///
    /// - parameter request: the observed request.
    /// - returns: a ValueObservation.
    public static func forOne<Request: FetchRequest>(withUniquing request: Request) ->
        ValueObservation<ValueReducers.UniqueRecord<Request.RowDecoder>>
        where Request.RowDecoder: FetchableRecord
    {
        return ValueObservation<ValueReducers.UniqueRecord<Request.RowDecoder>>(
            observing: request.databaseRegion,
            reducer: ValueReducers.UniqueRecord { try Row.fetchOne($0, request) })
    }
}

//// MARK: - DatabaseValueConvertible Observation
//
//extension ValueObservation where Value == Void {
//    /// Creates a ValueObservation which observes *request*, and notifies
//    /// fresh values whenever the request is impacted by a
//    /// database transaction.
//    ///
//    /// For example:
//    ///
//    ///     let request = Player.select(Column("name"), as: String.self)
//    ///     let observation = ValueObservation.forAll(request)
//    ///
//    ///     let observer = dbQueue.add(observation: observation) { names: [String] in
//    ///         print("player name have changed")
//    ///     }
//    ///
//    /// The returned observation has the default configuration:
//    ///
//    /// - When started with the `add(observation:)` method, a fresh value is
//    /// immediately notified on the dispatch queue which starts the observation.
//    /// - Upon subsequent database changes, fresh values are notified on the
//    /// main queue.
//    /// - The observation lasts until the observer returned by
//    /// `add(observation:)` is deallocated.
//    ///
//    /// See ValueObservation for more information.
//    ///
//    /// - parameter request: the observed request.
//    /// - returns: a ValueObservation.
//    public static func forAll<Request: FetchRequest>(_ request: Request)
//        -> ValueObservation<[Request.RowDecoder]>
//        where Request.RowDecoder: DatabaseValueConvertible
//    {
//        return ValueObservation<[Request.RowDecoder]>(
//            observing: request.databaseRegion,
//            fetch: request.fetchAll)
//    }
//    
//    /// Creates a ValueObservation which observes *request*, and notifies a
//    /// fresh value whenever the request is impacted by a database transaction.
//    ///
//    /// For example:
//    ///
//    ///     let request = Player.select(max(Column("score")), as: Int.self)
//    ///     let observation = ValueObservation.forOne(request)
//    ///
//    ///     let observer = dbQueue.add(observation: observation) { maxScore: Int? in
//    ///         print("maximum score has changed")
//    ///     }
//    ///
//    /// The returned observation has the default configuration:
//    ///
//    /// - When started with the `add(observation:)` method, a fresh value is
//    /// immediately notified on the dispatch queue which starts the observation.
//    /// - Upon subsequent database changes, fresh values are notified on the
//    /// main queue.
//    /// - The observation lasts until the observer returned by
//    /// `add(observation:)` is deallocated.
//    ///
//    /// See ValueObservation for more information.
//    ///
//    /// - parameter request: the observed request.
//    /// - returns: a ValueObservation.
//    public static func forOne<Request: FetchRequest>(_ request: Request)
//        -> ValueObservation<Request.RowDecoder?>
//        where Request.RowDecoder: DatabaseValueConvertible
//    {
//        return ValueObservation<Request.RowDecoder?>(
//            observing: request.databaseRegion,
//            fetch: request.fetchOne)
//    }
//}
//
//// MARK: - DatabaseValueConvertible & StatementColumnConvertible Observation
//
//extension ValueObservation where Value == Void {
//    /// Creates a ValueObservation which observes *request*, and notifies
//    /// fresh values whenever the request is impacted by a
//    /// database transaction.
//    ///
//    /// For example:
//    ///
//    ///     let request = Player.select(Column("name"), as: String.self)
//    ///     let observation = ValueObservation.forAll(request)
//    ///
//    ///     let observer = dbQueue.add(observation: observation) { names: [String] in
//    ///         print("player name have changed")
//    ///     }
//    ///
//    /// The returned observation has the default configuration:
//    ///
//    /// - When started with the `add(observation:)` method, a fresh value is
//    /// immediately notified on the dispatch queue which starts the observation.
//    /// - Upon subsequent database changes, fresh values are notified on the
//    /// main queue.
//    /// - The observation lasts until the observer returned by
//    /// `add(observation:)` is deallocated.
//    ///
//    /// See ValueObservation for more information.
//    ///
//    /// - parameter request: the observed request.
//    /// - returns: a ValueObservation.
//    public static func forAll<Request: FetchRequest>(_ request: Request)
//        -> ValueObservation<[Request.RowDecoder]>
//        where Request.RowDecoder: DatabaseValueConvertible & StatementColumnConvertible
//    {
//        return ValueObservation<[Request.RowDecoder]>(
//            observing: request.databaseRegion,
//            fetch: request.fetchAll)
//    }
//    
//    /// Creates a ValueObservation which observes *request*, and notifies a
//    /// fresh value whenever the request is impacted by a database transaction.
//    ///
//    /// For example:
//    ///
//    ///     let request = Player.select(max(Column("score")), as: Int.self)
//    ///     let observation = ValueObservation.forOne(request)
//    ///
//    ///     let observer = dbQueue.add(observation: observation) { maxScore: Int? in
//    ///         print("maximum score has changed")
//    ///     }
//    ///
//    /// The returned observation has the default configuration:
//    ///
//    /// - When started with the `add(observation:)` method, a fresh value is
//    /// immediately notified on the dispatch queue which starts the observation.
//    /// - Upon subsequent database changes, fresh values are notified on the
//    /// main queue.
//    /// - The observation lasts until the observer returned by
//    /// `add(observation:)` is deallocated.
//    ///
//    /// See ValueObservation for more information.
//    ///
//    /// - parameter request: the observed request.
//    /// - returns: a ValueObservation.
//    public static func forOne<Request: FetchRequest>(_ request: Request)
//        -> ValueObservation<Request.RowDecoder?>
//        where Request.RowDecoder: DatabaseValueConvertible & StatementColumnConvertible
//    {
//        return ValueObservation<Request.RowDecoder?>(
//            observing: request.databaseRegion,
//            fetch: request.fetchOne)
//    }
//}
//
//// MARK: - Optional DatabaseValueConvertible Observation
//
//extension ValueObservation where Value == Void {
//    /// Creates a ValueObservation which observes *request*, and notifies
//    /// fresh values whenever the request is impacted by a
//    /// database transaction.
//    ///
//    /// For example:
//    ///
//    ///     let request = Player.select(Column("name"), as: String.self)
//    ///     let observation = ValueObservation.forAll(request)
//    ///
//    ///     let observer = dbQueue.add(observation: observation) { names: [String] in
//    ///         print("player name have changed")
//    ///     }
//    ///
//    /// The returned observation has the default configuration:
//    ///
//    /// - When started with the `add(observation:)` method, a fresh value is
//    /// immediately notified on the dispatch queue which starts the observation.
//    /// - Upon subsequent database changes, fresh values are notified on the
//    /// main queue.
//    /// - The observation lasts until the observer returned by
//    /// `add(observation:)` is deallocated.
//    ///
//    /// See ValueObservation for more information.
//    ///
//    /// - parameter request: the observed request.
//    /// - returns: a ValueObservation.
//    public static func forAll<Request: FetchRequest>(_ request: Request)
//        -> ValueObservation<[Request.RowDecoder._Wrapped?]>
//        where Request.RowDecoder: _OptionalProtocol,
//        Request.RowDecoder._Wrapped: DatabaseValueConvertible
//    {
//        return ValueObservation<[Request.RowDecoder._Wrapped?]>(
//            observing: request.databaseRegion,
//            fetch: request.fetchAll)
//    }
//}
//
//// MARK: - Optional DatabaseValueConvertible & StatementColumnConvertible Observation
//
//extension ValueObservation where Value == Void {
//    /// Creates a ValueObservation which observes *request*, and notifies
//    /// fresh values whenever the request is impacted by a
//    /// database transaction.
//    ///
//    /// For example:
//    ///
//    ///     let request = Player.select(Column("name"), as: String.self)
//    ///     let observation = ValueObservation.forAll(request)
//    ///
//    ///     let observer = dbQueue.add(observation: observation) { names: [String] in
//    ///         print("player name have changed")
//    ///     }
//    ///
//    /// The returned observation has the default configuration:
//    ///
//    /// - When started with the `add(observation:)` method, a fresh value is
//    /// immediately notified on the dispatch queue which starts the observation.
//    /// - Upon subsequent database changes, fresh values are notified on the
//    /// main queue.
//    /// - The observation lasts until the observer returned by
//    /// `add(observation:)` is deallocated.
//    ///
//    /// See ValueObservation for more information.
//    ///
//    /// - parameter request: the observed request.
//    /// - returns: a ValueObservation.
//    public static func forAll<Request: FetchRequest>(_ request: Request)
//        -> ValueObservation<[Request.RowDecoder._Wrapped?]>
//        where Request.RowDecoder: _OptionalProtocol,
//        Request.RowDecoder._Wrapped: DatabaseValueConvertible & StatementColumnConvertible
//    {
//        return ValueObservation<[Request.RowDecoder._Wrapped?]>(
//            observing: request.databaseRegion,
//            fetch: request.fetchAll)
//    }
//}
