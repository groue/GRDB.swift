extension ValueObservation where Reducer: ValueReducer, Reducer.Value: Equatable {
    /// Returns a ValueObservation which filters out consecutive equal values.
    public func distinctUntilChanged()
        -> ValueObservation<DistinctUntilChangedValueReducer<Reducer>>
    {
        return mapReducer { $1.distinctUntilChanged() }
    }
}

extension ValueReducer where Value: Equatable {
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// Returns a ValueReducer which filters out consecutive equal values.
    public func distinctUntilChanged() -> DistinctUntilChangedValueReducer<Self> {
        return DistinctUntilChangedValueReducer(self)
    }
}

/// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
///
/// See ValueReducer.distinctUntilChanged()
///
/// :nodoc:
public struct DistinctUntilChangedValueReducer<Base: ValueReducer>: ValueReducer where Base.Value: Equatable {
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
