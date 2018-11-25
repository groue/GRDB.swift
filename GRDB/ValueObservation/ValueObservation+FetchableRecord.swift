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
        -> ValueObservation<ValueReducers.Records<Request.RowDecoder>>
        where Request.RowDecoder: FetchableRecord
    {
        return ValueObservation<ValueReducers.Records<Request.RowDecoder>>.tracking(
            request,
            reducer: { _ in ValueReducers.Records { try Row.fetchAll($0, request) } })
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
            reducer: { _ in ValueReducers.Record { try Row.fetchOne($0, request) } })
    }
}

extension ValueReducers {
    /// A reducer which outputs arrays of records, filtering out consecutive
    /// identical database rows.
    public struct Records<Record: FetchableRecord>: ValueReducer {
        private let _fetch: (Database) throws -> [Row]
        private var previousRows: [Row]?
        
        init(_ fetch: @escaping (Database) throws -> [Row]) {
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
        
        init(_ fetch: @escaping (Database) throws -> Row?) {
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
}
