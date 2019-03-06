extension ValueObservation where Reducer == Void {

    // MARK: - Row Observation
    
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
        -> ValueObservation<RowsReducer<Request>>
        where Request.RowDecoder == Row
    {
        return ValueObservation<RowsReducer<Request>>.tracking(request, reducer: { _ in
            RowsReducer(request: request)
        })
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
        -> ValueObservation<RowReducer<Request>>
        where Request.RowDecoder == Row
    {
        return ValueObservation<RowReducer<Request>>.tracking(request, reducer: { _ in
            RowReducer(request: request)
        })
    }
}

/// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
///
/// A reducer which outputs arrays of database rows, filtering out
/// consecutive identical arrays.
///
/// :nodoc:
public struct RowsReducer<Request: FetchRequest>: ValueReducer
    where Request.RowDecoder == Row
{
    public let request: Request
    private var previousRows: [Row]?
    
    init(request: Request) {
        self.request = request
    }
    
    public func fetch(_ db: Database) throws -> [Row] {
        return try request.fetchAll(db)
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
public struct RowReducer<Request: FetchRequest>: ValueReducer
    where Request.RowDecoder == Row
{
    public let request: Request
    private var previousRow: Row??
    
    init(request: Request) {
        self.request = request
    }
    
    public func fetch(_ db: Database) throws -> Row? {
        return try request.fetchOne(db)
    }
    
    public mutating func value(_ row: Row?) -> Row?? {
        if let previousRow = previousRow, previousRow == row {
            // Don't notify consecutive identical rows
            // TODO: Remove this implicit `distinctUntilDatabaseChanged` in GRDB 4
            return nil
        }
        self.previousRow = row
        return row
    }
}
