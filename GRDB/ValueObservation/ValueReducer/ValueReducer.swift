/// Implementation details of `ValueReducer`.
///
/// :nodoc:
public protocol _ValueReducer {
    /// The type of fetched database values
    associatedtype Fetched
    
    /// The type of observed values
    associatedtype Value
    
    /// Transforms a fetched value into an eventual observed value. Returns nil
    /// when observer should not be notified.
    ///
    /// This method runs in some unspecified dispatch queue.
    ///
    /// ValueReducer semantics require that the first invocation of this
    /// method returns a non-nil value:
    ///
    ///     let reducer = MyReducer()
    ///     reducer._value(...) // MUST NOT be nil
    ///     reducer._value(...) // MAY be nil
    ///     reducer._value(...) // MAY be nil
    mutating func _value(_ fetched: Fetched) throws -> Value?
}

/// Implementation details of `ValueReducer`, able to observe from any database
/// reader (``DatabaseQueue``, ``DatabasePool``).
///
/// :nodoc:
public protocol _DatabaseValueReducer: _ValueReducer {
    /// Fetches database values upon changes in an observed database region.
    ///
    /// This method must does not depend on the state of the reducer.
    func _fetch(_ db: Database) throws -> Fetched
}

/// `ValueReducer` supports ``ValueObservation`` that can observe from any
/// database reader (``DatabaseQueue``, ``DatabasePool``).
public typealias ValueReducer = _ValueReducer & _DatabaseValueReducer

/// A namespace for types related to the `ValueReducer` protocol.
public enum ValueReducers {
    // ValueReducers.Auto allows us to define ValueObservation factory methods.
    //
    // For example, ValueObservation.tracking(_:) is, practically,
    // ValueObservation<ValueReducers.Auto>.tracking(_:).
    /// :nodoc:
    public enum Auto: _ValueReducer {
        public mutating func _value(_ fetched: Never) -> Never? { }
    }
}
