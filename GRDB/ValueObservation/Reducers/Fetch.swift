extension ValueReducers {
    /// A `ValueReducer` that perform database fetches.
    public struct Fetch<Value: Sendable>: ValueReducer {
        public struct _Fetcher: _ValueReducerFetcher {
            let _fetch: @Sendable (Database) throws -> Value
            
            public func fetch(_ db: Database) throws -> Value {
                assert(db.isInsideTransaction, "Fetching in a non-isolated way is illegal")
                return try _fetch(db)
            }
        }
        
        private let _fetch: @Sendable (Database) throws -> Value
        
        /// Creates a reducer which passes raw fetched values through.
        init(fetch: @escaping @Sendable (Database) throws -> Value) {
            self._fetch = fetch
        }
        
        public func _makeFetcher() -> _Fetcher {
            _Fetcher(_fetch: _fetch)
        }
        
        public func _value(_ fetched: Value) -> Value? {
            fetched
        }
    }
}
