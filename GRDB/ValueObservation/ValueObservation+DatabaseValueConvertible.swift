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
    public static func trackingAll<Request: FetchRequest>(_ request: Request)
        -> ValueObservation<DatabaseValuesReducer<Request>>
        where Request.RowDecoder: DatabaseValueConvertible
    {
        return ValueObservation<DatabaseValuesReducer<Request>>.tracking(request, reducer: { _ in
            DatabaseValuesReducer(request: request) }
        )
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
        -> ValueObservation<DatabaseValueReducer<Request>>
        where Request.RowDecoder: DatabaseValueConvertible
    {
        return ValueObservation<DatabaseValueReducer<Request>>.tracking(request, reducer: { _ in DatabaseValueReducer(request: request)
        })
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
    public static func trackingAll<Request: FetchRequest>(_ request: Request)
        -> ValueObservation<OptionalDatabaseValuesReducer<Request>>
        where Request.RowDecoder: _OptionalProtocol,
        Request.RowDecoder._Wrapped: DatabaseValueConvertible
    {
        return ValueObservation<OptionalDatabaseValuesReducer<Request>>.tracking(request, reducer: { _ in
            OptionalDatabaseValuesReducer(request: request)
        })
    }
}

/// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
///
/// A reducer which outputs arrays of values, filtering out consecutive
/// identical database values.
///
/// :nodoc:
public struct DatabaseValuesReducer<Request: FetchRequest>: ValueReducer
    where Request.RowDecoder: DatabaseValueConvertible
{
    public let request: Request
    private var previousDbValues: [DatabaseValue]?
    
    init(request: Request) {
        self.request = request
    }
    
    public func fetch(_ db: Database) throws -> [DatabaseValue] {
        return try DatabaseValue.fetchAll(db, request)
    }
    
    public mutating func value(_ dbValues: [DatabaseValue]) -> [Request.RowDecoder]? {
        if let previousDbValues = previousDbValues, previousDbValues == dbValues {
            // Don't notify consecutive identical dbValue arrays
            // TODO: Remove this implicit `distinctUntilDatabaseChanged` in GRDB 4
            return nil
        }
        self.previousDbValues = dbValues
        return dbValues.map {
            Request.RowDecoder.decode(from: $0, conversionContext: nil)
        }
    }
}

/// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
///
/// A reducer which outputs optional values, filtering out consecutive
/// identical database values.
///
/// :nodoc:
public struct DatabaseValueReducer<Request: FetchRequest>: ValueReducer
    where Request.RowDecoder: DatabaseValueConvertible
{
    public let request: Request
    private var previousDbValue: DatabaseValue??
    private var previousValueWasNil = false
    
    init(request: Request) {
        self.request = request
    }
    
    public func fetch(_ db: Database) throws -> DatabaseValue? {
        return try DatabaseValue.fetchOne(db, request)
    }
    
    public mutating func value(_ dbValue: DatabaseValue?) -> Request.RowDecoder?? {
        if let previousDbValue = previousDbValue, previousDbValue == dbValue {
            // Don't notify consecutive identical dbValue
            // TODO: Remove this implicit `distinctUntilDatabaseChanged` in GRDB 4
            return nil
        }
        self.previousDbValue = dbValue
        if let dbValue = dbValue,
            let value = Request.RowDecoder.decodeIfPresent(from: dbValue, conversionContext: nil)
        {
            previousValueWasNil = false
            return .some(value)
        } else if previousValueWasNil {
            // Don't notify consecutive nil values
            // TODO: Remove this implicit `distinctUntilDatabaseChanged` in GRDB 4
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
public struct OptionalDatabaseValuesReducer<Request: FetchRequest>: ValueReducer
    where
    Request.RowDecoder: _OptionalProtocol,
    Request.RowDecoder._Wrapped: DatabaseValueConvertible
{
    public let request: Request
    private var previousDbValues: [DatabaseValue]?
    
    init(request: Request) {
        self.request = request
    }
    
    public func fetch(_ db: Database) throws -> [DatabaseValue] {
        return try DatabaseValue.fetchAll(db, request)
    }
    
    public mutating func value(_ dbValues: [DatabaseValue]) -> [Request.RowDecoder._Wrapped?]? {
        if let previousDbValues = previousDbValues, previousDbValues == dbValues {
            // Don't notify consecutive identical dbValue arrays
            // TODO: Remove this implicit `distinctUntilDatabaseChanged` in GRDB 4
            return nil
        }
        self.previousDbValues = dbValues
        return dbValues.map {
            Request.RowDecoder._Wrapped.decodeIfPresent(from: $0, conversionContext: nil)
        }
    }
}
