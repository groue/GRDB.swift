/// The protocol for database schema cache.
protocol DatabaseSchemaCache {
    mutating func clear()
    
    var schemaInfo: SchemaInfo? { get set }
    
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
struct SimpleDatabaseSchemaCache: DatabaseSchemaCache {
    var schemaInfo: SchemaInfo?
    private var primaryKeys: [String: PrimaryKeyInfo] = [:]
    private var columns: [String: [ColumnInfo]] = [:]
    private var indexes: [String: [IndexInfo]] = [:]
    private var foreignKeys: [String: [ForeignKeyInfo]] = [:]
    
    mutating func clear() {
        primaryKeys = [:]
        columns = [:]
        indexes = [:]
        foreignKeys = [:]
        schemaInfo = nil
    }
    
    func primaryKey(_ table: String) -> PrimaryKeyInfo? {
        return primaryKeys[table]
    }
    
    mutating func set(primaryKey: PrimaryKeyInfo, forTable table: String) {
        primaryKeys[table] = primaryKey
    }
    
    func columns(in table: String) -> [ColumnInfo]? {
        return columns[table]
    }
    
    mutating func set(columns: [ColumnInfo], forTable table: String) {
        self.columns[table] = columns
    }
    
    func indexes(on table: String) -> [IndexInfo]? {
        return indexes[table]
    }
    
    mutating func set(indexes: [IndexInfo], forTable table: String) {
        self.indexes[table] = indexes
    }
    
    func foreignKeys(on table: String) -> [ForeignKeyInfo]? {
        return foreignKeys[table]
    }
    
    mutating func set(foreignKeys: [ForeignKeyInfo], forTable table: String) {
        self.foreignKeys[table] = foreignKeys
    }
}

/// A thread-unsafe database schema cache
class SharedDatabaseSchemaCache: DatabaseSchemaCache {
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

/// An always empty database schema cache
struct EmptyDatabaseSchemaCache: DatabaseSchemaCache {
    func clear() { }
    
    var schemaInfo: SchemaInfo? {
        get { return nil }
        set { }
    }
    
    func primaryKey(_ table: String) -> PrimaryKeyInfo? { return nil }
    func set(primaryKey: PrimaryKeyInfo, forTable table: String) { }
    
    func columns(in table: String) -> [ColumnInfo]? { return nil }
    func set(columns: [ColumnInfo], forTable table: String) { }
    
    func indexes(on table: String) -> [IndexInfo]? { return nil }
    func set(indexes: [IndexInfo], forTable table: String) { }
    
    func foreignKeys(on table: String) -> [ForeignKeyInfo]? { return nil }
    func set(foreignKeys: [ForeignKeyInfo], forTable table: String) { }
}
