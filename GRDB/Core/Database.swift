/// A nicer name than COpaquePointer for SQLite connection handle
typealias SQLiteConnection = COpaquePointer

/**
A Database connection.

You don't create a database directly. Instead, you use a DatabaseQueue:

    let dbQueue = DatabaseQueue(...)

    // The Database is the `db` in the closure:
    dbQueue.inDatabase { db in
        db.execute(...)
    }
*/
public final class Database {
    
    // MARK: - Select Statements
    
    /**
    Returns a select statement that can be reused.
    
        let statement = db.selectStatement("SELECT * FROM persons WHERE age > ?")
        let moreThanTwentyCount = Int.fetchOne(statement, arguments: [20])!
        let moreThanThirtyCount = Int.fetchOne(statement, arguments: [30])!
    
    - parameter sql: An SQL query.
    - returns: A SelectStatement.
    */
    public func selectStatement(sql: String) -> SelectStatement {
        return try! SelectStatement(database: self, sql: sql)
    }
    
    
    // MARK: - Update Statements
    
    /**
    Returns an update statement that can be reused.
    
        let statement = try db.updateStatement("INSERT INTO persons (name) VALUES (?)")
        try statement.execute(arguments: ["Arthur"])
        try statement.execute(arguments: ["Barbara"])
    
    This method may throw a DatabaseError.
    
    - parameter sql: An SQL query.
    - returns: An UpdateStatement.
    - throws: A DatabaseError whenever a SQLite error occurs.
    */
    public func updateStatement(sql: String) -> UpdateStatement {
        return try! UpdateStatement(database: self, sql: sql)
    }
    
    /**
    Executes an update statement.
    
        db.excute("INSERT INTO persons (name) VALUES (?)", arguments: ["Arthur"])
    
    This method may throw a DatabaseError.
    
    - parameter sql: An SQL query.
    - parameter arguments: Optional query arguments.
    - returns: A DatabaseChanges.
    - throws: A DatabaseError whenever a SQLite error occurs.
    */
    public func execute(sql: String, arguments: StatementArguments? = nil) throws -> DatabaseChanges {
        let statement = updateStatement(sql)
        return try statement.execute(arguments: arguments)
    }
    
    
    /**
    Executes multiple SQL statements (separated by a semi-colon).
    
        try db.executeMultiStatement(
            "INSERT INTO persons (name) VALUES ('Harry');" +
            "INSERT INTO persons (name) VALUES ('Ron');" +
            "INSERT INTO persons (name) VALUES ('Hermione');")
    
    This method may throw a DatabaseError.
    
    - parameter sql: SQL containing multiple statements separated by semi-colons.
    - returns: A DatabaseChanges. Note that insertedRowID will always be nil.
    - throws: A DatabaseError whenever a SQLite error occurs.
    */
    public func executeMultiStatement(sql: String) throws -> DatabaseChanges {
        assertValidQueue()
        
        if let trace = self.configuration.trace {
            trace(sql: sql, arguments: nil)
        }
        
        let changedRowsBefore = sqlite3_total_changes(self.sqliteConnection)
        
        let code = sqlite3_exec(self.sqliteConnection, sql, nil, nil, nil)
        guard code == SQLITE_OK else {
            throw DatabaseError(code: code, message: self.lastErrorMessage, sql: sql, arguments: nil)
        }
        
        let changedRowsAfter = sqlite3_total_changes(self.sqliteConnection)
        return DatabaseChanges(changedRowCount: changedRowsAfter - changedRowsBefore, insertedRowID: nil)
    }
    
    
    // MARK: - Transactions
    
    /// A SQLite transaction type. See https://www.sqlite.org/lang_transaction.html
    public enum TransactionType {
        case Deferred
        case Immediate
        case Exclusive
    }
    
    /// The end of a transaction: Commit, or Rollback
    public enum TransactionCompletion {
        case Commit
        case Rollback
    }
    
    /**
    Executes a block inside a database transaction.
    
        try dbQueue.inTransaction do {
            try db.execute("INSERT ...")
            return .Commit
        }
    
    If the block throws an error, the transaction is rollbacked and the error is
    rethrown.
    
    This method is not reentrant: you can't nest transactions.
    
    - parameter type:  The transaction type
                       See https://www.sqlite.org/lang_transaction.html
    - parameter block: A block that executes SQL statements and return either
                       .Commit or .Rollback.
    - throws: The error thrown by the block.
    */
    func inTransaction(type: TransactionType?, block: () throws -> TransactionCompletion) throws {
        var completion: TransactionCompletion = .Rollback
        var blockError: ErrorType? = nil
        
        try beginTransaction(type)
        
        do {
            completion = try block()
        } catch {
            completion = .Rollback
            blockError = error
        }
        
        switch completion {
        case .Commit:
            try commit()
        case .Rollback:
            // https://www.sqlite.org/lang_transaction.html#immediate
            //
            // > Response To Errors Within A Transaction
            //
            // > If certain kinds of errors occur within a transaction, the
            // > transaction may or may not be rolled back automatically. The
            // > errors that can cause an automatic rollback include:
            // >
            // > - SQLITE_FULL: database or disk full
            // > - SQLITE_IOERR: disk I/O error
            // > - SQLITE_BUSY: database in use by another process
            // > - SQLITE_NOMEM: out or memory
            // >
            // > [...] It is recommended that applications respond to the errors
            // > listed above by explicitly issuing a ROLLBACK command. If the
            // > transaction has already been rolled back automatically by the
            // > error response, then the ROLLBACK command will fail with an
            // > error, but no harm is caused by this.
            if let blockError = blockError as? DatabaseError {
                switch Int32(blockError.code) {
                case SQLITE_FULL, SQLITE_IOERR, SQLITE_BUSY, SQLITE_NOMEM:
                    do { try rollback() } catch { }
                default:
                    try rollback()
                }
            } else {
                try rollback()
            }
        }
        
        if let blockError = blockError {
            throw blockError
        }
    }
    
    private func beginTransaction(type: TransactionType? = nil) throws {
        switch type ?? configuration.transactionType {
        case .Deferred:
            try execute("BEGIN DEFERRED TRANSACTION")
        case .Immediate:
            try execute("BEGIN IMMEDIATE TRANSACTION")
        case .Exclusive:
            try execute("BEGIN EXCLUSIVE TRANSACTION")
        }
    }
    
    private func rollback() throws {
        try execute("ROLLBACK TRANSACTION")
    }
    
    private func commit() throws {
        try execute("COMMIT TRANSACTION")
    }
    
    
    // MARK: - Transaction Delegate
    
    /// EXPERIMENTAL
    public weak var transactionDelegate: DatabaseTransactionDelegate? = nil {
        willSet {
            assertValidQueue()
        }
        didSet {
            if transactionDelegate == nil {
                sqlite3_update_hook(sqliteConnection, nil, nil)
                sqlite3_commit_hook(sqliteConnection, nil, nil)
                sqlite3_rollback_hook(sqliteConnection, nil, nil)
                return
            }
            
            let dbPointer = unsafeBitCast(self, UnsafeMutablePointer<Void>.self)
            
            sqlite3_update_hook( sqliteConnection, { (dbPointer, updateKind, databaseName, tableName, rowID) in
                let event = DatabaseEvent(
                    kind: DatabaseEvent.Kind(rawValue: updateKind)!,
                    databaseName: String.fromCString(databaseName)!,
                    tableName: String.fromCString(tableName)!,
                    rowID: rowID)
                let database = unsafeBitCast(dbPointer, Database.self)
                database.transactionDelegate!.databaseDidChangeWithEvent(event)
                }, dbPointer)
            
            sqlite3_commit_hook(sqliteConnection, { dbPointer in
                let database = unsafeBitCast(dbPointer, Database.self)
                if database.transactionDelegate!.databaseShouldCommit() {
                    database.transactionDelegate!.databaseWillCommit()
                    return 0
                } else {
                    return 1
                }
                }, dbPointer)
            
            sqlite3_rollback_hook(sqliteConnection, { dbPointer in
                let database = unsafeBitCast(dbPointer, Database.self)
                database.transactionDelegate!.databaseWillRollback()
                }, dbPointer)
        }
    }
    
    
    
    // MARK: - Database Informations
    
    /// The last error message
    var lastErrorMessage: String? { return String.fromCString(sqlite3_errmsg(sqliteConnection)) }
    
    /**
    Returns whether a table exists.
    
    - parameter tableName: A table name.
    - returns: true if the table exists.
    */
    public func tableExists(tableName: String) -> Bool {
        // SQlite identifiers are case-insensitive, case-preserving (http://www.alberton.info/dbms_identifiers_and_case_sensitivity.html)
        return Row.fetchOne(self,
            "SELECT \"sql\" FROM sqlite_master WHERE \"type\" = 'table' AND LOWER(name) = ?",
            arguments: [tableName.lowercaseString]) != nil
    }
    
    /// Return the primary key for table named `tableName`, or nil if table does
    /// not exist.
    ///
    /// This method is not thread-safe.
    func primaryKeyForTable(named tableName: String) -> PrimaryKey? {
        // https://www.sqlite.org/pragma.html
        //
        // > PRAGMA database.table_info(table-name);
        // >
        // > This pragma returns one row for each column in the named table.
        // > Columns in the result set include the column name, data type,
        // > whether or not the column can be NULL, and the default value for
        // > the column. The "pk" column in the result set is zero for columns
        // > that are not part of the primary key, and is the index of the
        // > column in the primary key for columns that are part of the primary
        // > key.
        //
        // CREATE TABLE persons (
        //   id INTEGER PRIMARY KEY,
        //   firstName TEXT,
        //   lastName TEXT)
        //
        // PRAGMA table_info("persons")
        //
        // cid | name      | type    | notnull | dflt_value | pk |
        // 0   | id        | INTEGER | 0       | NULL       | 1  |
        // 1   | firstName | TEXT    | 0       | NULL       | 0  |
        // 2   | lastName  | TEXT    | 0       | NULL       | 0  |
        
        let columnInfos = columnInfosForTable(named: tableName)
        guard columnInfos.count > 0 else {
            // Table does not exist
            return nil
        }
        
        let pkColumnInfos = columnInfos
            .filter { $0.primaryKeyIndex > 0 }
            .sort { $0.primaryKeyIndex < $1.primaryKeyIndex }
        
        switch pkColumnInfos.count {
        case 0:
            // No primary key column
            return PrimaryKey.None
        case 1:
            // Single column
            let pkColumnInfo = pkColumnInfos.first!
            
            // https://www.sqlite.org/lang_createtable.html:
            //
            // > With one exception noted below, if a rowid table has a primary
            // > key that consists of a single column and the declared type of
            // > that column is "INTEGER" in any mixture of upper and lower
            // > case, then the column becomes an alias for the rowid. Such a
            // > column is usually referred to as an "integer primary key".
            // > A PRIMARY KEY column only becomes an integer primary key if the
            // > declared type name is exactly "INTEGER". Other integer type
            // > names like "INT" or "BIGINT" or "SHORT INTEGER" or "UNSIGNED
            // > INTEGER" causes the primary key column to behave as an ordinary
            // > table column with integer affinity and a unique index, not as
            // > an alias for the rowid.
            // >
            // > The exception mentioned above is that if the declaration of a
            // > column with declared type "INTEGER" includes an "PRIMARY KEY
            // > DESC" clause, it does not become an alias for the rowid [...]
            //
            // We ignore the exception, and consider all INTEGER primary keys as
            // aliases for the rowid:
            if pkColumnInfo.type.uppercaseString == "INTEGER" {
                return .Managed(pkColumnInfo.name)
            } else {
                return .Unmanaged([pkColumnInfo.name])
            }
        default:
            // Multi-columns primary key
            return .Unmanaged(pkColumnInfos.map { $0.name })
        }
    }
    
    // CREATE TABLE persons (
    //   id INTEGER PRIMARY KEY,
    //   firstName TEXT,
    //   lastName TEXT)
    //
    // PRAGMA table_info("persons")
    //
    // cid | name      | type    | notnull | dflt_value | pk |
    // 0   | id        | INTEGER | 0       | NULL       | 1  |
    // 1   | firstName | TEXT    | 0       | NULL       | 0  |
    // 2   | lastName  | TEXT    | 0       | NULL       | 0  |
    struct ColumnInfo : RowConvertible {
        let name: String
        let type: String
        let notNull: Bool
        let defaultDatabaseValue: DatabaseValue
        let primaryKeyIndex: Int
        init(row: Row) {
            name = row.value(named: "name")!
            type = row.value(named: "type")!
            notNull = row.value(named: "notnull")!
            defaultDatabaseValue = row["dflt_value"]!
            primaryKeyIndex = row.value(named: "pk")!
        }
    }
    
    // Cache for columnInfosForTable(named:)
    private var columnInfosCache: [String: [ColumnInfo]] = [:]
    func columnInfosForTable(named tableName: String) -> [ColumnInfo] {
        if let columnInfos = columnInfosCache[tableName] {
            return columnInfos
        } else {
            // This pragma is case-insensitive: PRAGMA table_info("PERSONS") and
            // PRAGMA table_info("persons") yield the same results.
            let columnInfos = ColumnInfo.fetchAll(self, "PRAGMA table_info(\(tableName.quotedDatabaseIdentifier))")
            columnInfosCache[tableName] = columnInfos
            return columnInfos
        }
    }
    
    
    // MARK: - Initialization
    
    /// See BusyMode and https://www.sqlite.org/c3ref/busy_handler.html
    public typealias BusyCallback = (numberOfTries: Int) -> Bool
    
    /**
    When there are several connections to a database, a connection may try to
    access the database while it is locked by another connection.
    
    The BusyMode enum describes the behavior of GRDB when such a situation
    occurs:
    
    - .ImmediateError: The SQLITE_BUSY error is immediately returned to the
      connection that tries to access the locked database.
    
    - .Timeout: The SQLITE_BUSY error will be returned only if the database
      remains locked for more than the specified duration.
    
    - .Callback: Perform your custom lock handling.
    
    To set the busy mode of a database, use Configuration:
    
        let configuration = Configuration(busyMode: .Timeout(1))
        let dbQueue = DatabaseQueue(path: "...", configuration: configuration)
    
    Relevant SQLite documentation:
    
    - https://www.sqlite.org/c3ref/busy_timeout.html
    - https://www.sqlite.org/c3ref/busy_handler.html
    - https://www.sqlite.org/lang_transaction.html
    - https://www.sqlite.org/wal.html
    */
    public enum BusyMode {
        /// The SQLITE_BUSY error is immediately returned to the connection that
        /// tries to access the locked database.
        case ImmediateError
        
        /// The SQLITE_BUSY error will be returned only if the database remains
        /// locked for more than the specified duration.
        case Timeout(NSTimeInterval)
        
        /// A custom callback that is called when a database is locked.
        /// See https://www.sqlite.org/c3ref/busy_handler.html
        case Callback(BusyCallback)
    }
    
    /// The database configuration
    let configuration: Configuration
    
    /// The busy handler callback, if any. See Configuration.busyMode.
    var busyCallback: BusyCallback?
    
    /// The SQLite connection handle
    let sqliteConnection: SQLiteConnection
    
    /// The queue from which the database can be used. See assertValidQueue().
    /// Design note: this is not very clean. A delegation pattern may be a
    /// better fit.
    var databaseQueueID: DatabaseQueueID = nil
    
    init(path: String, configuration: Configuration) throws {
        self.configuration = configuration
        
        // See https://www.sqlite.org/c3ref/open.html
        var sqliteConnection = SQLiteConnection()
        let code = sqlite3_open_v2(path, &sqliteConnection, configuration.sqliteOpenFlags, nil)
        self.sqliteConnection = sqliteConnection
        if code != SQLITE_OK {
            throw DatabaseError(code: code, message: String.fromCString(sqlite3_errmsg(sqliteConnection)))
        }
        
        if configuration.foreignKeysEnabled {
            try execute("PRAGMA foreign_keys = ON")
        }
        
        setupBusyMode(configuration.busyMode)
    }
    
    // Initializes an in-memory database
    convenience init(configuration: Configuration) {
        try! self.init(path: ":memory:", configuration: configuration)
    }
    
    deinit {
        sqlite3_close(sqliteConnection)
    }
    
    func assertValidQueue() {
        guard databaseQueueID == nil || databaseQueueID == dispatch_get_specific(DatabaseQueue.databaseQueueIDKey) else {
            fatalError("Database was not used on the correct queue. Execute your statements inside DatabaseQueue.inDatabase() or DatabaseQueue.inTransaction(). Consider using fetchAll() method if this error message happens when iterating the result of the fetch() method.")
        }
    }
    
    func setupBusyMode(busyMode: BusyMode) {
        switch busyMode {
        case .ImmediateError:
            break
            
        case .Timeout(let duration):
            let milliseconds = Int32(duration * 1000)
            sqlite3_busy_timeout(sqliteConnection, milliseconds)
            
        case .Callback(let callback):
            let dbPointer = unsafeBitCast(self, UnsafeMutablePointer<Void>.self)
            self.busyCallback = callback
            
            sqlite3_busy_handler(
                sqliteConnection,
                { (dbPointer: UnsafeMutablePointer<Void>, numberOfTries: Int32) in
                    let database = unsafeBitCast(dbPointer, Database.self)
                    let callback = database.busyCallback!
                    return callback(numberOfTries: Int(numberOfTries)) ? 1 : 0
                },
                dbPointer)
        }
    }
}


// MARK: - PrimaryKey

/// A primary key
enum PrimaryKey {
    
    /// No primary key
    case None
    
    /// A primary key managed by SQLite. Associated string is a column name.
    case Managed(String)
    
    /// A primary key not managed by SQLite. It can span accross several
    /// columns. Associated strings are column names.
    case Unmanaged([String])
    
    /// The columns in the primary key. May be empty.
    var columns: [String] {
        switch self {
        case .None:
            return []
        case .Managed(let column):
            return [column]
        case .Unmanaged(let columns):
            return columns
        }
    }
}

