extension ValueReducers {
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// :nodoc:
    public struct Trace<Base: _ValueReducer>: _ValueReducer {
        var base: Base
        let willFetch: () -> Void
        let didReceiveValue: (Base.Value) -> Void
        public var isSelectedRegionDeterministic: Bool { base.isSelectedRegionDeterministic }
        
        public func fetch(_ db: Database) throws -> Base.Fetched {
            willFetch()
            return try base.fetch(db)
        }
        
        public mutating func value(_ fetched: Base.Fetched) -> Base.Value? {
            guard let value = base.value(fetched) else {
                return nil
            }
            didReceiveValue(value)
            return value
        }
    }
}
