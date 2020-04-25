/// DatabasePromise represents a value that can only be resolved when a
/// database connection is available.
///
/// This type is important for the query interface, which lets the user define
/// requests without any database context.
///
/// For example, consider those two requests:
///
///     let playerRequest = Player.filter(key: 1)
///     let countryRequest = Country.filter(key: "FR")
///
/// Both need a database connection in order to introspect the database schema,
/// find the primary key of both table, and generate the correct SQL:
///
///     try dbQueue.read { db in
///         // SELECT * FROM player WHERE id = 1
///         let player = try playerRequest.fetchOne(db)
///         // SELECT * FROM country WHERE code = 'FR'
///         let country = try countryRequest.fetchOne(db)
///     }
///
/// Such late computations are backed by DatabasePromise. In our example,
/// see SQLRelation.filterPromise.
struct DatabasePromise<T> {
    /// Returns the resolved value.
    let resolve: (Database) throws -> T
    
    /// Creates a promise that resolves to a value.
    init(value: T) {
        self.resolve = { _ in value }
    }
    
    /// Creates a promise from a closure.
    init(_ resolve: @escaping (Database) throws -> T) {
        self.resolve = resolve
    }
    
    /// Returns a promise whose value is transformed by the given closure.
    func map<U>(_ transform: @escaping (T) throws -> U) -> DatabasePromise<U> {
        DatabasePromise<U> { db in
            try transform(self.resolve(db))
        }
    }
}
