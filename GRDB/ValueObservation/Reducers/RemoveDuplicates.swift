extension ValueObservation {
    /// Notifies only values that don’t match the previously observed value, as
    /// evaluated by a provided closure.
    ///
    /// - parameter predicate: A closure to evaluate whether two values are
    ///   equivalent, for purposes of filtering. Return true from this closure
    ///   to indicate that the second element is a duplicate of the first.
    public func removeDuplicates(by predicate: @escaping (Reducer.Value, Reducer.Value) -> Bool)
    -> ValueObservation<ValueReducers.RemoveDuplicates<Reducer>>
    {
        mapReducer { ValueReducers.RemoveDuplicates($0, predicate: predicate) }
    }
}

extension ValueObservation where Reducer.Value: Equatable {
    /// Notifies only values that don’t match the previously observed value.
    ///
    /// For example:
    ///
    /// ```swift
    /// // An observation of distinct Player?
    /// let observation = ValueObservation
    ///     .tracking { db in try Player.fetchOne(db, id: 42) }
    ///     .removeDuplicates()
    /// ```
    ///
    /// > Tip: When the observed value does not adopt `Equatable`, and it is
    /// > impractical to provide a custom comparison function, you can observe
    /// > distinct raw database values such as ``Row`` or ``DatabaseValue``,
    /// > before converting them to the desired type. For example, the previous
    /// > observation can be rewritten as below:
    /// >
    /// > ```swift
    /// > // An observation of distinct `Player?`
    /// > let request = Player.filter(id: 42)
    /// > let observation = ValueObservation
    /// >     .tracking { db in try Row.fetchOne(db, request) }
    /// >     .removeDuplicates()
    /// >     .map { row in try row.map(Player.init(row:)) }
    /// > ```
    /// >
    /// > This technique is also available for requests that
    /// > involve associations:
    /// >
    /// > ```swift
    /// > struct TeamInfo: Decodable, FetchableRecord {
    /// >     var team: Team
    /// >     var players: [Player]
    /// > }
    /// >
    /// > // An observation of distinct `[TeamInfo]`
    /// > let request = Team.including(all: Team.players)
    /// > let observation = ValueObservation
    /// >     .tracking { db in try Row.fetchAll(db, request) }
    /// >     .removeDuplicates() // Row adopts Equatable
    /// >     .map { rows in try rows.map(TeamInfo.init(row:)) }
    /// > ```
    public func removeDuplicates()
    -> ValueObservation<ValueReducers.RemoveDuplicates<Reducer>>
    {
        mapReducer { ValueReducers.RemoveDuplicates($0, predicate: ==) }
    }
}

extension ValueReducers {
    /// A `ValueReducer` that notifies only values that don’t match the
    /// previously observed value.
    ///
    /// See ``ValueObservation/removeDuplicates()``.
    public struct RemoveDuplicates<Base: _ValueReducer>: _ValueReducer {
        private var base: Base
        private var previousValue: Base.Value?
        private var predicate: (Base.Value, Base.Value) -> Bool
        
        init(_ base: Base, predicate: @escaping (Base.Value, Base.Value) -> Bool) {
            self.base = base
            self.predicate = predicate
        }
        
        public mutating func _value(_ fetched: Base.Fetched) throws -> Base.Value? {
            guard let value = try base._value(fetched) else {
                return nil
            }
            if let previousValue, predicate(previousValue, value) {
                // Don't notify consecutive identical values
                return nil
            }
            self.previousValue = value
            return value
        }
    }
}

extension ValueReducers.RemoveDuplicates: ValueReducer where Base: ValueReducer {
    public func _fetch(_ db: Database) throws -> Base.Fetched {
        try base._fetch(db)
    }
}
