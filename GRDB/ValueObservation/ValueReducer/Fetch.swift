extension ValueReducers {
    /// A reducer which passes raw fetched values through.
    public struct Fetch<Value>: ValueReducer {
        private let __fetch: (Database) throws -> Value
        /// :nodoc:
        public let _trackingMode: _ValueReducerTrackingMode
        
        /// Creates a reducer which passes raw fetched values through.
        init(trackingMode: _ValueReducerTrackingMode, fetch: @escaping (Database) throws -> Value) {
            self._trackingMode = trackingMode
            self.__fetch = fetch
        }
        
        /// :nodoc:
        public func _fetch(_ db: Database) throws -> Value {
            assert(db.isInsideTransaction, "Fetching in a non-isolated way is illegal")
            return try __fetch(db)
        }
        
        /// :nodoc:
        public func _value(_ fetched: Value) -> Value? {
            fetched
        }
    }
}
