// swiftlint:disable:next line_length
#if SQLITE_ENABLE_SNAPSHOT || (!GRDBCUSTOMSQLITE && !GRDBCIPHER && (compiler(>=5.7.1) || !(os(macOS) || targetEnvironment(macCatalyst))))
/// A long-live read-only WAL transaction.
///
/// `WALSnapshotTransaction` **takes ownership** of its reader
/// `SerializedDatabase` (TODO: make it a move-only type eventually).
class WALSnapshotTransaction {
    private let reader: SerializedDatabase
    private let transactionDidComplete: (Bool) -> Void
    
    /// The state of the database at the beginning of the transaction.
    let walSnapshot: WALSnapshot
    
    /// Creates a long-live WAL transaction on a read-only connection.
    ///
    /// The `transactionDidComplete` closure is called when the
    /// `WALSnapshotTransaction` is deallocated, or if the
    /// initializer throws. Its argument tells if the long-lived
    /// transaction could be properly terminated.
    ///
    /// - parameter reader: A read-only database connection.
    /// - parameter transactionDidComplete: A closure to call when the
    ///   snapshot transaction ends.
    init(
        reader: SerializedDatabase,
        transactionDidComplete: @escaping (Bool) -> Void)
    throws
    {
        assert(reader.configuration.readonly)
        
        // Open a transaction and enter snapshot isolation
        reader.allowsUnsafeTransactions = true
        do {
            try reader.sync { db in
                try db.beginTransaction(.deferred)
                try db.execute(sql: "SELECT rootpage FROM sqlite_master LIMIT 1")
            }
        } catch {
            // self is not initialized, so deinit will not run.
            Self.commitAndRelease(reader: reader, transactionDidComplete: transactionDidComplete)
            throw error
        }
        
        self.reader = reader
        self.transactionDidComplete = transactionDidComplete
        self.walSnapshot = try reader.sync { db in
            return try WALSnapshot(db)
        }
    }
    
    deinit {
        Self.commitAndRelease(reader: reader, transactionDidComplete: transactionDidComplete)
    }
    
    /// Executes database operations in the snapshot transaction, and
    /// returns their result after they have finished executing.
    func read<T>(_ value: (Database) throws -> T) rethrows -> T {
        // TODO: we should check the validity of the snapshot, as DatabaseSnapshotPool does.
        try reader.sync(value)
    }
    
    private static func commitAndRelease(
        reader: SerializedDatabase,
        transactionDidComplete: (Bool) -> Void)
    {
        reader.allowsUnsafeTransactions = false
        let success = reader.sync { db in
            try? db.commit()
            return db.isInsideTransaction
        }
        transactionDidComplete(success)
    }
}
#endif
