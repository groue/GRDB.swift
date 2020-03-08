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
    public func observationForAll() -> ValueObservation<ValueReducers.AllValues<RowDecoder>> {
        return ValueObservation.tracking(self, reducer: { _ in
            ValueReducers.AllValues { try DatabaseValue.fetchAll($0, self) }
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
    public func observationForFirst() -> ValueObservation<ValueReducers.OneValue<RowDecoder>> {
        return ValueObservation.tracking(self, reducer: { _ in
            ValueReducers.OneValue { try DatabaseValue.fetchOne($0, self) }
        })
    }
}

extension FetchRequest where RowDecoder: _OptionalProtocol, RowDecoder._Wrapped: DatabaseValueConvertible {
    
    // MARK: - Observation
    
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
    public func observationForAll() -> ValueObservation<ValueReducers.AllOptionalValues<RowDecoder._Wrapped>> {
        return ValueObservation.tracking(self, reducer: { _ in
            ValueReducers.AllOptionalValues { try DatabaseValue.fetchAll($0, self) }
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
    public func observationForFirst() -> ValueObservation<ValueReducers.OneValue<RowDecoder._Wrapped>> {
        return ValueObservation.tracking(self, reducer: { _ in
            ValueReducers.OneValue { try DatabaseValue.fetchOne($0, self) }
        })
    }
}

extension ValueReducers {
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// A reducer which outputs arrays of values, filtering out consecutive
    /// identical database values.
    ///
    /// :nodoc:
    public struct AllValues<RowDecoder>: ValueReducer
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
    public struct OneValue<RowDecoder>: ValueReducer
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
    public struct AllOptionalValues<RowDecoder>: ValueReducer
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
}
