extension ValueObservation {
    /// Returns a ValueObservation which only publishes elements that don’t
    /// match the previous element, as evaluated by a provided closure.
    public func removeDuplicates(by predicate: @escaping (Reducer.Value, Reducer.Value) -> Bool)
    -> ValueObservation<ValueReducers.RemoveDuplicates<Reducer>>
    {
        mapReducer { ValueReducers.RemoveDuplicates($0, predicate: predicate) }
    }
}

extension ValueObservation where Reducer.Value: Equatable {
    /// Returns a ValueObservation which filters out consecutive equal values.
    public func removeDuplicates()
    -> ValueObservation<ValueReducers.RemoveDuplicates<Reducer>>
    {
        mapReducer { ValueReducers.RemoveDuplicates($0, predicate: ==) }
    }
}

extension ValueReducers {
    /// See `ValueObservation.removeDuplicates()`
    public struct RemoveDuplicates<Base: ValueReducer>: ValueReducer {
        private var base: Base
        private var previousValue: Base.Value?
        private var predicate: (Base.Value, Base.Value) -> Bool
        
        init(_ base: Base, predicate: @escaping (Base.Value, Base.Value) -> Bool) {
            self.base = base
            self.predicate = predicate
        }
        
        /// :nodoc:
        public func _fetch(_ db: Database) throws -> Base.Fetched {
            try base._fetch(db)
        }
        
        /// :nodoc:
        public mutating func _value(_ fetched: Base.Fetched) -> Base.Value? {
            guard let value = base._value(fetched) else {
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
