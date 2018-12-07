extension ValueObservation where Reducer == Void {
    
    // MARK: - FetchableRecord Observation
    
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
        -> ValueObservation<FetchableRecordsReducer<Request>>
        where Request.RowDecoder: FetchableRecord
    {
        return ValueObservation<FetchableRecordsReducer<Request>>.tracking(request, reducer: { _ in
            FetchableRecordsReducer(request: request)
        })
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
        ValueObservation<FetchableRecordReducer<Request>>
        where Request.RowDecoder: FetchableRecord
    {
        return ValueObservation<FetchableRecordReducer<Request>>.tracking(request, reducer: { _ in
            FetchableRecordReducer(request: request)
        })
    }
}

/// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
///
/// A reducer which outputs arrays of records, filtering out consecutive
/// identical database rows.
///
/// :nodoc:
public struct FetchableRecordsReducer<Request: FetchRequest>: ValueReducer
    where Request.RowDecoder: FetchableRecord
{
    public let request: Request
    private var previousRows: [Row]?
    
    init(request: Request) {
        self.request = request
    }
    
    public func fetch(_ db: Database) throws -> [Row] {
        return try Row.fetchAll(db, request)
    }
    
    public mutating func value(_ rows: [Row]) -> [Request.RowDecoder]? {
        if let previousRows = previousRows, previousRows == rows {
            // Don't notify consecutive identical row arrays
            // TODO: Remove this implicit `distinctUntilDatabaseChanged` in GRDB 4
            return nil
        }
        self.previousRows = rows
        return rows.map(Request.RowDecoder.init(row:))
    }
}

/// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
///
/// A reducer which outputs optional records, filtering out consecutive
/// identical database rows.
///
/// :nodoc:
public struct FetchableRecordReducer<Request: FetchRequest>: ValueReducer
    where Request.RowDecoder: FetchableRecord
{
    public let request: Request
    private var previousRow: Row??
    
    init(request: Request) {
        self.request = request
    }
    
    public func fetch(_ db: Database) throws -> Row? {
        return try Row.fetchOne(db, request)
    }
    
    public mutating func value(_ row: Row?) -> Request.RowDecoder?? {
        if let previousRow = previousRow, previousRow == row {
            // Don't notify consecutive identical rows
            // TODO: Remove this implicit `distinctUntilDatabaseChanged` in GRDB 4
            return nil
        }
        self.previousRow = row
        return .some(row.map(Request.RowDecoder.init(row:)))
    }
}
