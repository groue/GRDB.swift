extension FetchRequest where RowDecoder: DatabaseValueConvertible {
    
    // MARK: - Observation
    
    /// Creates a ValueObservation which observes *request*, and notifies
    /// fresh values whenever the request is modified by a
    /// database transaction.
    ///
    /// For example:
    ///
    ///     let request = Player.select(Column("name"), as: String.self)
    ///     let observation = request.observationForAll()
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
    /// - returns: a ValueObservation.
    public func observationForAll() -> ValueObservation<DatabaseValuesReducer<RowDecoder>> {
        return ValueObservation.tracking(self, reducer: { _ in
            DatabaseValuesReducer { try DatabaseValue.fetchAll($0, self) }
        })
    }
    
    /// Creates a ValueObservation which observes *request*, and notifies a
    /// fresh value whenever the request is modified by a database transaction.
    ///
    /// For example:
    ///
    ///     let request = Player.select(max(Column("score")), as: Int.self)
    ///     let observation = request.observationForFirst()
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
    public func observationForFirst() -> ValueObservation<DatabaseValueReducer<RowDecoder>> {
        return ValueObservation.tracking(self, reducer: { _ in
            DatabaseValueReducer { try DatabaseValue.fetchOne($0, self) }
        })
    }
}

extension FetchRequest where RowDecoder: _OptionalProtocol, RowDecoder._Wrapped: DatabaseValueConvertible {
    
    // MARK: - Observation
    
    // TODO: add support for trackingOne as well
    
    /// Creates a ValueObservation which observes *request*, and notifies
    /// fresh values whenever the request is modified by a
    /// database transaction.
    ///
    /// For example:
    ///
    ///     let request = Player.select(Column("name"), as: Optional<String>.self)
    ///     let observation = request.observationForAll()
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
    /// - returns: a ValueObservation.
    public func observationForAll() -> ValueObservation<OptionalDatabaseValuesReducer<RowDecoder._Wrapped>> {
        return ValueObservation.tracking(self, reducer: { _ in
            OptionalDatabaseValuesReducer { try DatabaseValue.fetchAll($0, self) }
        })
    }
    
    /// Creates a ValueObservation which observes *request*, and notifies
    /// fresh values whenever the request is modified by a
    /// database transaction.
    ///
    /// For example:
    ///
    ///     let request = Player.select(Column("name"), as: Optional<String>.self)
    ///     let observation = request.observationForAll()
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
    /// - returns: a ValueObservation.
    public func observationForFirst() -> ValueObservation<DatabaseValueReducer<RowDecoder._Wrapped>> {
        return ValueObservation.tracking(self, reducer: { _ in
            DatabaseValueReducer { try DatabaseValue.fetchOne($0, self) }
        })
    }
}

extension ValueObservation where Reducer == Void {

    // MARK: - DatabaseValueConvertible Observation

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
    @available(*, deprecated, message: "Use request.observationForAll() instead")
    public static func trackingAll<Request: FetchRequest>(_ request: Request)
        -> ValueObservation<DatabaseValuesReducer<Request.RowDecoder>>
        where Request.RowDecoder: DatabaseValueConvertible
    {
        return request.observationForAll()
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
    @available(*, deprecated, message: "Use request.observationForFirst() instead")
    public static func trackingOne<Request: FetchRequest>(_ request: Request)
        -> ValueObservation<DatabaseValueReducer<Request.RowDecoder>>
        where Request.RowDecoder: DatabaseValueConvertible
    {
        return request.observationForFirst()
    }
    
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
    @available(*, deprecated, message: "Use request.observationForAll() instead")
    public static func trackingAll<Request: FetchRequest>(_ request: Request)
        -> ValueObservation<OptionalDatabaseValuesReducer<Request.RowDecoder._Wrapped>>
        where Request.RowDecoder: _OptionalProtocol,
        Request.RowDecoder._Wrapped: DatabaseValueConvertible
    {
        return request.observationForAll()
    }
}

/// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
///
/// A reducer which outputs arrays of values, filtering out consecutive
/// identical database values.
///
/// :nodoc:
public struct DatabaseValuesReducer<RowDecoder>: ValueReducer
    where RowDecoder: DatabaseValueConvertible
{
    private let _fetch: (Database) throws -> [DatabaseValue]
    private var previousDbValues: [DatabaseValue]?
    
    init(fetch: @escaping (Database) throws -> [DatabaseValue]) {
        self._fetch = fetch
    }
    
    public func fetch(_ db: Database) throws -> [DatabaseValue] {
        return try _fetch(db)
    }
    
    public mutating func value(_ dbValues: [DatabaseValue]) -> [RowDecoder]? {
        if let previousDbValues = previousDbValues, previousDbValues == dbValues {
            // Don't notify consecutive identical dbValue arrays
            return nil
        }
        self.previousDbValues = dbValues
        return dbValues.map {
            RowDecoder.decode(from: $0, conversionContext: nil)
        }
    }
}

/// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
///
/// A reducer which outputs optional values, filtering out consecutive
/// identical database values.
///
/// :nodoc:
public struct DatabaseValueReducer<RowDecoder>: ValueReducer
    where RowDecoder: DatabaseValueConvertible
{
    private let _fetch: (Database) throws -> DatabaseValue?
    private var previousDbValue: DatabaseValue??
    private var previousValueWasNil = false
    
    init(fetch: @escaping (Database) throws -> DatabaseValue?) {
        self._fetch = fetch
    }
    
    public func fetch(_ db: Database) throws -> DatabaseValue? {
        return try _fetch(db)
    }

    public mutating func value(_ dbValue: DatabaseValue?) -> RowDecoder?? {
        if let previousDbValue = previousDbValue, previousDbValue == dbValue {
            // Don't notify consecutive identical dbValue
            return nil
        }
        self.previousDbValue = dbValue
        if let dbValue = dbValue,
            let value = RowDecoder.decodeIfPresent(from: dbValue, conversionContext: nil)
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

/// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
///
/// A reducer which outputs arrays of optional values, filtering out consecutive
/// identical database values.
///
/// :nodoc:
public struct OptionalDatabaseValuesReducer<RowDecoder>: ValueReducer
    where RowDecoder: DatabaseValueConvertible
{
    private let _fetch: (Database) throws -> [DatabaseValue]
    private var previousDbValues: [DatabaseValue]?
    
    init(fetch: @escaping (Database) throws -> [DatabaseValue]) {
        self._fetch = fetch
    }
    
    public func fetch(_ db: Database) throws -> [DatabaseValue] {
        return try _fetch(db)
    }

    public mutating func value(_ dbValues: [DatabaseValue]) -> [RowDecoder?]? {
        if let previousDbValues = previousDbValues, previousDbValues == dbValues {
            // Don't notify consecutive identical dbValue arrays
            return nil
        }
        self.previousDbValues = dbValues
        return dbValues.map {
            RowDecoder.decodeIfPresent(from: $0, conversionContext: nil)
        }
    }
}
