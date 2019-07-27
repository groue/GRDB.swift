extension ValueObservation where Reducer: ValueReducer, Reducer.Value: Equatable {
    /// Returns a ValueObservation which filters out consecutive equal values.
    @available(*, deprecated, renamed: "removeDuplicates")
    public func distinctUntilChanged()
        -> ValueObservation<ValueReducers.RemoveDuplicates<Reducer>>
    {
        return removeDuplicates()
    }
    
    /// Returns a ValueObservation which filters out consecutive equal values.
    public func removeDuplicates()
        -> ValueObservation<ValueReducers.RemoveDuplicates<Reducer>>
    {
        return mapReducer { $1.removeDuplicates() }
    }
}

extension ValueReducer where Value: Equatable {
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// Returns a ValueReducer which filters out consecutive equal values.
    @available(*, deprecated, renamed: "removeDuplicates")
    public func distinctUntilChanged() -> ValueReducers.RemoveDuplicates<Self> {
        return removeDuplicates()
    }
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// Returns a ValueReducer which filters out consecutive equal values.
    public func removeDuplicates() -> ValueReducers.RemoveDuplicates<Self> {
        return ValueReducers.RemoveDuplicates(self)
    }
}

extension ValueReducers {
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// See ValueReducer.removeDuplicates()
    ///
    /// :nodoc:
    public struct RemoveDuplicates<Base: ValueReducer>: ValueReducer where Base.Value: Equatable {
        private var base: Base
        private var previousValue: Base.Value?
        
        init(_ base: Base) {
            self.base = base
        }
        
        public func fetch(_ db: Database) throws -> Base.Fetched {
            return try base.fetch(db)
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

/// :nodoc:
@available(*, deprecated, renamed: "ValueReducers.RemoveDuplicates")
public typealias DistinctUntilChangedValueReducer<Base> = ValueReducers.RemoveDuplicates<Base>
    where Base: ValueReducer, Base.Value: Equatable
