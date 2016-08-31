/// The protocol for schema cache.
///
/// This protocol must not contain values that are valid for a single connection
/// only, because several connections can share the same schema cache.
///
/// Statements can't be cached here, for example.
protocol DatabaseSchemaCacheType {
    mutating func clear()
    
    func primaryKey(tableName tableName: String) -> PrimaryKeyInfo??
    mutating func setPrimaryKey(primaryKey: PrimaryKeyInfo?, forTableName tableName: String)
    
    func columns(in tableName: String) -> [ColumnInfo]?
    mutating func setColumns(columns: [ColumnInfo], forTableName tableName: String)

    func indexes(on tableName: String) -> [IndexInfo]?
    mutating func setIndexes(indexes: [IndexInfo], forTableName tableName: String)
}

/// A thread-unsafe database schema cache
final class DatabaseSchemaCache: DatabaseSchemaCacheType {
    private var primaryKeys: [String: PrimaryKeyInfo?] = [:]
    private var columns: [String: [ColumnInfo]] = [:]
    private var indexes: [String: [IndexInfo]] = [:]
    
    func clear() {
        primaryKeys = [:]
        columns = [:]
        indexes = [:]
    }
    
    func primaryKey(tableName tableName: String) -> PrimaryKeyInfo?? {
        return primaryKeys[tableName]
    }
    
    func setPrimaryKey(primaryKey: PrimaryKeyInfo?, forTableName tableName: String) {
        primaryKeys[tableName] = primaryKey
    }
    
    func columns(in tableName: String) -> [ColumnInfo]? {
        return columns[tableName]
    }
    
    func setColumns(columns: [ColumnInfo], forTableName tableName: String) {
        self.columns[tableName] = columns
    }
    
    func indexes(on tableName: String) -> [IndexInfo]? {
        return indexes[tableName]
    }
    
    func setIndexes(indexes: [IndexInfo], forTableName tableName: String) {
        self.indexes[tableName] = indexes
    }
}

/// A thread-safe database schema cache
final class SharedDatabaseSchemaCache: DatabaseSchemaCacheType {
    private let cache = ReadWriteBox(DatabaseSchemaCache())
    
    func clear() {
        cache.write { $0.clear() }
    }
    
    func primaryKey(tableName tableName: String) -> PrimaryKeyInfo?? {
        return cache.read { $0.primaryKey(tableName: tableName) }
    }
    
    func setPrimaryKey(primaryKey: PrimaryKeyInfo?, forTableName tableName: String) {
        cache.write { $0.setPrimaryKey(primaryKey, forTableName: tableName) }
    }
    
    func columns(in tableName: String) -> [ColumnInfo]? {
        return cache.read { $0.columns(in: tableName) }
    }
    
    func setColumns(columns: [ColumnInfo], forTableName tableName: String) {
        cache.write { $0.setColumns(columns, forTableName: tableName) }
    }
    
    func indexes(on tableName: String) -> [IndexInfo]? {
        return cache.read { $0.indexes(on: tableName) }
    }
    
    func setIndexes(indexes: [IndexInfo], forTableName tableName: String) {
        cache.write { $0.setIndexes(indexes, forTableName: tableName) }
    }
}
