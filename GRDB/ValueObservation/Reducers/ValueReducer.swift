/// Implementation details of `ValueReducer`.
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

/// `ValueReducer` supports ``ValueObservation``.
///
/// A `ValueReducer` fetches and transforms the database values
/// observed by a ``ValueObservation``.
///
/// ## Topics
///
/// ### Support
///
/// - ``ValueReducers``
public protocol ValueReducer: _ValueReducer {
    /// Fetches database values upon changes in an observed database region.
    ///
    /// This method must does not depend on the state of the reducer.
    func _fetch(_ db: Database) throws -> Fetched
}

/// A namespace for concrete types that adopt the ``ValueReducer`` protocol.
public enum ValueReducers { }
