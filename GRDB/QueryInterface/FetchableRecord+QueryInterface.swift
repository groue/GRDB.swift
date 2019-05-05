extension QueryInterfaceRequest where RowDecoder: FetchableRecord {
    /// An array of fetched records.
    ///
    ///     let request: QueryInterfaceRequest<Player> = ...
    ///     let players = try request.fetchAll(db) // [Player]
    ///
    /// - parameter db: A database connection.
    /// - returns: An array of records.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    @inlinable // TODO: should not be inlinable
    public func fetchAll(_ db: Database) throws -> [RowDecoder] {
        return try RowDecoder.fetchAll(db, self)
    }
    
    /// The first fetched record.
    ///
    ///     let request: QueryInterfaceRequest<Player> = ...
    ///     let player = try request.fetchOne(db) // Player?
    ///
    /// - parameter db: A database connection.
    /// - returns: An optional record.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    @inlinable // TODO: should not be inlinable
    public func fetchOne(_ db: Database) throws -> RowDecoder? {
        return try RowDecoder.fetchOne(db, self)
    }
}

extension FetchableRecord {
    
    // MARK: Fetching From QueryInterfaceRequest
    
    /// Returns an array of records fetched from a query interface request.
    ///
    ///     let request = try Player.all()
    ///     let players = try Player.fetchAll(db, request) // [Player]
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - sql: a FetchRequest.
    /// - returns: An array of records.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    @inlinable // TODO: should not be inlinable
    public static func fetchAll<T>(_ db: Database, _ request: QueryInterfaceRequest<T>) throws -> [Self] {
        let (statement, adapter) = try request.prepare(db, forSingleResult: false)
        let associations = request.prefetchedAssociations
        if associations.isEmpty {
            return try fetchAll(statement, adapter: adapter)
        } else {
            let rows = try Row.fetchAll(statement, adapter: adapter)
            try Row.prefetch(db, associations: associations, in: rows)
            return rows.map(Self.init(row:))
        }
    }
    
    /// Returns a single record fetched from a query interface request.
    ///
    ///     let request = try Player.filter(key: 1)
    ///     let player = try Player.fetchOne(db, request) // Player?
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - sql: a FetchRequest.
    /// - returns: An optional record.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    @inlinable // TODO: should not be inlinable
    public static func fetchOne<T>(_ db: Database, _ request: QueryInterfaceRequest<T>) throws -> Self? {
        let (statement, adapter) = try request.prepare(db, forSingleResult: true)
        let associations = request.prefetchedAssociations
        if associations.isEmpty {
            return try fetchOne(statement, adapter: adapter)
        } else {
            guard let row = try Row.fetchOne(statement, adapter: adapter) else {
                return nil
            }
            try Row.prefetch(db, associations: associations, in: [row])
            return Self.init(row: row)
        }
    }
}
