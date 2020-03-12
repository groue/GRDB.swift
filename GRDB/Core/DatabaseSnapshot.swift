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
    
    init(path: String, configuration: Configuration = Configuration(), defaultLabel: String, purpose: String) throws {
        var configuration = configuration
        configuration.readonly = true
        configuration.allowsUnsafeTransactions = true // Snaphost keeps a long-lived transaction
        
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
        }
    }
    
    deinit {
        // Leave snapshot isolation
        serializedDatabase.sync { db in
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
    ///     let players = try snapshot.asyncRead { result in
    ///         do {
    ///             let db = try result.get()
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
    
    // MARK: - Value Observation
    
    public func add<Reducer: _ValueReducer>(
        observation: ValueObservation<Reducer>,
        onError: @escaping (Error) -> Void,
        onChange: @escaping (Reducer.Value) -> Void)
        -> TransactionObserver
    {
        switch observation.scheduling {
        case .mainQueue:
            if DispatchQueue.isMain {
                do {
                    try onChange(serializedDatabase.reentrantSync(observation.fetchValue))
                } catch {
                    onError(error)
                }
            } else {
                serializedDatabase.async { db in
                    let result = Result { try observation.fetchValue(db) }
                    DispatchQueue.main.async {
                        do {
                            try onChange(result.get())
                        } catch {
                            onError(error)
                        }
                    }
                }
            }
        case let .async(onQueue: queue):
            serializedDatabase.async { db in
                let result = Result { try observation.fetchValue(db) }
                queue.async {
                    do {
                        try onChange(result.get())
                    } catch {
                        onError(error)
                    }
                }
            }
        case .unsafe:
            do {
                try onChange(serializedDatabase.reentrantSync(observation.fetchValue))
            } catch {
                onError(error)
            }
        }
        
        // Return a dummy observer, because snapshots never change
        return SnapshotValueObserver()
    }
    
    public func remove(transactionObserver: TransactionObserver) {
        // Can't remove an observer which could not be added :-)
    }
}

/// An observer that does nothing, support for
/// `DatabaseSnapshot.add(observation:onError:onChange:)`.
private class SnapshotValueObserver: TransactionObserver {
    func observes(eventsOfKind eventKind: DatabaseEventKind) -> Bool { false }
    func databaseDidChange(with event: DatabaseEvent) { }
    func databaseDidCommit(_ db: Database) { }
    func databaseDidRollback(_ db: Database) { }
}
