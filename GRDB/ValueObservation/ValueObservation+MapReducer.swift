extension ValueObservation {
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// Returns a ValueObservation with a transformed reducer.
    public func mapReducer<R>(_ transform: @escaping (Database, Reducer) throws -> R) -> ValueObservation<R> {
        let makeReducer = self.makeReducer
        return ValueObservation<R>(
            observedRegion: observedRegion,
            makeReducer: { db in try transform(db, makeReducer(db)) },
            requiresWriteAccess: requiresWriteAccess,
            scheduling: scheduling)
    }
}
