/// The protocol for schema cache.
///
/// This protocol must not contain values that are valid for a single connection
/// only, because several connections can share the same schema cache.
///
/// Statements can't be cached here, for example.
protocol DatabaseSchemaCache {
    mutating func clear()
    
    func primaryKey(_ tableName: String) -> PrimaryKey??
    mutating func set(primaryKey: PrimaryKey?, for tableName: String)

    func indexes(on tableName: String) -> [Database.IndexInfo]?
    mutating func set(indexes: [Database.IndexInfo], forTableName tableName: String)
}

/// A thread-unsafe database schema cache
final class SimpleDatabaseSchemaCache: DatabaseSchemaCache {
    private var primaryKeys: [String: PrimaryKey?] = [:]
    private var indexes: [String: [Database.IndexInfo]] = [:]
    
    func clear() {
        primaryKeys = [:]
        indexes = [:]
    }
    
    func primaryKey(_ tableName: String) -> PrimaryKey?? {
        return primaryKeys[tableName]
    }
    
    func set(primaryKey: PrimaryKey?, for tableName: String) {
        primaryKeys[tableName] = primaryKey
    }
    
    func indexes(on tableName: String) -> [Database.IndexInfo]? {
        return indexes[tableName]
    }
    
    func set(indexes: [Database.IndexInfo], forTableName tableName: String) {
        self.indexes[tableName] = indexes
    }
}

/// A thread-safe database schema cache
final class SharedDatabaseSchemaCache: DatabaseSchemaCache {
    private let cache = ReadWriteBox(SimpleDatabaseSchemaCache())
    
    func clear() {
        cache.write { $0.clear() }
    }
    
    func primaryKey(_ tableName: String) -> PrimaryKey?? {
        return cache.read { $0.primaryKey(tableName) }
    }
    
    func set(primaryKey: PrimaryKey?, for tableName: String) {
        cache.write { $0.set(primaryKey: primaryKey, for: tableName) }
    }
    
    func indexes(on tableName: String) -> [Database.IndexInfo]? {
        return cache.read { $0.indexes(on: tableName) }
    }
    
    func set(indexes: [Database.IndexInfo], forTableName tableName: String) {
        cache.write { $0.set(indexes: indexes, forTableName: tableName) }
    }
}
