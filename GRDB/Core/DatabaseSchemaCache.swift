/// The protocol for schema cache.
///
/// This protocol must not contain values that are valid for a single connection
/// only, because several connections can share the same schema cache.
///
/// Statements can't be cached here, for example.
protocol DatabaseSchemaCache {
    mutating func clear()
    
    func primaryKey(_ tableName: String) -> PrimaryKeyInfo??
    mutating func set(primaryKey: PrimaryKeyInfo?, for tableName: String)
    
    func columns(in tableName: String) -> [ColumnInfo]?
    mutating func set(columns: [ColumnInfo], forTableName tableName: String)
    
    func indexes(on tableName: String) -> [IndexInfo]?
    mutating func set(indexes: [IndexInfo], forTableName tableName: String)
}

/// A thread-unsafe database schema cache
final class SimpleDatabaseSchemaCache: DatabaseSchemaCache {
    private var primaryKeys: [String: PrimaryKeyInfo?] = [:]
    private var columns: [String: [ColumnInfo]] = [:]
    private var indexes: [String: [IndexInfo]] = [:]
    
    func clear() {
        primaryKeys = [:]
        columns = [:]
        indexes = [:]
    }
    
    func primaryKey(_ tableName: String) -> PrimaryKeyInfo?? {
        return primaryKeys[tableName]
    }
    
    func set(primaryKey: PrimaryKeyInfo?, for tableName: String) {
        primaryKeys[tableName] = primaryKey
    }
    
    func columns(in tableName: String) -> [ColumnInfo]? {
        return columns[tableName]
    }
    
    func set(columns: [ColumnInfo], forTableName tableName: String) {
        self.columns[tableName] = columns
    }
    
    func indexes(on tableName: String) -> [IndexInfo]? {
        return indexes[tableName]
    }
    
    func set(indexes: [IndexInfo], forTableName tableName: String) {
        self.indexes[tableName] = indexes
    }
}

/// A thread-safe database schema cache
final class SharedDatabaseSchemaCache: DatabaseSchemaCache {
    private let cache = ReadWriteBox(SimpleDatabaseSchemaCache())
    
    func clear() {
        cache.write { $0.clear() }
    }
    
    func primaryKey(_ tableName: String) -> PrimaryKeyInfo?? {
        return cache.read { $0.primaryKey(tableName) }
    }
    
    func set(primaryKey: PrimaryKeyInfo?, for tableName: String) {
        cache.write { $0.set(primaryKey: primaryKey, for: tableName) }
    }
    
    func columns(in tableName: String) -> [ColumnInfo]? {
        return cache.read { $0.columns(in: tableName) }
    }
    
    func set(columns: [ColumnInfo], forTableName tableName: String) {
        cache.write { $0.set(columns: columns, forTableName: tableName) }
    }
    
    func indexes(on tableName: String) -> [IndexInfo]? {
        return cache.read { $0.indexes(on: tableName) }
    }
    
    func set(indexes: [IndexInfo], forTableName tableName: String) {
        cache.write { $0.set(indexes: indexes, forTableName: tableName) }
    }
}
