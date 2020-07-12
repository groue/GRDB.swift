extension ValueReducers {
    /// See `ValueObservation.handleEvents()`
    public struct Trace<Base: ValueReducer>: ValueReducer {
        var base: Base
        let willFetch: () -> Void
        let didReceiveValue: (Base.Value) -> Void
        /// :nodoc:
        public var _isSelectedRegionDeterministic: Bool { base._isSelectedRegionDeterministic }
        
        /// :nodoc:
        public func _fetch(_ db: Database) throws -> Base.Fetched {
            willFetch()
            return try base._fetch(db)
        }
        
        /// :nodoc:
        public mutating func _value(_ fetched: Base.Fetched) -> Base.Value? {
            guard let value = base._value(fetched) else {
                return nil
            }
            didReceiveValue(value)
            return value
        }
    }
}
