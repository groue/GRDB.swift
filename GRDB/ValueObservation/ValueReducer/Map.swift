extension ValueObservation {
    /// Transforms all values from the upstream observation with a
    /// provided closure.
    ///
    /// - parameter transform: A closure that takes one value as its parameter
    ///   and returns a new value.
    public func map<T>(_ transform: @escaping (Reducer.Value) throws -> T)
    -> ValueObservation<ValueReducers.Map<Reducer, T>>
    {
        mapReducer { ValueReducers.Map($0, transform) }
    }
}

extension ValueReducers {
    /// A `ValueReducer` whose values consist of those in a `Base` reduced
    /// passed through a transform function.
    ///
    /// See ``ValueObservation/map(_:)``.
    public struct Map<Base: _ValueReducer, Value>: _ValueReducer {
        private var base: Base
        private let transform: (Base.Value) throws -> Value
        
        init(_ base: Base, _ transform: @escaping (Base.Value) throws -> Value) {
            self.base = base
            self.transform = transform
        }
        
        public mutating func _value(_ fetched: Base.Fetched) throws -> Value? {
            guard let value = try base._value(fetched) else { return nil }
            return try transform(value)
        }
    }
}

extension ValueReducers.Map: _DatabaseValueReducer where Base: _DatabaseValueReducer {
    public func _fetch(_ db: Database) throws -> Base.Fetched {
        try base._fetch(db)
    }
}
