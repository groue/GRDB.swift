import Dispatch

/// A DatabaseSnapshot sees an unchanging database content, as it existed at the
/// moment it was created.
///
/// See DatabasePool.makeSnapshot()
///
/// For more information, read about "snapshot isolation" at https://sqlite.org/isolation.html
public class DatabaseSnapshot: DatabaseReader {
    private var serializedDatabase: SerializedDatabase
    
    /// The database configuration
    public var configuration: Configuration {
        serializedDatabase.configuration
    }
    
    /// Not nil iff SQLite was compiled with `SQLITE_ENABLE_SNAPSHOT`.
    private(set) var version: UnsafeMutablePointer<sqlite3_snapshot>?
    
    init(path: String, configuration: Configuration = Configuration(), defaultLabel: String, purpose: String) throws {
        var configuration = configuration
        configuration.readonly = true
        configuration.allowsUnsafeTransactions = true // Snaphost keeps a long-lived transaction

        // https://www.sqlite.org/wal.html#sometimes_queries_return_sqlite_busy_in_wal_mode
        // > But there are some obscure cases where a query against a WAL-mode
        // > database can return SQLITE_BUSY, so applications should be prepared
        // > for that happenstance.
        // >
        // > - If another database connection has the database mode open in
        // >   exclusive locking mode [...]
        // > - When the last connection to a particular database is closing,
        // >   that connection will acquire an exclusive lock for a short time
        // >   while it cleans up the WAL and shared-memory files [...]
        // > - If the last connection to a database crashed, then the first new
        // >   connection to open the database will start a recovery process. An
        // >   exclusive lock is held during recovery. [...]
        //
        // The whole point of WAL readers is to avoid SQLITE_BUSY, so let's
        // setup a busy handler for pool readers, in order to workaround those
        // "obscure cases" that may happen when the database is shared between
        // multiple processes.
        if configuration.readonlyBusyMode == nil {
            configuration.readonlyBusyMode = .timeout(10)
        }

        serializedDatabase = try SerializedDatabase(
            path: path,
            configuration: configuration,
            schemaCache: DatabaseSchemaCache(),
            defaultLabel: defaultLabel,
            purpose: purpose)
        
        try serializedDatabase.sync { db in
            // Assert WAL mode
            let journalMode = try String.fetchOne(db, sql: "PRAGMA journal_mode")
            guard journalMode == "wal" else {
                throw DatabaseError(message: "WAL mode is not activated at path: \(path)")
            }
            try db.beginSnapshotTransaction()
            version = try? db.takeVersionSnapshot()
        }
    }
    
    deinit {
        // Leave snapshot isolation
        serializedDatabase.reentrantSync { db in
            if let version = version {
                grdb_snapshot_free(version)
            }
            try? db.commit()
        }
    }
}

// DatabaseReader
extension DatabaseSnapshot {
    
    // MARK: - Interrupting Database Operations
    
    public func interrupt() {
        serializedDatabase.interrupt()
    }
    
    // MARK: - Reading from Database
    
    /// Synchronously executes a read-only block that takes a database
    /// connection, and returns its result.
    ///
    ///     let players = try snapshot.read { db in
    ///         try Player.fetchAll(...)
    ///     }
    ///
    /// - parameter block: A block that accesses the database.
    /// - throws: The error thrown by the block.
    public func read<T>(_ block: (Database) throws -> T) rethrows -> T {
        try serializedDatabase.sync(block)
    }
    
    /// Asynchronously executes a read-only block in a protected dispatch queue.
    ///
    ///     let players = try snapshot.asyncRead { dbResult in
    ///         do {
    ///             let db = try dbResult.get()
    ///             let count = try Player.fetchCount(db)
    ///         } catch {
    ///             // Handle error
    ///         }
    ///     }
    ///
    /// - parameter block: A block that accesses the database.
    public func asyncRead(_ block: @escaping (Result<Database, Error>) -> Void) {
        serializedDatabase.async { block(.success($0)) }
    }
    
    /// :nodoc:
    public func _weakAsyncRead(_ block: @escaping (Result<Database, Error>?) -> Void) {
        serializedDatabase.weakAsync { block($0.map { .success($0) }) }
    }
    
    /// :nodoc:
    public func unsafeRead<T>(_ block: (Database) throws -> T) rethrows -> T {
        try serializedDatabase.sync(block)
    }
    
    /// :nodoc:
    public func unsafeReentrantRead<T>(_ block: (Database) throws -> T) throws -> T {
        try serializedDatabase.reentrantSync(block)
    }
    
    // MARK: - Functions
    
    public func add(function: DatabaseFunction) {
        serializedDatabase.sync { $0.add(function: function) }
    }
    
    public func remove(function: DatabaseFunction) {
        serializedDatabase.sync { $0.remove(function: function) }
    }
    
    // MARK: - Collations
    
    public func add(collation: DatabaseCollation) {
        serializedDatabase.sync { $0.add(collation: collation) }
    }
    
    public func remove(collation: DatabaseCollation) {
        serializedDatabase.sync { $0.remove(collation: collation) }
    }
    
    // MARK: - Database Observation
    
    /// :nodoc:
    public func _add<Reducer: _ValueReducer>(
        observation: ValueObservation<Reducer>,
        scheduling scheduler: ValueObservationScheduler,
        onChange: @escaping (Reducer.Value) -> Void)
        -> DatabaseCancellable
    {
        _addReadOnly(
            observation: observation,
            scheduling: scheduler,
            onChange: onChange)
    }
}
