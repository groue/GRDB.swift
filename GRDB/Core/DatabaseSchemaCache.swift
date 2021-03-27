/// A thread-unsafe database schema cache
struct DatabaseSchemaCache {
    /// A cached value
    ///
    /// We cache both hits and misses, because we often query both the temp
    /// schema and the main schema: not remembering misses would have us
    /// perform too many database queries.
    enum Presence<T> {
        /// Value does not exist in the schema.
        case missing
        
        /// Value exists in the schema.
        case value(T)
        
        var value: T? {
            switch self {
            case .missing: return nil
            case let .value(value): return value
            }
        }
    }
    
    var schemaInfo: SchemaInfo?
    private var primaryKeys: [String: Presence<PrimaryKeyInfo>] = [:]
    private var columns: [String: Presence<[ColumnInfo]>] = [:]
    private var indexes: [String: Presence<[IndexInfo]>] = [:]
    private var foreignKeys: [String: Presence<[ForeignKeyInfo]>] = [:]
    
    mutating func clear() {
        primaryKeys = [:]
        columns = [:]
        indexes = [:]
        foreignKeys = [:]
        schemaInfo = nil
    }
    
    func primaryKey(_ table: String) -> Presence<PrimaryKeyInfo>? {
        primaryKeys[table]
    }
    
    mutating func set(primaryKey: Presence<PrimaryKeyInfo>, forTable table: String) {
        primaryKeys[table] = primaryKey
    }
    
    func columns(in table: String) -> Presence<[ColumnInfo]>? {
        columns[table]
    }
    
    mutating func set(columns: Presence<[ColumnInfo]>, forTable table: String) {
        self.columns[table] = columns
    }
    
    func indexes(on table: String) -> Presence<[IndexInfo]>? {
        indexes[table]
    }
    
    mutating func set(indexes: Presence<[IndexInfo]>, forTable table: String) {
        self.indexes[table] = indexes
    }
    
    func foreignKeys(on table: String) -> Presence<[ForeignKeyInfo]>? {
        foreignKeys[table]
    }
    
    mutating func set(foreignKeys: Presence<[ForeignKeyInfo]>, forTable table: String) {
        self.foreignKeys[table] = foreignKeys
    }
}
