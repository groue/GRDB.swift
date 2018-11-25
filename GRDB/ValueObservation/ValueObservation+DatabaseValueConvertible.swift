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
        -> ValueObservation<ValueReducers.Values<Request.RowDecoder>>
        where Request.RowDecoder: DatabaseValueConvertible
    {
        return ValueObservation<ValueReducers.Values<Request.RowDecoder>>.tracking(
            request,
            reducer: { _ in ValueReducers.Values { try DatabaseValue.fetchAll($0, request) } })
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
            reducer: { _ in ValueReducers.Value { try DatabaseValue.fetchOne($0, request) } })
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
        -> ValueObservation<ValueReducers.OptionalValues<Request.RowDecoder._Wrapped>>
        where Request.RowDecoder: _OptionalProtocol,
        Request.RowDecoder._Wrapped: DatabaseValueConvertible
    {
        return ValueObservation<ValueReducers.OptionalValues<Request.RowDecoder._Wrapped>>.tracking(
            request,
            reducer: { _ in ValueReducers.OptionalValues { try DatabaseValue.fetchAll($0, request) } })
    }
}

extension ValueReducers {
    /// A reducer which outputs arrays of values, filtering out consecutive
    /// identical database values.
    public struct Values<T: DatabaseValueConvertible>: ValueReducer {
        private let _fetch: (Database) throws -> [DatabaseValue]
        private var previousDbValues: [DatabaseValue]?
        
        init(_ fetch: @escaping (Database) throws -> [DatabaseValue]) {
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
        
        init(_ fetch: @escaping (Database) throws -> DatabaseValue?) {
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
        
        init(_ fetch: @escaping (Database) throws -> [DatabaseValue]) {
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
