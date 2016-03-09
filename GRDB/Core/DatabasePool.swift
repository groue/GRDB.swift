public final class DatabasePool {
    public convenience init(path: String, configuration: Configuration = Configuration(), maxReaderCount: Int = 5) throws {
        precondition(maxReaderCount > 1, "maxReaderCount must be at least 1")
        
        // Shared database schema cache
        let schemaCache = SharedDatabaseSchemaCache()
        
        // Readers
        var readConfig = configuration
        readConfig.readonly = true
        let readerPool = Pool(size: maxReaderCount) {
            try! SerializedDatabase(path: path, configuration: readConfig, schemaCache: schemaCache)
        }
        
        // Writer
        var writeConfig = configuration
        writeConfig.readonly = false
        let writer = try SerializedDatabase(path: path, configuration: writeConfig, schemaCache: schemaCache)
        
        // Activate WAL Mode
        writer.inDatabase { db in
            let mode = String.fetchOne(db, "PRAGMA journal_mode=WAL")
            precondition(mode == "wal", "Could not open the database in WAL Mode.")
        }
        
        self.init(readerPool: readerPool, writer: writer)
    }
    
    public func read(block: (db: Database) throws -> Void) rethrows {
        try readerPool.get { serializedDatabase in
            try serializedDatabase.inDatabase(block)
        }
    }
    
    public func read<T>(block: (db: Database) throws -> T) rethrows -> T {
        return try readerPool.get { serializedDatabase in
            try serializedDatabase.inDatabase(block)
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
    
    public func checkpoint() throws {
        try writer.inDatabase { db in
            // TODO: read https://www.sqlite.org/c3ref/wal_checkpoint_v2.html and
            // check whether we need a busy handler on writer and/or readers.
            let code = sqlite3_wal_checkpoint_v2(db.sqliteConnection, nil, SQLITE_CHECKPOINT_TRUNCATE, nil, nil)
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
