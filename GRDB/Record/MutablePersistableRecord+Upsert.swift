// MARK: - Upsert

extension MutablePersistableRecord {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
    /// Executes an `INSERT ... ON CONFLICT DO UPDATE` statement.
    ///
    /// - parameter db: A database connection.
    /// - throws: A DatabaseError whenever an SQLite error occurs.
    @inlinable // allow specialization so that empty callbacks are removed
    public mutating func upsert(_ db: Database) throws {
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
    public mutating func upsertAndFetch(_ db: Database) throws -> Self
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
    public mutating func upsertAndFetch<T: FetchableRecord & TableRecord>(
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
    public mutating func upsert(_ db: Database) throws {
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
    public mutating func upsertAndFetch(_ db: Database) throws -> Self
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
    public mutating func upsertAndFetch<T: FetchableRecord & TableRecord>(
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

extension MutablePersistableRecord {
    @inlinable // allow specialization so that empty callbacks are removed
    mutating func upsertWithCallbacks(_ db: Database)
    throws -> InsertionSuccess
    {
        let (inserted, _) = try upsertAndFetchWithCallbacks(
            db, selection: [],
            decode: { _ in /* Nothing to decode */ })
        return inserted
    }
    
    @inlinable // allow specialization so that empty callbacks are removed
    mutating func upsertAndFetchWithCallbacks<T>(
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
    
    /// Executes an `INSERT ... RETURNING` statement, and DOES NOT run
    /// insertion callbacks.
    @usableFromInline
    func upsertAndFetchWithoutCallbacks<T>(
        _ db: Database,
        selection: [any SQLSelectable],
        decode: (Row) throws -> T)
    throws -> (InsertionSuccess, T)
    {
        // Append the rowID to the returned columns
        let selection = selection + [Column.rowID]
        
        let dao = try DAO(db, self)
        let statement = try dao.upsertStatement(
            db,
            conflictTarget: [],
            returning: selection)
        let cursor = try Row.fetchCursor(statement)
        
        // Keep cursor alive until we can process the fetched row
        let (rowid, returned): (Int64, T) = try withExtendedLifetime(cursor) { cursor in
            guard let row = try cursor.next() else {
                throw DatabaseError(message: "Insertion failed")
            }
            
            // Rowid is the last column
            let rowid: Int64 = row[row.count - 1]
            let returned = try decode(row)
            return (rowid, returned)
        }
        
        // Update the persistenceContainer with the inserted rowid.
        // This allows the Record class to set its `hasDatabaseChanges` property
        // to false in its `aroundInsert` callback.
        var persistenceContainer = dao.persistenceContainer
        let rowIDColumn = dao.primaryKey.rowIDColumn
        if let rowIDColumn = rowIDColumn {
            persistenceContainer[caseInsensitive: rowIDColumn] = rowid
        }
        
        let inserted = InsertionSuccess(
            rowID: rowid,
            rowIDColumn: rowIDColumn,
            persistenceContainer: persistenceContainer)
        return (inserted, returned)
    }
}
