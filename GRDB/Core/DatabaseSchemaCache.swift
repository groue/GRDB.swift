/// A thread-unsafe database schema cache
final class SimpleDatabaseSchemaCache: DatabaseSchemaCache {
    private var primaryKeys: [String: PrimaryKey?] = [:]
    
    func clear() {
        primaryKeys = [:]
    }
    
    func primaryKey(_ tableName: String) -> PrimaryKey?? {
        guard let pk = primaryKeys[tableName] else {
            return nil
        }
        return pk
    }
    
    func set(primaryKey: PrimaryKey?, for tableName: String) {
        primaryKeys[tableName] = primaryKey
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
}
