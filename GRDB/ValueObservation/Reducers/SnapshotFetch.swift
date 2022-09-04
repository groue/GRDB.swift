extension ValueReducers {
    /// A reducer which passes raw fetched values through.
    public struct SnapshotFetch<Value>: SnapshotReducer {
        private let __fetch: (Database, DatabaseSnapshot) throws -> Value
        
        /// Creates a reducer which passes raw fetched values through.
        init(fetch: @escaping (Database, DatabaseSnapshot) throws -> Value) {
            self.__fetch = fetch
        }
        
        /// :nodoc:
        public func _fetch(_ db: Database, snapshot: DatabaseSnapshot) throws -> Value {
            return try __fetch(db, snapshot)
        }
        
        /// :nodoc:
        public func _value(_ fetched: Value) -> Value? {
            fetched
        }
    }
}
