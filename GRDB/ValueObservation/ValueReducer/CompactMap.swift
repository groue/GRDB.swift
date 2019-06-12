extension ValueObservation where Reducer: ValueReducer {
    /// Returns a ValueObservation which notifies the non-nil results of calling
    /// the given transformation which each element notified by this
    /// value observation.
    public func compactMap<T>(_ transform: @escaping (Reducer.Value) -> T?)
        -> ValueObservation<ValueReducers.CompactMap<Reducer, T>>
    {
        return mapReducer { $1.compactMap(transform) }
    }
}

extension ValueReducer {
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// Returns a reducer which outputs the non-nil results of calling the given
    /// transformation which each element emitted by this reducer.
    public func compactMap<T>(_ transform: @escaping (Value) -> T?) -> ValueReducers.CompactMap<Self, T> {
        return ValueReducers.CompactMap(self, transform)
    }
}

extension ValueReducers {
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// See ValueObservation.compactMap(_:)
    ///
    /// :nodoc:
    public struct CompactMap<Base: ValueReducer, Value>: ValueReducer {
        private var base: Base
        private let transform: (Base.Value) -> Value?
        
        init(_ base: Base, _ transform: @escaping (Base.Value) -> Value?) {
            self.base = base
            self.transform = transform
        }
        
        public func fetch(_ db: Database) throws -> Base.Fetched {
            return try base.fetch(db)
        }
        
        public mutating func value(_ fetched: Base.Fetched) -> Value? {
            guard let value = base.value(fetched) else { return nil }
            return transform(value)
        }
    }
}

/// :nodoc:
@available(*, deprecated, renamed: "ValueReducers.CompactMap")
public typealias CompactMapValueReducer<Base, Value> = ValueReducers.CompactMap<Base, Value> where Base: ValueReducer
