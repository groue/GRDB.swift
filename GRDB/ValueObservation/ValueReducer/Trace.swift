extension ValueReducers {
    /// See `ValueObservation.handleEvents()`
    public struct Trace<Base: _ValueReducer>: _ValueReducer {
        var base: Base
        let willFetch: () -> Void
        let didReceiveValue: (Base.Value) -> Void
        
        /// :nodoc:
        public mutating func _value(_ fetched: Base.Fetched) throws -> Base.Value? {
            guard let value = try base._value(fetched) else {
                return nil
            }
            didReceiveValue(value)
            return value
        }
    }
}

extension ValueReducers.Trace: _DatabaseValueReducer where Base: _DatabaseValueReducer {
    /// :nodoc:
    public func _fetch(_ db: Database) throws -> Base.Fetched {
        willFetch()
        return try base._fetch(db)
    }
}
