/// The protocol for schema cache.
///
/// This protocol must not contain values that are valid for a single connection
/// only, because several connections can share the same schema cache.
///
/// Statements can't be cached here, for example.
protocol DatabaseSchemaCacheType {
    mutating func clear()
    
    func primaryKey(tableName tableName: String) -> PrimaryKey??
    mutating func setPrimaryKey(primaryKey: PrimaryKey?, forTableName tableName: String)

    func indexes(on tableName: String) -> [TableIndex]?
    mutating func setIndexes(indexes: [TableIndex], forTableName tableName: String)
}

/// A thread-unsafe database schema cache
final class DatabaseSchemaCache: DatabaseSchemaCacheType {
    private var primaryKeys: [String: PrimaryKey?] = [:]
    private var indexes: [String: [TableIndex]] = [:]
    
    func clear() {
        primaryKeys = [:]
        indexes = [:]
    }
    
    func primaryKey(tableName tableName: String) -> PrimaryKey?? {
        return primaryKeys[tableName]
    }
    
    func setPrimaryKey(primaryKey: PrimaryKey?, forTableName tableName: String) {
        primaryKeys[tableName] = primaryKey
    }
    
    func indexes(on tableName: String) -> [TableIndex]? {
        return indexes[tableName]
    }
    
    func setIndexes(indexes: [TableIndex], forTableName tableName: String) {
        self.indexes[tableName] = indexes
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
    
    func indexes(on tableName: String) -> [TableIndex]? {
        return cache.read { $0.indexes(on: tableName) }
    }
    
    func setIndexes(indexes: [TableIndex], forTableName tableName: String) {
        cache.write { $0.setIndexes(indexes, forTableName: tableName) }
    }
}
