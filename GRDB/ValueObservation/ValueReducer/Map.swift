extension ValueObservation where Reducer: ValueReducer {
    /// Returns a ValueObservation which notifies the results of calling the
    /// given transformation which each element notified by this
    /// value observation.
    public func map<T>(_ transform: @escaping (Reducer.Value) -> T)
        -> ValueObservation<ValueReducers.Map<Reducer, T>>
    {
        return mapReducer { $1.map(transform) }
    }
}

extension ValueReducer {
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// Returns a reducer which outputs the results of calling the given
    /// transformation which each element emitted by this reducer.
    public func map<T>(_ transform: @escaping (Value) -> T) -> ValueReducers.Map<Self, T> {
        return ValueReducers.Map(self, transform)
    }
}

extension ValueReducers {
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// A ValueReducer whose values consist of those in a Base ValueReducer passed
    /// through a transform function.
    ///
    /// See ValueReducer.map(_:)
    ///
    /// :nodoc:
    public struct Map<Base: ValueReducer, Value>: ValueReducer {
        private var base: Base
        private let transform: (Base.Value) -> Value
        
        init(_ base: Base, _ transform: @escaping (Base.Value) -> Value) {
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
@available(*, deprecated, renamed: "ValueReducers.Map")
public typealias MapValueReducer<Base, Value> = ValueReducers.Map<Base, Value> where Base: ValueReducer
