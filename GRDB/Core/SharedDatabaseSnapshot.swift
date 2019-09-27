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
    private struct State {
        let snapshot: Database.Snapshot
        let schemaCache: SchemaCache
    }
    
    private let databasePool: DatabasePool
    private var state: ReadWriteBox<State>
    
    convenience init(databasePool: DatabasePool, database: Database) throws {
        let snapshot = try Database.Snapshot(from: database)
        self.init(databasePool: databasePool, snapshot: snapshot)
    }
    
    private init(databasePool: DatabasePool, snapshot: Database.Snapshot) {
        self.databasePool = databasePool
        self.state = ReadWriteBox(State(snapshot: snapshot, schemaCache: SchemaCache()))
    }
}

extension SharedDatabaseSnapshot: DatabaseReader {
    // :nodoc:
    public var configuration: Configuration {
        return databasePool.readerConfiguration
    }
    
    public func read<T>(_ block: (Database) throws -> T) throws -> T {
        let state = self.state.value
        return try databasePool.read { db in
            try db.openSnapshot(state.snapshot)
            db.schemaCache = state.schemaCache
            return try block(db)
        }
    }
    
    #if compiler(>=5.0)
    public func asyncRead(_ block: @escaping (Result<Database, Error>) -> Void) {
        // Use current state, regardless of self's state when the async read
        // eventually happens.
        let state = self.state.value
        
        databasePool.asyncRead { db in
            do {
                let db = try db.get()
                // Ignore error because we can not notify it.
                try db.openSnapshot(state.snapshot)
                db.schemaCache = state.schemaCache
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
    
    // TODO: will we have to refresh the observation when we implement snapshot refresh?
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
