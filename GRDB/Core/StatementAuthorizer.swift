#if canImport(string_h)
import string_h
#elseif os(Linux)
import Glibc
#elseif os(macOS) || os(iOS) || os(watchOS) || os(tvOS) || os(visionOS)
import Darwin
#endif

/// `StatementAuthorizer` provides information about compiled database
/// statements, and prevents the truncate optimization when row deletions are
/// observed by transaction observers.
///
/// <https://www.sqlite.org/c3ref/set_authorizer.html>
/// <https://www.sqlite.org/lang_delete.html#the_truncate_optimization>
final class StatementAuthorizer {
    private unowned var database: Database
    
    /// What a statement reads.
    var selectedRegion = DatabaseRegion()
    
    /// What a statement writes.
    var databaseEventKinds: [DatabaseEventKind] = []
    
    /// True if a statement alters the schema in a way that requires
    /// invalidation of the schema cache. For example, adding a column to a
    /// table invalidates the schema cache.
    var invalidatesDatabaseSchemaCache = false
    
    /// Not nil if a statement is a BEGIN/COMMIT/ROLLBACK/RELEASE transaction or
    /// savepoint statement.
    var transactionEffect: Statement.TransactionEffect?
    
    private var isDropStatement = false
    
    init(_ database: Database) {
        self.database = database
    }
    
    /// Registers the authorizer with `sqlite3_set_authorizer`.
    func register() {
        let authorizerP = Unmanaged.passUnretained(self).toOpaque()
        sqlite3_set_authorizer(
            database.sqliteConnection,
            { (authorizerP, actionCode, cString1, cString2, cString3, cString4) in
                Unmanaged<StatementAuthorizer>
                    .fromOpaque(authorizerP.unsafelyUnwrapped)
                    .takeUnretainedValue()
                    .authorize(actionCode, cString1, cString2, cString3, cString4)
            },
            authorizerP)
    }
    
    /// Reset before compiling a new statement
    func reset() {
        selectedRegion = DatabaseRegion()
        databaseEventKinds = []
        invalidatesDatabaseSchemaCache = false
        transactionEffect = nil
        isDropStatement = false
    }
    
    private func authorize(
        _ actionCode: CInt,
        _ cString1: UnsafePointer<CChar>?,
        _ cString2: UnsafePointer<CChar>?,
        _ cString3: UnsafePointer<CChar>?,
        _ cString4: UnsafePointer<CChar>?)
    -> CInt
    {
        // Uncomment when debugging
        // print("""
        //     StatementAuthorizer: \
        //     \(AuthorizerActionCode(rawValue: actionCode)) \
        //     \([cString1, cString2, cString3, cString4].compactMap { $0.map(String.init) }.joined(separator: ", "))
        //     """)
        
        switch actionCode {
        case SQLITE_DROP_TABLE, SQLITE_DROP_VTABLE, SQLITE_DROP_TEMP_TABLE,
             SQLITE_DROP_INDEX, SQLITE_DROP_TEMP_INDEX,
             SQLITE_DROP_VIEW, SQLITE_DROP_TEMP_VIEW,
             SQLITE_DROP_TRIGGER, SQLITE_DROP_TEMP_TRIGGER:
            isDropStatement = true
            invalidatesDatabaseSchemaCache = true
            return SQLITE_OK
            
        case SQLITE_ATTACH, SQLITE_DETACH, SQLITE_ALTER_TABLE,
             SQLITE_CREATE_INDEX, SQLITE_CREATE_TABLE,
             SQLITE_CREATE_TEMP_INDEX, SQLITE_CREATE_TEMP_TABLE,
             SQLITE_CREATE_TEMP_TRIGGER, SQLITE_CREATE_TEMP_VIEW,
             SQLITE_CREATE_TRIGGER, SQLITE_CREATE_VIEW,
             SQLITE_CREATE_VTABLE:
            invalidatesDatabaseSchemaCache = true
            return SQLITE_OK
            
        case SQLITE_READ:
            guard let tableName = cString1.map(String.init) else { return SQLITE_OK }
            guard let columnName = cString2.map(String.init) else { return SQLITE_OK }
            if columnName.isEmpty {
                // SELECT COUNT(*) FROM table
                selectedRegion.formUnion(DatabaseRegion(table: tableName))
            } else {
                // SELECT column FROM table
                selectedRegion.formUnion(DatabaseRegion(table: tableName, columns: [columnName]))
            }
            return SQLITE_OK
            
        case SQLITE_INSERT:
            guard let tableName = cString1.map(String.init) else { return SQLITE_OK }
            databaseEventKinds.append(.insert(tableName: tableName))
            return SQLITE_OK
            
        case SQLITE_DELETE:
            if isDropStatement { return SQLITE_OK }
            guard let cString1 else { return SQLITE_OK }
            
            // Deletions from sqlite_master and sqlite_temp_master are not like
            // other deletions: `sqlite3_update_hook` does not notify them, and
            // they are prevented when the truncate optimization is disabled.
            // Let's always authorize such deletions by returning SQLITE_OK:
            guard strcmp(cString1, "sqlite_master") != 0 else { return SQLITE_OK }
            guard strcmp(cString1, "sqlite_temp_master") != 0 else { return SQLITE_OK }
            
            let tableName = String(cString: cString1)
            databaseEventKinds.append(.delete(tableName: tableName))
            
            if let observationBroker = database.observationBroker,
               observationBroker.observesDeletions(on: tableName)
            {
                // Prevent the truncate optimization so that
                // `sqlite3_update_hook` notifies individual row deletions to
                // transaction observers.
                return SQLITE_IGNORE
            } else {
                return SQLITE_OK
            }
            
        case SQLITE_UPDATE:
            guard let tableName = cString1.map(String.init) else { return SQLITE_OK }
            guard let columnName = cString2.map(String.init) else { return SQLITE_OK }
            insertUpdateEventKind(tableName: tableName, columnName: columnName)
            return SQLITE_OK
            
        case SQLITE_TRANSACTION:
            guard let cString1 else { return SQLITE_OK }
            if strcmp(cString1, "BEGIN") == 0 {
                transactionEffect = .beginTransaction
            } else if strcmp(cString1, "COMMIT") == 0 {
                transactionEffect = .commitTransaction
            } else if strcmp(cString1, "ROLLBACK") == 0 {
                transactionEffect = .rollbackTransaction
            }
            return SQLITE_OK
            
        case SQLITE_SAVEPOINT:
            guard let cString1 else { return SQLITE_OK }
            guard let name = cString2.map(String.init) else { return SQLITE_OK }
            if strcmp(cString1, "BEGIN") == 0 {
                transactionEffect = .beginSavepoint(name)
            } else if strcmp(cString1, "RELEASE") == 0 {
                transactionEffect = .releaseSavepoint(name)
            } else if strcmp(cString1, "ROLLBACK") == 0 {
                transactionEffect = .rollbackSavepoint(name)
            }
            return SQLITE_OK
            
        case SQLITE_FUNCTION:
            // SQLite 3.37.2 does not report ALTER TABLE DROP COLUMN with the
            // SQLITE_ALTER_TABLE action code. SQLite 3.38 does.
            //
            // Until SQLite 3.38, we need to find another way to set the
            // `invalidatesDatabaseSchemaCache` flag for such
            // statement, and it is SQLITE_FUNCTION sqlite_drop_column.
            //
            // See <https://github.com/groue/GRDB.swift/pull/1144#issuecomment-1015155717>
            // See <https://sqlite.org/forum/forumpost/bd47580ec2>
            if sqlite3_libversion_number() < 3038000,
               let cString2,
               strcmp(cString2, "sqlite_drop_column") == 0
            {
                invalidatesDatabaseSchemaCache = true
            }
            return SQLITE_OK
            
        default:
            return SQLITE_OK
        }
    }
    
    private func insertUpdateEventKind(tableName: String, columnName: String) {
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

private struct AuthorizerActionCode: RawRepresentable, CustomStringConvertible {
    let rawValue: CInt
    
    var description: String {
        switch rawValue {
        case 1: return "SQLITE_CREATE_INDEX"
        case 2: return "SQLITE_CREATE_TABLE"
        case 3: return "SQLITE_CREATE_TEMP_INDEX"
        case 4: return "SQLITE_CREATE_TEMP_TABLE"
        case 5: return "SQLITE_CREATE_TEMP_TRIGGER"
        case 6: return "SQLITE_CREATE_TEMP_VIEW"
        case 7: return "SQLITE_CREATE_TRIGGER"
        case 8: return "SQLITE_CREATE_VIEW"
        case 9: return "SQLITE_DELETE"
        case 10: return "SQLITE_DROP_INDEX"
        case 11: return "SQLITE_DROP_TABLE"
        case 12: return "SQLITE_DROP_TEMP_INDEX"
        case 13: return "SQLITE_DROP_TEMP_TABLE"
        case 14: return "SQLITE_DROP_TEMP_TRIGGER"
        case 15: return "SQLITE_DROP_TEMP_VIEW"
        case 16: return "SQLITE_DROP_TRIGGER"
        case 17: return "SQLITE_DROP_VIEW"
        case 18: return "SQLITE_INSERT"
        case 19: return "SQLITE_PRAGMA"
        case 20: return "SQLITE_READ"
        case 21: return "SQLITE_SELECT"
        case 22: return "SQLITE_TRANSACTION"
        case 23: return "SQLITE_UPDATE"
        case 24: return "SQLITE_ATTACH"
        case 25: return "SQLITE_DETACH"
        case 26: return "SQLITE_ALTER_TABLE"
        case 27: return "SQLITE_REINDEX"
        case 28: return "SQLITE_ANALYZE"
        case 29: return "SQLITE_CREATE_VTABLE"
        case 30: return "SQLITE_DROP_VTABLE"
        case 31: return "SQLITE_FUNCTION"
        case 32: return "SQLITE_SAVEPOINT"
        case 0: return "SQLITE_COPY"
        case 33: return "SQLITE_RECURSIVE"
        default: return "\(rawValue)"
        }
    }
}
