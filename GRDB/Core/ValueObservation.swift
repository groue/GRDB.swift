//
//  ValueObservation.swift
//  GRDB
//
//  Created by Gwendal Roué on 23/10/2018.
//  Copyright © 2018 Gwendal Roué. All rights reserved.
//

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
    ///     let observation = ValueObservation.trackingAll(Player.all())
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
    ///     let observation = ValueObservation.trackingAll(Player.all())
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
    case onQueue(DispatchQueue, startImmediately: Bool)
    
    /// Values are not all notified on the same dispatch queue.
    ///
    /// If `startImmediately` is true, an initial value is notified right upon
    /// subscription, synchronously, on the dispatch queue which starts
    /// the observation.
    ///
    ///     // On any queue
    ///     var observation = ValueObservation.trackingAll(Player.all())
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

extension DispatchQueue {
    private static var mainKey: DispatchSpecificKey<()> = {
        let key = DispatchSpecificKey<()>()
        DispatchQueue.main.setSpecific(key: key, value: ())
        return key
    }()
    
    static var isMain: Bool {
        return DispatchQueue.getSpecific(key: mainKey) != nil
    }
}

// MARK: - ValueReducer

/// The ValueReducer protocol supports ValueObservation.
public protocol ValueReducer {
    /// The type of fetched database values
    associatedtype Fetched
    
    /// The type of observed values
    associatedtype Value
    
    /// Feches database values upon changes in an observed database region.
    func fetch(_ db: Database) throws -> Fetched
    
    /// Transforms a fetched value into an eventual observed value. Returns nil
    /// when observer should not be notified.
    ///
    /// This method runs inside a private dispatch queue.
    mutating func value(_ fetched: Fetched) -> Value?
}

extension ValueReducer {
    /// Returns a reducer which transforms the values returned by this reducer.
    public func map<T>(_ transform: @escaping (Value) -> T?) -> MapValueReducer<Self, T> {
        return MapValueReducer(self, transform)
    }
}

/// A ValueReducer whose values consist of those in a Base ValueReducer passed
/// through a transform function.
///
/// See ValueReducer.map(_:)
///
/// :nodoc:
public struct MapValueReducer<Base: ValueReducer, T>: ValueReducer {
    private var base: Base
    private let transform: (Base.Value) -> T?

    init(_ base: Base, _ transform: @escaping (Base.Value) -> T?) {
        self.base = base
        self.transform = transform
    }

    public func fetch(_ db: Database) throws -> Base.Fetched {
        return try base.fetch(db)
    }

    public mutating func value(_ fetched: Base.Fetched) -> T? {
        guard let value = base.value(fetched) else { return nil }
        return transform(value)
    }
}

/// A type-erased ValueReducer.
///
/// An AnyValueReducer forwards its operations to an underlying reducer,
/// hiding its specifics.
public struct AnyValueReducer<Fetched, Value>: ValueReducer {
    private var _fetch: (Database) throws -> Fetched
    private var _value: (Fetched) -> Value?
    
    /// Creates a reducer whose `fetch(_:)` and `value(_:)` methods wrap and
    /// forward operations the argument closures.
    ///
    /// For example, this reducer counts the number of a times the player table
    /// is modified:
    ///
    ///     var count = 0
    ///     let reducer = AnyValueReducer(
    ///         fetch: { _ in },
    ///         value: { _ -> Int? in
    ///             count += 1
    ///             return count
    ///     })
    ///     let observer = ValueObservation
    ///         .tracking(Player.all(), reducer: reducer)
    ///         .start(in: dbQueue) { count: Int in
    ///             print("Players have been modified \(count) times.")
    ///         }
    public init(fetch: @escaping (Database) throws -> Fetched, value: @escaping (Fetched) -> Value?) {
        self._fetch = fetch
        self._value = value
    }
    
    /// Creates a reducer that wraps and forwards operations to `reducer`.
    public init<Base: ValueReducer>(_ reducer: Base) where Base.Fetched == Fetched, Base.Value == Value {
        var reducer = reducer
        self._fetch = { try reducer.fetch($0) }
        self._value = { reducer.value($0) }
    }
    
    /// :nodoc:
    public func fetch(_ db: Database) throws -> Fetched {
        return try _fetch(db)
    }
    
    /// :nodoc:
   public func value(_ fetched: Fetched) -> Value? {
        return _value(fetched)
    }
}

public enum ValueReducers {
    /// A reducer which outputs raw database values, without any processing.
    public struct Raw<Value>: ValueReducer {
        private let _fetch: (Database) throws -> Value
        
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
    
    /// A reducer which outputs raw database values, filtering out consecutive
    /// values that are equal.
    public struct Distinct<Value: Equatable>: ValueReducer {
        private let _fetch: (Database) throws -> Value
        private var previousValue: Value??
        
        public init(_ fetch: @escaping (Database) throws -> Value) {
            self._fetch = fetch
        }
        
        /// :nodoc:
        public func fetch(_ db: Database) throws -> Value {
            return try _fetch(db)
        }
        
        /// :nodoc:
        public mutating func value(_ value: Value) -> Value? {
            if let previousValue = previousValue, previousValue == value {
                // Don't notify consecutive identical values
                return nil
            }
            self.previousValue = value
            return value
        }
    }
    
    /// A reducer which outputs arrays of records, filtering out consecutive
    /// identical database rows.
    public struct Records<Record: FetchableRecord>: ValueReducer {
        private let _fetch: (Database) throws -> [Row]
        private var previousRows: [Row]?
        
        /// TODO
        public init(_ fetch: @escaping (Database) throws -> [Row]) {
            self._fetch = fetch
        }
        
        /// :nodoc:
        public func fetch(_ db: Database) throws -> [Row] {
            return try _fetch(db)
        }
        
        /// :nodoc:
        public mutating func value(_ rows: [Row]) -> [Record]? {
            if let previousRows = previousRows, previousRows == rows {
                // Don't notify consecutive identical row arrays
                return nil
            }
            self.previousRows = rows
            return rows.map(Record.init(row:))
        }
    }
    
    /// A reducer which outputs optional records, filtering out consecutive
    /// identical database rows.
    public struct Record<Record: FetchableRecord>: ValueReducer {
        private let _fetch: (Database) throws -> Row?
        private var previousRow: Row??
        
        /// TODO
        public init(_ fetch: @escaping (Database) throws -> Row?) {
            self._fetch = fetch
        }
        
        /// :nodoc:
        public func fetch(_ db: Database) throws -> Row? {
            return try _fetch(db)
        }
        
        /// :nodoc:
        public mutating func value(_ row: Row?) -> Record?? {
            if let previousRow = previousRow, previousRow == row {
                // Don't notify consecutive identical rows
                return nil
            }
            self.previousRow = row
            return .some(row.map(Record.init(row:)))
        }
    }
    
    /// A reducer which outputs arrays of values, filtering out consecutive
    /// identical database values.
    public struct Values<T: DatabaseValueConvertible>: ValueReducer {
        private let _fetch: (Database) throws -> [DatabaseValue]
        private var previousDbValues: [DatabaseValue]?
        
        /// TODO
        public init(_ fetch: @escaping (Database) throws -> [DatabaseValue]) {
            self._fetch = fetch
        }
        
        /// :nodoc:
        public func fetch(_ db: Database) throws -> [DatabaseValue] {
            return try _fetch(db)
        }
        
        /// :nodoc:
        public mutating func value(_ dbValues: [DatabaseValue]) -> [T]? {
            if let previousDbValues = previousDbValues, previousDbValues == dbValues {
                // Don't notify consecutive identical dbValue arrays
                return nil
            }
            self.previousDbValues = dbValues
            return dbValues.map {
                T.decode(from: $0, conversionContext: nil)
            }
        }
    }
    
    /// A reducer which outputs optional values, filtering out consecutive
    /// identical database values.
    public struct Value<T: DatabaseValueConvertible>: ValueReducer {
        private let _fetch: (Database) throws -> DatabaseValue?
        private var previousDbValue: DatabaseValue??
        private var previousValueWasNil = false
        
        /// TODO
        public init(_ fetch: @escaping (Database) throws -> DatabaseValue?) {
            self._fetch = fetch
        }
        
        /// :nodoc:
        public func fetch(_ db: Database) throws -> DatabaseValue? {
            return try _fetch(db)
        }
        
        /// :nodoc:
        public mutating func value(_ dbValue: DatabaseValue?) -> T?? {
            if let previousDbValue = previousDbValue, previousDbValue == dbValue {
                // Don't notify consecutive identical dbValue
                return nil
            }
            self.previousDbValue = dbValue
            if let dbValue = dbValue,
                let value = T.decodeIfPresent(from: dbValue, conversionContext: nil)
            {
                previousValueWasNil = false
                return .some(value)
            } else if previousValueWasNil {
                // Don't notify consecutive nil values
                return nil
            } else {
                previousValueWasNil = true
                return .some(nil)
            }
        }
    }
    
    /// A reducer which outputs arrays of optional values, filtering out consecutive
    /// identical database values.
    public struct OptionalValues<T: DatabaseValueConvertible>: ValueReducer {
        private let _fetch: (Database) throws -> [DatabaseValue]
        private var previousDbValues: [DatabaseValue]?
        
        /// TODO
        public init(_ fetch: @escaping (Database) throws -> [DatabaseValue]) {
            self._fetch = fetch
        }
        
        /// :nodoc:
        public func fetch(_ db: Database) throws -> [DatabaseValue] {
            return try _fetch(db)
        }
        
        /// :nodoc:
        public mutating func value(_ dbValues: [DatabaseValue]) -> [T?]? {
            if let previousDbValues = previousDbValues, previousDbValues == dbValues {
                // Don't notify consecutive identical dbValue arrays
                return nil
            }
            self.previousDbValues = dbValues
            return dbValues.map {
                T.decodeIfPresent(from: $0, conversionContext: nil)
            }
        }
    }
}

// MARK: - ValueObservation

/// ValueObservation tracks changes in the results of database requests, and
/// notifies fresh values whenever the database changes.
///
/// For example:
///
///     let observation = ValueObservation.trackingAll(Player.all)
///     let observer = try observation.start(in: dbQueue) { players: [Player] in
///         print("Players have changed.")
///     }
public struct ValueObservation<Reducer> {
    /// A closure that is evaluated when the observation starts, and returns
    /// the observed database region.
    var observedRegion: (Database) throws -> DatabaseRegion
    
    /// The reducer is triggered upon each database change in *observedRegion*.
    var reducer: Reducer
    
    /// Default is false. Set this property to true when the observation
    /// requires write access in order to fetch fresh values. Fetches are then
    /// wrapped inside a savepoint.
    ///
    /// Don't set this flag to true unless you really need it. A read/write
    /// observation is less efficient than a read-only observation.
    public var requiresWriteAccess: Bool = false
    
    /// The extent of the database observation. The default is
    /// `.observerLifetime`: the observation lasts until the
    /// observer returned by the `start(in:onError:onChange:)` method
    /// is deallocated.
    public var extent = Database.TransactionObservationExtent.observerLifetime
    
    /// `scheduling` controls how fresh values are notified. Default
    /// is `.mainQueue`.
    ///
    /// - `.mainQueue`: all values are notified on the main queue.
    ///
    ///     If the observation starts on the main queue, an initial value is
    ///     notified right upon subscription, synchronously::
    ///
    ///         // On main queue
    ///         let observation = ValueObservation.trackingAll(Player.all())
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
    ///         let observation = ValueObservation.trackingAll(Player.all())
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
    ///         var observation = ValueObservation.trackingAll(Player.all())
    ///         observation.scheduling = .unsafe(startImmediately: true)
    ///         let observer = try observation.start(in: dbQueue) { players: [Player] in
    ///             print("fresh players: \(players)")
    ///         }
    ///         // <- here "fresh players" is already printed.
    ///
    ///     When the database changes, other values are notified on
    ///     unspecified queues.
    public var scheduling: ValueScheduling = .mainQueue
    
    /// The dispatch queue where change callbacks are called.
    var notificationQueue: DispatchQueue? {
        switch scheduling {
        case .mainQueue:
            return DispatchQueue.main
        case .onQueue(let queue, startImmediately: _):
            return queue
        case .unsafe:
            return nil
        }
    }
    
    // Not public. See ValueObservation.tracking(_:reducer:)
    init(
        tracking region: @escaping (Database) throws -> DatabaseRegion,
        reducer: Reducer)
    {
        self.observedRegion = region
        self.reducer = reducer
    }
    
    /// Returs a ValueObservation which observes *regions*, and notifies the
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
    ///         fetch: { _ in },
    ///         value: { _ -> Int? in
    ///             count += 1
    ///             return count
    ///     })
    ///     let observation = ValueObservation.tracking(Player.all(), reducer: reducer)
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
        reducer: Reducer)
        -> ValueObservation
    {
        return ValueObservation(tracking: union(regions), reducer: reducer)
    }
}

extension ValueObservation where Reducer: ValueReducer {
    /// Returns a ValueObservation which transforms the values returned by
    /// this ValueObservation.
    public func map<T>(_ transform: @escaping (Reducer.Value) -> T)
        -> ValueObservation<MapValueReducer<Reducer, T>>
    {
        return ValueObservation<MapValueReducer<Reducer, T>>(
            tracking: observedRegion,
            reducer: reducer.map(transform))
    }
}

extension ValueObservation where Reducer == Void {
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
    ///     let observer = try observation.start(in: dbQueue) { player: [Player] in
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
        -> ValueObservation<ValueReducers.Raw<Value>>
    {
        return ValueObservation<ValueReducers.Raw<Value>>(
            tracking: union(regions),
            reducer: ValueReducers.Raw(fetch))
    }
    
    /// Creates a ValueObservation which observes *regions*, and notifies the
    /// values returned by the *fetch* closure whenever one of the observed
    /// regions is modified by a database transaction. Consecutive equal values
    /// are filtered out.
    ///
    /// For example:
    ///
    ///     let observation = ValueObservation.tracking(
    ///         Player.all(),
    ///         fetchDistinct: { db in return try Player.fetchAll(db) })
    ///
    ///     let observer = try observation.start(in: dbQueue) { player: [Player] in
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
        fetchDistinct fetch: @escaping (Database) throws -> Value)
        -> ValueObservation<ValueReducers.Distinct<Value>>
        where Value: Equatable
    {
        return ValueObservation<ValueReducers.Distinct<Value>>(
            tracking: union(regions),
            reducer: ValueReducers.Distinct(fetch))
    }
}

private func union(_ regions: [DatabaseRegionConvertible]) -> (Database) throws -> DatabaseRegion {
    return { db in
        try regions.reduce(into: DatabaseRegion()) { union, region in
            try union.formUnion(region.databaseRegion(db))
        }
    }
}

// MARK: - Starting Observation

extension ValueObservation where Reducer: ValueReducer {
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
        onError: ((Error) -> Void)? = nil,
        onChange: @escaping (Reducer.Value) -> Void) throws -> TransactionObserver
    {
        return try reader.add(observation: self, onError: onError, onChange: onChange)
    }
}

// MARK: - Count Observation

extension ValueObservation where Reducer == Void {
    /// Creates a ValueObservation which observes *request*, and notifies its
    /// count whenever it is modified by a database transaction.
    ///
    /// For example:
    ///
    ///     let request = Player.all()
    ///     let observation = ValueObservation.trackingCount(request)
    ///
    ///     let observer = try observation.start(in: dbQueue) { count: Int in
    ///         print("Number of players has changed")
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
    /// - parameter request: the observed request.
    /// - returns: a ValueObservation.
    public static func trackingCount<Request: FetchRequest>(_ request: Request)
        -> ValueObservation<ValueReducers.Distinct<Int>>
    {
        return ValueObservation.tracking(request, fetchDistinct: request.fetchCount)
    }
}

// MARK: - Row Observation

extension ValueObservation where Reducer == Void {
    /// Creates a ValueObservation which observes *request*, and notifies
    /// fresh rows whenever the request is modified by a database transaction.
    ///
    /// For example:
    ///
    ///     let request = SQLRequest<Row>("SELECT * FROM player")
    ///     let observation = ValueObservation.trackingAll(request)
    ///
    ///     let observer = try observation.start(in: dbQueue) { rows: [Row] in
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
    /// - parameter request: the observed request.
    /// - returns: a ValueObservation.
    public static func trackingAll<Request: FetchRequest>(_ request: Request)
        -> ValueObservation<ValueReducers.Distinct<[Row]>>
        where Request.RowDecoder == Row
    {
        return ValueObservation.tracking(request, fetchDistinct: request.fetchAll)
    }
    
    /// Creates a ValueObservation which observes *request*, and notifies a
    /// fresh row whenever the request is modified by a database transaction.
    ///
    /// For example:
    ///
    ///     let request = SQLRequest<Row>("SELECT * FROM player WHERE id = ?", arguments: [1])
    ///     let observation = ValueObservation.trackingOne(request)
    ///
    ///     let observer = try observation.start(in: dbQueue) { row: Row? in
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
    /// - parameter request: the observed request.
    /// - returns: a ValueObservation.
    public static func trackingOne<Request: FetchRequest>(_ request: Request)
        -> ValueObservation<ValueReducers.Distinct<Row?>>
        where Request.RowDecoder == Row
    {
        return ValueObservation.tracking(request, fetchDistinct: request.fetchOne)
    }
}

// MARK: - FetchableRecord Observation

extension ValueObservation where Reducer == Void {
    /// Creates a ValueObservation which observes *request*, and notifies
    /// fresh records whenever the request is modified by a
    /// database transaction.
    ///
    /// For example:
    ///
    ///     let request = Player.all()
    ///     let observation = ValueObservation.trackingAll(request)
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
    /// - parameter request: the observed request.
    /// - returns: a ValueObservation.
    public static func trackingAll<Request: FetchRequest>(_ request: Request)
        -> ValueObservation<ValueReducers.Records<Request.RowDecoder>>
        where Request.RowDecoder: FetchableRecord
    {
        return ValueObservation<ValueReducers.Records<Request.RowDecoder>>.tracking(
            request,
            reducer: ValueReducers.Records { try Row.fetchAll($0, request) })
    }
    
    /// Creates a ValueObservation which observes *request*, and notifies a
    /// fresh record whenever the request is modified by a database transaction.
    ///
    /// For example:
    ///
    ///     let request = Player.filter(key: 1)
    ///     let observation = ValueObservation.trackingOne(request)
    ///
    ///     let observer = try observation.start(in: dbQueue) { player: Player? in
    ///         print("Player has changed")
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
    /// - parameter request: the observed request.
    /// - returns: a ValueObservation.
    public static func trackingOne<Request: FetchRequest>(_ request: Request) ->
        ValueObservation<ValueReducers.Record<Request.RowDecoder>>
        where Request.RowDecoder: FetchableRecord
    {
        return ValueObservation<ValueReducers.Record<Request.RowDecoder>>.tracking(
            request,
            reducer: ValueReducers.Record { try Row.fetchOne($0, request) })
    }
}

// MARK: - DatabaseValueConvertible Observation

extension ValueObservation where Reducer == Void {
    /// Creates a ValueObservation which observes *request*, and notifies
    /// fresh values whenever the request is modified by a
    /// database transaction.
    ///
    /// For example:
    ///
    ///     let request = Player.select(Column("name"), as: String.self)
    ///     let observation = ValueObservation.trackingAll(request)
    ///
    ///     let observer = try observation.start(in: dbQueue) { names: [String] in
    ///         print("Player names have changed")
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
    /// - parameter request: the observed request.
    /// - returns: a ValueObservation.
    public static func trackingAll<Request: FetchRequest>(_ request: Request)
        -> ValueObservation<ValueReducers.Values<Request.RowDecoder>>
        where Request.RowDecoder: DatabaseValueConvertible
    {
        return ValueObservation<ValueReducers.Values<Request.RowDecoder>>.tracking(
            request,
            reducer: ValueReducers.Values { try DatabaseValue.fetchAll($0, request) })
    }
    
    /// Creates a ValueObservation which observes *request*, and notifies a
    /// fresh value whenever the request is modified by a database transaction.
    ///
    /// For example:
    ///
    ///     let request = Player.select(max(Column("score")), as: Int.self)
    ///     let observation = ValueObservation.trackingOne(request)
    ///
    ///     let observer = try observation.start(in: dbQueue) { maxScore: Int? in
    ///         print("Maximum score has changed")
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
    /// - parameter request: the observed request.
    /// - returns: a ValueObservation.
    public static func trackingOne<Request: FetchRequest>(_ request: Request)
        -> ValueObservation<ValueReducers.Value<Request.RowDecoder>>
        where Request.RowDecoder: DatabaseValueConvertible
    {
        return ValueObservation<ValueReducers.Value<Request.RowDecoder>>.tracking(
            request,
            reducer: ValueReducers.Value { try DatabaseValue.fetchOne($0, request) })
    }
}

// MARK: - Optional DatabaseValueConvertible Observation

extension ValueObservation where Reducer == Void {
    /// Creates a ValueObservation which observes *request*, and notifies
    /// fresh values whenever the request is modified by a
    /// database transaction.
    ///
    /// For example:
    ///
    ///     let request = Player.select(Column("name"), as: Optional<String>.self)
    ///     let observation = ValueObservation.trackingAll(request)
    ///
    ///     let observer = try observation.start(in: dbQueue) { names: [String?] in
    ///         print("Player names have changed")
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
    /// - parameter request: the observed request.
    /// - returns: a ValueObservation.
    public static func trackingAll<Request: FetchRequest>(_ request: Request)
        -> ValueObservation<ValueReducers.OptionalValues<Request.RowDecoder._Wrapped>>
        where Request.RowDecoder: _OptionalProtocol,
        Request.RowDecoder._Wrapped: DatabaseValueConvertible
    {
        return ValueObservation<ValueReducers.OptionalValues<Request.RowDecoder._Wrapped>>.tracking(
            request,
            reducer: ValueReducers.OptionalValues { try DatabaseValue.fetchAll($0, request) })
    }
}
