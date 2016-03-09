public final class DatabasePool {
    
    // MARK: - Initializers
    
    /// Opens the SQLite database at path *path*.
    ///
    ///     let dbPool = try DatabasePool(path: "/path/to/database.sqlite")
    ///
    /// Database connections get closed when the database pool gets deallocated.
    ///
    /// - parameters:
    ///     - path: The path to the database file.
    ///     - configuration: A configuration.
    ///     - maximumReaderCount: The maximum number of readers. Default is 5.
    /// - throws: A DatabaseError whenever an SQLite error occurs.
    public convenience init(path: String, configuration: Configuration = Configuration(), maximumReaderCount: Int = 5) throws {
        precondition(maximumReaderCount > 1, "maximumReaderCount must be at least 1")
        
        // Shared database schema cache
        let schemaCache = SharedDatabaseSchemaCache()
        
        // Readers
        var readConfig = configuration
        readConfig.readonly = true
        readConfig.defaultTransactionKind = .Deferred
        let readerPool = Pool(maximumCount: maximumReaderCount) {
            try! SerializedDatabase(
                path: path,
                configuration: readConfig,
                schemaCache: schemaCache)
        }
        
        // Writer
        var writeConfig = configuration
        writeConfig.readonly = false
        let writer = try SerializedDatabase(
            path: path,
            configuration: writeConfig,
            schemaCache: schemaCache)
        
        // Activate WAL Mode
        let mode = writer.inDatabase { db in
            String.fetchOne(db, "PRAGMA journal_mode=WAL")
        }
        guard mode == "wal" else {
            throw DatabaseError(message: "could not activate WAL Mode at path: \(path)")
        }
        
        self.init(readerPool: readerPool, writer: writer)
    }
    
    public func read<T>(block: (db: Database) throws -> T) rethrows -> T {
        // Wrap the read in a DEFERRED transaction.
        //
        // This prevents the writer to sneak in between two selects:
        //
        //      Thread 1                            Thread 2
        //      BEGIN DEFERRED TRANSACTION
        //      SELECT COUNT(*) FROM items -> 0
        //                                          INSERT INTO items...
        //      SELECT COUNT(*) FROM items -> 0 (invisible insert)
        //      COMMIT
        //
        // Without the transaction, we would get:
        //
        //      Thread 1                            Thread 2
        //      SELECT COUNT(*) FROM items -> 0
        //                                          INSERT INTO items...
        //      SELECT COUNT(*) FROM items -> 1 (visible insert)
        //
        // See DatabasePoolTests.testTwoReadsWithMiddleWrite().
        
        return try readerPool.get { serializedDatabase in
            try serializedDatabase.inDatabase { db in
                var result: T? = nil
                try db.inTransaction(.Deferred) {
                    result = try block(db: db)
                    return .Commit
                }
                return result!
            }
        }
    }
    
    public func write(block: (db: Database) throws -> Void) rethrows {
        try writer.inDatabase(block)
    }
    
    public func writeInTransaction(kind: TransactionKind? = nil, _ block: (db: Database) throws -> TransactionCompletion) rethrows {
        try writer.inDatabase { db in
            try db.inTransaction(kind) {
                try block(db: db)
            }
        }
    }
    
    public func checkpoint(kind: CheckpointKind = .Passive) throws {
        try writer.inDatabase { db in
            // TODO: read https://www.sqlite.org/c3ref/wal_checkpoint_v2.html and
            // check whether we need a busy handler on writer and/or readers.
            let code = sqlite3_wal_checkpoint_v2(db.sqliteConnection, nil, kind.rawValue, nil, nil)
            guard code == SQLITE_OK else {
                throw DatabaseError(code: code, message: db.lastErrorMessage, sql: nil)
            }
        }
    }
    
    private let writer: SerializedDatabase
    private let readerPool: Pool<SerializedDatabase>
    
    private init(readerPool: Pool<SerializedDatabase>, writer: SerializedDatabase) {
        self.readerPool = readerPool
        self.writer = writer
    }
}

// See https://www.sqlite.org/c3ref/wal_checkpoint_v2.html
public enum CheckpointKind: Int32 {
    case Passive = 0    // SQLITE_CHECKPOINT_PASSIVE
    case Full = 1       // SQLITE_CHECKPOINT_FULL
    case Restart = 2    // SQLITE_CHECKPOINT_RESTART
    case Truncate = 3   // SQLITE_CHECKPOINT_TRUNCATE
}
