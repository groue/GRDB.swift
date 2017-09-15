/// The protocol for schema cache.
///
/// This protocol must not contain values that are valid for a single connection
/// only, because several connections can share the same schema cache.
///
/// Statements can't be cached here, for example.
protocol DatabaseSchemaCache {
    mutating func clear()
    
    func primaryKey(_ table: String) -> PrimaryKeyInfo?
    mutating func set(primaryKey: PrimaryKeyInfo, forTable table: String)
    
    func columns(in table: String) -> [ColumnInfo]?
    mutating func set(columns: [ColumnInfo], forTable table: String)
    
    func indexes(on table: String) -> [IndexInfo]?
    mutating func set(indexes: [IndexInfo], forTable table: String)
    
    func foreignKeys(on table: String) -> [ForeignKeyInfo]?
    mutating func set(foreignKeys: [ForeignKeyInfo], forTable table: String)
}

/// A thread-unsafe database schema cache
final class SimpleDatabaseSchemaCache: DatabaseSchemaCache {
    private var primaryKeys: [String: PrimaryKeyInfo] = [:]
    private var columns: [String: [ColumnInfo]] = [:]
    private var indexes: [String: [IndexInfo]] = [:]
    private var foreignKeys: [String: [ForeignKeyInfo]] = [:]
    
    func clear() {
        primaryKeys = [:]
        columns = [:]
        indexes = [:]
        foreignKeys = [:]
    }
    
    func primaryKey(_ table: String) -> PrimaryKeyInfo? {
        return primaryKeys[table]
    }
    
    func set(primaryKey: PrimaryKeyInfo, forTable table: String) {
        primaryKeys[table] = primaryKey
    }
    
    func columns(in table: String) -> [ColumnInfo]? {
        return columns[table]
    }
    
    func set(columns: [ColumnInfo], forTable table: String) {
        self.columns[table] = columns
    }
    
    func indexes(on table: String) -> [IndexInfo]? {
        return indexes[table]
    }
    
    func set(indexes: [IndexInfo], forTable table: String) {
        self.indexes[table] = indexes
    }
    
    func foreignKeys(on table: String) -> [ForeignKeyInfo]? {
        return foreignKeys[table]
    }
    
    func set(foreignKeys: [ForeignKeyInfo], forTable table: String) {
        self.foreignKeys[table] = foreignKeys
    }
}

/// A thread-safe database schema cache
final class SharedDatabaseSchemaCache: DatabaseSchemaCache {
    private let cache = ReadWriteBox(SimpleDatabaseSchemaCache())
    
    func clear() {
        cache.write { $0.clear() }
    }
    
    func primaryKey(_ table: String) -> PrimaryKeyInfo? {
        return cache.read { $0.primaryKey(table) }
    }
    
    func set(primaryKey: PrimaryKeyInfo, forTable table: String) {
        cache.write { $0.set(primaryKey: primaryKey, forTable: table) }
    }
    
    func columns(in table: String) -> [ColumnInfo]? {
        return cache.read { $0.columns(in: table) }
    }
    
    func set(columns: [ColumnInfo], forTable table: String) {
        cache.write { $0.set(columns: columns, forTable: table) }
    }
    
    func indexes(on table: String) -> [IndexInfo]? {
        return cache.read { $0.indexes(on: table) }
    }
    
    func set(indexes: [IndexInfo], forTable table: String) {
        cache.write { $0.set(indexes: indexes, forTable: table) }
    }
    
    func foreignKeys(on table: String) -> [ForeignKeyInfo]? {
        return cache.read { $0.foreignKeys(on: table) }
    }
    
    func set(foreignKeys: [ForeignKeyInfo], forTable table: String) {
        cache.write { $0.set(foreignKeys: foreignKeys, forTable: table) }
    }
}
