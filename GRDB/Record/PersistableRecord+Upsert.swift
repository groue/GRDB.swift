// MARK: - Upsert

extension PersistableRecord {
#if GRDBCUSTOMSQLITE || SQLITE_HAS_CODEC
    /// Executes an `INSERT ON CONFLICT DO UPDATE` statement.
    ///
    /// The upsert behavior is triggered by a violation of any uniqueness
    /// constraint on the table (primary key or unique index). In case of
    /// violation, all columns but the primary key are overwritten with the
    /// inserted values.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Player: Encodable, PersistableRecord {
    ///     var id: Int64
    ///     var name: String
    ///     var score: Int
    /// }
    ///
    /// // INSERT INTO player (id, name, score)
    /// // VALUES (1, 'Arthur', 1000)
    /// // ON CONFLICT DO UPDATE SET
    /// //   name = excluded.name,
    /// //   score = excluded.score
    /// let player = Player(id: 1, name: "Arthur", score: 1000)
    /// try player.upsert(db)
    /// ```
    ///
    /// - parameter db: A database connection.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs, or any
    ///   error thrown by the persistence callbacks defined by the record type.
    @inlinable // allow specialization so that empty callbacks are removed
    public func upsert(_ db: Database) throws {
        try willSave(db)
        
        var saved: PersistenceSuccess?
        try aroundSave(db) {
            let inserted = try upsertWithCallbacks(db)
            saved = PersistenceSuccess(inserted)
            return saved!
        }
        
        guard let saved else {
            try persistenceCallbackMisuse("aroundSave")
        }
        didSave(saved)
    }
    
    // TODO: Make it possible to build assignments from $0.columnName
    /// Executes an `INSERT ON CONFLICT DO UPDATE RETURNING` statement, and
    /// returns the upserted record.
    ///
    /// With default parameters (`upsertAndFetch(db)`), the upsert behavior is
    /// triggered by a violation of any uniqueness constraint on the table
    /// (primary key or unique index). In case of violation, all columns but the
    /// primary key are overwritten with the inserted values:
    ///
    /// ```swift
    /// struct Player: Encodable, PersistableRecord {
    ///     var id: Int64
    ///     var name: String
    ///     var score: Int
    /// }
    ///
    /// // INSERT INTO player (id, name, score)
    /// // VALUES (1, 'Arthur', 1000)
    /// // ON CONFLICT DO UPDATE SET
    /// //   name = excluded.name,
    /// //   score = excluded.score
    /// // RETURNING *
    /// let player = Player(id: 1, name: "Arthur", score: 1000)
    /// let upsertedPlayer = try player.upsertAndFetch(db)
    /// ```
    ///
    /// With the `conflictTarget`, `strategy`, and `assignments` arguments,
    /// you can further control the upsert behavior. Make sure you check
    /// <https://www.sqlite.org/lang_UPSERT.html> for detailed information.
    ///
    /// The conflict target consists of the columns of the uniqueness constraint
    /// (primary key or unique index) that triggers the upsert. If empty, all
    /// uniqueness constraints are considered.
    ///
    /// The strategy controls which columns are updated in case of
    /// uniqueness constraint violation: all columns unless specified (the
    /// default), or only the specified columns.
    ///
    /// For example, compare:
    ///
    /// ```swift
    /// // In case of conflict, updates all columns, including columns added
    /// // in a future migration.
    /// let upserted = try player.upsertAndFetch(db)
    ///
    /// // In case of conflict, updates all columns, including future ones,
    /// // but 'score'.
    /// let upserted = try player.upsertAndFetch(db) { _ in
    ///     [Column("score").noOverwrite]
    /// }
    ///
    /// // In case of conflict, do not update any column.
    /// let upserted = try player.upsertAndFetch(db, updating: .noColumnUnlessSpecified)
    ///
    /// // In case of conflict, only update 'name'.
    /// let upserted = try player.upsertAndFetch(db, updating: .noColumnUnlessSpecified) { excluded in
    ///     [Column("name").set(to: excluded[Column("name")])]
    /// }
    /// ```
    ///
    /// - parameter db: A database connection.
    /// - parameter conflictTarget: The conflict target.
    /// - parameter strategy: The default strategy, `.allColumns`, updates
    ///   all columns in case of conflict, unless specified otherwise in the
    ///   `assignments` parameter. Use `.noColumnUnlessSpecified` to only
    ///   update the columns assigned in the `assignments` parameter.
    /// - parameter assignments: An optional function that returns an array of
    ///   ``ColumnAssignment``. In case of violation of a uniqueness
    ///   constraint, these assignments are performed, and remaining columns
    ///   are overwritten by inserted values, or not, depending on the
    ///   chosen `strategy`. To use the value that would have been inserted
    ///   had the constraint not failed, use the `excluded` parameter.
    /// - returns: The upserted record.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs, or any
    ///   error thrown by the persistence callbacks defined by the record type.
    @inlinable // allow specialization so that empty callbacks are removed
    public func upsertAndFetch(
        _ db: Database,
        onConflict conflictTarget: [String] = [],
        updating strategy: UpsertUpdateStrategy = .allColumns,
        doUpdate assignments: ((_ excluded: TableAlias<Self>) -> [ColumnAssignment])? = nil)
    throws -> Self
    where Self: FetchableRecord
    {
        try upsertAndFetch(
            db, as: Self.self, onConflict: conflictTarget,
            updating: strategy, doUpdate: assignments)
    }
    
    /// Executes an `INSERT ON CONFLICT DO UPDATE RETURNING` statement, and
    /// returns the upserted record.
    ///
    /// See ``upsertAndFetch(_:onConflict:updating:doUpdate:)`` for more
    /// information about the `conflictTarget`, `strategy`, and
    /// `assignments` parameters.
    ///
    /// - parameter db: A database connection.
    /// - parameter returnedType: The type of the returned record.
    /// - parameter conflictTarget: The conflict target.
    /// - parameter strategy: The default strategy, `.allColumns`, updates
    ///   all columns in case of conflict, unless specified otherwise in the
    ///   `assignments` parameter. Use `.noColumnUnlessSpecified` to only
    ///   update the columns assigned in the `assignments` parameter.
    /// - parameter assignments: An optional function that returns an array of
    ///   ``ColumnAssignment``. In case of violation of a uniqueness
    ///   constraint, these assignments are performed, and remaining columns
    ///   are overwritten by inserted values, or not, depending on the
    ///   chosen `strategy`. To use the value that would have been inserted
    ///   had the constraint not failed, use the `excluded` parameter.
    /// - returns: A record of type `returnedType`.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs, or any
    ///   error thrown by the persistence callbacks defined by the record type.
    @inlinable // allow specialization so that empty callbacks are removed
    public func upsertAndFetch<T: FetchableRecord & TableRecord>(
        _ db: Database,
        as returnedType: T.Type,
        onConflict conflictTarget: [String] = [],
        updating strategy: UpsertUpdateStrategy = .allColumns,
        doUpdate assignments: ((_ excluded: TableAlias<Self>) -> [ColumnAssignment])? = nil)
    throws -> T
    {
        try willSave(db)
        
        var success: (inserted: InsertionSuccess, returned: T)?
        try aroundSave(db) {
            success = try upsertAndFetchWithCallbacks(
                db, onConflict: conflictTarget,
                updating: strategy, doUpdate: assignments,
                selection: T.databaseSelection,
                decode: { try T(row: $0) })
            return PersistenceSuccess(success!.inserted)
        }
        
        guard let success else {
            try persistenceCallbackMisuse("aroundSave")
        }
        didSave(PersistenceSuccess(success.inserted))
        return success.returned
    }
#else
    /// Executes an `INSERT ON CONFLICT DO UPDATE` statement.
    ///
    /// The upsert behavior is triggered by a violation of any uniqueness
    /// constraint on the table (primary key or unique index). In case of
    /// violation, all columns but the primary key are overwritten with the
    /// inserted values.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Player: Encodable, PersistableRecord {
    ///     var id: Int64
    ///     var name: String
    ///     var score: Int
    /// }
    ///
    /// // INSERT INTO player (id, name, score)
    /// // VALUES (1, 'Arthur', 1000)
    /// // ON CONFLICT DO UPDATE SET
    /// //   name = excluded.name,
    /// //   score = excluded.score
    /// let player = Player(id: 1, name: "Arthur", score: 1000)
    /// try player.upsert(db)
    /// ```
    ///
    /// - parameter db: A database connection.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs, or any
    ///   error thrown by the persistence callbacks defined by the record type.
    @inlinable // allow specialization so that empty callbacks are removed
    @available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) // SQLite 3.35.0+
    public func upsert(_ db: Database) throws {
        try willSave(db)
        
        var saved: PersistenceSuccess?
        try aroundSave(db) {
            let inserted = try upsertWithCallbacks(db)
            saved = PersistenceSuccess(inserted)
            return saved!
        }
        
        guard let saved else {
            try persistenceCallbackMisuse("aroundSave")
        }
        didSave(saved)
    }
    
    /// Executes an `INSERT ON CONFLICT DO UPDATE RETURNING` statement, and
    /// returns the upserted record.
    ///
    /// With default parameters (`upsertAndFetch(db)`), the upsert behavior is
    /// triggered by a violation of any uniqueness constraint on the table
    /// (primary key or unique index). In case of violation, all columns but the
    /// primary key are overwritten with the inserted values:
    ///
    /// ```swift
    /// struct Player: Encodable, PersistableRecord {
    ///     var id: Int64
    ///     var name: String
    ///     var score: Int
    /// }
    ///
    /// // INSERT INTO player (id, name, score)
    /// // VALUES (1, 'Arthur', 1000)
    /// // ON CONFLICT DO UPDATE SET
    /// //   name = excluded.name,
    /// //   score = excluded.score
    /// // RETURNING *
    /// let player = Player(id: 1, name: "Arthur", score: 1000)
    /// let upsertedPlayer = try player.upsertAndFetch(db)
    /// ```
    ///
    /// With the `conflictTarget`, `strategy`, and `assignments` arguments,
    /// you can further control the upsert behavior. Make sure you check
    /// <https://www.sqlite.org/lang_UPSERT.html> for detailed information.
    ///
    /// The conflict target consists of the columns of the uniqueness constraint
    /// (primary key or unique index) that triggers the upsert. If empty, all
    /// uniqueness constraints are considered.
    ///
    /// The strategy controls which columns are updated in case of
    /// uniqueness constraint violation: all columns unless specified (the
    /// default), or only the specified columns.
    ///
    /// For example, compare:
    ///
    /// ```swift
    /// // In case of conflict, updates all columns, including columns added
    /// // in a future migration.
    /// let upserted = try player.upsertAndFetch(db)
    ///
    /// // In case of conflict, updates all columns, including future ones,
    /// // but 'score'.
    /// let upserted = try player.upsertAndFetch(db) { _ in
    ///     [Column("score").noOverwrite]
    /// }
    ///
    /// // In case of conflict, do not update any column.
    /// let upserted = try player.upsertAndFetch(db, updating: .noColumnUnlessSpecified)
    ///
    /// // In case of conflict, only update 'name'.
    /// let upserted = try player.upsertAndFetch(db, updating: .noColumnUnlessSpecified) { excluded in
    ///     [Column("name").set(to: excluded[Column("name")])]
    /// }
    /// ```
    ///
    /// - parameter db: A database connection.
    /// - parameter conflictTarget: The conflict target.
    /// - parameter strategy: The default strategy, `.allColumns`, updates
    ///   all columns in case of conflict, unless specified otherwise in the
    ///   `assignments` parameter. Use `.noColumnUnlessSpecified` to only
    ///   update the columns assigned in the `assignments` parameter.
    /// - parameter assignments: An optional function that returns an array of
    ///   ``ColumnAssignment``. In case of violation of a uniqueness
    ///   constraint, these assignments are performed, and remaining columns
    ///   are overwritten by inserted values, or not, depending on the
    ///   chosen `strategy`. To use the value that would have been inserted
    ///   had the constraint not failed, use the `excluded` parameter.
    /// - returns: The upserted record.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs, or any
    ///   error thrown by the persistence callbacks defined by the record type.
    @inlinable // allow specialization so that empty callbacks are removed
    @available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) // SQLite 3.35.0+
    public func upsertAndFetch(
        _ db: Database,
        onConflict conflictTarget: [String] = [],
        updating strategy: UpsertUpdateStrategy = .allColumns,
        doUpdate assignments: ((_ excluded: TableAlias<Self>) -> [ColumnAssignment])? = nil)
    throws -> Self
    where Self: FetchableRecord
    {
        try upsertAndFetch(
            db, as: Self.self, onConflict: conflictTarget,
            updating: strategy, doUpdate: assignments)
    }
    
    /// Executes an `INSERT ON CONFLICT DO UPDATE RETURNING` statement, and
    /// returns the upserted record.
    ///
    /// See ``upsertAndFetch(_:onConflict:updating:doUpdate:)`` for more
    /// information about the `conflictTarget`, `strategy`, and
    /// `assignments` parameters.
    ///
    /// - parameter db: A database connection.
    /// - parameter returnedType: The type of the returned record.
    /// - parameter conflictTarget: The conflict target.
    /// - parameter strategy: The default strategy, `.allColumns`, updates
    ///   all columns in case of conflict, unless specified otherwise in the
    ///   `assignments` parameter. Use `.noColumnUnlessSpecified` to only
    ///   update the columns assigned in the `assignments` parameter.
    /// - parameter assignments: An optional function that returns an array of
    ///   ``ColumnAssignment``. In case of violation of a uniqueness
    ///   constraint, these assignments are performed, and remaining columns
    ///   are overwritten by inserted values, or not, depending on the
    ///   chosen `strategy`. To use the value that would have been inserted
    ///   had the constraint not failed, use the `excluded` parameter.
    /// - returns: A record of type `returnedType`.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs, or any
    ///   error thrown by the persistence callbacks defined by the record type.
    @inlinable // allow specialization so that empty callbacks are removed
    @available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) // SQLite 3.35.0+
    public func upsertAndFetch<T: FetchableRecord & TableRecord>(
        _ db: Database,
        as returnedType: T.Type,
        onConflict conflictTarget: [String] = [],
        updating strategy: UpsertUpdateStrategy = .allColumns,
        doUpdate assignments: ((_ excluded: TableAlias<Self>) -> [ColumnAssignment])? = nil)
    throws -> T
    {
        try willSave(db)
        
        var success: (inserted: InsertionSuccess, returned: T)?
        try aroundSave(db) {
            success = try upsertAndFetchWithCallbacks(
                db, onConflict: conflictTarget,
                updating: strategy, doUpdate: assignments,
                selection: T.databaseSelection,
                decode: { try T(row: $0) })
            return PersistenceSuccess(success!.inserted)
        }
        
        guard let success else {
            try persistenceCallbackMisuse("aroundSave")
        }
        didSave(PersistenceSuccess(success.inserted))
        return success.returned
    }
#endif
}

// MARK: - Internal

extension PersistableRecord {
    @inlinable // allow specialization so that empty callbacks are removed
    func upsertWithCallbacks(_ db: Database)
    throws -> InsertionSuccess
    {
        try upsertWithCallbacks(
            db, onConflict: [],
            updating: .allColumns,
            doUpdate: nil)
    }
    
    @inlinable // allow specialization so that empty callbacks are removed
    func upsertAndFetchWithCallbacks<T>(
        _ db: Database,
        onConflict conflictTarget: [String],
        updating strategy: UpsertUpdateStrategy,
        doUpdate assignments: ((_ excluded: TableAlias<Self>) -> [ColumnAssignment])?,
        selection: [any SQLSelectable],
        decode: (Row) throws -> T)
    throws -> (InsertionSuccess, T)
    {
        try willInsert(db)
        
        var success: (inserted: InsertionSuccess, returned: T)?
        try aroundInsert(db) {
            success = try upsertAndFetchWithoutCallbacks(
                db, onConflict: conflictTarget,
                updating: strategy, doUpdate: assignments,
                selection: selection,
                decode: decode)
            return success!.inserted
        }
        
        guard let success else {
            try persistenceCallbackMisuse("aroundInsert")
        }
        didInsert(success.inserted)
        return success
    }
    
    @inlinable // allow specialization so that empty callbacks are removed
    func upsertWithCallbacks(
        _ db: Database,
        onConflict conflictTarget: [String],
        updating strategy: UpsertUpdateStrategy,
        doUpdate assignments: ((_ excluded: TableAlias<Self>) -> [ColumnAssignment])?
    ) throws -> InsertionSuccess {
        try willInsert(db)
        
        var inserted: InsertionSuccess?
        try aroundInsert(db) {
            inserted = try upsertWithoutCallbacks(
                db, onConflict: conflictTarget,
                updating: strategy, doUpdate: assignments)
            return inserted!
        }
        
        guard let inserted else {
            try persistenceCallbackMisuse("aroundInsert")
        }
        didInsert(inserted)
        return inserted
    }
}
