/// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
///
/// The _ValueReducer protocol supports ValueObservation.
public protocol _ValueReducer {
    /// The type of fetched database values
    associatedtype Fetched
    
    /// The type of observed values
    associatedtype Value
    
    /// Returns whether the database region selected by the fetch(_:) method
    /// is constant.
    var isSelectedRegionDeterministic: Bool { get }
    
    /// Fetches database values upon changes in an observed database region.
    ///
    /// _ValueReducer semantics require that this method does not depend on
    /// the state of the reducer.
    func fetch(_ db: Database) throws -> Fetched
    
    /// Transforms a fetched value into an eventual observed value. Returns nil
    /// when observer should not be notified.
    ///
    /// This method runs in some unspecified dispatch queue.
    ///
    /// _ValueReducer semantics require that the first invocation of this
    /// method returns a non-nil value:
    ///
    ///     let reducer = MyReducer()
    ///     reducer.value(...) // MUST NOT be nil
    ///     reducer.value(...) // MAY be nil
    ///     reducer.value(...) // MAY be nil
    mutating func value(_ fetched: Fetched) -> Value?
}

extension _ValueReducer {
    func fetch(_ db: Database, requiringWriteAccess: Bool) throws -> Fetched {
        if requiringWriteAccess {
            var fetchedValue: Fetched?
            try db.inSavepoint {
                fetchedValue = try fetch(db)
                return .commit
            }
            return fetchedValue!
        } else {
            return try db.readOnly {
                try fetch(db)
            }
        }
    }
    
    mutating func fetchAndReduce(_ db: Database, requiringWriteAccess: Bool) throws -> Value? {
        let fetchedValue = try fetch(db, requiringWriteAccess: requiringWriteAccess)
        return value(fetchedValue)
    }
}

/// A namespace for types related to the _ValueReducer protocol.
public enum ValueReducers {
    // ValueReducers.Auto allows us to define ValueObservation factory methods.
    //
    // For example, ValueObservation.tracking(_:) is, practically,
    // ValueObservation<ValueReducers.Auto>.tracking(_:).
    /// :nodoc:
    public enum Auto: _ValueReducer {
        public var isSelectedRegionDeterministic: Bool { preconditionFailure() }
        public func fetch(_ db: Database) throws -> Never { preconditionFailure() }
        public mutating func value(_ fetched: Never) -> Never? { }
    }
}
