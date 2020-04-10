extension ValueReducers {
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// A reducer which pass raw fetched values through.
    ///
    /// :nodoc:
    public struct Fetch<Value>: _ValueReducer {
        private let _fetch: (Database) throws -> Value
        public let isSelectedRegionDeterministic: Bool
        
        public init(isSelectedRegionDeterministic: Bool, fetch: @escaping (Database) throws -> Value) {
            self.isSelectedRegionDeterministic = isSelectedRegionDeterministic
            self._fetch = fetch
        }
        
        public func fetch(_ db: Database) throws -> Value {
            try _fetch(db)
        }
        
        public func value(_ fetched: Value) -> Value? {
            fetched
        }
    }
}
