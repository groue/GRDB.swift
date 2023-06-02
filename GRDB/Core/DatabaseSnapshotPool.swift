// swiftlint:disable:next line_length
#if SQLITE_ENABLE_SNAPSHOT || (!GRDBCUSTOMSQLITE && !GRDBCIPHER && (compiler(>=5.7.1) || !(os(macOS) || targetEnvironment(macCatalyst))))
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
    
    /// The WAL snapshot
    private let walSnapshot: WALSnapshot
    
    /// A connection that prevents checkpoints and keeps the WAL snapshot valid.
    /// It is never used.
    private let snapshotHolder: DatabaseQueue
    
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
    /// A ``DatabaseError`` of code `SQLITE_ERROR` is thrown if the SQLite
    /// database is not in the [WAL mode](https://www.sqlite.org/wal.html),
    /// or if this method is called from a write transaction, or if the
    /// wal file is missing or truncated (size zero).
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/c3ref/snapshot_get.html>
    ///
    /// - parameter db: A database connection.
    /// - parameter configuration: A configuration. If nil, the configuration of
    ///   `db` is used.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public init(_ db: Database, configuration: Configuration? = nil) throws {
        var configuration = Self.configure(configuration ?? db.configuration)
        
        // Acquire and hold WAL snapshot
        let walSnapshot = try db.isolated(readOnly: true) {
            try WALSnapshot(db)
        }
        var holderConfig = Configuration()
        holderConfig.allowsUnsafeTransactions = true
        snapshotHolder = try DatabaseQueue(path: db.path, configuration: holderConfig)
        try snapshotHolder.inDatabase { db in
            try db.beginTransaction(.deferred)
            try db.execute(sql: "SELECT rootpage FROM sqlite_master LIMIT 1")
            let code = sqlite3_snapshot_open(db.sqliteConnection, "main", walSnapshot.sqliteSnapshot)
            guard code == SQLITE_OK else {
                throw DatabaseError(resultCode: code)
            }
        }
        
        configuration.prepareDatabase { db in
            try db.beginTransaction(.deferred)
            try db.execute(sql: "SELECT rootpage FROM sqlite_master LIMIT 1")
            let code = sqlite3_snapshot_open(db.sqliteConnection, "main", walSnapshot.sqliteSnapshot)
            guard code == SQLITE_OK else {
                throw DatabaseError(resultCode: code)
            }
        }
        
        self.configuration = configuration
        self.path = db.path
        self.walSnapshot = walSnapshot
        
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
    }
    
    /// Creates a snapshot of the database.
    ///
    /// For example:
    ///
    /// ```swift
    /// let snapshot = try DatabaseSnapshotPool(path: "/path/to/database.sqlite")
    /// ```
    ///
    /// A ``DatabaseError`` of code `SQLITE_ERROR` is thrown if the SQLite
    /// database is not in the [WAL mode](https://www.sqlite.org/wal.html),
    /// or if the wal file is missing or truncated (size zero).
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/c3ref/snapshot_get.html>
    ///
    /// - parameters:
    ///     - path: The path to the database file.
    ///     - configuration: A configuration.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public init(path: String, configuration: Configuration = Configuration()) throws {
        var configuration = Self.configure(configuration)
        
        // Acquire and hold WAL snapshot
        var holderConfig = Configuration()
        holderConfig.allowsUnsafeTransactions = true
        snapshotHolder = try DatabaseQueue(path: path, configuration: holderConfig)
        let walSnapshot = try snapshotHolder.inDatabase { db in
            try db.beginTransaction(.deferred)
            try db.execute(sql: "SELECT rootpage FROM sqlite_master LIMIT 1")
            return try WALSnapshot(db)
        }
        
        configuration.prepareDatabase { db in
            try db.beginTransaction(.deferred)
            try db.execute(sql: "SELECT rootpage FROM sqlite_master LIMIT 1")
            let code = sqlite3_snapshot_open(db.sqliteConnection, "main", walSnapshot.sqliteSnapshot)
            guard code == SQLITE_OK else {
                throw DatabaseError(resultCode: code)
            }
        }
        
        self.configuration = configuration
        self.path = path
        self.walSnapshot = walSnapshot
        
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
    }
    
    private static func configure(_ configuration: Configuration) -> Configuration {
        var configuration = configuration
        
        // DatabaseSnapshotPool needs a non-empty pool of connections.
        GRDBPrecondition(configuration.maximumReaderCount > 0, "configuration.maximumReaderCount must be at least 1")
        
        // DatabaseSnapshotPool is read-only.
        configuration.readonly = true
        
        // DatabaseSnapshotPool uses deferred transactions by default.
        // Other transaction kinds are forbidden by SQLite in read-only connections.
        configuration.defaultTransactionKind = .deferred
        
        // DatabaseSnapshotPool keeps a long-lived transaction.
        configuration.allowsUnsafeTransactions = true
        
        // DatabaseSnapshotPool requires the WAL mode.
        // See <https://www.sqlite.org/wal.html#sometimes_queries_return_sqlite_busy_in_wal_mode>
        if configuration.readonlyBusyMode == nil {
            configuration.readonlyBusyMode = .timeout(10)
        }
        
        return configuration
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
        
        let (reader, releaseReader) = try readerPool.get()
        var completion: PoolCompletion!
        defer {
            releaseReader(completion)
        }
        return try reader.sync { db in
            do {
                let value = try value(db)
                completion = poolCompletion(db)
                return value
            } catch {
                completion = poolCompletion(db)
                throw error
            }
        }
    }
    
    public func asyncRead(_ value: @escaping (Result<Database, Error>) -> Void) {
        guard let readerPool else {
            value(.failure(DatabaseError.connectionIsClosed()))
            return
        }
        
        readerPool.asyncGet { result in
            do {
                let (reader, releaseReader) = try result.get()
                // Second async jump because that's how `Pool.async` has to be used.
                reader.async { db in
                    value(.success(db))
                    releaseReader(self.poolCompletion(db))
                }
            } catch {
                value(.failure(error))
            }
        }
    }
    
    public func unsafeReentrantRead<T>(_ value: (Database) throws -> T) throws -> T {
        if let reader = currentReader {
            return try reader.reentrantSync { db in
                let result = try value(db)
                if snapshotIsLost(db) {
                    throw DatabaseError(resultCode: .SQLITE_ABORT, message: "Snapshot is lost.")
                }
                return result
            }
        } else {
            // There is no unsafe access to a snapshot.
            return try read(value)
        }
    }
    
    public func _add<Reducer>(
        observation: ValueObservation<Reducer>,
        scheduling scheduler: some ValueObservationScheduler,
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
    
    private func poolCompletion(_ db: Database) -> PoolCompletion {
        snapshotIsLost(db) ? .discard : .reuse
    }
    
    private func snapshotIsLost(_ db: Database) -> Bool {
        do {
            let currentSnapshot = try WALSnapshot(db)
            if currentSnapshot.compare(walSnapshot) == 0 {
                return false
            } else {
                return true
            }
        } catch {
            return true
        }
    }
}
#endif
