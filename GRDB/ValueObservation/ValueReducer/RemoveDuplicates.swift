// TODO: add removeDuplicates(by:)
extension ValueObservation where Reducer.Value: Equatable {
    /// Returns a ValueObservation which filters out consecutive equal values.
    public func removeDuplicates()
    -> ValueObservation<ValueReducers.RemoveDuplicates<Reducer>>
    {
        mapReducer { ValueReducers.RemoveDuplicates($0) }
    }
}

extension ValueReducers {
    /// See `ValueObservation.removeDuplicates()`
    public struct RemoveDuplicates<Base: ValueReducer>: ValueReducer where Base.Value: Equatable {
        private var base: Base
        private var previousValue: Base.Value?
        
        init(_ base: Base) {
            self.base = base
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
            if let previousValue = previousValue, previousValue == value {
                // Don't notify consecutive identical values
                return nil
            }
            self.previousValue = value
            return value
        }
    }
}
