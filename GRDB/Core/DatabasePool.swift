/// A DatabasePool grants concurrent accesses to an SQLite database.
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
        
        // Database Store
        let store = try DatabaseStore(path: path, attributes: configuration.fileAttributes)
        
        // Shared database schema cache
        let databaseSchemaCache = SharedDatabaseSchemaCache()
        
        // Writer
        let writer = try SerializedDatabase(
            path: path,
            configuration: configuration,
            schemaCache: databaseSchemaCache)
        
        // Activate WAL Mode unless readonly
        if !configuration.readonly {
            let mode = writer.inDatabase { db in
                String.fetchOne(db, "PRAGMA journal_mode=WAL")
            }
            guard mode == "wal" else {
                throw DatabaseError(message: "could not activate WAL Mode at path: \(path)")
            }
        }
        
        self.init(path: path, configuration: configuration, maximumReaderCount: maximumReaderCount, databaseSchemaCache: databaseSchemaCache, writer: writer, store: store)
    }
    
    
    // MARK: - WAL Management
    
    /// Runs a WAL checkpoint
    ///
    /// See https://www.sqlite.org/wal.html and
    /// https://www.sqlite.org/c3ref/wal_checkpoint_v2.html) for
    /// more information.
    ///
    /// - parameter kind: The checkpoint mode (default passive)
    public func checkpoint(kind: CheckpointMode = .Passive) throws {
        try writer.inDatabase { db in
            // TODO: read https://www.sqlite.org/c3ref/wal_checkpoint_v2.html and
            // check whether we need a busy handler on writer and/or readers
            // when kind is not .Passive.
            let code = sqlite3_wal_checkpoint_v2(db.sqliteConnection, nil, kind.rawValue, nil, nil)
            guard code == SQLITE_OK else {
                throw DatabaseError(code: code, message: db.lastErrorMessage, sql: nil)
            }
        }
    }
    
    
    // MARK: - Memory management
    
    /// Free as much memory as possible.
    ///
    /// This method blocks the current thread until all database accesses are completed.
    public func releaseMemory() {
        // TODO: test that this method blocks the current thread until all database accesses are completed.
        writer.inDatabase { db in
            db.releaseMemory()
        }
        
        readerPool.forEach { reader in
            reader.inDatabase { db in
                db.releaseMemory()
            }
        }
        
        readerPool.clear()
    }
    
    
    // MARK: - Not public
    
    let store: DatabaseStore    // Not private for tests that require syncing with the store
    private let writer: SerializedDatabase
    private let readerPool: Pool<SerializedDatabase>
    
    private var functions = Set<DatabaseFunction>()
    private var collations = Set<DatabaseCollation>()
    
    private init(path: String, configuration: Configuration, maximumReaderCount: Int, databaseSchemaCache: DatabaseSchemaCacheType, writer: SerializedDatabase, store: DatabaseStore) {
        self.store = store
        self.writer = writer
        self.readerPool = Pool<SerializedDatabase>(maximumCount: maximumReaderCount)
        
        var readerConfig = configuration
        readerConfig.readonly = true
        readerConfig.defaultTransactionKind = .Deferred // Make it the default. Other transaction kinds are forbidden by SQLite in read-only connections.
        
        readerPool.makeElement = { [unowned self] in
            let serializedDatabase = try! SerializedDatabase(
                path: path,
                configuration: readerConfig,
                schemaCache: databaseSchemaCache)
            
            serializedDatabase.inDatabase { db in
                for function in self.functions {
                    db.addFunction(function)
                }
                for collation in self.collations {
                    db.addCollation(collation)
                }
            }
            
            return serializedDatabase
        }
    }
}

/// The available [checkpoint modes](https://www.sqlite.org/c3ref/wal_checkpoint_v2.html).
public enum CheckpointMode: Int32 {
    case Passive = 0    // SQLITE_CHECKPOINT_PASSIVE
    case Full = 1       // SQLITE_CHECKPOINT_FULL
    case Restart = 2    // SQLITE_CHECKPOINT_RESTART
    case Truncate = 3   // SQLITE_CHECKPOINT_TRUNCATE
}


// =========================================================================
// MARK: - DatabaseReader

extension DatabasePool : DatabaseReader {
    
    // MARK: - Read From Database
    
    /// Synchronously executes a read-only block in a protected dispatch queue,
    /// and returns its result. The block is wrapped in a transaction.
    ///
    ///     let persons = dbPool.read { db in
    ///         Person.fetchAll(...)
    ///     }
    ///
    /// The block is completely isolated. Eventual concurrent database updates
    /// are *not visible* inside the block:
    ///
    ///     dbPool.read { db in
    ///         // Those two values are guaranteed to be equal, even if the
    ///         // `wines` table is modified between the two requests:
    ///         let count1 = Int.fetchOne(db, "SELECT COUNT(*) FROM wines")!
    ///         let count2 = Int.fetchOne(db, "SELECT COUNT(*) FROM wines")!
    ///     }
    ///
    ///     dbPool.read { db in
    ///         // Now this value may be different:
    ///         let count = Int.fetchOne(db, "SELECT COUNT(*) FROM wines")!
    ///     }
    ///
    /// This method is *not* reentrant.
    ///
    /// - parameter block: A block that accesses the database.
    /// - throws: The error thrown by the block.
    public func read<T>(block: (db: Database) throws -> T) rethrows -> T {
        // The block isolation comes from the DEFERRED transaction.
        // See DatabasePoolTests.testReadMethodIsolationOfBlock().
        return try readerPool.get { reader in
            try reader.inDatabase { db in
                var result: T? = nil
                try db.inTransaction(.Deferred) {
                    result = try block(db: db)
                    return .Commit
                }
                return result!
            }
        }
    }
    
    /// Synchronously executes a read-only block in a protected dispatch queue,
    /// and returns its result.
    ///
    ///     let persons = dbPool.nonIsolatedRead { db in
    ///         Person.fetchAll(...)
    ///     }
    ///
    /// The block is not isolated from eventual concurrent database updates:
    ///
    ///     dbPool.nonIsolatedRead { db in
    ///         // Those two values may be different because some other thread
    ///         // may have inserted or deleted a wine between the two requests:
    ///         let count1 = Int.fetchOne(db, "SELECT COUNT(*) FROM wines")!
    ///         let count2 = Int.fetchOne(db, "SELECT COUNT(*) FROM wines")!
    ///     }
    ///
    /// This method is *not* reentrant.
    ///
    /// - parameter block: A block that accesses the database.
    /// - throws: The error thrown by the block.
    public func nonIsolatedRead<T>(block: (db: Database) throws -> T) rethrows -> T {
        return try readerPool.get { reader in
            try reader.inDatabase { db in
                try block(db: db)
            }
        }
    }
    
    
    // MARK: - Functions
    
    /// Add or redefine an SQL function.
    ///
    ///     let fn = DatabaseFunction("succ", argumentCount: 1) { databaseValues in
    ///         let dbv = databaseValues.first!
    ///         guard let int = dbv.value() as Int? else {
    ///             return nil
    ///         }
    ///         return int + 1
    ///     }
    ///     dbPool.addFunction(fn)
    ///     dbPool.read { db in
    ///         Int.fetchOne(db, "SELECT succ(1)") // 2
    ///     }
    public func addFunction(function: DatabaseFunction) {
        functions.remove(function)
        functions.insert(function)
        
        writer.inDatabase { db in
            db.addFunction(function)
        }
        
        readerPool.forEach { reader in
            reader.inDatabase { db in
                db.addFunction(function)
            }
        }
    }
    
    /// Remove an SQL function.
    public func removeFunction(function: DatabaseFunction) {
        functions.remove(function)
        
        writer.inDatabase { db in
            db.removeFunction(function)
        }
        
        readerPool.forEach { reader in
            reader.inDatabase { db in
                db.removeFunction(function)
            }
        }
    }
    
    
    // MARK: - Collations
    
    /// Add or redefine a collation.
    ///
    ///     let collation = DatabaseCollation("localized_standard") { (string1, string2) in
    ///         return (string1 as NSString).localizedStandardCompare(string2)
    ///     }
    ///     dbPool.addCollation(collation)
    ///     dbPool.write { db in
    ///         try db.execute("CREATE TABLE files (name TEXT COLLATE LOCALIZED_STANDARD")
    ///     }
    public func addCollation(collation: DatabaseCollation) {
        collations.remove(collation)
        collations.insert(collation)
        
        writer.inDatabase { db in
            db.addCollation(collation)
        }
        
        readerPool.forEach { reader in
            reader.inDatabase { db in
                db.addCollation(collation)
            }
        }
    }
    
    /// Remove a collation.
    public func removeCollation(collation: DatabaseCollation) {
        collations.remove(collation)
        
        writer.inDatabase { db in
            db.removeCollation(collation)
        }
        
        readerPool.forEach { reader in
            reader.inDatabase { db in
                db.removeCollation(collation)
            }
        }
    }
}


// =========================================================================
// MARK: - DatabaseWriter

extension DatabasePool : DatabaseWriter {
    
    // MARK: - Writing in Database
    
    /// Synchronously executes an update block in a protected dispatch queue,
    /// and returns its result.
    ///
    ///     dbPool.write { db in
    ///         db.execute(...)
    ///     }
    ///
    /// This method is *not* reentrant.
    ///
    /// - parameter block: A block that accesses the database.
    /// - throws: The error thrown by the block.
    public func write<T>(block: (db: Database) throws -> T) rethrows -> T {
        return try writer.inDatabase(block)
    }
    
    /// Synchronously executes a block in a protected dispatch queue, wrapped
    /// inside a transaction.
    ///
    /// If the block throws an error, the transaction is rollbacked and the
    /// error is rethrown.
    ///
    ///     try dbPool.writeInTransaction { db in
    ///         db.execute(...)
    ///         return .Commit
    ///     }
    ///
    /// This method is *not* reentrant.
    ///
    /// - parameters:
    ///     - kind: The transaction type (default nil). If nil, the transaction
    ///       type is configuration.defaultTransactionKind, which itself
    ///       defaults to .Immediate. See https://www.sqlite.org/lang_transaction.html
    ///       for more information.
    ///     - block: A block that executes SQL statements and return either
    ///       .Commit or .Rollback.
    /// - throws: The error thrown by the block.
    public func writeInTransaction(kind: TransactionKind? = nil, _ block: (db: Database) throws -> TransactionCompletion) rethrows {
        try writer.inDatabase { db in
            try db.inTransaction(kind) {
                try block(db: db)
            }
        }
    }
}
