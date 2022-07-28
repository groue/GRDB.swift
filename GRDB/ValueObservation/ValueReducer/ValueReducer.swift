/// Implementation details of `ValueReducer`.
///
/// :nodoc:
public protocol _ValueReducer {
    /// The type of fetched database values
    associatedtype Fetched
    
    /// The type of observed values
    associatedtype Value
    
    /// Fetches database values upon changes in an observed database region.
    ///
    /// ValueReducer semantics require that this method does not depend on
    /// the state of the reducer.
    func _fetch(_ db: Database) throws -> Fetched
    
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

/// The `ValueReducer` protocol supports `ValueObservation`.
public protocol ValueReducer: _ValueReducer { }

/// A namespace for types related to the `ValueReducer` protocol.
public enum ValueReducers {
    // ValueReducers.Auto allows us to define ValueObservation factory methods.
    //
    // For example, ValueObservation.tracking(_:) is, practically,
    // ValueObservation<ValueReducers.Auto>.tracking(_:).
    /// :nodoc:
    public enum Auto: ValueReducer {
        /// :nodoc:
        public func _fetch(_ db: Database) throws -> Never { preconditionFailure() }
        /// :nodoc:
        public mutating func _value(_ fetched: Never) -> Never? { }
    }
}
