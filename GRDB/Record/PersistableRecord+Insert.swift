// MARK: - Insert Callbacks

extension PersistableRecord {
    @inline(__always)
    @inlinable
    public func willInsert(_ db: Database) throws { }
    
    @inline(__always)
    @inlinable
    public func didInsert(_ inserted: InsertionSuccess) { }
}

// MARK: - Insert

extension PersistableRecord {
    /// Executes an `INSERT` statement.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.write { db in
    ///     let player = Player(name: "Arthur")
    ///     try player.insert(db)
    /// }
    /// ```
    ///
    /// - parameter db: A database connection.
    /// - parameter conflictResolution: A policy for conflict resolution. If
    ///   nil, <doc:/MutablePersistableRecord/persistenceConflictPolicy-1isyv>
    ///   is used.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs, or any
    ///   error thrown by the persistence callbacks defined by the record type.
    @inlinable // allow specialization so that empty callbacks are removed
    public func insert(
        _ db: Database,
        onConflict conflictResolution: Database.ConflictResolution? = nil)
    throws
    {
        try willSave(db)
        
        var saved: PersistenceSuccess?
        try aroundSave(db) {
            let inserted = try insertWithCallbacks(db, onConflict: conflictResolution)
            saved = PersistenceSuccess(inserted)
            return saved!
        }
        
        guard let saved else {
            try persistenceCallbackMisuse("aroundSave")
        }
        didSave(saved)
    }
}

// MARK: - Insert and Fetch

extension PersistableRecord {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
    // TODO: GRDB7 make it unable to return an optional
    /// Executes an `INSERT RETURNING` statement, and returns a new record built
    /// from the inserted row.
    ///
    /// This method helps dealing with default column values and
    /// generated columns.
    ///
    /// For example:
    ///
    /// ```swift
    /// // A table with an auto-incremented primary key and a default value
    /// try dbQueue.write { db in
    ///     try db.execute(sql: """
    ///         CREATE TABLE player(
    ///           id INTEGER PRIMARY KEY AUTOINCREMENT,
    ///           name TEXT,
    ///           score INTEGER DEFAULT 1000)
    ///         """)
    /// }
    ///
    /// // A player with partial database information
    /// struct PartialPlayer: PersistableRecord {
    ///     static let databaseTableName = "player"
    ///     var name: String
    /// }
    ///
    /// // A full player, with all database information
    /// struct Player: TableRecord, FetchableRecord {
    ///     var id: Int64
    ///     var name: String
    ///     var score: Int
    /// }
    ///
    /// // Insert a partial player, get a full one
    /// try dbQueue.write { db in
    ///     let partialPlayer = PartialPlayer(name: "Alice")
    ///
    ///     // INSERT INTO player (name) VALUES ('Alice') RETURNING *
    ///     if let player = try partialPlayer.insertAndFetch(db, as: FullPlayer.self) {
    ///         print(player.id)    // The inserted id
    ///         print(player.name)  // The inserted name
    ///         print(player.score) // The default score
    ///     }
    /// }
    /// ```
    ///
    /// - parameter db: A database connection.
    /// - parameter conflictResolution: A policy for conflict resolution. If
    ///   nil, <doc:/MutablePersistableRecord/persistenceConflictPolicy-1isyv>
    ///   is used.
    /// - parameter returnedType: The type of the returned record.
    /// - returns: A record of type `returnedType`, if any. The result can be
    ///   nil when the conflict policy is `IGNORE`.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs, or any
    ///   error thrown by the persistence callbacks defined by the record type.
    @inlinable // allow specialization so that empty callbacks are removed
    public func insertAndFetch<T: FetchableRecord & TableRecord>(
        _ db: Database,
        onConflict conflictResolution: Database.ConflictResolution? = nil,
        as returnedType: T.Type)
    throws -> T?
    {
        try insertAndFetch(db, onConflict: conflictResolution, selection: T.databaseSelection) {
            try T.fetchOne($0)
        }
    }
    
    /// Executes an `INSERT RETURNING` statement, and returns the selected
    /// columns from the inserted row.
    ///
    /// This method helps dealing with default column values and
    /// generated columns.
    ///
    /// For example:
    ///
    /// ```swift
    /// // A table with an auto-incremented primary key and a default value
    /// try dbQueue.write { db in
    ///     try db.execute(sql: """
    ///         CREATE TABLE player(
    ///           id INTEGER PRIMARY KEY AUTOINCREMENT,
    ///           name TEXT,
    ///           score INTEGER DEFAULT 1000)
    ///         """)
    /// }
    ///
    /// // A player with partial database information
    /// struct PartialPlayer: PersistableRecord {
    ///     static let databaseTableName = "player"
    ///     var name: String
    /// }
    ///
    /// // Insert a partial player, get the inserted score
    /// try dbQueue.write { db in
    ///     let partialPlayer = PartialPlayer(name: "Alice")
    ///
    ///     // INSERT INTO player (name) VALUES ('Alice') RETURNING score
    ///     let score = try partialPlayer.insertAndFetch(db, selection: [Column("score")]) { statement in
    ///         try Int.fetchOne(statement)
    ///     }
    ///     print(score) // The inserted score
    /// }
    /// ```
    ///
    /// - parameter db: A database connection.
    /// - parameter conflictResolution: A policy for conflict resolution. If
    ///   nil, <doc:/MutablePersistableRecord/persistenceConflictPolicy-1isyv>
    ///   is used.
    /// - parameter selection: The returned columns (must not be empty).
    /// - parameter fetch: A closure that executes its ``Statement`` argument.
    ///   If the conflict policy is `IGNORE`, the statement may return no row.
    /// - returns: The result of the `fetch` function.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs, or any
    ///   error thrown by the persistence callbacks defined by the record type.
    /// - precondition: `selection` is not empty.
    @inlinable // allow specialization so that empty callbacks are removed
    public func insertAndFetch<T>(
        _ db: Database,
        onConflict conflictResolution: Database.ConflictResolution? = nil,
        selection: [any SQLSelectable],
        fetch: (Statement) throws -> T)
    throws -> T
    {
        GRDBPrecondition(!selection.isEmpty, "Invalid empty selection")
        
        try willSave(db)
        
        var success: (inserted: InsertionSuccess, returned: T)?
        try aroundSave(db) {
            success = try insertAndFetchWithCallbacks(
                db, onConflict: conflictResolution,
                selection: selection,
                fetch: fetch)
            return PersistenceSuccess(success!.inserted)
        }
        
        guard let success else {
            try persistenceCallbackMisuse("aroundSave")
        }
        didSave(PersistenceSuccess(success.inserted))
        return success.returned
    }
#else
    // TODO: GRDB7 make it unable to return an optional
    /// Executes an `INSERT RETURNING` statement, and returns a new record built
    /// from the inserted row.
    ///
    /// This method helps dealing with default column values and
    /// generated columns.
    ///
    /// For example:
    ///
    /// ```swift
    /// // A table with an auto-incremented primary key and a default value
    /// try dbQueue.write { db in
    ///     try db.execute(sql: """
    ///         CREATE TABLE player(
    ///           id INTEGER PRIMARY KEY AUTOINCREMENT,
    ///           name TEXT,
    ///           score INTEGER DEFAULT 1000)
    ///         """)
    /// }
    ///
    /// // A player with partial database information
    /// struct PartialPlayer: PersistableRecord {
    ///     static let databaseTableName = "player"
    ///     var name: String
    /// }
    ///
    /// // A full player, with all database information
    /// struct Player: TableRecord, FetchableRecord {
    ///     var id: Int64
    ///     var name: String
    ///     var score: Int
    /// }
    ///
    /// // Insert a partial player, get a full one
    /// try dbQueue.write { db in
    ///     let partialPlayer = PartialPlayer(name: "Alice")
    ///
    ///     // INSERT INTO player (name) VALUES ('Alice') RETURNING *
    ///     if let player = try partialPlayer.insertAndFetch(db, as: FullPlayer.self) {
    ///         print(player.id)    // The inserted id
    ///         print(player.name)  // The inserted name
    ///         print(player.score) // The default score
    ///     }
    /// }
    /// ```
    ///
    /// - parameter db: A database connection.
    /// - parameter conflictResolution: A policy for conflict resolution. If
    ///   nil, <doc:/MutablePersistableRecord/persistenceConflictPolicy-1isyv>
    ///   is used.
    /// - parameter returnedType: The type of the returned record.
    /// - returns: A record of type `returnedType`, if any. The result can be
    ///   nil when the conflict policy is `IGNORE`.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs, or any
    ///   error thrown by the persistence callbacks defined by the record type.
    @inlinable // allow specialization so that empty callbacks are removed
    @available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) // SQLite 3.35.0+
    public func insertAndFetch<T: FetchableRecord & TableRecord>(
        _ db: Database,
        onConflict conflictResolution: Database.ConflictResolution? = nil,
        as returnedType: T.Type)
    throws -> T?
    {
        try insertAndFetch(db, onConflict: conflictResolution, selection: T.databaseSelection) {
            try T.fetchOne($0)
        }
    }
    
    /// Executes an `INSERT RETURNING` statement, and returns the selected
    /// columns from the inserted row.
    ///
    /// This method helps dealing with default column values and
    /// generated columns.
    ///
    /// For example:
    ///
    /// ```swift
    /// // A table with an auto-incremented primary key and a default value
    /// try dbQueue.write { db in
    ///     try db.execute(sql: """
    ///         CREATE TABLE player(
    ///           id INTEGER PRIMARY KEY AUTOINCREMENT,
    ///           name TEXT,
    ///           score INTEGER DEFAULT 1000)
    ///         """)
    /// }
    ///
    /// // A player with partial database information
    /// struct PartialPlayer: PersistableRecord {
    ///     static let databaseTableName = "player"
    ///     var name: String
    /// }
    ///
    /// // Insert a partial player, get the inserted score
    /// try dbQueue.write { db in
    ///     let partialPlayer = PartialPlayer(name: "Alice")
    ///
    ///     // INSERT INTO player (name) VALUES ('Alice') RETURNING score
    ///     let score = try partialPlayer.insertAndFetch(db, selection: [Column("score")]) { statement in
    ///         try Int.fetchOne(statement)
    ///     }
    ///     print(score) // The inserted score
    /// }
    /// ```
    ///
    /// - parameter db: A database connection.
    /// - parameter conflictResolution: A policy for conflict resolution. If
    ///   nil, <doc:/MutablePersistableRecord/persistenceConflictPolicy-1isyv>
    ///   is used.
    /// - parameter selection: The returned columns (must not be empty).
    /// - parameter fetch: A closure that executes its ``Statement`` argument.
    ///   If the conflict policy is `IGNORE`, the statement may return no row.
    /// - returns: The result of the `fetch` function.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs, or any
    ///   error thrown by the persistence callbacks defined by the record type.
    /// - precondition: `selection` is not empty.
    @inlinable // allow specialization so that empty callbacks are removed
    @available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) // SQLite 3.35.0+
    public func insertAndFetch<T>(
        _ db: Database,
        onConflict conflictResolution: Database.ConflictResolution? = nil,
        selection: [any SQLSelectable],
        fetch: (Statement) throws -> T)
    throws -> T
    {
        GRDBPrecondition(!selection.isEmpty, "Invalid empty selection")
        
        try willSave(db)
        
        var success: (inserted: InsertionSuccess, returned: T)?
        try aroundSave(db) {
            success = try insertAndFetchWithCallbacks(
                db, onConflict: conflictResolution,
                selection: selection,
                fetch: fetch)
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

// MARK: - Internals

extension PersistableRecord {
    /// Executes an `INSERT` statement, and runs insertion callbacks.
    @inlinable // allow specialization so that empty callbacks are removed
    func insertWithCallbacks(
        _ db: Database,
        onConflict conflictResolution: Database.ConflictResolution?)
    throws -> InsertionSuccess
    {
        let (inserted, _) = try insertAndFetchWithCallbacks(db, onConflict: conflictResolution, selection: []) {
            // Nothing to fetch
            try $0.execute()
        }
        return inserted
    }
    
    /// Executes an `INSERT` statement, with `RETURNING` clause if `selection`
    /// is not empty, and runs insertion callbacks.
    @inlinable // allow specialization so that empty callbacks are removed
    func insertAndFetchWithCallbacks<T>(
        _ db: Database,
        onConflict conflictResolution: Database.ConflictResolution?,
        selection: [any SQLSelectable],
        fetch: (Statement) throws -> T)
    throws -> (InsertionSuccess, T)
    {
        try willInsert(db)
        
        var success: (inserted: InsertionSuccess, returned: T)?
        try aroundInsert(db) {
            success = try insertAndFetchWithoutCallbacks(
                db, onConflict: conflictResolution,
                selection: selection,
                fetch: fetch)
            return success!.inserted
        }
        
        guard let success else {
            try persistenceCallbackMisuse("aroundInsert")
        }
        didInsert(success.inserted)
        return success
    }
}
