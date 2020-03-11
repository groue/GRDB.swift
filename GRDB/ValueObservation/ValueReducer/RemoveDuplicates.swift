// TODO: add removeDuplicates(by:)
extension ValueObservation where Reducer.Value: Equatable {
    /// Returns a ValueObservation which filters out consecutive equal values.
    public func removeDuplicates()
        -> ValueObservation<ValueReducers.RemoveDuplicates<Reducer>>
    {
        return mapReducer { $1.removeDuplicates() }
    }
}

extension _ValueReducer where Value: Equatable {
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// Returns a _ValueReducer which filters out consecutive equal values.
    public func removeDuplicates() -> ValueReducers.RemoveDuplicates<Self> {
        ValueReducers.RemoveDuplicates(self)
    }
}

extension ValueReducers {
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// See _ValueReducer.removeDuplicates()
    ///
    /// :nodoc:
    public struct RemoveDuplicates<Base: _ValueReducer>: _ValueReducer where Base.Value: Equatable {
        private var base: Base
        private var previousValue: Base.Value?
        
        init(_ base: Base) {
            self.base = base
        }
        
        public func fetch(_ db: Database) throws -> Base.Fetched {
            try base.fetch(db)
        }
        
        public mutating func value(_ fetched: Base.Fetched) -> Base.Value? {
            guard let value = base.value(fetched) else {
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
