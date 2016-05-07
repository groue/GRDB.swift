/// A thread-unsafe database schema cache
class DatabaseSchemaCache: DatabaseSchemaCacheType {
    private var primaryKeys: [String: PrimaryKey] = [:]
    
    func clear() {
        primaryKeys = [:]
    }
    
    func primaryKey(tableName tableName: String) -> PrimaryKey? {
        return primaryKeys[tableName]
    }
    
    func setPrimaryKey(primaryKey: PrimaryKey, forTableName tableName: String) {
        primaryKeys[tableName] = primaryKey
    }
}

/// A thread-safe database schema cache
struct SharedDatabaseSchemaCache: DatabaseSchemaCacheType {
    private var primaryKeys: ReadWriteBox<[String: PrimaryKey]> = ReadWriteBox([:])
    
    mutating func clear() {
        primaryKeys.write { $0 = [:] }
    }
    
    func primaryKey(tableName tableName: String) -> PrimaryKey? {
        return primaryKeys.read { $0[tableName] }
    }
    
    mutating func setPrimaryKey(primaryKey: PrimaryKey, forTableName tableName: String) {
        primaryKeys.write { $0[tableName] = primaryKey }
    }
}
