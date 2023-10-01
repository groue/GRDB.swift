// MARK: - Save Callbacks

extension MutablePersistableRecord {
    @inline(__always)
    @inlinable
    public func willSave(_ db: Database) throws { }
    
    @inline(__always)
    @inlinable
    public func aroundSave(_ db: Database, save: () throws -> PersistenceSuccess) throws {
        _ = try save()
    }
    
    @inline(__always)
    @inlinable
    public func didSave(_ saved: PersistenceSuccess) { }
}

// MARK: - Save

extension MutablePersistableRecord {
    /// Executes an `INSERT` or `UPDATE` statement.
    ///
    /// If the receiver has a non-nil primary key and a matching row in the
    /// database, this method performs an update.
    ///
    /// Otherwise, performs an insert.
    ///
    /// - parameter db: A database connection.
    /// - parameter conflictResolution: A policy for conflict resolution. If
    ///   nil, <doc:/MutablePersistableRecord/persistenceConflictPolicy-1isyv>
    ///   is used.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs, or any
    ///   error thrown by the persistence callbacks defined by the record type.
    @inlinable // allow specialization so that empty callbacks are removed
    public mutating func save(
        _ db: Database,
        onConflict conflictResolution: Database.ConflictResolution? = nil)
    throws
    {
        try willSave(db)
        
        var saved: PersistenceSuccess?
        try aroundSave(db) {
            saved = try updateOrInsertWithCallbacks(db, onConflict: conflictResolution)
            return saved!
        }
        
        guard let saved else {
            try persistenceCallbackMisuse("aroundSave")
        }
        didSave(saved)
    }
    
    /// Executes an `INSERT` or `UPDATE` statement, and returns the
    /// saved record.
    ///
    /// Usage:
    ///
    ///     let player = Player(id: nil, name: "Arthur")
    ///     let savedPlayer = try dbQueue.write { db in
    ///         try player.saved(db)
    ///     }
    ///     print(player.id)      // nil
    ///     print(savedPlayer.id) // some id
    ///
    /// - parameter db: A database connection.
    /// - parameter conflictResolution: A policy for conflict resolution. If
    ///   nil, <doc:/MutablePersistableRecord/persistenceConflictPolicy-1isyv>
    ///   is used.
    /// - returns: The saved record.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs, or any
    ///   error thrown by the persistence callbacks defined by the record type.
    @inlinable // allow specialization so that empty callbacks are removed
    public func saved(
        _ db: Database,
        onConflict conflictResolution: Database.ConflictResolution? = nil)
    throws -> Self
    {
        var result = self
        try result.save(db, onConflict: conflictResolution)
        return result
    }
}

// MARK: - Save and Fetch

extension MutablePersistableRecord {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
    // TODO: GRDB7 make it unable to return an optional
    /// Executes an `INSERT RETURNING` or `UPDATE RETURNING` statement, and
    /// returns a new record built from the saved row.
    ///
    /// If the receiver has a non-nil primary key and a matching row in the
    /// database, this method performs an update. Otherwise, it performs
    /// an insert.
    ///
    /// This method helps dealing with default column values and
    /// generated columns.
    ///
    /// For example:
    ///
    ///     let player: Player = ...
    ///     let savedPlayer = player.saveAndFetch(db)
    ///
    /// - parameter db: A database connection.
    /// - parameter conflictResolution: A policy for conflict resolution. If
    ///   nil, <doc:/MutablePersistableRecord/persistenceConflictPolicy-1isyv>
    ///   is used.
    /// - returns: The saved record. The result can be nil when the
    ///   conflict policy is `IGNORE`.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs, or any
    ///   error thrown by the persistence callbacks defined by the record type.
    @inlinable // allow specialization so that empty callbacks are removed
    public func saveAndFetch(
        _ db: Database,
        onConflict conflictResolution: Database.ConflictResolution? = nil)
    throws -> Self?
    where Self: FetchableRecord
    {
        var result = self
        return try result.saveAndFetch(db, onConflict: conflictResolution, as: Self.self)
    }
    
    // TODO: GRDB7 make it unable to return an optional
    /// Executes an `INSERT RETURNING` or `UPDATE RETURNING` statement, and
    /// returns a new record built from the saved row.
    ///
    /// If the receiver has a non-nil primary key and a matching row in the
    /// database, this method performs an update. Otherwise, it performs
    /// an insert.
    ///
    /// - parameter db: A database connection.
    /// - parameter conflictResolution: A policy for conflict resolution. If
    ///   nil, <doc:/MutablePersistableRecord/persistenceConflictPolicy-1isyv>
    ///   is used.
    /// - parameter returnedType: The type of the returned record.
    /// - returns: A record of type `returnedType`. The result can be nil when
    ///   the conflict policy is `IGNORE`.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs, or any
    ///   error thrown by the persistence callbacks defined by the record type.
    @inlinable // allow specialization so that empty callbacks are removed
    public mutating func saveAndFetch<T: FetchableRecord & TableRecord>(
        _ db: Database,
        onConflict conflictResolution: Database.ConflictResolution? = nil,
        as returnedType: T.Type)
    throws -> T?
    {
        try willSave(db)
        
        var success: (saved: PersistenceSuccess, returned: T?)?
        try aroundSave(db) {
            success = try updateOrInsertAndFetchWithCallbacks(
                db, onConflict: conflictResolution,
                selection: T.databaseSelection,
                fetch: {
                    try T.fetchOne($0)
                })
            return success!.saved
        }
        
        guard let success else {
            try persistenceCallbackMisuse("aroundSave")
        }
        didSave(success.saved)
        return success.returned
    }
    
    /// Executes an `INSERT RETURNING` or `UPDATE RETURNING` statement, and
    /// returns the selected columns from the saved row.
    ///
    /// If the receiver has a non-nil primary key and a matching row in the
    /// database, this method performs an update. Otherwise, it performs
    /// an insert.
    ///
    /// - parameter db: A database connection.
    /// - parameter conflictResolution: A policy for conflict resolution. If
    ///   nil, <doc:/MutablePersistableRecord/persistenceConflictPolicy-1isyv>
    ///   is used.
    /// - parameter selection: The returned columns (must not be empty).
    /// - parameter fetch: A function that executes it ``Statement`` argument.
    /// - returns: The result of the `fetch` function.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs, or any
    ///   error thrown by the persistence callbacks defined by the record type.
    /// - precondition: `selection` is not empty.
    @inlinable // allow specialization so that empty callbacks are removed
    public mutating func saveAndFetch<T>(
        _ db: Database,
        onConflict conflictResolution: Database.ConflictResolution? = nil,
        selection: [any SQLSelectable],
        fetch: (Statement) throws -> T)
    throws -> T
    {
        GRDBPrecondition(!selection.isEmpty, "Invalid empty selection")
        
        try willSave(db)
        
        var success: (saved: PersistenceSuccess, returned: T)?
        try aroundSave(db) {
            success = try updateOrInsertAndFetchWithCallbacks(
                db, onConflict: conflictResolution,
                selection: selection,
                fetch: fetch)
            return success!.saved
        }
        
        guard let success else {
            try persistenceCallbackMisuse("aroundSave")
        }
        didSave(success.saved)
        return success.returned
    }
#else
    // TODO: GRDB7 make it unable to return an optional
    /// Executes an `INSERT RETURNING` or `UPDATE RETURNING` statement, and
    /// returns a new record built from the saved row.
    ///
    /// If the receiver has a non-nil primary key and a matching row in the
    /// database, this method performs an update. Otherwise, it performs
    /// an insert.
    ///
    /// This method helps dealing with default column values and
    /// generated columns.
    ///
    /// For example:
    ///
    ///     let player: Player = ...
    ///     let savedPlayer = player.saveAndFetch(db)
    ///
    /// - parameter db: A database connection.
    /// - parameter conflictResolution: A policy for conflict resolution. If
    ///   nil, <doc:/MutablePersistableRecord/persistenceConflictPolicy-1isyv>
    ///   is used.
    /// - returns: The saved record. The result can be nil when the
    ///   conflict policy is `IGNORE`.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs, or any
    ///   error thrown by the persistence callbacks defined by the record type.
    @inlinable // allow specialization so that empty callbacks are removed
    @available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) // SQLite 3.35.0+
    public func saveAndFetch(
        _ db: Database,
        onConflict conflictResolution: Database.ConflictResolution? = nil)
    throws -> Self?
    where Self: FetchableRecord
    {
        var result = self
        return try result.saveAndFetch(db, onConflict: conflictResolution, as: Self.self)
    }
    
    // TODO: GRDB7 make it unable to return an optional
    /// Executes an `INSERT RETURNING` or `UPDATE RETURNING` statement, and
    /// returns a new record built from the saved row.
    ///
    /// If the receiver has a non-nil primary key and a matching row in the
    /// database, this method performs an update. Otherwise, it performs
    /// an insert.
    ///
    /// - parameter db: A database connection.
    /// - parameter conflictResolution: A policy for conflict resolution. If
    ///   nil, <doc:/MutablePersistableRecord/persistenceConflictPolicy-1isyv>
    ///   is used.
    /// - parameter returnedType: The type of the returned record.
    /// - returns: A record of type `returnedType`. The result can be nil when
    ///   the conflict policy is `IGNORE`.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs, or any
    ///   error thrown by the persistence callbacks defined by the record type.
    @inlinable // allow specialization so that empty callbacks are removed
    @available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) // SQLite 3.35.0+
    public mutating func saveAndFetch<T: FetchableRecord & TableRecord>(
        _ db: Database,
        onConflict conflictResolution: Database.ConflictResolution? = nil,
        as returnedType: T.Type)
    throws -> T?
    {
        try willSave(db)
        
        var success: (saved: PersistenceSuccess, returned: T?)?
        try aroundSave(db) {
            success = try updateOrInsertAndFetchWithCallbacks(
                db, onConflict: conflictResolution,
                selection: T.databaseSelection,
                fetch: {
                    try T.fetchOne($0)
                })
            return success!.saved
        }
        
        guard let success else {
            try persistenceCallbackMisuse("aroundSave")
        }
        didSave(success.saved)
        return success.returned
    }
    
    /// Executes an `INSERT RETURNING` or `UPDATE RETURNING` statement, and
    /// returns the selected columns from the saved row.
    ///
    /// If the receiver has a non-nil primary key and a matching row in the
    /// database, this method performs an update. Otherwise, it performs
    /// an insert.
    ///
    /// - parameter db: A database connection.
    /// - parameter conflictResolution: A policy for conflict resolution. If
    ///   nil, <doc:/MutablePersistableRecord/persistenceConflictPolicy-1isyv>
    ///   is used.
    /// - parameter selection: The returned columns (must not be empty).
    /// - parameter fetch: A function that executes it ``Statement`` argument.
    /// - returns: The result of the `fetch` function.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs, or any
    ///   error thrown by the persistence callbacks defined by the record type.
    /// - precondition: `selection` is not empty.
    @inlinable // allow specialization so that empty callbacks are removed
    @available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) // SQLite 3.35.0+
    public mutating func saveAndFetch<T>(
        _ db: Database,
        onConflict conflictResolution: Database.ConflictResolution? = nil,
        selection: [any SQLSelectable],
        fetch: (Statement) throws -> T)
    throws -> T
    {
        GRDBPrecondition(!selection.isEmpty, "Invalid empty selection")
        
        try willSave(db)
        
        var success: (saved: PersistenceSuccess, returned: T)?
        try aroundSave(db) {
            success = try updateOrInsertAndFetchWithCallbacks(
                db, onConflict: conflictResolution,
                selection: selection,
                fetch: fetch)
            return success!.saved
        }
        
        guard let success else {
            try persistenceCallbackMisuse("aroundSave")
        }
        didSave(success.saved)
        return success.returned
    }
#endif
}

// MARK: - Internal

extension MutablePersistableRecord {
    /// Executes an `UPDATE` or `INSERT` statement, and runs insertion or
    /// update callbacks.
    @inlinable // allow specialization so that empty callbacks are removed
    mutating func updateOrInsertWithCallbacks(
        _ db: Database,
        onConflict conflictResolution: Database.ConflictResolution?)
    throws -> PersistenceSuccess
    {
        let (saved, _) = try updateOrInsertAndFetchWithCallbacks(
            db, onConflict: conflictResolution,
            selection: [],
            fetch: {
                // Nothing to fetch
                try $0.execute()
            })
        return saved
    }
    
    /// Executes an `UPDATE` or `INSERT` statement, with `RETURNING` clause
    /// if `selection` is not empty, and runs insertion or update callbacks.
    @inlinable // allow specialization so that empty callbacks are removed
    mutating func updateOrInsertAndFetchWithCallbacks<T>(
        _ db: Database,
        onConflict conflictResolution: Database.ConflictResolution?,
        selection: [any SQLSelectable],
        fetch: (Statement) throws -> T)
    throws -> (PersistenceSuccess, T)
    {
        // Attempt at updating if the record has a primary key
        if let key = try primaryKey(db) {
            let databaseTableName = type(of: self).databaseTableName
            do {
                let columns = try Set(db.columns(in: databaseTableName).map(\.name))
                return try updateAndFetchWithCallbacks(
                    db, onConflict: conflictResolution,
                    columns: columns,
                    selection: selection,
                    fetch: fetch)
            } catch RecordError.recordNotFound(databaseTableName: databaseTableName, key: key) {
                // No row was updated: fallback on insert.
            }
        }
        
        // Insert
        let (inserted, returned) = try insertAndFetchWithCallbacks(
            db, onConflict: conflictResolution,
            selection: selection,
            fetch: fetch)
        return (PersistenceSuccess(inserted), returned)
    }
    
    /// Return a non-nil dictionary if record has a non-null primary key
    @usableFromInline
    func primaryKey(_ db: Database) throws -> [String: DatabaseValue]? {
        let databaseTableName = type(of: self).databaseTableName
        let primaryKeyInfo = try db.primaryKey(databaseTableName)
        let container = try PersistenceContainer(db, self)
        let primaryKey = Dictionary(uniqueKeysWithValues: primaryKeyInfo.columns.map {
            ($0, container[caseInsensitive: $0]?.databaseValue ?? .null)
        })
        if primaryKey.allSatisfy({ $0.value.isNull }) {
            return nil
        }
        return primaryKey
    }
}
