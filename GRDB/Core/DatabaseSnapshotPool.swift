// swiftlint:disable:next line_length
#if (compiler(<5.7.1) && (os(macOS) || targetEnvironment(macCatalyst))) || GRDBCIPHER || (GRDBCUSTOMSQLITE && !SQLITE_ENABLE_SNAPSHOT)
#else

/// A database connection that allows concurrent accesses to an unchanging
/// database content, as it existed at the moment the snapshot was created.
///
/// ## Overview
///
/// - note: [**🔥 EXPERIMENTAL**](https://github.com/groue/GRDB.swift/blob/master/README.md#what-are-experimental-features)
///
/// A `DatabaseSnapshotPool` never sees any database modification during all its
/// lifetime. All database accesses performed from a snapshot always see the
/// same identical database content.
///
/// A `DatabaseSnapshotPool` instance shares the same pool of reader SQLite
/// connections as a ``DatabasePool``. It requires an SQLite database in the
/// [WAL mode](https://www.sqlite.org/wal.html).
///
/// ## Usage
///
/// You create a `DatabaseSnapshotPool` from a ``DatabasePool``,
/// with ``DatabasePool/makeSnapshotPool()``:
///
/// ```swift
/// let dbPool = try DatabasePool(path: "/path/to/database.sqlite")
/// let snapshot = try dbPool.makeSnapshotPool()
/// let playerCount = try snapshot.read { db in
///     try Player.fetchCount(db)
/// }
/// ```
///
/// When you want to control the database state seen by a snapshot, create the
/// snapshot from within a write access, outside of any transaction.
///
/// For example, compare the two snapshots below. The first one is guaranteed to
/// see an empty table of players, because is is created after all players have
/// been deleted, and from the serialized writer dispatch queue which prevents
/// any concurrent write. The second is created without this concurrency
/// protection, which means that some other threads may already have created
/// some players:
///
/// ```swift
/// let snapshot1 = try dbPool.writeWithoutTransaction { db -> DatabaseSnapshot in
///     try db.inTransaction {
///         try Player.deleteAll()
///         return .commit
///     }
///
///     return dbPool.makeSnapshotPool()
/// }
///
/// // <- Other threads may have created some players here
/// let snapshot2 = try dbPool.makeSnapshotPool()
///
/// // Guaranteed to be zero
/// let count1 = try snapshot1.read(Player.fetchCount)
///
/// // Could be anything
/// let count2 = try snapshot2.read(Player.fetchCount)
/// ```
///
/// `DatabaseSnapshotPool` inherits its database access methods from the
/// ``DatabaseReader`` protocols.
///
/// Related SQLite documentation:
///
/// - <https://www.sqlite.org/c3ref/snapshot_get.html>
/// - <https://www.sqlite.org/c3ref/snapshot_open.html>
public final class DatabaseSnapshotPool {
    /// The DatabasePool that provides reader connections.
    let dbPool: DatabasePool
    
    /// The connection that holds a transaction and prevents checkpointing in
    /// order to keep `walSnapshot` valid.
    let dbSnapshot: DatabaseSnapshot
    
    /// The WAL snapshot
    let walSnapshot: WALSnapshot
    
    /// The version of the schema cache.
    let schemaVersion: Int32
    
    // Protected by a lock because the cache can be used by multiple
    // database connections.
    @LockedBox var schemaCache: Database.SchemaCache
    
    init(
        dbPool: DatabasePool,
        dbSnapshot: DatabaseSnapshot,
        walSnapshot: WALSnapshot,
        schemaVersion: Int32,
        schemaCache: Database.SchemaCache)
    {
        self.dbPool = dbPool
        self.dbSnapshot = dbSnapshot
        self.walSnapshot = walSnapshot
        self.schemaVersion = schemaVersion
        self.schemaCache = schemaCache
    }
}

extension DatabaseSnapshotPool: @unchecked Sendable { }

extension DatabaseSnapshotPool: DatabaseReader {
    public var configuration: Configuration {
        DatabasePool.readerConfiguration(dbPool.configuration)
    }
    
    /// Throws a ``DatabaseError`` of code `SQLITE_MISUSE`. Close the source
    /// ``DatabasePool`` instead.
    public func close() throws {
        throw DatabaseError(resultCode: .SQLITE_MISUSE, message: "")
    }
    
    public func interrupt() {
        dbPool.interrupt()
    }
    
    public func read<T>(_ value: (Database) throws -> T) throws -> T {
        try dbPool.read { db in
            try db.read(from: self) {
                try value(db)
            }
        }
    }
    
    public func unsafeRead<T>(_ value: (Database) throws -> T) throws -> T {
        /// There is no unsafe access to a snapshot.
        try read(value)
    }
    
    public func asyncRead(_ value: @escaping (Result<Database, Error>) -> Void) {
        dbPool.asyncRead { dbResult in
            do {
                let db = try dbResult.get()
                try db.read(from: self) {
                    value(.success(db))
                }
            } catch {
                value(.failure(error))
            }
        }
    }
    
    public func asyncUnsafeRead(_ value: @escaping (Result<Database, Error>) -> Void) {
        /// There is no unsafe access to a snapshot.
        dbPool.asyncRead(value)
    }
    
    public func unsafeReentrantRead<T>(_ value: (Database) throws -> T) throws -> T {
        try dbPool.unsafeReentrantRead { db in
            try db.isolated {
                try db.read(from: self) {
                    try value(db)
                }
            }
        }
    }
    
    public func _add<Reducer>(
        observation: ValueObservation<Reducer>,
        scheduling scheduler: ValueObservationScheduler,
        onChange: @escaping (Reducer.Value) -> Void)
    -> AnyDatabaseCancellable where Reducer: ValueReducer
    {
        _addReadOnly(observation: observation, scheduling: scheduler, onChange: onChange)
    }
}

extension DatabasePool {
    /// Creates a database snapshot that uses the reader connections of
    /// the pool.
    ///
    /// - note: [**🔥 EXPERIMENTAL**](https://github.com/groue/GRDB.swift/blob/master/README.md#what-are-experimental-features)
    ///
    /// The returned snapshot sees an unchanging database content, as it existed
    /// at the moment it was created. It shares the same reader SQLite
    /// connections as the `DatabasePool`.
    ///
    /// An error is thrown unless the SQLite database is in the
    /// [WAL mode](https://www.sqlite.org/wal.html).
    ///
    /// It is a programmer error to create a snapshot from the writer dispatch
    /// queue when a transaction is opened:
    ///
    /// ```swift
    /// try dbPool.write { db in
    ///     try Player.deleteAll()
    ///
    ///     // fatal error: makeSnapshot() must not be called from inside a transaction
    ///     let snapshot = try dbPool.makeSnapshot()
    /// }
    /// ```
    ///
    /// To avoid this fatal error, create the snapshot *before* or *after*
    /// the transaction:
    ///
    /// ```swift
    /// let snapshot = try dbPool.makeSnapshot() // OK
    ///
    /// try dbPool.writeWithoutTransaction { db in
    ///     let snapshot = try dbPool.makeSnapshot() // OK
    ///
    ///     try db.inTransaction {
    ///         try Player.deleteAll()
    ///         return .commit
    ///     }
    ///
    ///     // OK
    ///     let snapshot = try dbPool.makeSnapshot() // OK
    /// }
    ///
    /// let snapshot = try dbPool.makeSnapshot() // OK
    /// ```
    public func makeSnapshotPool() throws -> DatabaseSnapshotPool {
        let dbSnapshot = try makeSnapshot()
        return try dbSnapshot.read { db in
            try DatabaseSnapshotPool(
                dbPool: self,
                dbSnapshot: dbSnapshot,
                walSnapshot: WALSnapshot(db),
                schemaVersion: db.schemaVersion(),
                schemaCache: db.schemaCache)
        }
    }
}

extension Database {
    fileprivate func open(_ snapshot: DatabaseSnapshotPool) throws {
        let code = sqlite3_snapshot_open(sqliteConnection, "main", snapshot.walSnapshot.sqliteSnapshot)
        guard code == SQLITE_OK else {
            throw DatabaseError(resultCode: code)
        }
        lastSchemaVersion = snapshot.schemaVersion
        schemaCache = snapshot.schemaCache
    }
    
    fileprivate func read<T>(from snapshot: DatabaseSnapshotPool, _ value: () throws -> T) throws -> T {
        try open(snapshot)
        defer {
            snapshot.$schemaCache.update { $0.formUnion(schemaCache) }
        }
        
        return try value()
    }
}
#endif
