/// An thread-unsafe database schema cache
class DatabaseSchemaCache: DatabaseSchemaCacheType {
    private var primaryKeys: [String: PrimaryKey] = [:]
    private var updateStatements: [String: UpdateStatement] = [:]
    private var selectStatements: [String: SelectStatement] = [:]
    
    func clear() {
        primaryKeys = [:]
        
        // We do clear updateStatementCache and selectStatementCache despite
        // the automatic statement recompilation (see https://www.sqlite.org/c3ref/prepare.html)
        // because the automatic statement recompilation only happens a
        // limited number of times.
        updateStatements = [:]
        selectStatements = [:]
    }
    
    func primaryKey(tableName tableName: String) -> PrimaryKey? {
        return primaryKeys[tableName]
    }
    
    func setPrimaryKey(primaryKey: PrimaryKey, forTableName tableName: String) {
        primaryKeys[tableName] = primaryKey
    }
    
    func updateStatement(sql sql: String) -> UpdateStatement? {
        return updateStatements[sql]
    }
    
    func setUpdateStatement(statement: UpdateStatement, forSQL sql: String) {
        updateStatements[sql] = statement
    }
    
    func selectStatement(sql sql: String) -> SelectStatement? {
        return selectStatements[sql]
    }
    
    func setSelectStatement(statement: SelectStatement, forSQL sql: String) {
        selectStatements[sql] = statement
    }
}

/// A thread-safe database schema cache
struct SharedDatabaseSchemaCache: DatabaseSchemaCacheType {
    private let cache = ReadWriteBox(DatabaseSchemaCache())
    
    mutating func clear() {
        cache.write { $0.clear() }
    }
    
    func primaryKey(tableName tableName: String) -> PrimaryKey? {
        return cache.read { $0.primaryKey(tableName: tableName) }
    }
    
    mutating func setPrimaryKey(primaryKey: PrimaryKey, forTableName tableName: String) {
        cache.write { $0.setPrimaryKey(primaryKey, forTableName: tableName) }
    }
    
    func updateStatement(sql sql: String) -> UpdateStatement? {
        return cache.read { $0.updateStatement(sql: sql) }
    }
    
    mutating func setUpdateStatement(statement: UpdateStatement, forSQL sql: String) {
        cache.write { $0.setUpdateStatement(statement, forSQL: sql) }
    }
    
    func selectStatement(sql sql: String) -> SelectStatement? {
        return cache.read { $0.selectStatement(sql: sql) }
    }
    
    mutating func setSelectStatement(statement: SelectStatement, forSQL sql: String) {
        cache.write { $0.setSelectStatement(statement, forSQL: sql) }
    }
}
