//
//  ValueReducer.swift
//  GRDB
//
//  Created by Gwendal Roué on 24/11/2018.
//  Copyright © 2018 Gwendal Roué. All rights reserved.
//

/// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
///
/// The ValueReducer protocol supports ValueObservation.
public protocol ValueReducer {
    /// The type of fetched database values
    associatedtype Fetched
    
    /// The type of observed values
    associatedtype Value
    
    /// Feches database values upon changes in an observed database region.
    func fetch(_ db: Database) throws -> Fetched
    
    /// Transforms a fetched value into an eventual observed value. Returns nil
    /// when observer should not be notified.
    ///
    /// This method runs inside a private dispatch queue.
    mutating func value(_ fetched: Fetched) -> Value?
}

/// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
///
/// A type-erased ValueReducer.
///
/// An AnyValueReducer forwards its operations to an underlying reducer,
/// hiding its specifics.
public struct AnyValueReducer<Fetched, Value>: ValueReducer {
    private var _fetch: (Database) throws -> Fetched
    private var _value: (Fetched) -> Value?
    
    /// Creates a reducer whose `fetch(_:)` and `value(_:)` methods wrap and
    /// forward operations the argument closures.
    ///
    /// For example, this reducer counts the number of a times the player table
    /// is modified:
    ///
    ///     var count = 0
    ///     let reducer = AnyValueReducer(
    ///         fetch: { _ in },
    ///         value: { _ -> Int? in
    ///             count += 1
    ///             return count
    ///     })
    ///     let observer = ValueObservation
    ///         .tracking(Player.all(), reducer: reducer)
    ///         .start(in: dbQueue) { count: Int in
    ///             print("Players have been modified \(count) times.")
    ///         }
    public init(fetch: @escaping (Database) throws -> Fetched, value: @escaping (Fetched) -> Value?) {
        self._fetch = fetch
        self._value = value
    }
    
    /// Creates a reducer that wraps and forwards operations to `reducer`.
    public init<Base: ValueReducer>(_ reducer: Base) where Base.Fetched == Fetched, Base.Value == Value {
        var reducer = reducer
        self._fetch = { try reducer.fetch($0) }
        self._value = { reducer.value($0) }
    }
    
    /// :nodoc:
    public func fetch(_ db: Database) throws -> Fetched {
        return try _fetch(db)
    }
    
    /// :nodoc:
    public func value(_ fetched: Fetched) -> Value? {
        return _value(fetched)
    }
}

/// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
public enum ValueReducers {
    /// A reducer which outputs raw database values, without any processing.
    public struct Raw<Value>: ValueReducer {
        private let _fetch: (Database) throws -> Value
        
        init(_ fetch: @escaping (Database) throws -> Value) {
            self._fetch = fetch
        }
        
        /// :nodoc:
        public func fetch(_ db: Database) throws -> Value {
            return try _fetch(db)
        }
        
        /// :nodoc:
        public func value(_ fetched: Value) -> Value? {
            return fetched
        }
    }
    
    /// A reducer which outputs raw database values, filtering out consecutive
    /// values that are equal.
    public struct Distinct<Value: Equatable>: ValueReducer {
        private let _fetch: (Database) throws -> Value
        private var previousValue: Value??
        
        init(_ fetch: @escaping (Database) throws -> Value) {
            self._fetch = fetch
        }
        
        /// :nodoc:
        public func fetch(_ db: Database) throws -> Value {
            return try _fetch(db)
        }
        
        /// :nodoc:
        public mutating func value(_ value: Value) -> Value? {
            if let previousValue = previousValue, previousValue == value {
                // Don't notify consecutive identical values
                return nil
            }
            self.previousValue = value
            return value
        }
    }
}
