extension ValueReducers {
    /// A reducer which passes raw fetched values through.
    public struct Fetch<Value>: ValueReducer {
        private let __fetch: (Database) throws -> Value
        /// :nodoc:
        public let _isSelectedRegionDeterministic: Bool
        
        /// Creates a reducer, which passes raw fetched values through.
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
        init(isSelectedRegionDeterministic: Bool, fetch: @escaping (Database) throws -> Value) {
            self._isSelectedRegionDeterministic = isSelectedRegionDeterministic
            self.__fetch = fetch
        }
        
        /// :nodoc:
        public func _fetch(_ db: Database) throws -> Value {
            try __fetch(db)
        }
        
        /// :nodoc:
        public func _value(_ fetched: Value) -> Value? {
            fetched
        }
    }
}
