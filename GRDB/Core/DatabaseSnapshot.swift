import Dispatch

/// A database connection that sees an unchanging database content, as it
/// existed at the moment it was created.
///
/// You create instances of `DatabaseSnapshot` from a ``DatabasePool``, with
/// ``DatabasePool/makeSnapshot()``.
///
/// A database snapshot creates one single SQLite connection. All database
/// accesses are executed in a serial dispatch queue.
///
/// A database snapshot inherits all of its database access methods from the
/// ``DatabaseReader`` protocol.
///
/// Related SQLite documentation: <https://sqlite.org/isolation.html>
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
