#if SQLITE_ENABLE_SNAPSHOT
#if SWIFT_PACKAGE
import CSQLite
#elseif GRDBCIPHER
import SQLCipher
#elseif !GRDBCUSTOMSQLITE && !GRDBCIPHER
import SQLite3
#endif

public class DatabaseHistoricalSnapshot {    
    private let databasePool: DatabasePool
    private let snapshot: Database.Snapshot
    private let schemaCache: SharedDatabaseSchemaCache
    
    init(databasePool: DatabasePool, snapshot: Database.Snapshot) {
        self.databasePool = databasePool
        self.snapshot = snapshot
        self.schemaCache = SharedDatabaseSchemaCache()
    }
    
    deinit {
        if databasePool.configuration.historicalSnapshotsPreventAutomatickCheckpointing {
            databasePool.historicalSnapshotCount.decrement()
        }
    }
}

extension DatabaseHistoricalSnapshot: DatabaseReader {
    // :nodoc:
    public var configuration: Configuration {
        return databasePool.readerConfiguration
    }
    
    public func read<T>(_ block: (Database) throws -> T) throws -> T {
        return try databasePool.read { db in
            try db.openSnapshot(snapshot)
            return try db.withSchemaCache(schemaCache) {
                try block(db)
            }
        }
    }
    
    #if compiler(>=5.0)
    public func asyncRead(_ block: @escaping (Result<Database, Error>) -> Void) {
        databasePool.asyncRead { db in
            do {
                let db = try db.get()
                try db.openSnapshot(self.snapshot)
                db.withSchemaCache(self.schemaCache) {
                    block(.success(db))
                }
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
        return try databasePool.unsafeReentrantRead(checkingSnapshot: false) { db in
            if db.isInsideTransaction {
                guard db.currentSnapshot == self.snapshot else {
                    fatalError("unsafeReentrantRead misuse: this connection runs in a different snapshot")
                }
                // db.schemaCache is likely to already be self.schemaCache, but
                // we do not harm by forcing it.
                return try db.withSchemaCache(schemaCache) {
                    try block(db)
                }
            } else {
                var result: T? = nil
                try db.inTransaction(.deferred) {
                    try db.openSnapshot(snapshot)
                    result = try db.withSchemaCache(schemaCache) {
                        try block(db)
                    }
                    return .commit
                }
                return result!
            }
        }
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
