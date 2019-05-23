extension ValueObservation where Reducer == Void {

    // MARK: - Row Observation
    
    /// Creates a ValueObservation which observes *request*, and notifies
    /// fresh rows whenever the request is modified by a database transaction.
    ///
    /// For example:
    ///
    ///     let request = SQLRequest<Row>(sql: "SELECT * FROM player")
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
        -> ValueObservation<RowsReducer>
        where Request.RowDecoder == Row
    {
        return ValueObservation<RowsReducer>.tracking(request, reducer: { _ in
            RowsReducer(fetch: request.fetchAll)
        })
    }
    
    /// Creates a ValueObservation which observes *request*, and notifies
    /// fresh rows whenever the request is modified by a database transaction.
    ///
    /// For example:
    ///
    ///     let request = SQLRequest<Row>(sql: "SELECT * FROM player")
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
    public static func trackingAll(_ request: QueryInterfaceRequest<Row>)
        -> ValueObservation<RowsReducer>
    {
        return ValueObservation<RowsReducer>.tracking(request, reducer: { _ in
            RowsReducer(fetch: request.fetchAll)
        })
    }
    
    /// Creates a ValueObservation which observes *request*, and notifies a
    /// fresh row whenever the request is modified by a database transaction.
    ///
    /// For example:
    ///
    ///     let request = SQLRequest<Row>(sql: "SELECT * FROM player WHERE id = ?", arguments: [1])
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
        -> ValueObservation<RowReducer>
        where Request.RowDecoder == Row
    {
        return ValueObservation<RowReducer>.tracking(request, reducer: { _ in
            RowReducer(fetch: request.fetchOne)
        })
    }
    
    /// Creates a ValueObservation which observes *request*, and notifies a
    /// fresh row whenever the request is modified by a database transaction.
    ///
    /// For example:
    ///
    ///     let request = SQLRequest<Row>(sql: "SELECT * FROM player WHERE id = ?", arguments: [1])
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
    public static func trackingOne(_ request: QueryInterfaceRequest<Row>)
        -> ValueObservation<RowReducer>
    {
        return ValueObservation<RowReducer>.tracking(request, reducer: { _ in
            RowReducer(fetch: request.fetchOne)
        })
    }
}

/// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
///
/// A reducer which outputs arrays of database rows, filtering out
/// consecutive identical arrays.
///
/// :nodoc:
public struct RowsReducer: ValueReducer {
    private let _fetch: (Database) throws -> [Row]
    private var previousRows: [Row]?
    
    init(fetch: @escaping (Database) throws -> [Row]) {
        self._fetch = fetch
    }
    
    public func fetch(_ db: Database) throws -> [Row] {
        return try _fetch(db)
    }
    
    public mutating func value(_ rows: [Row]) -> [Row]? {
        if let previousRows = previousRows, previousRows == rows {
            // Don't notify consecutive identical row arrays
            return nil
        }
        self.previousRows = rows
        return rows
    }
}

/// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
///
/// A reducer which outputs optional records, filtering out consecutive
/// identical database rows.
///
/// :nodoc:
public struct RowReducer: ValueReducer {
    private let _fetch: (Database) throws -> Row?
    private var previousRow: Row??
    
    init(fetch: @escaping (Database) throws -> Row?) {
        self._fetch = fetch
    }
    
    public func fetch(_ db: Database) throws -> Row? {
        return try _fetch(db)
    }
    
    public mutating func value(_ row: Row?) -> Row?? {
        if let previousRow = previousRow, previousRow == row {
            // Don't notify consecutive identical rows
            return nil
        }
        self.previousRow = row
        return row
    }
}
