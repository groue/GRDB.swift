#if SQLITE_ENABLE_SNAPSHOT
#if SWIFT_PACKAGE
import CSQLite
#elseif GRDBCIPHER
import SQLCipher
#elseif !GRDBCUSTOMSQLITE && !GRDBCIPHER
import SQLite3
#endif

public class SharedDatabaseSnapshot {
    private let databasePool: DatabasePool
    private var sqliteSnapshot: UnsafeMutablePointer<sqlite3_snapshot>
    
    init(databasePool: DatabasePool) throws {
        var sqliteSnapshot: UnsafeMutablePointer<sqlite3_snapshot>?
        try databasePool.unsafeReentrantWrite { db in
            let code = withUnsafeMutablePointer(to: &sqliteSnapshot) {
                sqlite3_snapshot_get(db.sqliteConnection, "main", $0)
            }
            guard code == SQLITE_OK else {
                throw DatabaseError(resultCode: code, message: db.lastErrorMessage)
            }
        }
        
        self.databasePool = databasePool
        if let sqliteSnapshot = sqliteSnapshot {
            self.sqliteSnapshot = sqliteSnapshot
        } else {
            throw DatabaseError(resultCode: .SQLITE_INTERNAL) // WTF SQLite?
        }
    }
    
    deinit {
        sqlite3_snapshot_free(sqliteSnapshot)
    }
}

extension SharedDatabaseSnapshot: DatabaseReader {
    // :nodoc:
    public var configuration: Configuration {
        var configuration = databasePool.configuration
        configuration.readonly = true
        return configuration
    }
    
    public func read<T>(_ block: (Database) throws -> T) throws -> T {
        return try databasePool.unsafeRead { db in
            // TODO: carefully handle errors (https://www.sqlite.org/c3ref/snapshot_open.html)
            let code = sqlite3_snapshot_open(db.sqliteConnection, "main", sqliteSnapshot)
            guard code == SQLITE_OK else {
                throw DatabaseError(resultCode: code, message: db.lastErrorMessage)
            }
            
            
        }
    }
    
    public func asyncRead(_ block: @escaping (Result<Database, Error>) -> Void) {
        fatalError("Not implemented")
    }
    
    public func unsafeRead<T>(_ block: (Database) throws -> T) throws -> T {
        fatalError("Not implemented")
    }
    
    public func unsafeReentrantRead<T>(_ block: (Database) throws -> T) throws -> T {
        fatalError("Not implemented")
    }
    
    public func add(function: DatabaseFunction) {
        fatalError("Not implemented")
    }
    
    public func remove(function: DatabaseFunction) {
        fatalError("Not implemented")
    }
    
    public func add(collation: DatabaseCollation) {
        fatalError("Not implemented")
    }
    
    public func remove(collation: DatabaseCollation) {
        fatalError("Not implemented")
    }
    
    public func add<Reducer>(observation: ValueObservation<Reducer>, onError: @escaping (Error) -> Void, onChange: @escaping (Reducer.Value) -> Void) -> TransactionObserver where Reducer : ValueReducer {
        fatalError("Not implemented")
    }
    
    public func remove(transactionObserver: TransactionObserver) {
        fatalError("Not implemented")
    }
}
#endif
