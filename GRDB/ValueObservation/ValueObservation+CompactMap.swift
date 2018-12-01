extension ValueObservation where Reducer: ValueReducer {
    /// Returns a ValueObservation which notifies the non-nil results of calling
    /// the given transformation which each element notified by this
    /// value observation.
    public func compactMap<T>(_ transform: @escaping (Reducer.Value) -> T?)
        -> ValueObservation<CompactMapValueReducer<Reducer, T>>
    {
        let makeReducer = self.makeReducer
        return ValueObservation<CompactMapValueReducer<Reducer, T>>(
            tracking: observedRegion,
            reducer: { db in try makeReducer(db).compactMap(transform) })
    }
}

extension ValueReducer {
    /// Returns a reducer which outputs the non-nil results of calling the given
    /// transformation which each element emitted by this reducer.
    public func compactMap<T>(_ transform: @escaping (Value) -> T?) -> CompactMapValueReducer<Self, T> {
        return CompactMapValueReducer(self, transform)
    }
}

/// See ValueReducer.compactMap(_:)
///
/// :nodoc:
public struct CompactMapValueReducer<Base: ValueReducer, T>: ValueReducer {
    private var base: Base
    private let transform: (Base.Value) -> T?
    
    init(_ base: Base, _ transform: @escaping (Base.Value) -> T?) {
        self.base = base
        self.transform = transform
    }
    
    public func fetch(_ db: Database) throws -> Base.Fetched {
        return try base.fetch(db)
    }
    
    public mutating func value(_ fetched: Base.Fetched) -> T? {
        guard let value = base.value(fetched) else { return nil }
        return transform(value)
    }
}
