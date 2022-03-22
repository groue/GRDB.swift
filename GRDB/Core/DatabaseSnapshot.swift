import Dispatch

/// A DatabaseSnapshot sees an unchanging database content, as it existed at the
/// moment it was created.
///
/// See DatabasePool.makeSnapshot()
///
/// For more information, read about "snapshot isolation" at <https://sqlite.org/isolation.html>
public final class DatabaseSnapshot: DatabaseReader {
    private let serializedDatabase: SerializedDatabase
    
    /// The database configuration
    public var configuration: Configuration {
        serializedDatabase.configuration
    }
    
#if SQLITE_ENABLE_SNAPSHOT
    typealias Version = UnsafeMutablePointer<sqlite3_snapshot>
    // Support for ValueObservation in DatabasePool
    let version: Version?
#else
    typealias Version = Void
#endif
    
    init(path: String, configuration: Configuration = Configuration(), defaultLabel: String, purpose: String) throws {
        var configuration = DatabasePool.readerConfiguration(configuration)
        configuration.allowsUnsafeTransactions = true // Snaphost keeps a long-lived transaction
        
        serializedDatabase = try SerializedDatabase(
            path: path,
            configuration: configuration,
            defaultLabel: defaultLabel,
            purpose: purpose)

        let version: Version? = try serializedDatabase.sync { db in
            // Assert WAL mode
            let journalMode = try String.fetchOne(db, sql: "PRAGMA journal_mode")
            guard journalMode == "wal" else {
                throw DatabaseError(message: "WAL mode is not activated at path: \(path)")
            }
            
            // Open transaction
            try db.beginTransaction(.deferred)
            
            // Acquire snapshot isolation
            try db.internalCachedStatement(sql: "SELECT rootpage FROM sqlite_master LIMIT 1").makeCursor().next()
            
            #if SQLITE_ENABLE_SNAPSHOT
            // We must expect an error: https://www.sqlite.org/c3ref/snapshot_get.html
            // > At least one transaction must be written to it first.
            return try? db.takeVersionSnapshot()
            #else
            return nil
            #endif
        }
        
        #if SQLITE_ENABLE_SNAPSHOT
        self.version = version
        #endif
    }
    
    deinit {
        // Leave snapshot isolation
        serializedDatabase.reentrantSync { db in
            #if SQLITE_ENABLE_SNAPSHOT
            if let version = version {
                sqlite3_snapshot_free(version)
            }
            #endif
            try? db.commit()
        }
    }
    
    public func close() throws {
        try serializedDatabase.sync { try $0.close() }
    }
}

// DatabaseReader
extension DatabaseSnapshot {
    
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
    
    /// :nodoc:
    public func _add<Reducer: ValueReducer>(
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
