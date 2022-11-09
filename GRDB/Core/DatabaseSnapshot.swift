import Dispatch

/// A database connection that sees an unchanging database content, as it
/// existed at the moment it was created.
///
/// ## Overview
///
/// A `DatabaseSnapshot` creates one single SQLite connection. All database
/// accesses are executed in a serial **reader dispatch queue**. The SQLite
/// connection is closed when the `DatabaseSnapshot` is deallocated.
///
/// `DatabaseSnapshot` never sees any database modification during all its
/// lifetime, and yet it doesn't prevent database updates. This "magic" is made
/// possible by SQLite's WAL mode. See
/// [Isolation In SQLite](https://sqlite.org/isolation.html) for
/// more information.
///
/// ## Usage
///
/// You create instances of `DatabaseSnapshot` from a ``DatabasePool``, with
/// ``DatabasePool/makeSnapshot()``. The number of snapshots is unlimited,
/// regardless of the ``Configuration/maximumReaderCount`` configuration:
///
/// ```swift
/// let dbPool = try DatabasePool(path: "/path/to/database.sqlite")
/// let snapshot = try dbPool.makeSnapshot()
/// let playerCount = try snapshot.read { db in
///     try Player.fetchCount(db)
/// }
/// ```
///
/// When you want to control the database state seen by a snapshot,
/// create the snapshot from within a write access, outside of any transaction.
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
///     return dbPool.makeSnapshot()
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
public final class DatabaseSnapshot {
    private let serializedDatabase: SerializedDatabase
    
    /// The database configuration
    public var configuration: Configuration {
        serializedDatabase.configuration
    }
    
    init(path: String, configuration: Configuration = Configuration(), defaultLabel: String, purpose: String) throws {
        var configuration = DatabasePool.readerConfiguration(configuration)
        configuration.allowsUnsafeTransactions = true // Snapshot keeps a long-lived transaction
        
        serializedDatabase = try SerializedDatabase(
            path: path,
            configuration: configuration,
            defaultLabel: defaultLabel,
            purpose: purpose)
        
        try serializedDatabase.sync { db in
            // Assert WAL mode
            let journalMode = try String.fetchOne(db, sql: "PRAGMA journal_mode")
            guard journalMode == "wal" else {
                throw DatabaseError(message: "WAL mode is not activated at path: \(path)")
            }
            
            // Open transaction
            try db.beginTransaction(.deferred)
            
            // Acquire snapshot isolation
            try db.internalCachedStatement(sql: "SELECT rootpage FROM sqlite_master LIMIT 1").makeCursor().next()
        }
    }
    
    deinit {
        // Leave snapshot isolation
        serializedDatabase.reentrantSync { db in
            try? db.commit()
        }
    }
}

extension DatabaseSnapshot: DatabaseReader {
    public func close() throws {
        try serializedDatabase.sync { try $0.close() }
    }
    
    // MARK: - Interrupting Database Operations
    
    public func interrupt() {
        serializedDatabase.interrupt()
    }
    
    // MARK: - Reading from Database
    
    public func read<T>(_ block: (Database) throws -> T) rethrows -> T {
        try serializedDatabase.sync(block)
    }
    
    public func asyncRead(_ value: @escaping (Result<Database, Error>) -> Void) {
        serializedDatabase.async { value(.success($0)) }
    }
    
    public func unsafeRead<T>(_ value: (Database) throws -> T) rethrows -> T {
        try serializedDatabase.sync(value)
    }
    
    public func asyncUnsafeRead(_ value: @escaping (Result<Database, Error>) -> Void) {
        serializedDatabase.async { value(.success($0)) }
    }
    
    public func unsafeReentrantRead<T>(_ value: (Database) throws -> T) throws -> T {
        try serializedDatabase.reentrantSync(value)
    }
    
    // MARK: - Database Observation
    
    public func _add<Reducer: ValueReducer>(
        observation: ValueObservation<Reducer>,
        scheduling scheduler: ValueObservationScheduler,
        onChange: @escaping (Reducer.Value) -> Void)
    -> AnyDatabaseCancellable
    {
        _addReadOnly(
            observation: observation,
            scheduling: scheduler,
            onChange: onChange)
    }
}
