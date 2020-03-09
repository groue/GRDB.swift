/// A thread-unsafe database schema cache
struct DatabaseSchemaCache {
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
        primaryKeys[table]
    }
    
    mutating func set(primaryKey: PrimaryKeyInfo, forTable table: String) {
        primaryKeys[table] = primaryKey
    }
    
    func columns(in table: String) -> [ColumnInfo]? {
        columns[table]
    }
    
    mutating func set(columns: [ColumnInfo], forTable table: String) {
        self.columns[table] = columns
    }
    
    func indexes(on table: String) -> [IndexInfo]? {
        indexes[table]
    }
    
    mutating func set(indexes: [IndexInfo], forTable table: String) {
        self.indexes[table] = indexes
    }
    
    func foreignKeys(on table: String) -> [ForeignKeyInfo]? {
        foreignKeys[table]
    }
    
    mutating func set(foreignKeys: [ForeignKeyInfo], forTable table: String) {
        self.foreignKeys[table] = foreignKeys
    }
}
