import Foundation

/// A raw SQLite connection, suitable for the SQLite C API.
public typealias SQLiteConnection = COpaquePointer

/// A Database connection.
///
/// You don't create a database directly. Instead, you use a DatabaseQueue:
///
///     let dbQueue = DatabaseQueue(...)
///
///     // The Database is the `db` in the closure:
///     dbQueue.inDatabase { db in
///         db.execute(...)
///     }
public final class Database {
    
    // =========================================================================
    // MARK: - Select Statements
    
    /// Returns a select statement that can be reused.
    ///
    ///     let statement = db.selectStatement("SELECT * FROM persons WHERE age > ?")
    ///     let moreThanTwentyCount = Int.fetchOne(statement, arguments: [20])!
    ///     let moreThanThirtyCount = Int.fetchOne(statement, arguments: [30])!
    ///
    /// - parameter sql: An SQL query.
    /// - returns: A SelectStatement.
    public func selectStatement(sql: String) -> SelectStatement {
        return try! SelectStatement(database: self, sql: sql)
    }
    
    
    // =========================================================================
    // MARK: - Update Statements
    
    /// Returns an update statement that can be reused.
    ///
    ///     let statement = try db.updateStatement("INSERT INTO persons (name) VALUES (?)")
    ///     try statement.execute(arguments: ["Arthur"])
    ///     try statement.execute(arguments: ["Barbara"])
    ///
    /// This method may throw a DatabaseError.
    ///
    /// - parameter sql: An SQL query.
    /// - returns: An UpdateStatement.
    /// - throws: A DatabaseError whenever a SQLite error occurs.
    public func updateStatement(sql: String) -> UpdateStatement {
        return try! UpdateStatement(database: self, sql: sql)
    }
    
    /// Executes an update statement.
    ///
    ///     db.excute("INSERT INTO persons (name) VALUES (?)", arguments: ["Arthur"])
    ///
    /// This method may throw a DatabaseError.
    ///
    /// - parameter sql: An SQL query.
    /// - parameter arguments: Statement arguments.
    /// - returns: A DatabaseChanges.
    /// - throws: A DatabaseError whenever a SQLite error occurs.
    public func execute(sql: String, arguments: StatementArguments = StatementArguments.Default) throws -> DatabaseChanges {
        let statement = updateStatement(sql)
        return try statement.execute(arguments: arguments)
    }
    
    /// Executes multiple SQL statements (separated by a semi-colon).
    ///
    ///     try db.executeMultiStatement(
    ///         "INSERT INTO persons (name) VALUES ('Harry');" +
    ///         "INSERT INTO persons (name) VALUES ('Ron');" +
    ///         "INSERT INTO persons (name) VALUES ('Hermione');")
    ///
    /// This method may throw a DatabaseError.
    ///
    /// - parameter sql: SQL containing multiple statements separated by
    ///   semi-colons.
    /// - returns: A DatabaseChanges. Note that insertedRowID will always be nil.
    /// - throws: A DatabaseError whenever a SQLite error occurs.
    public func executeMultiStatement(sql: String) throws -> DatabaseChanges {
        assertValidQueue()
        
        let changedRowsBefore = sqlite3_total_changes(self.sqliteConnection)
        
        let code = sqlite3_exec(self.sqliteConnection, sql, nil, nil, nil)
        guard code == SQLITE_OK else {
            throw DatabaseError(code: code, message: self.lastErrorMessage, sql: sql, arguments: nil)
        }
        
        let changedRowsAfter = sqlite3_total_changes(self.sqliteConnection)
        return DatabaseChanges(changedRowCount: changedRowsAfter - changedRowsBefore, insertedRowID: nil)
    }
    
    
    // =========================================================================
    // MARK: - Transactions
    
    /// Executes a block inside a database transaction.
    ///
    ///     try dbQueue.inDatabase do {
    ///         try db.inTransaction {
    ///             try db.execute("INSERT ...")
    ///             return .Commit
    ///         }
    ///     }
    ///
    /// If the block throws an error, the transaction is rollbacked and the
    /// error is rethrown.
    ///
    /// This method is not reentrant: you can't nest transactions.
    ///
    /// - parameter kind: The transaction type (default nil). If nil, the
    ///   transaction type is configuration.defaultTransactionKind, which itself
    ///   defaults to .Immediate. See https://www.sqlite.org/lang_transaction.html
    ///   for more information.
    /// - parameter block: A block that executes SQL statements and return
    ///   either .Commit or .Rollback.
    /// - throws: The error thrown by the block.
    public func inTransaction(kind: TransactionKind? = nil, block: () throws -> TransactionCompletion) throws {
        assertValidQueue()
        
        var completion: TransactionCompletion = .Rollback
        var blockError: ErrorType? = nil
        
        try beginTransaction(kind)
        
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
            // >
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
    
    private func beginTransaction(kind: TransactionKind? = nil) throws {
        switch kind ?? configuration.defaultTransactionKind {
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
    
    
    // =========================================================================
    // MARK: - Transaction Observation
    
    private enum StatementCompletion {
        // Statement has ended with a commit (implicit or explicit).
        case TransactionCommit
        
        // Statement has ended with a rollback.
        case TransactionRollback
        
        // Statement has been rollbacked by transactionObserver.
        case TransactionErrorRollback(ErrorType)
        
        // All other cases (CREATE TABLE, etc.)
        case Regular
    }
    
    /// Updated in SQLite callbacks (see setupTransactionHooks())
    /// Consumed in updateStatementDidFail() and updateStatementDidExecute().
    private var statementCompletion: StatementCompletion = .Regular
    
    func updateStatementDidFail() throws {
        let statementCompletion = self.statementCompletion
        self.statementCompletion = .Regular
        
        switch statementCompletion {
        case .TransactionErrorRollback(let error):
            // The transaction has been rollbacked from
            // TransactionObserverType.transactionWillCommit().
            configuration.transactionObserver!.databaseDidRollback(self)
            throw error
        default:
            break
        }
    }
    
    func updateStatementDidExecute() {
        let statementCompletion = self.statementCompletion
        self.statementCompletion = .Regular
        
        switch statementCompletion {
        case .TransactionCommit:
            configuration.transactionObserver!.databaseDidCommit(self)
        case .TransactionRollback:
            configuration.transactionObserver!.databaseDidRollback(self)
        default:
            break
        }
    }
    
    private func setupTransactionHooks() {
        // No need to setup any hook when there is no transactionObserver:
        guard configuration.transactionObserver != nil else {
            return
        }
        
        let dbPointer = unsafeBitCast(self, UnsafeMutablePointer<Void>.self)
        
        
        sqlite3_update_hook(sqliteConnection, { (dbPointer, updateKind, databaseName, tableName, rowID) in
            let db = unsafeBitCast(dbPointer, Database.self)
            
            // Notify change event
            let event = DatabaseEvent(
                kind: DatabaseEvent.Kind(rawValue: updateKind)!,
                databaseName: String.fromCString(databaseName)!,
                tableName: String.fromCString(tableName)!,
                rowID: rowID)
            db.configuration.transactionObserver!.databaseDidChangeWithEvent(event)
            }, dbPointer)
        
        
        sqlite3_commit_hook(sqliteConnection, { dbPointer in
            let db = unsafeBitCast(dbPointer, Database.self)
            
            do {
                try db.configuration.transactionObserver!.databaseWillCommit()
                // Next step: updateStatementDidExecute()
                db.statementCompletion = .TransactionCommit
                return 0
            } catch {
                // Next step: sqlite3_rollback_hook callback
                db.statementCompletion = .TransactionErrorRollback(error)
                return 1
            }
            }, dbPointer)
        
        
        sqlite3_rollback_hook(sqliteConnection, { dbPointer in
            let db = unsafeBitCast(dbPointer, Database.self)
            
            switch db.statementCompletion {
            case .TransactionErrorRollback:
                // The transactionObserver has rollbacked the transaction.
                // Don't lose this information.
                // Next step: updateStatementDidFail()
                break
            default:
                // Next step: updateStatementDidExecute()
                db.statementCompletion = .TransactionRollback
            }
            }, dbPointer)
    }
    
    
    // =========================================================================
    // MARK: - Concurrency
    
    /// The busy handler callback, if any. See Configuration.busyMode.
    private var busyCallback: BusyCallback?
    
    func setupBusyMode() {
        switch configuration.busyMode {
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
    
    
    // =========================================================================
    // MARK: - Functions
    
    /// Remove a function.
    ///
    /// - parameter identifier: A function identifier returned by addFunction()
    ///   or addVariadicFunction().
    public func removeFunction(identifier: DatabaseFunctionIdentifier) {
        functions.removeValueForKey(identifier)
        let code = sqlite3_create_function_v2(
            sqliteConnection,
            identifier.name,
            identifier.argumentCount,
            SQLITE_UTF8,
            nil, nil, nil, nil, nil)
        guard code == SQLITE_OK else {
            fatalError(DatabaseError(code: code, message: self.lastErrorMessage, sql: nil, arguments: nil).description)
        }
    }
    
    /// Add or redefine a function with a variable number of arguments.
    ///
    ///     db.addVariadicFunction("f") { databaseValues in
    ///         return databaseValues.count
    ///     }
    ///     Int.fetchOne(db, "SELECT f()")!   // 0
    ///     Int.fetchOne(db, "SELECT f(1)")!  // 1
    ///     Int.fetchOne(db, "SELECT f(1,1)"! // 2
    ///
    /// - parameter name: The function name.
    /// - parameter pure: Whether the function is "pure", which means that its
    ///   results only depends on its inputs. When a function is pure, SQLite
    ///   has the opportunity to perform additional optimizations. Default value
    ///   is false.
    /// - parameter function: A function that takes an array of DatabaseValue
    ///   arguments, and returns an optional DatabaseValueConvertible such as
    ///   Int, String, NSDate, etc.
    /// - returns: A function identifier that can be used with removeFunction().
    public func addVariadicFunction(name: String, pure: Bool = false, function: [DatabaseValue] throws -> DatabaseValueConvertible?) -> DatabaseFunctionIdentifier {
        let identifier = DatabaseFunctionIdentifier(name: name, argumentCount: -1)
        let dbFunction = DatabaseFunction(pure: pure) { (context, argc, argv) in
            let arguments = (0..<Int(argc)).map { index in DatabaseValue(sqliteValue: argv[index]) }
            return try function(arguments)?.databaseValue ?? .Null
        }
        addFunction(dbFunction, forIdentifier: identifier)
        return identifier
    }
    
    /// Add or redefine a function with a fixed number of arguments.
    ///
    ///     db.addFunction("succ", argumentCount: 1) { databaseValues in
    ///         let dbv = databaseValues.first!
    ///         guard let int = dbv.value() as Int? else {
    ///             return nil
    ///         }
    ///         return int + 1
    ///     }
    ///     Int.fetchOne(db, "SELECT succ(1)")! // 2
    ///
    /// - parameter name: The function name.
    /// - parameter argumentCount: The number of arguments of the function.
    /// - parameter pure: Whether the function is "pure", which means that its
    ///   results only depends on its inputs. When a function is pure, SQLite
    ///   has the opportunity to perform additional optimizations. Default value
    ///   is false.
    /// - parameter function: A function that takes an array of DatabaseValue
    ///   arguments, and returns an optional DatabaseValueConvertible such as
    ///   Int, String, NSDate, etc. The array is guaranteed to have exactly
    ///   argumentCount elements.
    /// - returns: A function identifier that can be used with removeFunction().
    public func addFunction(name: String, argumentCount: Int, pure: Bool = false, function: [DatabaseValue] throws -> DatabaseValueConvertible?) -> DatabaseFunctionIdentifier {
        guard argumentCount >= 0 else {
            fatalError("Invalid negative argument count. Use addVariadicFunction() for arguments with variable arguments count.")
        }
        let identifier = DatabaseFunctionIdentifier(name: name, argumentCount: Int32(argumentCount))
        let dbFunction = DatabaseFunction(pure: pure) { (context, argc, argv) in
            let arguments = (0..<Int(argc)).map { index in DatabaseValue(sqliteValue: argv[index]) }
            return try function(arguments)?.databaseValue ?? .Null
        }
        addFunction(dbFunction, forIdentifier: identifier)
        return identifier
    }

    private var functions = [DatabaseFunctionIdentifier: DatabaseFunction]()
    
    private func addFunction(function: DatabaseFunction, forIdentifier identifier: DatabaseFunctionIdentifier) {
        functions[identifier] = function
        
        let functionPointer = unsafeBitCast(function, UnsafeMutablePointer<Void>.self)
        let code = sqlite3_create_function_v2(
            sqliteConnection,
            identifier.name,
            identifier.argumentCount,
            SQLITE_UTF8 | function.eTextRep,
            functionPointer,
            { (context, argc, argv) in
                let function = unsafeBitCast(sqlite3_user_data(context), DatabaseFunction.self)
                do {
                    let result = try function.function(context, argc, argv)
                    switch result.storage {
                    case .Null:
                        sqlite3_result_null(context)
                    case .Int64(let int64):
                        sqlite3_result_int64(context, int64)
                    case .Double(let double):
                        sqlite3_result_double(context, double)
                    case .String(let string):
                        sqlite3_result_text(context, string, -1, SQLITE_TRANSIENT)
                    case .Blob(let data):
                        sqlite3_result_blob(context, data.bytes, Int32(data.length), SQLITE_TRANSIENT)
                    }
                } catch let error as DatabaseError {
                    if let message = error.message {
                        sqlite3_result_error(context, message, -1)
                    }
                    sqlite3_result_error_code(context, Int32(error.code))
                } catch {
                    sqlite3_result_error(context, "\(error)", -1)
                }
            }, nil, nil, nil)
        
        guard code == SQLITE_OK else {
            fatalError(DatabaseError(code: code, message: self.lastErrorMessage, sql: nil, arguments: nil).description)
        }
    }
    
    
    // =========================================================================
    // MARK: - Database Informations
    
    /// The last error message
    var lastErrorMessage: String? { return String.fromCString(sqlite3_errmsg(sqliteConnection)) }
    
    /// Returns whether a table exists.
    ///
    /// - parameter tableName: A table name.
    /// - returns: True if the table exists.
    public func tableExists(tableName: String) -> Bool {
        // SQlite identifiers are case-insensitive, case-preserving (http://www.alberton.info/dbms_identifiers_and_case_sensitivity.html)
        return Row.fetchOne(self,
            "SELECT sql FROM sqlite_master WHERE type = 'table' AND LOWER(name) = ?",
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
    private struct ColumnInfo : RowConvertible {
        let name: String
        let type: String
        let notNull: Bool
        let defaultDatabaseValue: DatabaseValue
        let primaryKeyIndex: Int
        init(row: Row) {
            name = row.value(named: "name")
            type = row.value(named: "type")
            notNull = row.value(named: "notnull")
            defaultDatabaseValue = row["dflt_value"]!
            primaryKeyIndex = row.value(named: "pk")
        }
    }
    
    // Cache for columnInfosForTable(named:)
    private var columnInfosCache: [String: [ColumnInfo]] = [:]
    private func columnInfosForTable(named tableName: String) -> [ColumnInfo] {
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
    
    
    // =========================================================================
    // MARK: - Raw SQLite connetion
    
    /// The raw SQLite connection, suitable for the SQLite C API.
    public let sqliteConnection: SQLiteConnection
    
    
    // =========================================================================
    // MARK: - Configuration
    
    /// The database configuration
    public let configuration: Configuration
    
    
    // =========================================================================
    // MARK: - Initialization
    
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
        
        try setupForeignKeys()
        setupBusyMode()
        setupTransactionHooks()
        setupTrace()    // Last, after initialization queries have been performed.
    }
    
    // Initializes an in-memory database
    convenience init(configuration: Configuration) {
        try! self.init(path: ":memory:", configuration: configuration)
    }
    
    deinit {
        sqlite3_close(sqliteConnection)
    }
    
    
    // =========================================================================
    // MARK: - Misc
    
    func assertValidQueue() {
        guard databaseQueueID == nil || databaseQueueID == dispatch_get_specific(DatabaseQueue.databaseQueueIDKey) else {
            fatalError("Database was not used on the correct thread: execute your statements inside DatabaseQueue.inDatabase() or DatabaseQueue.inTransaction(). If you get this error while iterating the result of a fetch() method, use fetchAll() instead: it returns an Array that can be iterated on any thread.")
        }
    }
    
    func setupForeignKeys() throws {
        if configuration.foreignKeysEnabled {
            try execute("PRAGMA foreign_keys = ON")
        }
    }
    
    func setupTrace() {
        guard configuration.trace != nil else {
            return
        }
        let dbPointer = unsafeBitCast(self, UnsafeMutablePointer<Void>.self)
        sqlite3_trace(sqliteConnection, { (dbPointer, sql) in
            let database = unsafeBitCast(dbPointer, Database.self)
            database.configuration.trace!(String.fromCString(sql)!)
            }, dbPointer)
    }
}


// =============================================================================
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


// =============================================================================
// MARK: - TransactionKind

/// A SQLite transaction kind. See https://www.sqlite.org/lang_transaction.html
public enum TransactionKind {
    case Deferred
    case Immediate
    case Exclusive
}


// =============================================================================
// MARK: - TransactionCompletion

/// The end of a transaction: Commit, or Rollback
public enum TransactionCompletion {
    case Commit
    case Rollback
}


// =============================================================================
// MARK: - TransactionObserverType

/// A transaction observer is notified of all changes and transactions committed
/// or rollbacked on a database.
///
/// Adopting types must be a class.
public protocol TransactionObserverType : class {
    
    /// Notifies a database change (insert, update, or delete).
    ///
    /// The change is pending until the end of the current transaction, notified
    /// to databaseWillCommit, databaseDidCommit and databaseDidRollback.
    ///
    /// This method is called on the database queue.
    ///
    /// **WARNING**: this method must not change the database.
    ///
    /// - parameter event: A database event.
    func databaseDidChangeWithEvent(event: DatabaseEvent)
    
    /// When a transaction is about to be committed, the transaction observer
    /// has an opportunity to rollback pending changes by throwing an error.
    ///
    /// This method is called on the database queue.
    ///
    /// **WARNING**: this method must not change the database.
    ///
    /// - throws: An eventual error that rollbacks pending changes.
    func databaseWillCommit() throws
    
    /// Database changes have been committed.
    ///
    /// This method is called on the database queue. It can change the database.
    ///
    /// - parameter db: A Database.
    func databaseDidCommit(db: Database)
    
    /// Database changes have been rollbacked.
    ///
    /// This method is called on the database queue. It can change the database.
    ///
    /// - parameter db: A Database.
    func databaseDidRollback(db: Database)
}


// =============================================================================
// MARK: - DatabaseEvent

/// A database event, notified to TransactionObserverType.
///
/// See https://www.sqlite.org/c3ref/update_hook.html for more information.
public struct DatabaseEvent {
    /// An event kind
    public enum Kind: Int32 {
        case Insert = 18    // SQLITE_INSERT
        case Delete = 9     // SQLITE_DELETE
        case Update = 23    // SQLITE_UPDATE
    }
    
    /// The event kind
    public let kind: Kind
    
    /// The database name
    public let databaseName: String
    
    /// The table name
    public let tableName: String
    
    /// The rowID of the changed row.
    public let rowID: Int64
}


// =============================================================================
// MARK: - ThreadingMode

/// A SQLite threading mode. See https://www.sqlite.org/threadsafe.html.
enum ThreadingMode {
    case Default
    case MultiThread
    case Serialized
    
    var sqliteOpenFlags: Int32 {
        switch self {
        case .Default:
            return 0
        case .MultiThread:
            return SQLITE_OPEN_NOMUTEX
        case .Serialized:
            return SQLITE_OPEN_FULLMUTEX
        }
    }
}


// =============================================================================
// MARK: - BusyMode

/// See BusyMode and https://www.sqlite.org/c3ref/busy_handler.html
public typealias BusyCallback = (numberOfTries: Int) -> Bool

/// When there are several connections to a database, a connection may try to
/// access the database while it is locked by another connection.
///
/// The BusyMode enum describes the behavior of GRDB when such a situation
/// occurs:
///
/// - .ImmediateError: The SQLITE_BUSY error is immediately returned to the
///   connection that tries to access the locked database.
///
/// - .Timeout: The SQLITE_BUSY error will be returned only if the database
///   remains locked for more than the specified duration.
///
/// - .Callback: Perform your custom lock handling.
///
/// To set the busy mode of a database, use Configuration:
///
///     let configuration = Configuration(busyMode: .Timeout(1))
///     let dbQueue = DatabaseQueue(path: "...", configuration: configuration)
///
/// Relevant SQLite documentation:
///
/// - https://www.sqlite.org/c3ref/busy_timeout.html
/// - https://www.sqlite.org/c3ref/busy_handler.html
/// - https://www.sqlite.org/lang_transaction.html
/// - https://www.sqlite.org/wal.html
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


// =========================================================================
// MARK: - Functions

typealias DatabaseFunctionImpl = (COpaquePointer, Int32, UnsafeMutablePointer<COpaquePointer>) throws -> DatabaseValue

/// TODO
public struct DatabaseFunctionIdentifier : Hashable {
    let name: String
    let argumentCount: Int32
    
    public var hashValue: Int {
        return name.hashValue ^ argumentCount.hashValue
    }
}

// SQLite compares functions on their name and argumentCount.
public func ==(lhs: DatabaseFunctionIdentifier, rhs: DatabaseFunctionIdentifier) -> Bool {
    return lhs.name == rhs.name && lhs.argumentCount == rhs.argumentCount
}

class DatabaseFunction {
    let pure: Bool
    let function: DatabaseFunctionImpl
    var eTextRep: Int32 { return pure ? SQLITE_DETERMINISTIC : 0 }
    
    init(pure: Bool, function: DatabaseFunctionImpl) {
        self.pure = pure
        self.function = function
    }
}
