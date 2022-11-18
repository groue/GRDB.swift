extension ValueReducers {
    // swiftlint:disable line_length
    /// A `ValueReducer` that handles ``ValueObservation`` events.
    ///
    /// See ``ValueObservation/handleEvents(willStart:willFetch:willTrackRegion:databaseDidChange:didReceiveValue:didFail:didCancel:)``
    /// and ``ValueObservation/print(_:to:)``.
    public struct Trace<Base: _ValueReducer>: _ValueReducer {
        var base: Base
        let willFetch: () -> Void
        let didReceiveValue: (Base.Value) -> Void
        
        public mutating func _value(_ fetched: Base.Fetched) throws -> Base.Value? {
            guard let value = try base._value(fetched) else {
                return nil
            }
            didReceiveValue(value)
            return value
        }
    }
    // swiftlint:enable line_length
}

extension ValueReducers.Trace: ValueReducer where Base: ValueReducer {
    public func _fetch(_ db: Database) throws -> Base.Fetched {
        willFetch()
        return try base._fetch(db)
    }
}
