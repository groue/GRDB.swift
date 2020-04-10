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
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// See _ValueReducer.removeDuplicates()
    ///
    /// :nodoc:
    public struct RemoveDuplicates<Base: _ValueReducer>: _ValueReducer where Base.Value: Equatable {
        private var base: Base
        private var previousValue: Base.Value?
        public var isSelectedRegionDeterministic: Bool { base.isSelectedRegionDeterministic }
        
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
