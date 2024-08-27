extension ValueReducers {
    // swiftlint:disable line_length
    /// A `ValueReducer` that handles ``ValueObservation`` events.
    ///
    /// See ``ValueObservation/handleEvents(willStart:willFetch:willTrackRegion:databaseDidChange:didReceiveValue:didFail:didCancel:)``
    /// and ``ValueObservation/print(_:to:)``.
    public struct Trace<Base: ValueReducer>: ValueReducer {
        public struct _Fetcher: _ValueReducerFetcher {
            let base: Base.Fetcher
            let willFetch: @Sendable () -> Void
            
            public func fetch(_ db: Database) throws -> Base.Fetcher.Value {
                willFetch()
                return try base.fetch(db)
            }
        }
        
        var base: Base
        let willFetch: @Sendable () -> Void
        let didReceiveValue: (Base.Value) -> Void
        
        public func _makeFetcher() -> _Fetcher {
            _Fetcher(base: base._makeFetcher(), willFetch: willFetch)
        }
        
        public mutating func _value(_ fetched: Base.Fetcher.Value) throws -> Base.Value? {
            guard let value = try base._value(fetched) else {
                return nil
            }
            didReceiveValue(value)
            return value
        }
    }
    // swiftlint:enable line_length
}
