/// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
///
/// The _ValueReducer protocol supports ValueObservation.
public protocol _ValueReducer {
    /// The type of fetched database values
    associatedtype Fetched
    
    /// The type of observed values
    associatedtype Value
    
    /// Feches database values upon changes in an observed database region.
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
}

/// A namespace for types related to the _ValueReducer protocol.
public enum ValueReducers { }

// This allows us to use Never as a marker for ValueObservation factory methods:
//
// For example, ValueObservation.tracking(value:) is, practically,
// ValueObservation<Never>.tracking(value:).
extension Never: _ValueReducer {
    public func fetch(_ db: Database) throws -> Never { preconditionFailure() }
    public mutating func value(_ fetched: Never) -> Never? { }
}
