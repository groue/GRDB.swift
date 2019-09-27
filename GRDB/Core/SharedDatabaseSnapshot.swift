#if SQLITE_ENABLE_SNAPSHOT
#if SWIFT_PACKAGE
import CSQLite
#elseif GRDBCIPHER
import SQLCipher
#elseif !GRDBCUSTOMSQLITE && !GRDBCIPHER
import SQLite3
#endif

public class SharedDatabaseSnapshot {
    /// A reference-type cache
    private class SchemaCache: DatabaseSchemaCache {
        private var _cache = SimpleDatabaseSchemaCache()
        
        var schemaInfo: SchemaInfo? {
            get { return _cache.schemaInfo }
            set { _cache.schemaInfo = newValue }
        }
        
        func clear() {
            _cache.clear()
        }
        
        func primaryKey(_ table: String) -> PrimaryKeyInfo? {
            return _cache.primaryKey(table)
        }
        
        func set(primaryKey: PrimaryKeyInfo, forTable table: String) {
            _cache.set(primaryKey: primaryKey, forTable: table)
        }
        
        func columns(in table: String) -> [ColumnInfo]? {
            return _cache.columns(in: table)
        }
        
        func set(columns: [ColumnInfo], forTable table: String) {
            _cache.set(columns: columns, forTable: table)
        }
        
        func indexes(on table: String) -> [IndexInfo]? {
            return _cache.indexes(on: table)
        }
        
        func set(indexes: [IndexInfo], forTable table: String) {
            _cache.set(indexes: indexes, forTable: table)
        }
        
        func foreignKeys(on table: String) -> [ForeignKeyInfo]? {
            return _cache.foreignKeys(on: table)
        }
        
        func set(foreignKeys: [ForeignKeyInfo], forTable table: String) {
            _cache.set(foreignKeys: foreignKeys, forTable: table)
        }
    }
    
    /// An SQLite snapshot and the associated schema cache
    private class Context {
        let snapshot: SQLiteSnapshot
        let schemaCache: SchemaCache
        
        init(snapshot: SQLiteSnapshot, schemaCache: SchemaCache) {
            self.snapshot = snapshot
            self.schemaCache = schemaCache
        }
        
        deinit {
            sqlite3_snapshot_free(snapshot)
        }
    }
    
    private let databasePool: DatabasePool
    private var context: ReadWriteBox<Context>
    
    convenience init(databasePool: DatabasePool, database: Database) throws {
        let sqliteSnapshot = try database.makeSQLiteSnapshot()
        self.init(databasePool: databasePool, sqliteSnapshot: sqliteSnapshot)
    }
    
    private init(databasePool: DatabasePool, sqliteSnapshot: SQLiteSnapshot){
        self.databasePool = databasePool
        self.context = ReadWriteBox(Context(snapshot: sqliteSnapshot, schemaCache: SchemaCache()))
    }
}

extension SharedDatabaseSnapshot: DatabaseReader {
    // :nodoc:
    public var configuration: Configuration {
        return databasePool.readerConfiguration
    }
    
    public func read<T>(_ block: (Database) throws -> T) throws -> T {
        let context = self.context.value
        return try databasePool.read { db in
            try db.openSQLiteSnapshot(context.snapshot)
            db.schemaCache = context.schemaCache
            return try block(db)
        }
    }
    
    #if compiler(>=5.0)
    public func asyncRead(_ block: @escaping (Result<Database, Error>) -> Void) {
        // Use current context, regardless of self's context when the async read
        // eventually happens.
        let context = self.context.value
        
        databasePool.asyncRead { db in
            do {
                let db = try db.get()
                // Ignore error because we can not notify it.
                try db.openSQLiteSnapshot(context.snapshot)
                db.schemaCache = context.schemaCache
                block(.success(db))
            } catch {
                block(.failure(error))
            }
        }
    }
    #endif
    
    public func unsafeRead<T>(_ block: (Database) throws -> T) throws -> T {
        return try read(block)
    }
    
    public func unsafeReentrantRead<T>(_ block: (Database) throws -> T) throws -> T {
        // The difficulty is to have a reentrant `db.inSnapshot`.
        fatalError("Not implemented")
    }
    
    public func add(function: DatabaseFunction) {
        databasePool.add(function: function)
    }
    
    public func remove(function: DatabaseFunction) {
        databasePool.remove(function: function)
    }
    
    public func add(collation: DatabaseCollation) {
        databasePool.add(collation: collation)
    }
    
    public func remove(collation: DatabaseCollation) {
        databasePool.add(collation: collation)
    }
    
    public func add<Reducer>(
        observation: ValueObservation<Reducer>,
        onError: @escaping (Error) -> Void,
        onChange: @escaping (Reducer.Value) -> Void)
        -> TransactionObserver
        where Reducer: ValueReducer
    {
        fatalError("Not implemented")
    }
    
    public func remove(transactionObserver: TransactionObserver) {
        fatalError("Not implemented")
    }
}
#endif
