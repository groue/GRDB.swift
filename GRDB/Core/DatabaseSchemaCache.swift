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

/// A thread-safe reference-type cache
class SharedDatabaseSchemaCache: DatabaseSchemaCache {
    private var cache = ReadWriteBox(value: SimpleDatabaseSchemaCache())
    
    var schemaInfo: SchemaInfo? {
        get { return cache.read { $0.schemaInfo } }
        set { cache.write { $0.schemaInfo = newValue } }
    }
    
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
