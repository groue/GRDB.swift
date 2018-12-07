import Dispatch

/// A DatabaseSnapshot sees an unchanging database content, as it existed at the
/// moment it was created.
///
/// See DatabasePool.makeSnapshot()
///
/// For more information, read about "snapshot isolation" at https://sqlite.org/isolation.html
public class DatabaseSnapshot : DatabaseReader {
    private var serializedDatabase: SerializedDatabase
    
    /// The database configuration
    var configuration: Configuration {
        return serializedDatabase.configuration
    }
    
    init(path: String, configuration: Configuration = Configuration(), defaultLabel: String, purpose: String) throws {
        var configuration = configuration
        configuration.readonly = true
        configuration.allowsUnsafeTransactions = true // Snaphost keeps a long-lived transaction
        
        serializedDatabase = try SerializedDatabase(
            path: path,
            configuration: configuration,
            schemaCache: SimpleDatabaseSchemaCache(),
            defaultLabel: defaultLabel,
            purpose: purpose)
        
        try serializedDatabase.sync { db in
            // Assert WAL mode
            let journalMode = try String.fetchOne(db, "PRAGMA journal_mode")
            guard journalMode == "wal" else {
                throw DatabaseError(message: "WAL mode is not activated at path: \(path)")
            }
            try db.beginSnapshotIsolation()
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
        return try serializedDatabase.sync(block)
    }
    
    /// Alias for `read`. See `DatabaseReader.unsafeRead`.
    ///
    /// :nodoc:
    public func unsafeRead<T>(_ block: (Database) throws -> T) rethrows -> T {
        return try serializedDatabase.sync(block)
    }
    
    /// Alias for `read`. See `DatabaseReader.unsafeReentrantRead`.
    ///
    /// :nodoc:
    public func unsafeReentrantRead<T>(_ block: (Database) throws -> T) throws -> T {
        return try serializedDatabase.sync(block)
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
    
    public func add<Reducer: ValueReducer>(
        observation: ValueObservation<Reducer>,
        onError: ((Error) -> Void)?,
        onChange: @escaping (Reducer.Value) -> Void)
        throws -> TransactionObserver
    {
        // Deal with initial value
        switch observation.scheduling {
        case .mainQueue:
            if let value = try unsafeReentrantRead(observation.initialValue) {
                if DispatchQueue.isMain {
                    onChange(value)
                } else {
                    DispatchQueue.main.async {
                        onChange(value)
                    }
                }
            }
        case let .onQueue(queue, startImmediately: startImmediately):
            if startImmediately {
                if let value = try unsafeReentrantRead(observation.initialValue) {
                    queue.async {
                        onChange(value)
                    }
                }
            }
        case let .unsafe(startImmediately: startImmediately):
            if startImmediately {
                if let value = try unsafeReentrantRead(observation.initialValue) {
                    onChange(value)
                }
            }
        }
        
        // Return a dummy observer, because snapshots never change
        return SnapshotValueObserver()
    }
    
    public func remove(transactionObserver: TransactionObserver) {
        // Can't remove an observer which could not be added :-)
    }
}

extension ValueObservation where Reducer: ValueReducer {
    /// Helper method for DatabaseSnapshot.add(observation:onError:onChange:)
    fileprivate func initialValue(_ db: Database) throws -> Reducer.Value? {
        var reducer = try makeReducer(db)
        let fetched = try reducer.fetch(db)
        return reducer.value(fetched)
    }
}

/// An observer that does nothing, support for
/// `DatabaseSnapshot.add(observation:onError:onChange:)`.
private class SnapshotValueObserver: TransactionObserver {
    func observes(eventsOfKind eventKind: DatabaseEventKind) -> Bool { return false }
    func databaseDidChange(with event: DatabaseEvent) { }
    func databaseDidCommit(_ db: Database) { }
    func databaseDidRollback(_ db: Database) { }
}
