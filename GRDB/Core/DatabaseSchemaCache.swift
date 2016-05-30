/// A thread-unsafe database schema cache
final class DatabaseSchemaCache: DatabaseSchemaCacheType {
    private var primaryKeys: [String: PrimaryKey?] = [:]
    
    func clear() {
        primaryKeys = [:]
    }
    
    func primaryKey(tableName tableName: String) -> PrimaryKey?? {
        guard let pk = primaryKeys[tableName] else {
            return nil
        }
        return pk
    }
    
    func setPrimaryKey(primaryKey: PrimaryKey?, forTableName tableName: String) {
        primaryKeys[tableName] = primaryKey
    }
}

/// A thread-safe database schema cache
final class SharedDatabaseSchemaCache: DatabaseSchemaCacheType {
    private let cache = ReadWriteBox(DatabaseSchemaCache())
    
    func clear() {
        cache.write { $0.clear() }
    }
    
    func primaryKey(tableName tableName: String) -> PrimaryKey?? {
        return cache.read { $0.primaryKey(tableName: tableName) }
    }
    
    func setPrimaryKey(primaryKey: PrimaryKey?, forTableName tableName: String) {
        cache.write { $0.setPrimaryKey(primaryKey, forTableName: tableName) }
    }
}
