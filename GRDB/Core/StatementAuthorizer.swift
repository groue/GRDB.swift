#if os(Linux)
    import Glibc
#endif
#if SWIFT_PACKAGE
    import CSQLite
#elseif GRDBCIPHER
    import SQLCipher
#elseif !GRDBCUSTOMSQLITE && !GRDBCIPHER
    import SQLite3
#endif

/// A protocol around sqlite3_set_authorizer
protocol StatementAuthorizer : class {
    func authorize(
        _ actionCode: Int32,
        _ cString1: UnsafePointer<Int8>?,
        _ cString2: UnsafePointer<Int8>?,
        _ cString3: UnsafePointer<Int8>?,
        _ cString4: UnsafePointer<Int8>?)
        -> Int32
}

/// A class that gathers information about one statement during its compilation.
final class StatementCompilationAuthorizer : StatementAuthorizer {
    /// What this statements reads
    var databaseRegion = DatabaseRegion()
    
    /// What this statements writes
    var databaseEventKinds: [DatabaseEventKind] = []
    
    /// True if a statement alter the schema in a way that required schema cache
    /// invalidation. For example, adding a column to a table invalidates the
    /// schema cache, but not creating a table.
    var invalidatesDatabaseSchemaCache = false
    
    /// Not nil if a statement is a BEGIN/COMMIT/ROLLBACK/RELEASE transaction or
    /// savepoint statement.
    var transactionEffect: UpdateStatement.TransactionEffect?
    
    private var isDropStatement = false
    
    func authorize(
        _ actionCode: Int32,
        _ cString1: UnsafePointer<Int8>?,
        _ cString2: UnsafePointer<Int8>?,
        _ cString3: UnsafePointer<Int8>?,
        _ cString4: UnsafePointer<Int8>?)
        -> Int32
    {
        // print("StatementCompilationAuthorizer: \(actionCode) \([cString1, cString2, cString3, cString4].flatMap { $0.map({ String(cString: $0) }) })")
        
        switch actionCode {
        case SQLITE_DROP_TABLE, SQLITE_DROP_VTABLE, SQLITE_DROP_TEMP_TABLE,
             SQLITE_DROP_INDEX, SQLITE_DROP_TEMP_INDEX,
             SQLITE_DROP_VIEW, SQLITE_DROP_TEMP_VIEW,
             SQLITE_DROP_TRIGGER, SQLITE_DROP_TEMP_TRIGGER:
            isDropStatement = true
            invalidatesDatabaseSchemaCache = true
            return SQLITE_OK
            
        case SQLITE_ALTER_TABLE, SQLITE_DETACH,
             SQLITE_CREATE_INDEX, SQLITE_CREATE_TABLE,
             SQLITE_CREATE_TEMP_INDEX, SQLITE_CREATE_TEMP_TABLE,
             SQLITE_CREATE_TEMP_TRIGGER, SQLITE_CREATE_TEMP_VIEW,
             SQLITE_CREATE_TRIGGER, SQLITE_CREATE_VIEW:
            invalidatesDatabaseSchemaCache = true
            return SQLITE_OK
            
        case SQLITE_READ:
            guard let tableName = cString1.map({ String(cString: $0) }) else { return SQLITE_OK }
            guard let columnName = cString2.map({ String(cString: $0) }) else { return SQLITE_OK }
            if columnName.isEmpty {
                // SELECT COUNT(*) FROM table
                databaseRegion.formUnion(DatabaseRegion(table: tableName))
            } else {
                // SELECT column FROM table
                databaseRegion.formUnion(DatabaseRegion(table: tableName, columns: [columnName]))
            }
            return SQLITE_OK
            
        case SQLITE_INSERT:
            guard let tableName = cString1.map({ String(cString: $0) }) else { return SQLITE_OK }
            databaseEventKinds.append(.insert(tableName: tableName))
            return SQLITE_OK
            
        case SQLITE_DELETE:
            if isDropStatement { return SQLITE_OK }
            guard let cString1 = cString1 else { return SQLITE_OK }
            
            // Deletions from sqlite_master and sqlite_temp_master are not like
            // other deletions: the update hook does not notify them, and they
            // are prevented when the truncate optimization is disabled.
            // Let's authorize such deletions by returning SQLITE_OK:
            guard strcmp(cString1, "sqlite_master") != 0 else { return SQLITE_OK }
            guard strcmp(cString1, "sqlite_temp_master") != 0 else { return SQLITE_OK }
            
            // Now we prevent the truncate optimization so that transaction
            // observers are notified of individual row deletions.
            databaseEventKinds.append(.delete(tableName: String(cString: cString1)))
            return SQLITE_IGNORE
            
        case SQLITE_UPDATE:
            guard let tableName = cString1.map({ String(cString: $0) }) else { return SQLITE_OK }
            guard let columnName = cString2.map({ String(cString: $0) }) else { return SQLITE_OK }
            insertUpdateEventKind(tableName: tableName, columnName: columnName)
            return SQLITE_OK
            
        case SQLITE_TRANSACTION:
            guard let cString1 = cString1 else { return SQLITE_OK }
            if strcmp(cString1, "BEGIN") == 0 {
                transactionEffect = .beginTransaction
            } else if strcmp(cString1, "COMMIT") == 0 {
                transactionEffect = .commitTransaction
            } else if strcmp(cString1, "ROLLBACK") == 0 {
                transactionEffect = .rollbackTransaction
            }
            return SQLITE_OK
            
        case SQLITE_SAVEPOINT:
            guard let cString1 = cString1 else { return SQLITE_OK }
            guard let name = cString2.map({ String(cString: $0) }) else { return SQLITE_OK }
            if strcmp(cString1, "BEGIN") == 0 {
                transactionEffect = .beginSavepoint(name)
            } else if strcmp(cString1, "RELEASE") == 0 {
                transactionEffect = .releaseSavepoint(name)
            } else if strcmp(cString1, "ROLLBACK") == 0 {
                transactionEffect = .rollbackSavepoint(name)
            }
            return SQLITE_OK
            
        case SQLITE_FUNCTION:
            // Starting SQLite 3.19.0, `SELECT COUNT(*) FROM table` triggers
            // an authorization callback for SQLITE_READ with an empty
            // column: http://www.sqlite.org/changes.html#version_3_19_0
            //
            // Before SQLite 3.19.0, `SELECT COUNT(*) FROM table` does not
            // trigger any authorization callback that tells about the
            // counted table: any use of the COUNT function makes the
            // region undetermined (the full database).
            guard sqlite3_libversion_number() < 3019000 else { return SQLITE_OK }
            guard let cString2 = cString2 else { return SQLITE_OK }
            if sqlite3_stricmp(cString2, "COUNT") == 0 {
                databaseRegion = .fullDatabase
            }
            return SQLITE_OK
            
        default:
            return SQLITE_OK
        }
    }
    
    func insertUpdateEventKind(tableName: String, columnName: String) {
        for (index, eventKind) in databaseEventKinds.enumerated() {
            if case .update(let t, let columnNames) = eventKind, t == tableName {
                var columnNames = columnNames
                columnNames.insert(columnName)
                databaseEventKinds[index] = .update(tableName: tableName, columnNames: columnNames)
                return
            }
        }
        databaseEventKinds.append(.update(tableName: tableName, columnNames: [columnName]))
    }
}

/// This authorizer prevents the [truncate optimization](https://www.sqlite.org/lang_delete.html#truncateopt)
/// which makes transaction observers unable to observe individual deletions
/// when user runs `DELETE FROM t` statements.
//
/// Warning: to perform well, this authorizer must be used during statement
/// execution, not during statement compilation.
final class TruncateOptimizationBlocker : StatementAuthorizer {
    func authorize(
        _ actionCode: Int32,
        _ cString1: UnsafePointer<Int8>?,
        _ cString2: UnsafePointer<Int8>?,
        _ cString3: UnsafePointer<Int8>?,
        _ cString4: UnsafePointer<Int8>?)
        -> Int32
    {
        // print("TruncateOptimizationBlocker: \(actionCode) \([cString1, cString2, cString3, cString4].flatMap { $0.map({ String(cString: $0) }) })")
        return (actionCode == SQLITE_DELETE) ? SQLITE_IGNORE : SQLITE_OK
    }
}

