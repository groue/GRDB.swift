import Dispatch

/// A database connection that serializes accesses to an unchanging
/// database content, as it existed at the moment the snapshot was created.
///
/// ## Overview
///
/// A `DatabaseSnapshot` never sees any database modification during all its
/// lifetime. All database accesses performed from a snapshot always see the
/// same identical database content.
///
/// A snapshot creates one single SQLite connection. All database
/// accesses are executed in a serial **reader dispatch queue**. The SQLite
/// connection is closed when the `DatabaseSnapshot` is deallocated.
///
/// A snapshot created on a [WAL](https://sqlite.org/wal.html) database doesn't
/// prevent database modifications performed by other connections (but it won't
/// see them). Refer to [Isolation In SQLite](https://sqlite.org/isolation.html)
/// for more information.
///
/// On non-WAL databases, a snapshot prevents all database modifications as long
/// as it exists, because of the
/// [SHARED lock](https://www.sqlite.org/lockingv3.html) it holds.
///
/// ## Usage
///
/// You create instances of `DatabaseSnapshot` from a ``DatabasePool``,
/// with ``DatabasePool/makeSnapshot()``:
///
/// ```swift
/// let dbPool = try DatabasePool(path: "/path/to/database.sqlite")
/// let snapshot = try dbPool.makeSnapshot()
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
///     return try dbPool.makeSnapshot()
/// }
///
/// // <- Other threads may have created some players here
/// let snapshot2 = try dbPool.makeSnapshot()
///
/// // Guaranteed to be zero
/// let count1 = try snapshot1.read(Player.fetchCount)
///
/// // Could be anything
/// let count2 = try snapshot2.read(Player.fetchCount)
/// ```
///
/// `DatabaseSnapshot` inherits its database access methods from the
/// ``DatabaseReader`` protocols.
///
/// `DatabaseSnapshot` serializes database accesses and can't perform concurrent
/// reads. For concurrent reads, see ``DatabaseSnapshotPool``.
public final class DatabaseSnapshot {
    private let reader: SerializedDatabase
    
    public var configuration: Configuration {
        reader.configuration
    }
    
    /// The path to the database file.
    public var path: String {
        reader.path
    }
    
    init(
        path: String,
        configuration: Configuration,
        defaultLabel: String = "GRDB.DatabaseSnapshot",
        purpose: String? = nil)
    throws
    {
        let configuration = Self.configure(configuration)
        
        reader = try SerializedDatabase(
            path: path,
            configuration: configuration,
            defaultLabel: defaultLabel,
            purpose: purpose)
        
        try reader.sync { db in
            // Open transaction
            try db.beginTransaction(.deferred)
            
            // Acquire snapshot isolation
            try db.execute(sql: "SELECT rootpage FROM sqlite_master LIMIT 1")
        }
    }
    
    deinit {
        // Leave snapshot isolation
        reader.reentrantSync { db in
            try? db.commit()
        }
    }
    
    private static func configure(_ configuration: Configuration) -> Configuration {
        var configuration = configuration
        
        // DatabaseSnapshot can't perform parallel reads.
        configuration.maximumReaderCount = 1

        // DatabaseSnapshot is read-only.
        configuration.readonly = true
        
        // DatabaseSnapshot uses deferred transactions by default.
        // Other transaction kinds are forbidden by SQLite in read-only connections.
        configuration.defaultTransactionKind = .deferred
        
        // DatabaseSnapshot keeps a long-lived transaction.
        configuration.allowsUnsafeTransactions = true
        
        return configuration
    }
}

extension DatabaseSnapshot: DatabaseSnapshotReader {
    public func close() throws {
        try reader.sync { try $0.close() }
    }
    
    // MARK: - Interrupting Database Operations
    
    public func interrupt() {
        reader.interrupt()
    }
    
    // MARK: - Reading from Database
    
    public func read<T>(_ block: (Database) throws -> T) rethrows -> T {
        try reader.sync(block)
    }
    
    public func asyncRead(_ value: @escaping (Result<Database, Error>) -> Void) {
        reader.async { value(.success($0)) }
    }
    
    public func unsafeRead<T>(_ value: (Database) throws -> T) rethrows -> T {
        try reader.sync(value)
    }
    
    public func asyncUnsafeRead(_ value: @escaping (Result<Database, Error>) -> Void) {
        reader.async { value(.success($0)) }
    }
    
    public func unsafeReentrantRead<T>(_ value: (Database) throws -> T) throws -> T {
        try reader.reentrantSync(value)
    }
    
    // MARK: - Database Observation
    
    public func _add<Reducer: ValueReducer>(
        observation: ValueObservation<Reducer>,
        scheduling scheduler: some ValueObservationScheduler,
        onChange: @escaping (Reducer.Value) -> Void)
    -> AnyDatabaseCancellable
    {
        _addReadOnly(
            observation: observation,
            scheduling: scheduler,
            onChange: onChange)
    }
}
