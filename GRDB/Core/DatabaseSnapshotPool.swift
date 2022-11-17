// swiftlint:disable:next line_length
#if (compiler(<5.7.1) && (os(macOS) || targetEnvironment(macCatalyst))) || GRDBCIPHER || (GRDBCUSTOMSQLITE && !SQLITE_ENABLE_SNAPSHOT)
#else
// Sharing connections with DatabasePool creates a problem with reentrant access.
// If we create a new pool of connections, we avoid this problem. And we can
// simplify the management of shared cache (drop all cache-merging code)

#warning("TODO: restore or don't reuse connections that have lost their transaction")
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
/// It creates a pool of up to ``Configuration/maximumReaderCount`` read-only
/// SQLite connections. All read accesses are executed in **reader dispatch
/// queues** (one per read-only SQLite connection). SQLite connections are
/// closed when the `DatabasePool` is deallocated.
///
/// An SQLite database in the [WAL mode](https://www.sqlite.org/wal.html) is
/// required for creating a `DatabaseSnapshotPool`.
///
/// ## Usage
///
/// You create a `DatabaseSnapshotPool` from a
/// [WAL mode](https://www.sqlite.org/wal.html) database, such as databases
/// created from a ``DatabasePool``:
///
/// ```swift
/// let dbPool = try DatabasePool(path: "/path/to/database.sqlite")
/// let snapshot = try dbPool.makeSnapshotPool()
/// ```
///
/// When you want to control the database state seen by a snapshot, create the
/// snapshot from a database connection, outside of a write transaction. You can
/// for example take snapshots from a ``ValueObservation``:
///
/// ```swift
/// // An observation of the 'player' table
/// // that notifies fresh database snapshots:
/// let observation = ValueObservation.tracking { db in
///     // Don't fetch players now, and return a snapshot instead.
///     // Register an access to the player table so that the
///     // observation tracks changes to this table.
///     try db.registerAccess(to: Player.all())
///     return try DatabaseSnapshotPool(db)
/// }
///
/// // Start observing the 'player' table
/// let cancellable = try observation.start(in: dbPool) { error in
///     // Handle error
/// } onChange: { (snapshot: DatabaseSnapshotPool) in
///     // Handle a fresh snapshot
/// }
/// ```
///
/// `DatabaseSnapshotPool` inherits its database access methods from the
/// ``DatabaseReader`` protocols.
///
/// Related SQLite documentation:
///
/// - <https://www.sqlite.org/c3ref/snapshot_get.html>
/// - <https://www.sqlite.org/c3ref/snapshot_open.html>
///
/// ## Topics
///
/// ### Creating a DatabaseSnapshotPool
///
/// See also ``DatabasePool/makeSnapshotPool()``.
///
/// - ``init(_:configuration:)``
/// - ``init(path:configuration:)``
public final class DatabaseSnapshotPool {
    public let configuration: Configuration
    
    /// The path to the database file.
    public let path: String
    
    /// The pool of reader connections.
    /// It is constant, until close() sets it to nil.
    private var readerPool: Pool<SerializedDatabase>?
    
    /// Creates a snapshot of the database.
    ///
    /// For example:
    ///
    /// ```swift
    /// let dbPool = try DatabasePool(path: "/path/to/database.sqlite")
    /// let snapshot = try dbPool.writeWithoutTransaction { db -> DatabaseSnapshotPool in
    ///     try db.inTransaction {
    ///         try Player.deleteAll()
    ///         return .commit
    ///     }
    ///
    ///     // Create the snapshot after all players have been deleted.
    ///     return DatabaseSnapshotPool(db)
    /// }
    ///
    /// // Later... Maybe some players have been created.
    /// // The snapshot is guaranteed to see an empty table of players, though:
    /// let count = try snapshot.read(Player.fetchCount)
    /// assert(count == 0)
    /// ```
    ///
    /// If any of the following statements are false when the snapshot is
    /// created, a ``DatabaseError`` of code `SQLITE_ERROR` is thrown:
    ///
    /// - The database connection must be in the
    ///   [WAL mode](https://www.sqlite.org/wal.html).
    /// - There must not be a write transaction open.
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/c3ref/snapshot_get.html>
    ///
    /// - parameter db: A database connection.
    /// - parameter configuration: A configuration. If nil, the configuration of
    ///   `db` is used.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public init(_ db: Database, configuration: Configuration? = nil) throws {
        var configuration = DatabasePool.readerConfiguration(configuration ?? db.configuration)
        
        // Snapshot keeps a long-lived transaction
        configuration.allowsUnsafeTransactions = true
        
        GRDBPrecondition(configuration.maximumReaderCount > 0, "configuration.maximumReaderCount must be at least 1")
        
        var walSnapshot: WALSnapshot?
        configuration.prepareDatabase { db in
            // Open transaction
            try db.beginTransaction(.deferred)
            
            // Acquire snapshot isolation
            try db.execute(sql: "SELECT rootpage FROM sqlite_master LIMIT 1")
            
            // Open snapshot
            let code = sqlite3_snapshot_open(db.sqliteConnection, "main", walSnapshot!.sqliteSnapshot)
            guard code == SQLITE_OK else {
                throw DatabaseError(resultCode: code)
            }
        }
        
        self.configuration = configuration
        self.path = db.path
        
        var readerCount = 0
        readerPool = Pool(
            maximumCount: configuration.maximumReaderCount,
            qos: configuration.readQoS,
            makeElement: {
                readerCount += 1 // protected by Pool (TODO: document this protection behavior)
                return try SerializedDatabase(
                    path: db.path,
                    configuration: configuration,
                    defaultLabel: "GRDB.DatabaseSnapshotPool",
                    purpose: "snapshot.\(readerCount)")
            })
        
        // Get WAL snapshot
        walSnapshot = try db.isolated(readOnly: true) {
            try WALSnapshot(db)
        }
        
        // Create first connection that will keep the WALSnapshot alive.
        try readerPool!.get { _ in }
    }
    
    /// Creates a snapshot of the database.
    ///
    /// For example:
    ///
    /// ```swift
    /// let snapshot = try DatabaseSnapshotPool(path: "/path/to/database.sqlite")
    /// ```
    ///
    /// If the database at `path` is not in the
    /// [WAL mode](https://www.sqlite.org/wal.html), a ``DatabaseError`` of code
    /// `SQLITE_ERROR` is thrown.
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/c3ref/snapshot_get.html>
    ///
    /// - parameters:
    ///     - path: The path to the database file.
    ///     - configuration: A configuration.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public init(path: String, configuration: Configuration = Configuration()) throws {
        var configuration = DatabasePool.readerConfiguration(configuration)
        GRDBPrecondition(configuration.maximumReaderCount > 0, "configuration.maximumReaderCount must be at least 1")
        
        // Snapshot keeps a long-lived transaction
        configuration.allowsUnsafeTransactions = true
        
        var walSnapshot: WALSnapshot?
        configuration.prepareDatabase { db in
            // Open transaction
            try db.beginTransaction(.deferred)
            
            // Acquire snapshot isolation
            try db.execute(sql: "SELECT rootpage FROM sqlite_master LIMIT 1")
            
            // Open snapshot
            if let walSnapshot { // nil on first connection created below
                let code = sqlite3_snapshot_open(db.sqliteConnection, "main", walSnapshot.sqliteSnapshot)
                guard code == SQLITE_OK else {
                    throw DatabaseError(resultCode: code)
                }
            }
        }
        
        self.configuration = configuration
        self.path = path
        
        var readerCount = 0
        readerPool = Pool(
            maximumCount: configuration.maximumReaderCount,
            qos: configuration.readQoS,
            makeElement: {
                readerCount += 1 // protected by Pool (TODO: document this protection behavior)
                return try SerializedDatabase(
                    path: path,
                    configuration: configuration,
                    defaultLabel: "GRDB.DatabaseSnapshotPool",
                    purpose: "snapshot.\(readerCount)")
            })
        
        walSnapshot = try readerPool!.get { reader in
            try reader.sync { db in
                try WALSnapshot(db)
            }
        }
    }
}

extension DatabaseSnapshotPool: @unchecked Sendable { }

extension DatabaseSnapshotPool: DatabaseSnapshotReader {
    public func close() throws {
        try readerPool?.barrier {
            defer { readerPool = nil }
            
            try readerPool?.forEach { reader in
                try reader.sync { try $0.close() }
            }
        }
    }
    
    public func interrupt() {
        readerPool?.forEach { $0.interrupt() }
    }
    
    @_disfavoredOverload // SR-15150 Async overloading in protocol implementation fails
    public func read<T>(_ value: (Database) throws -> T) throws -> T {
        GRDBPrecondition(currentReader == nil, "Database methods are not reentrant.")
        guard let readerPool else {
            throw DatabaseError.connectionIsClosed()
        }
        return try readerPool.get { reader in
            try reader.sync { db in
                return try value(db)
            }
        }
    }
    
    public func unsafeRead<T>(_ value: (Database) throws -> T) throws -> T {
        /// There is no unsafe access to a snapshot.
        try read(value)
    }
    
    public func asyncRead(_ value: @escaping (Result<Database, Error>) -> Void) {
        guard let readerPool else {
            value(.failure(DatabaseError(resultCode: .SQLITE_MISUSE, message: "Connection is closed")))
            return
        }
        
        readerPool.asyncGet { result in
            do {
                let (reader, releaseReader) = try result.get()
                // Second async jump because that's how `Pool.async` has to be used.
                reader.async { db in
                    value(.success(db))
                    releaseReader()
                }
            } catch {
                value(.failure(error))
            }
        }
    }
    
    public func asyncUnsafeRead(_ value: @escaping (Result<Database, Error>) -> Void) {
        /// There is no unsafe access to a snapshot.
        asyncRead(value)
    }
    
    public func unsafeReentrantRead<T>(_ value: (Database) throws -> T) throws -> T {
        if let reader = currentReader {
            return try reader.reentrantSync(value)
        } else {
            guard let readerPool else {
                throw DatabaseError.connectionIsClosed()
            }
            return try readerPool.get { reader in
                try reader.sync { db in
                    return try value(db)
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
    
    /// Returns a reader that can be used from the current dispatch queue,
    /// if any.
    private var currentReader: SerializedDatabase? {
        guard let readerPool else {
            return nil
        }
        
        var readers: [SerializedDatabase] = []
        readerPool.forEach { reader in
            // We can't check for reader.onValidQueue here because
            // Pool.forEach() runs its closure argument in some arbitrary
            // dispatch queue. We thus extract the reader so that we can query
            // it below.
            readers.append(reader)
        }
        
        // Now the readers array contains some readers. The pool readers may
        // already be different, because some other thread may have started
        // a new read, for example.
        //
        // This doesn't matter: the reader we are looking for is already on
        // its own dispatch queue. If it exists, is still in use, thus still
        // in the pool, and thus still relevant for our check:
        return readers.first { $0.onValidQueue }
    }
}
#endif
