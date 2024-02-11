extension ValueReducers {
    /// A `ValueReducer` that perform database fetches.
    public struct Fetch<Value: Sendable>: ValueReducer {
        private let __fetch: @Sendable (Database) throws -> Value
        
        /// Creates a reducer which passes raw fetched values through.
        init(fetch: @escaping @Sendable (Database) throws -> Value) {
            self.__fetch = fetch
        }
        
        public func _fetch(_ db: Database) throws -> Value {
            assert(db.isInsideTransaction, "Fetching in a non-isolated way is illegal")
            return try __fetch(db)
        }
        
        public func _value(_ fetched: Value) -> Value? {
            fetched
        }
    }
}
