extension ValueObservation {
    /// Returns a ValueObservation with a transformed reducer.
    func mapReducer<R>(_ transform: @escaping (Reducer) -> R) -> ValueObservation<R> {
        let makeReducer = self.makeReducer
        return ValueObservation<R>(
            baseRegion: baseRegion,
            observesSelectedRegion: observesSelectedRegion,
            makeReducer: { transform(makeReducer()) },
            requiresWriteAccess: requiresWriteAccess,
            scheduling: scheduling)
    }
}
