extension ValueObservation {
    /// Returns a ValueObservation which notifies the results of calling the
    /// given transformation which each element notified by this
    /// value observation.
    public func map<T>(_ transform: @escaping (Reducer.Value) -> T)
    -> ValueObservation<ValueReducers.Map<Reducer, T>>
    {
        mapReducer { ValueReducers.Map($0, transform) }
    }
}

extension ValueReducers {
    /// A reducer whose values consist of those in a `Base` reducer
    /// passed through a transform function.
    ///
    /// See `ValueObservation.map(_:)`
    public struct Map<Base: ValueReducer, Value>: ValueReducer {
        private var base: Base
        private let transform: (Base.Value) -> Value
        
        init(_ base: Base, _ transform: @escaping (Base.Value) -> Value) {
            self.base = base
            self.transform = transform
        }
        
        /// :nodoc:
        public func _fetch(_ db: Database) throws -> Base.Fetched {
            try base._fetch(db)
        }
        
        /// :nodoc:
        public mutating func _value(_ fetched: Base.Fetched) -> Value? {
            guard let value = base._value(fetched) else { return nil }
            return transform(value)
        }
    }
}
