#if SQLITE_ENABLE_SNAPSHOT || (!GRDBCUSTOMSQLITE && !GRDBCIPHER)
/// A long-live read-only WAL transaction.
///
/// `WALSnapshotTransaction` **takes ownership** of its reader
/// `SerializedDatabase` (TODO: make it a move-only type eventually).
final class WALSnapshotTransaction: @unchecked Sendable {
    // @unchecked because `databaseAccess` is protected by a mutex.
    
    private struct DatabaseAccess {
        let reader: SerializedDatabase
        let release: @Sendable (_ isInsideTransaction: Bool) -> Void
        
        // MUST be called only once
        func commitAndRelease() {
            // WALSnapshotTransaction may be deinitialized in the dispatch
            // queue of its reader: allow reentrancy.
            let isInsideTransaction = reader.reentrantSync(allowingLongLivedTransaction: false) { db in
                try? db.commit()
                return db.isInsideTransaction
            }
            release(isInsideTransaction)
        }
    }
    
    // TODO: consider using the serialized DispatchQueue of reader instead of a lock.
    /// nil when closed
    private let databaseAccessMutex: Mutex<DatabaseAccess?>
    
    /// The state of the database at the beginning of the transaction.
    let walSnapshot: WALSnapshot
    
    /// Creates a long-live WAL transaction on a read-only connection.
    ///
    /// The `release` closure is always called. It is called when the
    /// `WALSnapshotTransaction` is deallocated, or if the initializer
    /// throws.
    ///
    /// In normal operations, the argument to `release` is always false,
    /// meaning that the connection is no longer in a transaction. If true,
    /// the connection has been left inside a transaction, due to
    /// some error.
    ///
    /// Usage:
    ///
    /// ```swift
    /// let transaction = WALSnapshotTransaction(
    ///     reader: reader,
    ///     release: { isInsideTransaction in
    ///         ...
    ///     })
    /// ```
    ///
    /// - parameter reader: A read-only database connection.
    /// - parameter release: A closure to call when the read-only connection
    ///   is no longer used.
    init(
        onReader reader: SerializedDatabase,
        release: @escaping @Sendable (_ isInsideTransaction: Bool) -> Void)
    throws
    {
        assert(reader.configuration.readonly)
        let databaseAccess = DatabaseAccess(reader: reader, release: release)
        
        do {
            // Open a long-lived transaction, and enter snapshot isolation
            self.walSnapshot = try reader.sync(allowingLongLivedTransaction: true) { db in
                try db.beginTransaction(.deferred)
                // This also acquires snapshot isolation because checking
                // database schema performs a read access.
                try db.clearSchemaCacheIfNeeded()
                return try WALSnapshot(db)
            }
            self.databaseAccessMutex = Mutex(databaseAccess)
        } catch {
            // self is not initialized, so deinit will not run.
            databaseAccess.commitAndRelease()
            throw error
        }
    }
    
    deinit {
        close()
    }
    
    /// Executes database operations in the snapshot transaction, and
    /// returns their result after they have finished executing.
    func read<T>(_ value: (Database) throws -> T) throws -> T {
        try databaseAccessMutex.withLock { databaseAccess in
            guard let databaseAccess else {
                throw DatabaseError.snapshotIsLost()
            }
            
            // We should check the validity of the snapshot, as DatabaseSnapshotPool does.
            return try databaseAccess.reader.sync(value)
        }
    }
    
    /// Schedules database operations for execution, and
    /// returns immediately.
    func asyncRead(_ value: @escaping @Sendable (Result<Database, Error>) -> Void) {
        databaseAccessMutex.withLock { databaseAccess in
            guard let databaseAccess else {
                value(.failure(DatabaseError.snapshotIsLost()))
                return
            }
            
            databaseAccess.reader.async { db in
                // We should check the validity of the snapshot, as DatabaseSnapshotPool does.
                // At least check if self was closed:
                if self.databaseAccessMutex.load() == nil {
                    value(.failure(DatabaseError.snapshotIsLost()))
                }
                value(.success(db))
            }
        }
    }
    
    func close() {
        databaseAccessMutex.withLock { databaseAccess in
            databaseAccess?.commitAndRelease()
            databaseAccess = nil
        }
    }
}
#endif
