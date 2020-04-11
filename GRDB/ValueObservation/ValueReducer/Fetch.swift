extension ValueReducers {
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// A reducer which passes raw fetched values through.
    ///
    /// :nodoc:
    public struct Fetch<Value>: _ValueReducer {
        private let _fetch: (Database) throws -> Value
        public let isSelectedRegionDeterministic: Bool
        
        /// Creates a ValueReducers.Fetch reducer, which passes raw fetched
        /// values through.
        ///
        /// - parameter isSelectedRegionDeterministic: When true, the fetching
        ///   function is assumed to always fetch from the same database region.
        ///   This information is used by ValueObserver, which can optimize the
        ///   observation by computing the observed region only once, and
        ///   performing concurrent fetches of fresh values.
        ///
        ///   When false, the ValueObserver always fetches fresh values from the
        ///   writer dispatch queue, and updates its observed region on
        ///   each fetch.
        ///
        /// - parameter fetch: A function that fetches the observed value.
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
