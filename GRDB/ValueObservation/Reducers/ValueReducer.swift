// A `ValueReducer` fetches and transforms the database values
// observed by a ``ValueObservation``.
//
// It is NOT Sendable, because we need `ValueReducers.RemoveDuplicates` to
// be able to call `Equatable.==`, which IS not a Sendable function.
// Thread-safety will be assured by `ValueObservation`, which will make sure
// it does not invoke the reducer concurrently.
//
// However, we need to be able to fetch from any database dispatch queue,
// and maybe concurrently. That's why a `ValueReducer` has a Sendable facet,
// which is its `Fetcher`.

/// Implementation details of `ValueReducer`.
public protocol _ValueReducer {
    /// The Sendable type that fetches database values
    associatedtype Fetcher: _ValueReducerFetcher
    
    /// The type of observed values
    associatedtype Value: Sendable
    
    /// Returns a value that fetches database values upon changes in an
    /// observed database region. The returned value method must not depend
    /// on the state of the reducer.
    func _makeFetcher() -> Fetcher
    
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
    mutating func _value(_ fetched: Fetcher.Value) throws -> Value?
}

public protocol _ValueReducerFetcher: Sendable {
    /// The type of fetched database values
    associatedtype Value
    
    func fetch(_ db: Database) throws -> Value
}

/// `ValueReducer` supports ``ValueObservation``.
///
/// A `ValueReducer` fetches and transforms the database values
/// observed by a ``ValueObservation``.
///
/// Do not declare new conformances to `ValueReducer`. Only the built-in
/// conforming types are valid.
///
/// ## Topics
///
/// ### Supporting Types
///
/// - ``ValueReducers``
public protocol ValueReducer: _ValueReducer { }

/// A namespace for concrete types that adopt the ``ValueReducer`` protocol.
public enum ValueReducers { }
