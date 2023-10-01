// MARK: - Update Callbacks

extension MutablePersistableRecord {
    @inline(__always)
    @inlinable
    public func willUpdate(_ db: Database, columns: Set<String>) throws { }
    
    @inline(__always)
    @inlinable
    public func aroundUpdate(_ db: Database, columns: Set<String>, update: () throws -> PersistenceSuccess) throws {
        _ = try update()
    }
    
    @inline(__always)
    @inlinable
    public func didUpdate(_ updated: PersistenceSuccess) { }
}

// MARK: - Update

extension MutablePersistableRecord {
    /// Executes an `UPDATE` statement on the provided columns.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.write { db in
    ///     var player = Player.find(db, id: 1)
    ///     player.score += 10
    ///     try player.update(db, columns: ["score"])
    /// }
    /// ```
    ///
    /// - parameter db: A database connection.
    /// - parameter conflictResolution: A policy for conflict resolution. If
    ///   nil, <doc:/MutablePersistableRecord/persistenceConflictPolicy-1isyv>
    ///   is used.
    /// - parameter columns: The columns to update.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs, or any
    ///   error thrown by the persistence callbacks defined by the record type,
    ///   or ``RecordError/recordNotFound(databaseTableName:key:)`` if the
    ///   primary key does not match any row in the database.
    @inlinable // allow specialization so that empty callbacks are removed
    public func update<Columns>(
        _ db: Database,
        onConflict conflictResolution: Database.ConflictResolution? = nil,
        columns: Columns)
    throws
    where Columns: Sequence, Columns.Element == String
    {
        try willSave(db)
        
        var updated: PersistenceSuccess?
        try aroundSave(db) {
            updated = try updateWithCallbacks(db, onConflict: conflictResolution, columns: Set(columns))
            return updated!
        }
        
        guard let updated else {
            try persistenceCallbackMisuse("aroundSave")
        }
        didSave(updated)
    }
    
    /// Executes an `UPDATE` statement on the provided columns.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.write { db in
    ///     var player = Player.find(db, id: 1)
    ///     player.score += 10
    ///     try player.update(db, columns: [Column("score")])
    /// }
    /// ```
    ///
    /// - parameter db: A database connection.
    /// - parameter conflictResolution: A policy for conflict resolution. If
    ///   nil, <doc:/MutablePersistableRecord/persistenceConflictPolicy-1isyv>
    ///   is used.
    /// - parameter columns: The columns to update.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs, or any
    ///   error thrown by the persistence callbacks defined by the record type,
    ///   or ``RecordError/recordNotFound(databaseTableName:key:)`` if the
    ///   primary key does not match any row in the database.
    @inlinable // allow specialization so that empty callbacks are removed
    public func update<Columns>(
        _ db: Database,
        onConflict conflictResolution: Database.ConflictResolution? = nil,
        columns: Columns)
    throws
    where Columns: Sequence, Columns.Element: ColumnExpression
    {
        try update(db, onConflict: conflictResolution, columns: columns.map(\.name))
    }
    
    /// Executes an `UPDATE` statement on all columns.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.write { db in
    ///     var player = Player.find(db, id: 1)
    ///     player.score += 10
    ///     try player.update(db)
    /// }
    /// ```
    ///
    /// - parameter db: A database connection.
    /// - parameter conflictResolution: A policy for conflict resolution. If
    ///   nil, <doc:/MutablePersistableRecord/persistenceConflictPolicy-1isyv>
    ///   is used.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs, or any
    ///   error thrown by the persistence callbacks defined by the record type,
    ///   or ``RecordError/recordNotFound(databaseTableName:key:)`` if the
    ///   primary key does not match any row in the database.
    @inlinable // allow specialization so that empty callbacks are removed
    public func update(
        _ db: Database,
        onConflict conflictResolution: Database.ConflictResolution? = nil)
    throws
    {
        let databaseTableName = type(of: self).databaseTableName
        let columns = try db.columns(in: databaseTableName).map(\.name)
        try update(db, onConflict: conflictResolution, columns: columns)
    }
    
    /// If the record has any difference from the other record, executes an
    /// `UPDATE` statement so that those differences and only those differences
    /// are updated in the database.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.write { db in
    ///     if let oldPlayer = Player.fetchOne(db, id: 1) {
    ///         var newPlayer = oldPlayer
    ///         newPlayer.score = 1000
    ///         newPlayer.hasAward = true
    ///         let modified = try newPlayer.updateChanges(db, from: oldPlayer)
    ///         if modified {
    ///             print("player was modified")
    ///         } else {
    ///             print("player was not modified")
    ///         }
    ///     }
    /// }
    /// ```
    ///
    /// - parameter db: A database connection.
    /// - parameter conflictResolution: A policy for conflict resolution. If
    ///   nil, <doc:/MutablePersistableRecord/persistenceConflictPolicy-1isyv>
    ///   is used.
    /// - parameter record: The comparison record.
    /// - returns: Whether the record had changes and was updated.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs, or any
    ///   error thrown by the persistence callbacks defined by the record type,
    ///   or ``RecordError/recordNotFound(databaseTableName:key:)`` if the
    ///   primary key does not match any row in the database.
    /// - SeeAlso: updateChanges(_:with:)
    @discardableResult
    @inlinable // allow specialization so that empty callbacks are removed
    public func updateChanges<Record: MutablePersistableRecord>(
        _ db: Database,
        onConflict conflictResolution: Database.ConflictResolution? = nil,
        from record: Record)
    throws -> Bool
    {
        try updateChanges(db, onConflict: conflictResolution, from: PersistenceContainer(db, record))
    }
    
    /// Modifies the record according to the provided `modify` closure, and
    /// executes an `UPDATE` statement that updates the modified columns, if and
    /// only if the record was modified.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.write { db in
    ///     var player = Player.find(db, id: 1)
    ///     let modified = try player.updateChanges(db) {
    ///         $0.score = 1000
    ///         $0.hasAward = true
    ///     }
    ///     if modified {
    ///         print("player was modified")
    ///     } else {
    ///         print("player was not modified")
    ///     }
    /// }
    /// ```
    ///
    /// - parameter db: A database connection.
    /// - parameter conflictResolution: A policy for conflict resolution. If
    ///   nil, <doc:/MutablePersistableRecord/persistenceConflictPolicy-1isyv>
    ///   is used.
    /// - parameter modify: A closure that modifies the record.
    /// - returns: Whether the record was changed and updated.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs, or any
    ///   error thrown by the persistence callbacks defined by the record type,
    ///   or ``RecordError/recordNotFound(databaseTableName:key:)`` if the
    ///   primary key does not match any row in the database.
    @discardableResult
    @inlinable // allow specialization so that empty callbacks are removed
    public mutating func updateChanges(
        _ db: Database,
        onConflict conflictResolution: Database.ConflictResolution? = nil,
        modify: (inout Self) throws -> Void)
    throws -> Bool
    {
        let container = try PersistenceContainer(db, self)
        try modify(&self)
        return try updateChanges(db, onConflict: conflictResolution, from: container)
    }
}

// MARK: - Update and Fetch

extension MutablePersistableRecord {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
    // TODO: GRDB7 make it unable to return an optional
    /// Executes an `UPDATE RETURNING` statement on all columns, and returns a
    /// new record built from the updated row.
    ///
    /// - parameter db: A database connection.
    /// - parameter conflictResolution: A policy for conflict resolution. If
    ///   nil, <doc:/MutablePersistableRecord/persistenceConflictPolicy-1isyv>
    ///   is used.
    /// - returns: The updated record. The result can be nil when the
    ///   conflict policy is `IGNORE`.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs, or any
    ///   error thrown by the persistence callbacks defined by the record type,
    ///   or ``RecordError/recordNotFound(databaseTableName:key:)`` if the
    ///   primary key does not match any row in the database.
    @inlinable // allow specialization so that empty callbacks are removed
    public func updateAndFetch(
        _ db: Database,
        onConflict conflictResolution: Database.ConflictResolution? = nil)
    throws -> Self?
    where Self: FetchableRecord
    {
        try updateAndFetch(db, onConflict: conflictResolution, as: Self.self)
    }
    
    // TODO: GRDB7 make it unable to return an optional
    /// Executes an `UPDATE RETURNING` statement on all columns, and returns a
    /// new record built from the updated row.
    ///
    /// - parameter db: A database connection.
    /// - parameter conflictResolution: A policy for conflict resolution. If
    ///   nil, <doc:/MutablePersistableRecord/persistenceConflictPolicy-1isyv>
    ///   is used.
    /// - parameter returnedType: The type of the returned record.
    /// - returns: A record of type `returnedType`. The result can be nil when
    ///   the conflict policy is `IGNORE`.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs, or any
    ///   error thrown by the persistence callbacks defined by the record type,
    ///   or ``RecordError/recordNotFound(databaseTableName:key:)`` if the
    ///   primary key does not match any row in the database.
    @inlinable // allow specialization so that empty callbacks are removed
    public func updateAndFetch<T: FetchableRecord & TableRecord>(
        _ db: Database,
        onConflict conflictResolution: Database.ConflictResolution? = nil,
        as returnedType: T.Type)
    throws -> T?
    {
        try updateAndFetch(db, onConflict: conflictResolution, selection: T.databaseSelection) {
            try T.fetchOne($0)
        }
    }
    
    // TODO: GRDB7 make it unable to return an optional
    /// Modifies the record according to the provided `modify` closure, and
    /// executes an `UPDATE RETURNING` statement that updates the modified
    /// columns, if and only if the record was modified. The method returns a
    /// new record built from the updated row.
    ///
    /// - parameter db: A database connection.
    /// - parameter conflictResolution: A policy for conflict resolution. If
    ///   nil, <doc:/MutablePersistableRecord/persistenceConflictPolicy-1isyv>
    ///   is used.
    /// - parameter modify: A closure that modifies the record.
    /// - returns: An updated record, or nil if the record has no change, or
    ///   in case of a failed update due to the `IGNORE` conflict policy.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs, or any
    ///   error thrown by the persistence callbacks defined by the record type,
    ///   or ``RecordError/recordNotFound(databaseTableName:key:)`` if the
    ///   primary key does not match any row in the database.
    @inlinable // allow specialization so that empty callbacks are removed
    public mutating func updateChangesAndFetch(
        _ db: Database,
        onConflict conflictResolution: Database.ConflictResolution? = nil,
        modify: (inout Self) throws -> Void)
    throws -> Self?
    where Self: FetchableRecord
    {
        try updateChangesAndFetch(db, onConflict: conflictResolution, as: Self.self, modify: modify)
    }
    
    // TODO: GRDB7 make it unable to return an optional
    /// Modifies the record according to the provided `modify` closure, and
    /// executes an `UPDATE RETURNING` statement that updates the modified
    /// columns, if and only if the record was modified. The method returns a
    /// new record built from the updated row.
    ///
    /// - parameter db: A database connection.
    /// - parameter conflictResolution: A policy for conflict resolution. If
    ///   nil, <doc:/MutablePersistableRecord/persistenceConflictPolicy-1isyv>
    ///   is used.
    /// - parameter returnedType: The type of the returned record.
    /// - parameter modify: A closure that modifies the record.
    /// - returns: A record of type `returnedType`, or nil if the record has
    ///   no change, or in case of a failed update due to the `IGNORE`
    ///   conflict policy.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs, or any
    ///   error thrown by the persistence callbacks defined by the record type,
    ///   or ``RecordError/recordNotFound(databaseTableName:key:)`` if the
    ///   primary key does not match any row in the database.
    @inlinable // allow specialization so that empty callbacks are removed
    public mutating func updateChangesAndFetch<T: FetchableRecord & TableRecord>(
        _ db: Database,
        onConflict conflictResolution: Database.ConflictResolution? = nil,
        as returnedType: T.Type,
        modify: (inout Self) throws -> Void)
    throws -> T?
    {
        try updateChangesAndFetch(
            db, onConflict: conflictResolution,
            selection: T.databaseSelection,
            fetch: { try T.fetchOne($0) },
            modify: modify)
    }
    
    /// Executes an `UPDATE RETURNING` statement on the provided columns, and
    /// returns the selected columns from the updated row.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.write { db in
    ///     // UPDATE player SET score = ... RETURNING totalScore
    ///     let totalScore = try player.updateAndFetch(
    ///         db, columns: ["Score"],
    ///         selection: [Column("totalScore")],
    ///         fetch: { statement in
    ///             try Int.fetchOne(statement)
    ///         })
    /// }
    /// ```
    ///
    /// - parameter db: A database connection.
    /// - parameter conflictResolution: A policy for conflict resolution. If
    ///   nil, <doc:/MutablePersistableRecord/persistenceConflictPolicy-1isyv>
    ///   is used.
    /// - parameter columns: The columns to update.
    /// - parameter selection: The returned columns (must not be empty).
    /// - parameter fetch: A function that executes it ``Statement`` argument.
    /// - returns: The result of the `fetch` function.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs, or any
    ///   error thrown by the persistence callbacks defined by the record type,
    ///   or ``RecordError/recordNotFound(databaseTableName:key:)`` if the
    ///   primary key does not match any row in the database.
    /// - precondition: `selection` is not empty.
    @inlinable // allow specialization so that empty callbacks are removed
    public func updateAndFetch<T, Columns>(
        _ db: Database,
        onConflict conflictResolution: Database.ConflictResolution? = nil,
        columns: Columns,
        selection: [any SQLSelectable],
        fetch: (Statement) throws -> T)
    throws -> T
    where Columns: Sequence, Columns.Element == String
    {
        GRDBPrecondition(!selection.isEmpty, "Invalid empty selection")
        
        try willSave(db)
        
        var success: (updated: PersistenceSuccess, returned: T)?
        try aroundSave(db) {
            success = try updateAndFetchWithCallbacks(
                db, onConflict: conflictResolution,
                columns: Set(columns),
                selection: selection,
                fetch: fetch)
            return success!.updated
        }
        
        guard let success else {
            try persistenceCallbackMisuse("aroundSave")
        }
        didSave(success.updated)
        return success.returned
    }
    
    /// Executes an `UPDATE RETURNING` statement on the provided columns, and
    /// returns the selected columns from the updated row.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.write { db in
    ///     // UPDATE player SET score = ... RETURNING totalScore
    ///     let totalScore = try player.updateAndFetch(
    ///         db, columns: [Column("Score")],
    ///         selection: [Column("totalScore")],
    ///         fetch: { statement in
    ///             try Int.fetchOne(statement)
    ///         })
    /// }
    /// ```
    ///
    /// - parameter db: A database connection.
    /// - parameter conflictResolution: A policy for conflict resolution. If
    ///   nil, <doc:/MutablePersistableRecord/persistenceConflictPolicy-1isyv>
    ///   is used.
    /// - parameter columns: The columns to update.
    /// - parameter selection: The returned columns (must not be empty).
    /// - parameter fetch: A function that executes it ``Statement`` argument.
    /// - returns: The result of the `fetch` function.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs, or any
    ///   error thrown by the persistence callbacks defined by the record type,
    ///   or ``RecordError/recordNotFound(databaseTableName:key:)`` if the
    ///   primary key does not match any row in the database.
    /// - precondition: `selection` is not empty.
    @inlinable // allow specialization so that empty callbacks are removed
    public func updateAndFetch<T, Columns>(
        _ db: Database,
        onConflict conflictResolution: Database.ConflictResolution? = nil,
        columns: Columns,
        selection: [any SQLSelectable],
        fetch: (Statement) throws -> T)
    throws -> T
    where Columns: Sequence, Columns.Element: ColumnExpression
    {
        try updateAndFetch(
            db, onConflict: conflictResolution,
            columns: columns.map(\.name),
            selection: selection,
            fetch: fetch)
    }
    
    /// Executes an `UPDATE RETURNING` statement on all columns, and returns the
    /// selected columns from the updated row.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.write { db in
    ///     // UPDATE player SET ... RETURNING totalScore
    ///     let totalScore = try player.updateAndFetch(db, selection: [Column("totalScore")]) { statement in
    ///         try Int.fetchOne(statement)
    ///     }
    /// }
    /// ```
    ///
    /// - parameter db: A database connection.
    /// - parameter conflictResolution: A policy for conflict resolution. If
    ///   nil, <doc:/MutablePersistableRecord/persistenceConflictPolicy-1isyv>
    ///   is used.
    /// - parameter selection: The returned columns (must not be empty).
    /// - parameter fetch: A function that executes it ``Statement`` argument.
    /// - returns: The result of the `fetch` function.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs, or any
    ///   error thrown by the persistence callbacks defined by the record type,
    ///   or ``RecordError/recordNotFound(databaseTableName:key:)`` if the
    ///   primary key does not match any row in the database.
    /// - precondition: `selection` is not empty.
    @inlinable // allow specialization so that empty callbacks are removed
    public func updateAndFetch<T>(
        _ db: Database,
        onConflict conflictResolution: Database.ConflictResolution? = nil,
        selection: [any SQLSelectable],
        fetch: (Statement) throws -> T)
    throws -> T
    {
        let databaseTableName = type(of: self).databaseTableName
        let columns = try db.columns(in: databaseTableName).map(\.name)
        return try updateAndFetch(
            db, onConflict: conflictResolution,
            columns: columns,
            selection: selection,
            fetch: fetch)
    }
    
    // TODO: GRDB7 make it unable to return an optional
    /// Modifies the record according to the provided `modify` closure, and
    /// executes an `UPDATE RETURNING` statement that updates the modified
    /// columns, if and only if the record was modified. The method returns a
    /// new record built from the updated row.
    ///
    /// - parameter db: A database connection.
    /// - parameter conflictResolution: A policy for conflict resolution. If
    ///   nil, <doc:/MutablePersistableRecord/persistenceConflictPolicy-1isyv>
    ///   is used.
    /// - parameter selection: The returned columns (must not be empty).
    /// - parameter fetch: A function that executes it ``Statement`` argument.
    /// - parameter modify: A closure that modifies the record.
    /// - returns: The result of the `fetch` function.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs, or any
    ///   error thrown by the persistence callbacks defined by the record type,
    ///   or ``RecordError/recordNotFound(databaseTableName:key:)`` if the
    ///   primary key does not match any row in the database.
    /// - precondition: `selection` is not empty.
    @inlinable // allow specialization so that empty callbacks are removed
    public mutating func updateChangesAndFetch<T>(
        _ db: Database,
        onConflict conflictResolution: Database.ConflictResolution? = nil,
        selection: [any SQLSelectable],
        fetch: (Statement) throws -> T?,
        modify: (inout Self) throws -> Void)
    throws -> T?
    {
        let container = try PersistenceContainer(db, self)
        try modify(&self)
        return try updateChangesAndFetch(
            db, onConflict: conflictResolution,
            from: container,
            selection: selection,
            fetch: fetch)
    }
#else
    // TODO: GRDB7 make it unable to return an optional
    /// Executes an `UPDATE RETURNING` statement on all columns, and returns a
    /// new record built from the updated row.
    ///
    /// - parameter db: A database connection.
    /// - parameter conflictResolution: A policy for conflict resolution. If
    ///   nil, <doc:/MutablePersistableRecord/persistenceConflictPolicy-1isyv>
    ///   is used.
    /// - returns: The updated record. The result can be nil when the
    ///   conflict policy is `IGNORE`.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs, or any
    ///   error thrown by the persistence callbacks defined by the record type,
    ///   or ``RecordError/recordNotFound(databaseTableName:key:)`` if the
    ///   primary key does not match any row in the database.
    @inlinable // allow specialization so that empty callbacks are removed
    @available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) // SQLite 3.35.0+
    public func updateAndFetch(
        _ db: Database,
        onConflict conflictResolution: Database.ConflictResolution? = nil)
    throws -> Self?
    where Self: FetchableRecord
    {
        try updateAndFetch(db, onConflict: conflictResolution, as: Self.self)
    }
    
    /// Executes an `UPDATE RETURNING` statement on all columns, and returns a
    /// new record built from the updated row.
    ///
    /// - parameter db: A database connection.
    /// - parameter conflictResolution: A policy for conflict resolution. If
    ///   nil, <doc:/MutablePersistableRecord/persistenceConflictPolicy-1isyv>
    ///   is used.
    /// - parameter returnedType: The type of the returned record.
    /// - returns: A record of type `returnedType`. The result can be nil when
    ///   the conflict policy is `IGNORE`.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs, or any
    ///   error thrown by the persistence callbacks defined by the record type,
    ///   or ``RecordError/recordNotFound(databaseTableName:key:)`` if the
    ///   primary key does not match any row in the database.
    @inlinable // allow specialization so that empty callbacks are removed
    @available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) // SQLite 3.35.0+
    public func updateAndFetch<T: FetchableRecord & TableRecord>(
        _ db: Database,
        onConflict conflictResolution: Database.ConflictResolution? = nil,
        as returnedType: T.Type)
    throws -> T?
    {
        try updateAndFetch(db, onConflict: conflictResolution, selection: T.databaseSelection) {
            try T.fetchOne($0)
        }
    }
    
    // TODO: GRDB7 make it unable to return an optional
    /// Modifies the record according to the provided `modify` closure, and
    /// executes an `UPDATE RETURNING` statement that updates the modified
    /// columns, if and only if the record was modified. The method returns a
    /// new record built from the updated row.
    ///
    /// - parameter db: A database connection.
    /// - parameter conflictResolution: A policy for conflict resolution. If
    ///   nil, <doc:/MutablePersistableRecord/persistenceConflictPolicy-1isyv>
    ///   is used.
    /// - parameter modify: A closure that modifies the record.
    /// - returns: An updated record, or nil if the record has no change, or
    ///   in case of a failed update due to the `IGNORE` conflict policy.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs, or any
    ///   error thrown by the persistence callbacks defined by the record type,
    ///   or ``RecordError/recordNotFound(databaseTableName:key:)`` if the
    ///   primary key does not match any row in the database.
    @inlinable // allow specialization so that empty callbacks are removed
    @available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) // SQLite 3.35.0+
    public mutating func updateChangesAndFetch(
        _ db: Database,
        onConflict conflictResolution: Database.ConflictResolution? = nil,
        modify: (inout Self) throws -> Void)
    throws -> Self?
    where Self: FetchableRecord
    {
        try updateChangesAndFetch(db, onConflict: conflictResolution, as: Self.self, modify: modify)
    }
    
    // TODO: GRDB7 make it unable to return an optional
    /// Modifies the record according to the provided `modify` closure, and
    /// executes an `UPDATE RETURNING` statement that updates the modified
    /// columns, if and only if the record was modified. The method returns a
    /// new record built from the updated row.
    ///
    /// - parameter db: A database connection.
    /// - parameter conflictResolution: A policy for conflict resolution. If
    ///   nil, <doc:/MutablePersistableRecord/persistenceConflictPolicy-1isyv>
    ///   is used.
    /// - parameter returnedType: The type of the returned record.
    /// - parameter modify: A closure that modifies the record.
    /// - returns: A record of type `returnedType`, or nil if the record has
    ///   no change, or in case of a failed update due to the `IGNORE`
    ///   conflict policy.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs, or any
    ///   error thrown by the persistence callbacks defined by the record type,
    ///   or ``RecordError/recordNotFound(databaseTableName:key:)`` if the
    ///   primary key does not match any row in the database.
    @inlinable // allow specialization so that empty callbacks are removed
    @available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) // SQLite 3.35.0+
    public mutating func updateChangesAndFetch<T: FetchableRecord & TableRecord>(
        _ db: Database,
        onConflict conflictResolution: Database.ConflictResolution? = nil,
        as returnedType: T.Type,
        modify: (inout Self) throws -> Void)
    throws -> T?
    {
        try updateChangesAndFetch(
            db, onConflict: conflictResolution,
            selection: T.databaseSelection,
            fetch: { try T.fetchOne($0) },
            modify: modify)
    }
    
    /// Executes an `UPDATE RETURNING` statement on the provided columns, and
    /// returns the selected columns from the updated row.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.write { db in
    ///     // UPDATE player SET score = ... RETURNING totalScore
    ///     let totalScore = try player.updateAndFetch(
    ///         db, columns: ["Score"],
    ///         selection: [Column("totalScore")],
    ///         fetch: { statement in
    ///             try Int.fetchOne(statement)
    ///         })
    /// }
    /// ```
    ///
    /// - parameter db: A database connection.
    /// - parameter conflictResolution: A policy for conflict resolution. If
    ///   nil, <doc:/MutablePersistableRecord/persistenceConflictPolicy-1isyv>
    ///   is used.
    /// - parameter columns: The columns to update.
    /// - parameter selection: The returned columns (must not be empty).
    /// - parameter fetch: A function that executes it ``Statement`` argument.
    /// - returns: The result of the `fetch` function.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs, or any
    ///   error thrown by the persistence callbacks defined by the record type,
    ///   or ``RecordError/recordNotFound(databaseTableName:key:)`` if the
    ///   primary key does not match any row in the database.
    /// - precondition: `selection` is not empty.
    @inlinable // allow specialization so that empty callbacks are removed
    @available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) // SQLite 3.35.0+
    public func updateAndFetch<T, Columns>(
        _ db: Database,
        onConflict conflictResolution: Database.ConflictResolution? = nil,
        columns: Columns,
        selection: [any SQLSelectable],
        fetch: (Statement) throws -> T)
    throws -> T
    where Columns: Sequence, Columns.Element == String
    {
        GRDBPrecondition(!selection.isEmpty, "Invalid empty selection")
        
        try willSave(db)
        
        var success: (updated: PersistenceSuccess, returned: T)?
        try aroundSave(db) {
            success = try updateAndFetchWithCallbacks(
                db, onConflict: conflictResolution,
                columns: Set(columns),
                selection: selection,
                fetch: fetch)
            return success!.updated
        }
        
        guard let success else {
            try persistenceCallbackMisuse("aroundSave")
        }
        didSave(success.updated)
        return success.returned
    }
    
    /// Executes an `UPDATE RETURNING` statement on the provided columns, and
    /// returns the selected columns from the updated row.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.write { db in
    ///     // UPDATE player SET score = ... RETURNING totalScore
    ///     let totalScore = try player.updateAndFetch(
    ///         db, columns: [Column("Score")],
    ///         selection: [Column("totalScore")],
    ///         fetch: { statement in
    ///             try Int.fetchOne(statement)
    ///         })
    /// }
    /// ```
    ///
    /// - parameter db: A database connection.
    /// - parameter conflictResolution: A policy for conflict resolution. If
    ///   nil, <doc:/MutablePersistableRecord/persistenceConflictPolicy-1isyv>
    ///   is used.
    /// - parameter columns: The columns to update.
    /// - parameter selection: The returned columns (must not be empty).
    /// - parameter fetch: A function that executes it ``Statement`` argument.
    /// - returns: The result of the `fetch` function.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs, or any
    ///   error thrown by the persistence callbacks defined by the record type,
    ///   or ``RecordError/recordNotFound(databaseTableName:key:)`` if the
    ///   primary key does not match any row in the database.
    /// - precondition: `selection` is not empty.
    @inlinable // allow specialization so that empty callbacks are removed
    @available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) // SQLite 3.35.0+
    public func updateAndFetch<T, Columns>(
        _ db: Database,
        onConflict conflictResolution: Database.ConflictResolution? = nil,
        columns: Columns,
        selection: [any SQLSelectable],
        fetch: (Statement) throws -> T)
    throws -> T
    where Columns: Sequence, Columns.Element: ColumnExpression
    {
        try updateAndFetch(
            db, onConflict: conflictResolution,
            columns: columns.map(\.name),
            selection: selection,
            fetch: fetch)
    }
    
    /// Executes an `UPDATE RETURNING` statement on all columns, and returns the
    /// selected columns from the updated row.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.write { db in
    ///     // UPDATE player SET ... RETURNING totalScore
    ///     let totalScore = try player.updateAndFetch(db, selection: [Column("totalScore")]) { statement in
    ///         try Int.fetchOne(statement)
    ///     }
    /// }
    /// ```
    ///
    /// - parameter db: A database connection.
    /// - parameter conflictResolution: A policy for conflict resolution. If
    ///   nil, <doc:/MutablePersistableRecord/persistenceConflictPolicy-1isyv>
    ///   is used.
    /// - parameter selection: The returned columns (must not be empty).
    /// - parameter fetch: A function that executes it ``Statement`` argument.
    /// - returns: The result of the `fetch` function.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs, or any
    ///   error thrown by the persistence callbacks defined by the record type,
    ///   or ``RecordError/recordNotFound(databaseTableName:key:)`` if the
    ///   primary key does not match any row in the database.
    /// - precondition: `selection` is not empty.
    @inlinable // allow specialization so that empty callbacks are removed
    @available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) // SQLite 3.35.0+
    public func updateAndFetch<T>(
        _ db: Database,
        onConflict conflictResolution: Database.ConflictResolution? = nil,
        selection: [any SQLSelectable],
        fetch: (Statement) throws -> T)
    throws -> T
    {
        let databaseTableName = type(of: self).databaseTableName
        let columns = try db.columns(in: databaseTableName).map(\.name)
        return try updateAndFetch(
            db, onConflict: conflictResolution,
            columns: columns,
            selection: selection,
            fetch: fetch)
    }
    
    // TODO: GRDB7 make it unable to return an optional
    /// Modifies the record according to the provided `modify` closure, and
    /// executes an `UPDATE RETURNING` statement that updates the modified
    /// columns, if and only if the record was modified. The method returns a
    /// new record built from the updated row.
    ///
    /// - parameter db: A database connection.
    /// - parameter conflictResolution: A policy for conflict resolution. If
    ///   nil, <doc:/MutablePersistableRecord/persistenceConflictPolicy-1isyv>
    ///   is used.
    /// - parameter selection: The returned columns (must not be empty).
    /// - parameter fetch: A function that executes it ``Statement`` argument.
    /// - parameter modify: A closure that modifies the record.
    /// - returns: The result of the `fetch` function.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs, or any
    ///   error thrown by the persistence callbacks defined by the record type,
    ///   or ``RecordError/recordNotFound(databaseTableName:key:)`` if the
    ///   primary key does not match any row in the database.
    /// - precondition: `selection` is not empty.
    @inlinable // allow specialization so that empty callbacks are removed
    @available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) // SQLite 3.35.0+
    public mutating func updateChangesAndFetch<T>(
        _ db: Database,
        onConflict conflictResolution: Database.ConflictResolution? = nil,
        selection: [any SQLSelectable],
        fetch: (Statement) throws -> T?,
        modify: (inout Self) throws -> Void)
    throws -> T?
    {
        let container = try PersistenceContainer(db, self)
        try modify(&self)
        return try updateChangesAndFetch(
            db, onConflict: conflictResolution,
            from: container,
            selection: selection,
            fetch: fetch)
    }
#endif
}

// MARK: - Internals

extension MutablePersistableRecord {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
    @inlinable // allow specialization so that empty callbacks are removed
    func updateChangesAndFetch<T>(
        _ db: Database,
        onConflict conflictResolution: Database.ConflictResolution?,
        from container: PersistenceContainer,
        selection: [any SQLSelectable],
        fetch: (Statement) throws -> T?)
    throws -> T?
    {
        let changes = try PersistenceContainer(db, self).changesIterator(from: container)
        let changedColumns: Set<String> = changes.reduce(into: []) { $0.insert($1.0) }
        if changedColumns.isEmpty {
            return nil
        }
        return try updateAndFetch(
            db, onConflict: conflictResolution,
            columns: changedColumns,
            selection: selection,
            fetch: fetch)
    }
#else
    @inlinable // allow specialization so that empty callbacks are removed
    @available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) // SQLite 3.35.0+
    func updateChangesAndFetch<T>(
        _ db: Database,
        onConflict conflictResolution: Database.ConflictResolution?,
        from container: PersistenceContainer,
        selection: [any SQLSelectable],
        fetch: (Statement) throws -> T?)
    throws -> T?
    {
        let changes = try PersistenceContainer(db, self).changesIterator(from: container)
        let changedColumns: Set<String> = changes.reduce(into: []) { $0.insert($1.0) }
        if changedColumns.isEmpty {
            return nil
        }
        return try updateAndFetch(
            db, onConflict: conflictResolution,
            columns: changedColumns,
            selection: selection,
            fetch: fetch)
    }
#endif
    
    /// Executes an `UPDATE` statement, and runs update callbacks.
    @inlinable // allow specialization so that empty callbacks are removed
    func updateWithCallbacks(
        _ db: Database,
        onConflict conflictResolution: Database.ConflictResolution?,
        columns: Set<String>)
    throws -> PersistenceSuccess
    {
        let (updated, _) = try updateAndFetchWithCallbacks(
            db, onConflict: conflictResolution,
            columns: columns,
            selection: [],
            fetch: {
                // Nothing to fetch
                try $0.execute()
            })
        return updated
    }
    
    /// Executes an `UPDATE` statement, with `RETURNING` clause if `selection`
    /// is not empty, and runs update callbacks.
    @inlinable // allow specialization so that empty callbacks are removed
    func updateAndFetchWithCallbacks<T>(
        _ db: Database,
        onConflict conflictResolution: Database.ConflictResolution?,
        columns: Set<String>,
        selection: [any SQLSelectable],
        fetch: (Statement) throws -> T)
    throws -> (PersistenceSuccess, T)
    {
        try willUpdate(db, columns: columns)
        
        var success: (updated: PersistenceSuccess, returned: T)?
        try aroundUpdate(db, columns: columns) {
            success = try updateAndFetchWithoutCallbacks(
                db, onConflict: conflictResolution,
                columns: columns,
                selection: selection,
                fetch: fetch)
            return success!.updated
        }
        
        guard let success else {
            try persistenceCallbackMisuse("aroundUpdate")
        }
        didUpdate(success.updated)
        return success
    }
    
    /// Executes an `UPDATE` statement, with `RETURNING` clause if `selection`
    /// is not empty, and DOES NOT run update callbacks.
    @usableFromInline
    func updateAndFetchWithoutCallbacks<T>(
        _ db: Database,
        onConflict conflictResolution: Database.ConflictResolution?,
        columns: Set<String>,
        selection: [any SQLSelectable],
        fetch: (Statement) throws -> T)
    throws -> (PersistenceSuccess, T)
    {
        let conflictResolution = conflictResolution ?? type(of: self)
            .persistenceConflictPolicy
            .conflictResolutionForUpdate
        let dao = try DAO(db, self)
        guard let statement = try dao.updateStatement(
            columns: columns,
            onConflict: conflictResolution,
            returning: selection)
        else {
            // Nil primary key
            try dao.recordNotFound()
        }
        let returned = try fetch(statement)
        if db.changesCount == 0 {
            // No row was updated
            try dao.recordNotFound()
        }
        let updated = PersistenceSuccess(persistenceContainer: dao.persistenceContainer)
        return (updated, returned)
    }
    
    @inlinable // allow specialization so that empty callbacks are removed
    func updateChanges(
        _ db: Database,
        onConflict conflictResolution: Database.ConflictResolution?,
        from container: PersistenceContainer)
    throws -> Bool
    {
        let changes = try PersistenceContainer(db, self).changesIterator(from: container)
        let changedColumns: Set<String> = changes.reduce(into: []) { $0.insert($1.0) }
        if changedColumns.isEmpty {
            return false
        }
        try update(db, onConflict: conflictResolution, columns: changedColumns)
        return true
    }
}
