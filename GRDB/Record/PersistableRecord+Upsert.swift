// MARK: - Upsert

extension PersistableRecord {
#if GRDBCUSTOMSQLITE
    /// Executes an `INSERT ... ON CONFLICT DO UPDATE` statement.
    ///
    /// - parameter db: A database connection.
    /// - throws: A DatabaseError whenever an SQLite error occurs.
    @inlinable // allow specialization so that empty callbacks are removed
    public func upsert(_ db: Database) throws {
        try willSave(db)
        
        var saved: PersistenceSuccess!
        try aroundSave(db) {
            let inserted = try upsertWithCallbacks(db)
            saved = PersistenceSuccess(inserted)
            return saved
        }
        
        didSave(saved)
    }
    
    /// Executes an `INSERT ... ON CONFLICT DO UPDATE ... RETURNING ...`
    /// statement, and returns the inserted record.
    ///
    /// This method helps dealing with default column values and
    /// generated columns.
    ///
    /// For example:
    ///
    ///     let player: Player = ...
    ///     let insertedPlayer = player.upsertAndFetch(db)
    ///
    /// - parameter db: A database connection.
    /// - returns: The inserted record.
    /// - throws: A DatabaseError whenever an SQLite error occurs.
    @inlinable // allow specialization so that empty callbacks are removed
    public func upsertAndFetch(_ db: Database) throws -> Self
    where Self: FetchableRecord
    {
        try upsertAndFetch(db, as: Self.self)
    }
    
    /// Executes an `INSERT ... ON CONFLICT DO UPDATE ... RETURNING ...`
    /// statement, and returns the inserted record.
    ///
    /// This method helps dealing with default column values and
    /// generated columns.
    ///
    /// For example:
    ///
    ///     let player: Player = ...
    ///     let insertedPlayer = player.upsertAndFetch(db)
    ///
    /// - parameter db: A database connection.
    /// - parameter returnedType: The type of the returned record.
    /// - returns: A record of type `returnedType`.
    /// - throws: A DatabaseError whenever an SQLite error occurs.
    @inlinable // allow specialization so that empty callbacks are removed
    public func upsertAndFetch<T: FetchableRecord & TableRecord>(
        _ db: Database,
        as returnedType: T.Type)
    throws -> T
    {
        try willSave(db)
        
        var inserted: InsertionSuccess!
        var returned: T!
        try aroundSave(db) {
            (inserted, returned) = try upsertAndFetchWithCallbacks(
                db, selection: T.databaseSelection,
                decode: { try T(row: $0) })
            return PersistenceSuccess(inserted)
        }
        
        didSave(PersistenceSuccess(inserted))
        return returned
    }
#else
    /// Executes an `INSERT ... ON CONFLICT DO UPDATE` statement.
    ///
    /// - parameter db: A database connection.
    /// - throws: A DatabaseError whenever an SQLite error occurs.
    @inlinable // allow specialization so that empty callbacks are removed
    @available(iOS 15.0, tvOS 15.0, watchOS 8.0, macOS 12.0, *) // SQLite 3.35.0+
    public func upsert(_ db: Database) throws {
        try willSave(db)
        
        var saved: PersistenceSuccess!
        try aroundSave(db) {
            let inserted = try upsertWithCallbacks(db)
            saved = PersistenceSuccess(inserted)
            return saved
        }
        
        didSave(saved)
    }
    
    /// Executes an `INSERT ... ON CONFLICT DO UPDATE ... RETURNING ...`
    /// statement, and returns the inserted record.
    ///
    /// This method helps dealing with default column values and
    /// generated columns.
    ///
    /// For example:
    ///
    ///     let player: Player = ...
    ///     let insertedPlayer = player.upsertAndFetch(db)
    ///
    /// - parameter db: A database connection.
    /// - returns: The inserted record.
    /// - throws: A DatabaseError whenever an SQLite error occurs.
    @inlinable // allow specialization so that empty callbacks are removed
    @available(iOS 15.0, tvOS 15.0, watchOS 8.0, macOS 12.0, *) // SQLite 3.35.0+
    public func upsertAndFetch(_ db: Database) throws -> Self
    where Self: FetchableRecord
    {
        try upsertAndFetch(db, as: Self.self)
    }
    
    /// Executes an `INSERT ... ON CONFLICT DO UPDATE ... RETURNING ...`
    /// statement, and returns the inserted record.
    ///
    /// This method helps dealing with default column values and
    /// generated columns.
    ///
    /// For example:
    ///
    ///     let player: Player = ...
    ///     let insertedPlayer = player.upsertAndFetch(db)
    ///
    /// - parameter db: A database connection.
    /// - parameter returnedType: The type of the returned record.
    /// - returns: A record of type `returnedType`.
    /// - throws: A DatabaseError whenever an SQLite error occurs.
    @inlinable // allow specialization so that empty callbacks are removed
    @available(iOS 15.0, tvOS 15.0, watchOS 8.0, macOS 12.0, *) // SQLite 3.35.0+
    public func upsertAndFetch<T: FetchableRecord & TableRecord>(
        _ db: Database,
        as returnedType: T.Type)
    throws -> T
    {
        try willSave(db)
        
        var inserted: InsertionSuccess!
        var returned: T!
        try aroundSave(db) {
            (inserted, returned) = try upsertAndFetchWithCallbacks(
                db, selection: T.databaseSelection,
                decode: { try T(row: $0) })
            return PersistenceSuccess(inserted)
        }
        
        didSave(PersistenceSuccess(inserted))
        return returned
    }
#endif
}

// MARK: - Internal

extension PersistableRecord {
    @inlinable // allow specialization so that empty callbacks are removed
    func upsertWithCallbacks(_ db: Database)
    throws -> InsertionSuccess
    {
        let (inserted, _) = try upsertAndFetchWithCallbacks(
            db, selection: [],
            decode: { _ in /* Nothing to decode */ })
        return inserted
    }
    
    @inlinable // allow specialization so that empty callbacks are removed
    func upsertAndFetchWithCallbacks<T>(
        _ db: Database,
        selection: [any SQLSelectable],
        decode: (Row) throws -> T)
    throws -> (InsertionSuccess, T)
    {
        try willInsert(db)
        
        var inserted: InsertionSuccess!
        var returned: T!
        try aroundInsert(db) {
            (inserted, returned) = try upsertAndFetchWithoutCallbacks(
                db, selection: selection,
                decode: decode)
            return inserted
        }
        
        didInsert(inserted)
        return (inserted, returned)
    }
}
