extension ValueObservation {
    /// Notifies only values that don’t match the previously observed value, as
    /// evaluated by a provided closure.
    ///
    /// - parameter predicate: A closure to evaluate whether two values are
    ///   equivalent, for purposes of filtering. Return true from this closure
    ///   to indicate that the second element is a duplicate of the first.
    public func removeDuplicates(by predicate: @escaping (Reducer.Value, Reducer.Value) -> Bool)
    -> ValueObservation<ValueReducers.RemoveDuplicates<Reducer>>
    {
        mapReducer { ValueReducers.RemoveDuplicates($0, predicate: predicate) }
    }
}

extension ValueObservation where Reducer.Value: Equatable {
    /// Notifies only values that don’t match the previously observed value.
    public func removeDuplicates()
    -> ValueObservation<ValueReducers.RemoveDuplicates<Reducer>>
    {
        mapReducer { ValueReducers.RemoveDuplicates($0, predicate: ==) }
    }
}

extension ValueReducers {
    /// A `ValueReducer` that notifies only values that don’t match the
    /// previously observed value.
    ///
    /// See ``ValueObservation/removeDuplicates()``.
    public struct RemoveDuplicates<Base: _ValueReducer>: _ValueReducer {
        private var base: Base
        private var previousValue: Base.Value?
        private var predicate: (Base.Value, Base.Value) -> Bool
        
        init(_ base: Base, predicate: @escaping (Base.Value, Base.Value) -> Bool) {
            self.base = base
            self.predicate = predicate
        }
        
        public mutating func _value(_ fetched: Base.Fetched) throws -> Base.Value? {
            guard let value = try base._value(fetched) else {
                return nil
            }
            if let previousValue = previousValue, predicate(previousValue, value) {
                // Don't notify consecutive identical values
                return nil
            }
            self.previousValue = value
            return value
        }
    }
}

extension ValueReducers.RemoveDuplicates: _DatabaseValueReducer where Base: _DatabaseValueReducer {
    public func _fetch(_ db: Database) throws -> Base.Fetched {
        try base._fetch(db)
    }
}
