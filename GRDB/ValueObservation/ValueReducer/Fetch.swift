extension ValueReducers {
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// A reducer which pass raw fetched values through.
    ///
    /// :nodoc:
    public struct Fetch<Value>: ValueReducer {
        private let _fetch: (Database) throws -> Value
        
        public init(_ fetch: @escaping (Database) throws -> Value) {
            self._fetch = fetch
        }
        
        public func fetch(_ db: Database) throws -> Value {
            return try _fetch(db)
        }
        
        public func value(_ fetched: Value) -> Value? {
            return fetched
        }
    }
}

/// :nodoc:
@available(*, deprecated, renamed: "ValueReducers.Fetch")
public typealias RawValueReducer<Value> = ValueReducers.Fetch<Value>
