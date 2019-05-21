extension QueryInterfaceRequest where RowDecoder: FetchableRecord {
    /// A cursor over fetched records.
    ///
    ///     let request: QueryInterfaceRequest<Player> = ...
    ///     let players = try request.fetchCursor(db) // Cursor of Player
    ///     while let player = try players.next() {   // Player
    ///         ...
    ///     }
    ///
    /// If the database is modified during the cursor iteration, the remaining
    /// elements are undefined.
    ///
    /// The cursor must be iterated in a protected dispath queue.
    ///
    /// - parameter db: A database connection.
    /// - returns: A cursor over fetched records.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public func fetchCursor(_ db: Database) throws -> RecordCursor<RowDecoder> {
        return try RowDecoder.fetchCursor(db, self)
    }
    
    /// An array of fetched records.
    ///
    ///     let request: QueryInterfaceRequest<Player> = ...
    ///     let players = try request.fetchAll(db) // [Player]
    ///
    /// - parameter db: A database connection.
    /// - returns: An array of records.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
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
    public func fetchOne(_ db: Database) throws -> RowDecoder? {
        return try RowDecoder.fetchOne(db, self)
    }
}

extension FetchableRecord {
    
    // MARK: Fetching From QueryInterfaceRequest
    
    /// Returns a cursor over records fetched from a fetch request.
    ///
    ///     let request = try Player.all()
    ///     let players = try Player.fetchCursor(db, request) // Cursor of Player
    ///     while let player = try players.next() { // Player
    ///         ...
    ///     }
    ///
    /// If the database is modified during the cursor iteration, the remaining
    /// elements are undefined.
    ///
    /// The cursor must be iterated in a protected dispath queue.
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - sql: a FetchRequest.
    /// - returns: A cursor over fetched records.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchCursor<T>(_ db: Database, _ request: QueryInterfaceRequest<T>) throws -> RecordCursor<Self> {
        precondition(request.prefetchedAssociations.isEmpty, "Not implemented: fetchCursor with prefetched associations")
        let (statement, adapter) = try request.prepare(db, forSingleResult: false)
        return try fetchCursor(statement, adapter: adapter)
    }
    
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
