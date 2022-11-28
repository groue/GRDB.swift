extension ValueObservation {
    /// Transforms all values from the upstream observation with a
    /// provided closure.
    ///
    /// For example:
    ///
    /// ```swift
    /// // Turn an observation of Player? into an observation of UIImage?
    /// let observation = ValueObservation
    ///     .tracking { db in try Player.fetchOne(db, id: 42) }
    ///     .map { player in player?.image }
    /// ```
    ///
    /// The `transform` closure does not run on the main thread, and does not
    /// block any database access This makes the `map` operator a tool that
    /// helps reducing database contention
    /// (see <doc:ValueObservation#ValueObservation-Performance>).
    ///
    /// - parameter transform: A closure that takes one value as its parameter
    ///   and returns a new value.
    public func map<T>(_ transform: @escaping (Reducer.Value) throws -> T)
    -> ValueObservation<ValueReducers.Map<Reducer, T>>
    {
        mapReducer { ValueReducers.Map($0, transform) }
    }
}

extension ValueReducers {
    /// A `ValueReducer` whose values consist of those in a `Base` reduced
    /// passed through a transform function.
    ///
    /// See ``ValueObservation/map(_:)``.
    public struct Map<Base: _ValueReducer, Value>: _ValueReducer {
        private var base: Base
        private let transform: (Base.Value) throws -> Value
        
        init(_ base: Base, _ transform: @escaping (Base.Value) throws -> Value) {
            self.base = base
            self.transform = transform
        }
        
        public mutating func _value(_ fetched: Base.Fetched) throws -> Value? {
            guard let value = try base._value(fetched) else { return nil }
            return try transform(value)
        }
    }
}

extension ValueReducers.Map: ValueReducer where Base: ValueReducer {
    public func _fetch(_ db: Database) throws -> Base.Fetched {
        try base._fetch(db)
    }
}
