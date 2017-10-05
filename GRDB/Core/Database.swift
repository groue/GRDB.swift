import Foundation
#if SWIFT_PACKAGE
    import CSQLite
#elseif !GRDBCUSTOMSQLITE && !GRDBCIPHER
    import SQLite3
#endif

/// A raw SQLite connection, suitable for the SQLite C API.
public typealias SQLiteConnection = OpaquePointer

/// A raw SQLite function argument.
typealias SQLiteValue = OpaquePointer

let SQLITE_TRANSIENT = unsafeBitCast(OpaquePointer(bitPattern: -1), to: sqlite3_destructor_type.self)

/// A Database connection.
///
/// You don't create a database directly. Instead, you use a DatabaseQueue, or
/// a DatabasePool:
///
///     let dbQueue = DatabaseQueue(...)
///
///     // The Database is the `db` in the closure:
///     try dbQueue.inDatabase { db in
///         try db.execute(...)
///     }
public final class Database {
    // The Database class is not thread-safe. An instance should always be
    // used through a SerializedDatabase.
    
    // MARK: - Database Types
    
    /// See BusyMode and https://www.sqlite.org/c3ref/busy_handler.html
    public typealias BusyCallback = (_ numberOfTries: Int) -> Bool
    
    /// When there are several connections to a database, a connection may try
    /// to access the database while it is locked by another connection.
    ///
    /// The BusyMode enum describes the behavior of GRDB when such a situation
    /// occurs:
    ///
    /// - .immediateError: The SQLITE_BUSY error is immediately returned to the
    ///   connection that tries to access the locked database.
    ///
    /// - .timeout: The SQLITE_BUSY error will be returned only if the database
    ///   remains locked for more than the specified duration.
    ///
    /// - .callback: Perform your custom lock handling.
    ///
    /// To set the busy mode of a database, use Configuration:
    ///
    ///     let configuration = Configuration(busyMode: .timeout(1))
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
        case immediateError
        
        /// The SQLITE_BUSY error will be returned only if the database remains
        /// locked for more than the specified duration.
        case timeout(TimeInterval)
        
        /// A custom callback that is called when a database is locked.
        /// See https://www.sqlite.org/c3ref/busy_handler.html
        case callback(BusyCallback)
    }
    
    /// The available [checkpoint modes](https://www.sqlite.org/c3ref/wal_checkpoint_v2.html).
    public enum CheckpointMode: Int32 {
        case passive = 0    // SQLITE_CHECKPOINT_PASSIVE
        case full = 1       // SQLITE_CHECKPOINT_FULL
        case restart = 2    // SQLITE_CHECKPOINT_RESTART
        case truncate = 3   // SQLITE_CHECKPOINT_TRUNCATE
    }
    
    /// A built-in SQLite collation.
    ///
    /// See https://www.sqlite.org/datatype3.html#collation
    public struct CollationName : RawRepresentable, Hashable {
        public let rawValue: String
        
        public init(rawValue: String) {
            self.rawValue = rawValue
        }
        
        public init(_ rawValue: String) {
            self.rawValue = rawValue
        }
        
        /// The hash value
        public var hashValue: Int {
            return rawValue.hashValue
        }
        
        /// The `BINARY` built-in SQL collation
        public static let binary = CollationName("BINARY")
        
        /// The `NOCASE` built-in SQL collation
        public static let nocase = CollationName("NOCASE")
        
        /// The `RTRIM` built-in SQL collation
        public static let rtrim = CollationName("RTRIM")
    }
    
    /// An SQLite conflict resolution.
    ///
    /// See https://www.sqlite.org/lang_conflict.html.
    public enum ConflictResolution : String {
        case rollback = "ROLLBACK"
        case abort = "ABORT"
        case fail = "FAIL"
        case ignore = "IGNORE"
        case replace = "REPLACE"
    }
    
    /// An SQL column type.
    ///
    ///     try db.create(table: "players") { t in
    ///         t.column("id", .integer).primaryKey()
    ///         t.column("title", .text)
    ///     }
    ///
    /// See https://www.sqlite.org/datatype3.html
    public struct ColumnType : RawRepresentable, Hashable {
        public let rawValue: String
        
        public init(rawValue: String) {
            self.rawValue = rawValue
        }
        
        public init(_ rawValue: String) {
            self.rawValue = rawValue
        }
        
        /// The hash value
        public var hashValue: Int {
            return rawValue.hashValue
        }
        
        /// The `TEXT` SQL column type
        public static let text = ColumnType("TEXT")
        
        /// The `INTEGER` SQL column type
        public static let integer = ColumnType("INTEGER")
        
        /// The `DOUBLE` SQL column type
        public static let double = ColumnType("DOUBLE")
        
        /// The `NUMERIC` SQL column type
        public static let numeric = ColumnType("NUMERIC")
        
        /// The `BOOLEAN` SQL column type
        public static let boolean = ColumnType("BOOLEAN")
        
        /// The `BLOB` SQL column type
        public static let blob = ColumnType("BLOB")
        
        /// The `DATE` SQL column type
        public static let date = ColumnType("DATE")
        
        /// The `DATETIME` SQL column type
        public static let datetime = ColumnType("DATETIME")
    }
    
    
    /// A foreign key action.
    ///
    /// See https://www.sqlite.org/foreignkeys.html
    public enum ForeignKeyAction : String {
        case cascade = "CASCADE"
        case restrict = "RESTRICT"
        case setNull = "SET NULL"
        case setDefault = "SET DEFAULT"
    }
    
    /// An SQLite threading mode. See https://www.sqlite.org/threadsafe.html.
    enum ThreadingMode {
        case `default`
        case multiThread
        case serialized
        
        var SQLiteOpenFlags: Int32 {
            switch self {
            case .`default`:
                return 0
            case .multiThread:
                return SQLITE_OPEN_NOMUTEX
            case .serialized:
                return SQLITE_OPEN_FULLMUTEX
            }
        }
    }
    
    /// An SQLite transaction kind. See https://www.sqlite.org/lang_transaction.html
    public enum TransactionKind {
        case deferred
        case immediate
        case exclusive
    }
    
    /// The end of a transaction: Commit, or Rollback
    public enum TransactionCompletion {
        case commit
        case rollback
    }
    
    /// The states that keep track of transaction completions in order to notify
    /// transaction observers.
    private enum TransactionHookState {
        case pending
        case commit
        case rollback
        case cancelledCommit(Error)
    }
    
    // MARK: - Error Log
    
    /// log function that takes an error message.
    public typealias LogErrorFunction = (_ resultCode: ResultCode, _ message: String) -> Void
    
    /// The error logging function.
    ///
    /// Quoting https://www.sqlite.org/errlog.html:
    ///
    /// > SQLite can be configured to invoke a callback function containing an
    /// > error code and a terse error message whenever anomalies occur. This
    /// > mechanism is very helpful in tracking obscure problems that occur
    /// > rarely and in the field. Application developers are encouraged to take
    /// > advantage of the error logging facility of SQLite in their products,
    /// > as it is very low CPU and memory cost but can be a huge aid
    /// > for debugging.
    public static var logError: LogErrorFunction? = nil
    
    private static func setupErrorLog() {
        struct Impl {
            static let setupErrorLog: () = {
                registerErrorLogCallback { (_, code, message) in
                    guard let log = Database.logError else { return }
                    guard let message = message.map({ String(cString: $0) }) else { return }
                    let resultCode = ResultCode(rawValue: code)
                    log(resultCode, message)
                }
            }()
        }
        Impl.setupErrorLog
    }
    
    
    // MARK: - Database Information
    
    /// The list of compile options used when building SQLite
    static let sqliteCompileOptions: Set<String> = DatabaseQueue().inDatabase { try! Set(String.fetchCursor($0, "PRAGMA COMPILE_OPTIONS")) }
    
    /// The database configuration
    public let configuration: Configuration
    
    /// The raw SQLite connection, suitable for the SQLite C API.
    public let sqliteConnection: SQLiteConnection
    
    /// The rowID of the most recently inserted row.
    ///
    /// If no row has ever been inserted using this database connection,
    /// returns zero.
    ///
    /// For more detailed information, see https://www.sqlite.org/c3ref/last_insert_rowid.html
    public var lastInsertedRowID: Int64 {
        SchedulingWatchdog.preconditionValidQueue(self)
        return sqlite3_last_insert_rowid(sqliteConnection)
    }
    
    /// The number of rows modified, inserted or deleted by the most recent
    /// successful INSERT, UPDATE or DELETE statement.
    ///
    /// For more detailed information, see https://www.sqlite.org/c3ref/changes.html
    public var changesCount: Int {
        SchedulingWatchdog.preconditionValidQueue(self)
        return Int(sqlite3_changes(sqliteConnection))
    }
    
    /// The total number of rows modified, inserted or deleted by all successful
    /// INSERT, UPDATE or DELETE statements since the database connection was
    /// opened.
    ///
    /// For more detailed information, see https://www.sqlite.org/c3ref/total_changes.html
    public var totalChangesCount: Int {
        SchedulingWatchdog.preconditionValidQueue(self)
        return Int(sqlite3_total_changes(sqliteConnection))
    }
    
    var lastErrorCode: ResultCode { return ResultCode(rawValue: sqlite3_errcode(sqliteConnection)) }
    var lastErrorMessage: String? { return String(cString: sqlite3_errmsg(sqliteConnection)) }
    
    /// True if the database connection is currently in a transaction.
    public var isInsideTransaction: Bool {
        // https://sqlite.org/c3ref/get_autocommit.html
        //
        // > The sqlite3_get_autocommit() interface returns non-zero or zero if
        // > the given database connection is or is not in autocommit mode,
        // > respectively.
        //
        // > Autocommit mode is on by default. Autocommit mode is disabled by a
        // > BEGIN statement. Autocommit mode is re-enabled by a COMMIT
        // > or ROLLBACK.
        return sqlite3_get_autocommit(sqliteConnection) == 0
    }
    
    /// Set by SAVEPOINT/COMMIT/ROLLBACK/RELEASE savepoint statements.
    private var savepointStack = SavepointStack()
    
    /// Traces transaction hooks
    private var transactionHookState: TransactionHookState = .pending
    
    /// Transaction observers
    private var transactionObservers = [ManagedTransactionObserver]()
    private var activeTransactionObservers = [ManagedTransactionObserver]()  // subset of transactionObservers, set in updateStatementWillExecute
    
    /// See setupBusyMode()
    private var busyCallback: BusyCallback?
    
    /// Available functions
    private var functions = Set<DatabaseFunction>()
    
    /// Available collations
    private var collations = Set<DatabaseCollation>()
    
    /// Current authorizer
    var authorizer: StatementAuthorizer? {
        didSet {
            switch (oldValue, authorizer) {
            case (.some, nil):
                sqlite3_set_authorizer(sqliteConnection, nil, nil)
            case (nil, .some):
                let dbPointer = Unmanaged.passUnretained(self).toOpaque()
                sqlite3_set_authorizer(sqliteConnection, { (dbPointer, actionCode, cString1, cString2, cString3, cString4) -> Int32 in
                    guard let dbPointer = dbPointer else { return SQLITE_OK }
                    let db = Unmanaged<Database>.fromOpaque(dbPointer).takeUnretainedValue()
                    return db.authorizer!.authorize(actionCode, cString1, cString2, cString3, cString4)
                }, dbPointer)
            default:
                break
            }
        }
    }
    
    /// Schema Cache
    var schemaCache: DatabaseSchemaCache    // internal so that it can be tested

    /// Statement caches are not part of the schema cache because statements
    /// belong to this connection, while schema cache can be shared with
    /// other connections.
    ///
    /// There are two statement caches: one for statements generated by the
    /// user, and one for the statements generated by GRDB. Those are separated
    /// so that GRDB has no opportunity to inadvertently modify the arguments of
    /// user statements.
    enum StatementCacheName {
        case grdb
        case user
    }
    private lazy var grdbStatementCache: StatementCache = StatementCache(database: self)
    private lazy var userStatementCache: StatementCache = StatementCache(database: self)
    
    init(path: String, configuration: Configuration, schemaCache: DatabaseSchemaCache) throws {
        // Error log setup must happen before any database connection
        Database.setupErrorLog()
        
        // See https://www.sqlite.org/c3ref/open.html
        var sqliteConnection: SQLiteConnection? = nil
        let code = sqlite3_open_v2(path, &sqliteConnection, configuration.SQLiteOpenFlags, nil)
        guard code == SQLITE_OK else {
            throw DatabaseError(resultCode: code, message: String(cString: sqlite3_errmsg(sqliteConnection)))
        }
        
        do {
            // Use extended result codes
            do {
                let code = sqlite3_extended_result_codes(sqliteConnection!, 1)
                guard code == SQLITE_OK else {
                    throw DatabaseError(resultCode: code, message: String(cString: sqlite3_errmsg(sqliteConnection)))
                }
            }
            
            #if SQLITE_HAS_CODEC
                // https://discuss.zetetic.net/t/important-advisory-sqlcipher-with-xcode-8-and-new-sdks/1688
                //
                // > In order to avoid situations where SQLite might be used
                // > improperly at runtime, we strongly recommend that
                // > applications institute a runtime test to ensure that the
                // > application is actually using SQLCipher on the active
                // > connection.
                
                let isSQLCipherValid: Bool
                do {
                    var sqliteStatement: SQLiteStatement? = nil
                    let code = sqlite3_prepare_v2(sqliteConnection, "PRAGMA cipher_version", -1, &sqliteStatement, nil)
                    guard code == SQLITE_OK else {
                        throw DatabaseError(resultCode: code, message: String(cString: sqlite3_errmsg(sqliteConnection)))
                    }
                    defer {
                        sqlite3_finalize(sqliteStatement)
                    }
                    switch sqlite3_step(sqliteStatement) {
                    case SQLITE_ROW:
                        isSQLCipherValid = (sqlite3_column_text(sqliteStatement, 0) != nil)
                    default:
                        isSQLCipherValid = false
                    }
                }
                
                guard isSQLCipherValid else {
                    throw DatabaseError(resultCode: .SQLITE_MISUSE, message: "GRDB is not linked against SQLCipher. Check https://discuss.zetetic.net/t/important-advisory-sqlcipher-with-xcode-8-and-new-sdks/1688")
                }
                
                if let passphrase = configuration.passphrase {
                    try Database.set(passphrase: passphrase, forConnection: sqliteConnection!)
                }
            #endif
            
            // Users are surprised when they open a picture as a database and
            // see no error (https://github.com/groue/GRDB.swift/issues/54).
            //
            // So let's fail early if file is not a database, or encrypted with
            // another passphrase.
            do {
                let code = sqlite3_exec(sqliteConnection, "SELECT * FROM sqlite_master LIMIT 1", nil, nil, nil)
                guard code == SQLITE_OK else {
                    throw DatabaseError(resultCode: code, message: String(cString: sqlite3_errmsg(sqliteConnection)))
                }
            }
        } catch {
            Database.close(connection: sqliteConnection!)
            throw error
        }
        
        self.configuration = configuration
        self.schemaCache = schemaCache
        self.sqliteConnection = sqliteConnection!
        
        configuration.SQLiteConnectionDidOpen?()
    }
    
    /// This method must be called after database initialization
    func setup() throws {
        // Setup trace first, so that setup queries are traced.
        setupTrace()
        try setupForeignKeys()
        setupBusyMode()
        setupDefaultFunctions()
        setupDefaultCollations()
        setupTransactionHooks()
    }
    
    /// This method must be called before database deallocation
    func close() {
        SchedulingWatchdog.preconditionValidQueue(self)
        assert(!isClosed)
        
        configuration.SQLiteConnectionWillClose?(sqliteConnection)
        grdbStatementCache.clear()
        userStatementCache.clear()
        Database.close(connection: sqliteConnection)
        isClosed = true
        configuration.SQLiteConnectionDidClose?()
    }
    
    private var isClosed: Bool = false
    deinit {
        assert(isClosed)
    }
    
    func releaseMemory() {
        sqlite3_db_release_memory(sqliteConnection)
        schemaCache.clear()
        grdbStatementCache.clear()
        userStatementCache.clear()
    }
    
    private func setupForeignKeys() throws {
        // Foreign keys are disabled by default with SQLite3
        if configuration.foreignKeysEnabled {
            try execute("PRAGMA foreign_keys = ON")
        }
    }
    
    private func setupTrace() {
        guard configuration.trace != nil else {
            return
        }
        let dbPointer = Unmanaged.passUnretained(self).toOpaque()
        // sqlite3_trace_v2 and sqlite3_expanded_sql were introduced in SQLite 3.14.0 http://www.sqlite.org/changes.html#version_3_14
        // It is available from iOS 10.0 and OS X 10.12 https://github.com/yapstudios/YapDatabase/wiki/SQLite-version-(bundled-with-OS)
        #if GRDBCUSTOMSQLITE
            sqlite3_trace_v2(sqliteConnection, UInt32(SQLITE_TRACE_STMT), { (mask, dbPointer, stmt, unexpandedSQL) -> Int32 in
                guard let stmt = stmt else { return SQLITE_OK }
                guard let expandedSQLCString = sqlite3_expanded_sql(OpaquePointer(stmt)) else { return SQLITE_OK }
                let sql = String(cString: expandedSQLCString)
                sqlite3_free(expandedSQLCString)
                let db = Unmanaged<Database>.fromOpaque(dbPointer!).takeUnretainedValue()
                db.configuration.trace!(sql)
                return SQLITE_OK
            }, dbPointer)
        #elseif GRDBCIPHER
            sqlite3_trace(sqliteConnection, { (dbPointer, sql) in
                guard let sql = sql.map({ String(cString: $0) }) else { return }
                let db = Unmanaged<Database>.fromOpaque(dbPointer!).takeUnretainedValue()
                db.configuration.trace!(sql)
            }, dbPointer)
        #else
            if #available(iOS 10.0, OSX 10.12, watchOS 3.0, *) {
                sqlite3_trace_v2(sqliteConnection, UInt32(SQLITE_TRACE_STMT), { (mask, dbPointer, stmt, unexpandedSQL) -> Int32 in
                    guard let stmt = stmt else { return SQLITE_OK }
                    guard let expandedSQLCString = sqlite3_expanded_sql(OpaquePointer(stmt)) else { return SQLITE_OK }
                    let sql = String(cString: expandedSQLCString)
                    sqlite3_free(expandedSQLCString)
                    let db = Unmanaged<Database>.fromOpaque(dbPointer!).takeUnretainedValue()
                    db.configuration.trace!(sql)
                    return SQLITE_OK
                }, dbPointer)
            } else {
                sqlite3_trace(sqliteConnection, { (dbPointer, sql) in
                    guard let sql = sql.map({ String(cString: $0) }) else { return }
                    let db = Unmanaged<Database>.fromOpaque(dbPointer!).takeUnretainedValue()
                    db.configuration.trace!(sql)
                }, dbPointer)
            }
        #endif
    }
    
    private func setupBusyMode() {
        switch configuration.busyMode {
        case .immediateError:
            break
            
        case .timeout(let duration):
            let milliseconds = Int32(duration * 1000)
            sqlite3_busy_timeout(sqliteConnection, milliseconds)
            
        case .callback(let callback):
            busyCallback = callback
            let dbPointer = Unmanaged.passUnretained(self).toOpaque()
            sqlite3_busy_handler(
                sqliteConnection,
                { (dbPointer, numberOfTries) in
                    let db = Unmanaged<Database>.fromOpaque(dbPointer!).takeUnretainedValue()
                    let callback = db.busyCallback!
                    return callback(Int(numberOfTries)) ? 1 : 0
                },
                dbPointer)
        }
    }
    
    private func setupDefaultFunctions() {
        add(function: .capitalize)
        add(function: .lowercase)
        add(function: .uppercase)
        
        if #available(iOS 9.0, OSX 10.11, watchOS 3.0, *) {
            add(function: .localizedCapitalize)
            add(function: .localizedLowercase)
            add(function: .localizedUppercase)
        }
    }
    
    private func setupDefaultCollations() {
        add(collation: .unicodeCompare)
        add(collation: .caseInsensitiveCompare)
        add(collation: .localizedCaseInsensitiveCompare)
        add(collation: .localizedCompare)
        add(collation: .localizedStandardCompare)
    }
    
    private func setupTransactionHooks() {
        let dbPointer = Unmanaged.passUnretained(self).toOpaque()

        sqlite3_commit_hook(sqliteConnection, { dbPointer in
            let db = Unmanaged<Database>.fromOpaque(dbPointer!).takeUnretainedValue()
            do {
                try db.willCommit()
                db.transactionHookState = .commit
                // Next step: updateStatementDidExecute()
                return 0
            } catch {
                db.transactionHookState = .cancelledCommit(error)
                // Next step: sqlite3_rollback_hook callback
                return 1
            }
        }, dbPointer)
        
        
        sqlite3_rollback_hook(sqliteConnection, { dbPointer in
            let db = Unmanaged<Database>.fromOpaque(dbPointer!).takeUnretainedValue()
            switch db.transactionHookState {
            case .cancelledCommit:
                // Next step: updateStatementDidFail()
                break
            default:
                db.transactionHookState = .rollback
                // Next step: updateStatementDidExecute()
            }
        }, dbPointer)
    }
    
    private static func close(connection sqliteConnection: SQLiteConnection) {
        #if GRDBCUSTOMSQLITE || GRDBCIPHER
            close_v2(connection: sqliteConnection)
        #else
            if #available(iOS 8.2, OSX 10.10, OSXApplicationExtension 10.10, *) {
                close_v2(connection: sqliteConnection)
            } else {
                // https://www.sqlite.org/c3ref/close.html
                // > If the database connection is associated with unfinalized prepared
                // > statements or unfinished sqlite3_backup objects then
                // > sqlite3_close() will leave the database connection open and
                // > return SQLITE_BUSY.
                let code = sqlite3_close(sqliteConnection)
                if code != SQLITE_OK, let log = logError {
                    // A rare situation where GRDB doesn't fatalError on
                    // unprocessed errors.
                    let message = String(cString: sqlite3_errmsg(sqliteConnection))
                    log(ResultCode(rawValue: code), "could not close database: \(message)")
                    if code == SQLITE_BUSY {
                        // Let the user know about unfinalized statements that did
                        // prevent the connection from closing properly.
                        var stmt: SQLiteStatement? = sqlite3_next_stmt(sqliteConnection, nil)
                        while stmt != nil {
                            log(ResultCode(rawValue: code), "unfinalized statement: \(String(cString: sqlite3_sql(stmt)))")
                            stmt = sqlite3_next_stmt(sqliteConnection, stmt)
                        }
                    }
                }
            }
        #endif
    }
    
    // sqlite3_close_v2 was added in SQLite 3.7.14 http://www.sqlite.org/changes.html#version_3_7_14
    // It is available from iOS 8.2 and OS X 10.10 https://github.com/yapstudios/YapDatabase/wiki/SQLite-version-(bundled-with-OS)
    #if GRDBCUSTOMSQLITE || GRDBCIPHER
    private static func close_v2(connection sqliteConnection: SQLiteConnection) {
        // https://www.sqlite.org/c3ref/close.html
        // > If sqlite3_close_v2() is called with unfinalized prepared
        // > statements and/or unfinished sqlite3_backups, then the database
        // > connection becomes an unusable "zombie" which will automatically
        // > be deallocated when the last prepared statement is finalized or the
        // > last sqlite3_backup is finished.
        let code = sqlite3_close_v2(sqliteConnection)
        if code != SQLITE_OK, let log = logError {
            // A rare situation where GRDB doesn't fatalError on
            // unprocessed errors.
            let message = String(cString: sqlite3_errmsg(sqliteConnection))
            log(ResultCode(rawValue: code), "could not close database: \(message)")
        }
    }
    #else
    @available(iOS 8.2, OSX 10.10, OSXApplicationExtension 10.10, *)
    private static func close_v2(connection sqliteConnection: SQLiteConnection) {
        // https://www.sqlite.org/c3ref/close.html
        // > If sqlite3_close_v2() is called with unfinalized prepared
        // > statements and/or unfinished sqlite3_backups, then the database
        // > connection becomes an unusable "zombie" which will automatically
        // > be deallocated when the last prepared statement is finalized or the
        // > last sqlite3_backup is finished.
        let code = sqlite3_close_v2(sqliteConnection)
        if code != SQLITE_OK, let log = logError {
            // A rare situation where GRDB doesn't fatalError on
            // unprocessed errors.
            let message = String(cString: sqlite3_errmsg(sqliteConnection))
            log(ResultCode(rawValue: code), "could not close database: \(message)")
        }
    }
    #endif
}


// =========================================================================
// MARK: - Statements

extension Database {
    
    /// Returns a new prepared statement that can be reused.
    ///
    ///     let statement = try db.makeSelectStatement("SELECT COUNT(*) FROM players WHERE score > ?")
    ///     let moreThanTwentyCount = try Int.fetchOne(statement, arguments: [20])!
    ///     let moreThanThirtyCount = try Int.fetchOne(statement, arguments: [30])!
    ///
    /// - parameter sql: An SQL query.
    /// - returns: A SelectStatement.
    /// - throws: A DatabaseError whenever SQLite could not parse the sql query.
    public func makeSelectStatement(_ sql: String) throws -> SelectStatement {
        return try makeSelectStatement(sql, prepFlags: 0)
    }
    
    /// Returns a new prepared statement that can be reused.
    ///
    ///     let statement = try db.makeSelectStatement("SELECT COUNT(*) FROM players WHERE score > ?", prepFlags: 0)
    ///     let moreThanTwentyCount = try Int.fetchOne(statement, arguments: [20])!
    ///     let moreThanThirtyCount = try Int.fetchOne(statement, arguments: [30])!
    ///
    /// - parameter sql: An SQL query.
    /// - parameter prepFlags: Flags for sqlite3_prepare_v3 (available from
    ///   SQLite 3.20.0, see http://www.sqlite.org/c3ref/prepare.html)
    /// - returns: A SelectStatement.
    /// - throws: A DatabaseError whenever SQLite could not parse the sql query.
    func makeSelectStatement(_ sql: String, prepFlags: Int32) throws -> SelectStatement {
        let statementCompilationAuthorizer = StatementCompilationAuthorizer()
        authorizer = statementCompilationAuthorizer
        defer { authorizer = nil }
        
        var statement: SelectStatement? = nil
        let sqlCodeUnits = sql.utf8CString
        var remainingSQL = ""
        try sqlCodeUnits.withUnsafeBufferPointer { codeUnits in
            let statementStart = UnsafePointer<Int8>(codeUnits.baseAddress)!
            var statementEnd: UnsafePointer<Int8>? = nil
            do {
                statement = try SelectStatement(
                    database: self,
                    statementStart: statementStart,
                    statementEnd: &statementEnd,
                    prepFlags: prepFlags,
                    authorizer: statementCompilationAuthorizer)
            } catch is EmptyStatementError {
                throw DatabaseError(resultCode: .SQLITE_ERROR, message: "empty statement", sql: sql, arguments: nil)
            }
            let remainingData = Data(
                bytesNoCopy: UnsafeMutableRawPointer(mutating: statementEnd!),
                count: statementStart + sqlCodeUnits.count - statementEnd! - 1,
                deallocator: .none)
            remainingSQL = String(data: remainingData, encoding: .utf8)!.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        guard remainingSQL.isEmpty else {
            throw DatabaseError(resultCode: .SQLITE_MISUSE, message: "Multiple statements found. To execute multiple statements, use Database.execute() instead.", sql: sql, arguments: nil)
        }

        return statement!
    }
    
    /// Returns a prepared statement that can be reused.
    ///
    ///     let statement = try db.cachedSelectStatement("SELECT COUNT(*) FROM players WHERE score > ?")
    ///     let moreThanTwentyCount = try Int.fetchOne(statement, arguments: [20])!
    ///     let moreThanThirtyCount = try Int.fetchOne(statement, arguments: [30])!
    ///
    /// The returned statement may have already been used: it may or may not
    /// contain values for its eventual arguments.
    ///
    /// - parameter sql: An SQL query.
    /// - returns: An UpdateStatement.
    /// - throws: A DatabaseError whenever SQLite could not parse the sql query.
    public func cachedSelectStatement(_ sql: String) throws -> SelectStatement {
        return try selectStatement(sql, fromCache: .user)
    }
    
    /// Returns a prepared statement that can be reused.
    func selectStatement(_ sql: String, fromCache cacheName: StatementCacheName) throws -> SelectStatement {
        switch cacheName {
        case .grdb: return try grdbStatementCache.selectStatement(sql)
        case .user: return try userStatementCache.selectStatement(sql)
        }
    }
    
    /// Returns a new prepared statement that can be reused.
    ///
    ///     let statement = try db.makeUpdateStatement("INSERT INTO players (name) VALUES (?)")
    ///     try statement.execute(arguments: ["Arthur"])
    ///     try statement.execute(arguments: ["Barbara"])
    ///
    /// - parameter sql: An SQL query.
    /// - returns: An UpdateStatement.
    /// - throws: A DatabaseError whenever SQLite could not parse the sql query.
    public func makeUpdateStatement(_ sql: String) throws -> UpdateStatement {
        return try makeUpdateStatement(sql, prepFlags: 0)
    }
    
    /// Returns a new prepared statement that can be reused.
    ///
    ///     let statement = try db.makeUpdateStatement("INSERT INTO players (name) VALUES (?)", prepFlags: 0)
    ///     try statement.execute(arguments: ["Arthur"])
    ///     try statement.execute(arguments: ["Barbara"])
    ///
    /// - parameter sql: An SQL query.
    /// - parameter prepFlags: Flags for sqlite3_prepare_v3 (available from
    ///   SQLite 3.20.0, see http://www.sqlite.org/c3ref/prepare.html)
    /// - returns: An UpdateStatement.
    /// - throws: A DatabaseError whenever SQLite could not parse the sql query.
    func makeUpdateStatement(_ sql: String, prepFlags: Int32) throws -> UpdateStatement {
        let statementCompilationAuthorizer = StatementCompilationAuthorizer()
        authorizer = statementCompilationAuthorizer
        defer { authorizer = nil }

        var statement: UpdateStatement? = nil
        let sqlCodeUnits = sql.utf8CString
        var remainingSQL = ""
        try sqlCodeUnits.withUnsafeBufferPointer { codeUnits in
            let statementStart = UnsafePointer<Int8>(codeUnits.baseAddress)!
            var statementEnd: UnsafePointer<Int8>? = nil
            do {
                statement = try UpdateStatement(
                    database: self,
                    statementStart: statementStart,
                    statementEnd: &statementEnd,
                    prepFlags: prepFlags,
                    authorizer: statementCompilationAuthorizer)
            } catch is EmptyStatementError {
                throw DatabaseError(resultCode: .SQLITE_ERROR, message: "empty statement", sql: sql, arguments: nil)
            }
            let remainingData = Data(
                bytesNoCopy: UnsafeMutableRawPointer(mutating: statementEnd!),
                count: statementStart + sqlCodeUnits.count - statementEnd! - 1,
                deallocator: .none)
            remainingSQL = String(data: remainingData, encoding: .utf8)!.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        guard remainingSQL.isEmpty else {
            throw DatabaseError(resultCode: .SQLITE_MISUSE, message: "Multiple statements found. To execute multiple statements, use Database.execute() instead.", sql: sql, arguments: nil)
        }
        
        return statement!
    }
    
    /// Returns a prepared statement that can be reused.
    ///
    ///     let statement = try db.cachedUpdateStatement("INSERT INTO players (name) VALUES (?)")
    ///     try statement.execute(arguments: ["Arthur"])
    ///     try statement.execute(arguments: ["Barbara"])
    ///
    /// The returned statement may have already been used: it may or may not
    /// contain values for its eventual arguments.
    ///
    /// - parameter sql: An SQL query.
    /// - returns: An UpdateStatement.
    /// - throws: A DatabaseError whenever SQLite could not parse the sql query.
    public func cachedUpdateStatement(_ sql: String) throws -> UpdateStatement {
        return try updateStatement(sql, fromCache: .grdb)
    }
    
    /// Returns a prepared statement that can be reused.
    func updateStatement(_ sql: String, fromCache cacheName: StatementCacheName) throws -> UpdateStatement {
        switch cacheName {
        case .grdb: return try grdbStatementCache.updateStatement(sql)
        case .user: return try userStatementCache.updateStatement(sql)
        }
    }
    
    /// Executes one or several SQL statements, separated by semi-colons.
    ///
    ///     try db.execute(
    ///         "INSERT INTO players (name) VALUES (:name)",
    ///         arguments: ["name": "Arthur"])
    ///
    ///     try db.execute("""
    ///         INSERT INTO players (name) VALUES (?);
    ///         INSERT INTO players (name) VALUES (?);
    ///         INSERT INTO players (name) VALUES (?);
    ///         """, arguments; ['Arthur', 'Barbara', 'Craig'])
    ///
    /// This method may throw a DatabaseError.
    ///
    /// - parameters:
    ///     - sql: An SQL query.
    ///     - arguments: Optional statement arguments.
    /// - throws: A DatabaseError whenever an SQLite error occurs.
    public func execute(_ sql: String, arguments: StatementArguments? = nil) throws {
        // This method is like sqlite3_exec (https://www.sqlite.org/c3ref/exec.html)
        // It adds support for arguments, and the tricky part is to consume
        // arguments as statements are executed.
        //
        // Here we build two functions:
        // - consumeArguments returns arguments for a statement
        // - validateRemainingArguments validates the remaining arguments, after
        //   all statements have been executed, in the same way
        //   as Statement.validate(arguments:)
        
        var arguments = arguments ?? StatementArguments()
        let initialValuesCount = arguments.values.count
        let consumeArguments = { (statement: UpdateStatement) throws -> StatementArguments in
            let bindings = try arguments.consume(statement, allowingRemainingValues: true)
            return StatementArguments(bindings)
        }
        let validateRemainingArguments = {
            if !arguments.values.isEmpty {
                throw DatabaseError(resultCode: .SQLITE_MISUSE, message: "wrong number of statement arguments: \(initialValuesCount)")
            }
        }
        
        // Execute statements
        
        let sqlCodeUnits = sql.utf8CString
        try sqlCodeUnits.withUnsafeBufferPointer { codeUnits in
            let sqlStart = UnsafePointer<Int8>(codeUnits.baseAddress)!
            let sqlEnd = sqlStart + sqlCodeUnits.count
            var statementStart = sqlStart
            while statementStart < sqlEnd - 1 {
                var statementEnd: UnsafePointer<Int8>? = nil
                
                do {
                    let statementCompilationAuthorizer = StatementCompilationAuthorizer()
                    authorizer = statementCompilationAuthorizer
                    defer { authorizer = nil }
                    
                    let statement = try UpdateStatement(
                        database: self,
                        statementStart: statementStart,
                        statementEnd: &statementEnd,
                        prepFlags: 0,
                        authorizer: statementCompilationAuthorizer)

                    let arguments = try consumeArguments(statement)
                    statement.unsafeSetArguments(arguments)
                    try statement.execute()
                    
                    statementStart = statementEnd!
                } catch is EmptyStatementError {
                    break
                }
            }
        }
        
        // Force arguments validity: it is a programmer error to provide
        // arguments that do not match the statement.
        try! validateRemainingArguments()   // throws if there are remaining arguments.
    }
}


// =========================================================================
// MARK: - Functions

extension Database {
    
    /// Add or redefine an SQL function.
    ///
    ///     let fn = DatabaseFunction("succ", argumentCount: 1) { dbValues in
    ///         guard let int = Int.fromDatabaseValue(dbValues[0]) else {
    ///             return nil
    ///         }
    ///         return int + 1
    ///     }
    ///     db.add(function: fn)
    ///     try Int.fetchOne(db, "SELECT succ(1)")! // 2
    public func add(function: DatabaseFunction) {
        functions.update(with: function)
        function.install(in: self)
    }
    
    /// Remove an SQL function.
    public func remove(function: DatabaseFunction) {
        functions.remove(function)
        function.uninstall(in: self)
    }
}


// =========================================================================
// MARK: - Collations

extension Database {
    
    /// Add or redefine a collation.
    ///
    ///     let collation = DatabaseCollation("localized_standard") { (string1, string2) in
    ///         return (string1 as NSString).localizedStandardCompare(string2)
    ///     }
    ///     db.add(collation: collation)
    ///     try db.execute("CREATE TABLE files (name TEXT COLLATE localized_standard")
    public func add(collation: DatabaseCollation) {
        collations.update(with: collation)
        let collationPointer = Unmanaged.passUnretained(collation).toOpaque()
        let code = sqlite3_create_collation_v2(
            sqliteConnection,
            collation.name,
            SQLITE_UTF8,
            collationPointer,
            { (collationPointer, length1, buffer1, length2, buffer2) -> Int32 in
                let collation = Unmanaged<DatabaseCollation>.fromOpaque(collationPointer!).takeUnretainedValue()
                return Int32(collation.function(length1, buffer1, length2, buffer2).rawValue)
            }, nil)
        guard code == SQLITE_OK else {
            // Assume a GRDB bug: there is no point throwing any error.
            fatalError(DatabaseError(resultCode: code, message: lastErrorMessage).description)
        }
    }
    
    /// Remove a collation.
    public func remove(collation: DatabaseCollation) {
        collations.remove(collation)
        sqlite3_create_collation_v2(
            sqliteConnection,
            collation.name,
            SQLITE_UTF8,
            nil, nil, nil)
    }
}

/// A Collation is a string comparison function used by SQLite.
public final class DatabaseCollation {
    public let name: String
    let function: (Int32, UnsafeRawPointer?, Int32, UnsafeRawPointer?) -> ComparisonResult
    
    /// Returns a collation.
    ///
    ///     let collation = DatabaseCollation("localized_standard") { (string1, string2) in
    ///         return (string1 as NSString).localizedStandardCompare(string2)
    ///     }
    ///     db.add(collation: collation)
    ///     try db.execute("CREATE TABLE files (name TEXT COLLATE localized_standard")
    ///
    /// - parameters:
    ///     - name: The function name.
    ///     - function: A function that compares two strings.
    public init(_ name: String, function: @escaping (String, String) -> ComparisonResult) {
        self.name = name
        self.function = { (length1, buffer1, length2, buffer2) in
            // Buffers are not C strings: they do not end with \0.
            let string1 = String(bytesNoCopy: UnsafeMutableRawPointer(mutating: buffer1.unsafelyUnwrapped), length: Int(length1), encoding: .utf8, freeWhenDone: false)!
            let string2 = String(bytesNoCopy: UnsafeMutableRawPointer(mutating: buffer2.unsafelyUnwrapped), length: Int(length2), encoding: .utf8, freeWhenDone: false)!
            return function(string1, string2)
        }
    }
}

extension DatabaseCollation : Hashable {
    /// The hash value
    public var hashValue: Int {
        // We can't compute a hash since the equality is based on the opaque
        // sqlite3_strnicmp SQLite function.
        return 0
    }
    
    /// Two collations are equal if they share the same name (case insensitive)
    public static func == (lhs: DatabaseCollation, rhs: DatabaseCollation) -> Bool {
        // See https://www.sqlite.org/c3ref/create_collation.html
        return sqlite3_stricmp(lhs.name, lhs.name) == 0
    }
}


// =========================================================================
// MARK: - Encryption

#if SQLITE_HAS_CODEC
extension Database {
    private class func set(passphrase: String, forConnection sqliteConnection: SQLiteConnection) throws {
        let data = passphrase.data(using: .utf8)!
        let code = data.withUnsafeBytes { bytes in
            sqlite3_key(sqliteConnection, bytes, Int32(data.count))
        }
        guard code == SQLITE_OK else {
            throw DatabaseError(resultCode: code, message: String(cString: sqlite3_errmsg(sqliteConnection)))
        }
    }

    func change(passphrase: String) throws {
        // FIXME: sqlite3_rekey is discouraged.
        //
        // https://github.com/ccgus/fmdb/issues/547#issuecomment-259219320
        //
        // > We (Zetetic) have been discouraging the use of sqlite3_rekey in
        // > favor of attaching a new database with the desired encryption
        // > options and using sqlcipher_export() to migrate the contents and
        // > schema of the original db into the new one:
        // > https://discuss.zetetic.net/t/how-to-encrypt-a-plaintext-sqlite-database-to-use-sqlcipher-and-avoid-file-is-encrypted-or-is-not-a-database-errors/
        let data = passphrase.data(using: .utf8)!
        let code = data.withUnsafeBytes { bytes in
            sqlite3_rekey(sqliteConnection, bytes, Int32(data.count))
        }
        guard code == SQLITE_OK else {
            throw DatabaseError(resultCode: code, message: lastErrorMessage)
        }
    }
}
#endif


// =========================================================================
// MARK: - Database Schema

extension Database {
    
    /// Clears the database schema cache.
    ///
    /// You may need to clear the cache manually if the database schema is
    /// modified by another connection.
    public func clearSchemaCache() {
        SchedulingWatchdog.preconditionValidQueue(self)
        schemaCache.clear()
        
        // We also clear updateStatementCache and selectStatementCache despite
        // the automatic statement recompilation (see https://www.sqlite.org/c3ref/prepare.html)
        // because the automatic statement recompilation only happens a
        // limited number of times.
        grdbStatementCache.clear()
        userStatementCache.clear()
    }
    
    /// Returns whether a table exists.
    public func tableExists(_ tableName: String) throws -> Bool {
        // SQlite identifiers are case-insensitive, case-preserving (http://www.alberton.info/dbms_identifiers_and_case_sensitivity.html)
        return try Row.fetchOne(self, "SELECT 1 FROM (SELECT sql, type, name FROM sqlite_master UNION SELECT sql, type, name FROM sqlite_temp_master) WHERE type = 'table' AND LOWER(name) = ?", arguments: [tableName.lowercased()]) != nil
    }
    
    /// The primary key for table named `tableName`.
    ///
    /// All tables have a primary key, even when it is not explicit. When a
    /// table has no explicit primary key, the result is the hidden
    /// "rowid" column.
    ///
    /// - throws: A DatabaseError if table does not exist.
    public func primaryKey(_ tableName: String) throws -> PrimaryKeyInfo {
        SchedulingWatchdog.preconditionValidQueue(self)
        
        if let primaryKey = schemaCache.primaryKey(tableName) {
            return primaryKey
        }
        
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
        // CREATE TABLE players (
        //   id INTEGER PRIMARY KEY,
        //   name TEXT,
        //   score INTEGER)
        //
        // PRAGMA table_info("players")
        //
        // cid | name  | type    | notnull | dflt_value | pk |
        // 0   | id    | INTEGER | 0       | NULL       | 1  |
        // 1   | name  | TEXT    | 0       | NULL       | 0  |
        // 2   | score | INTEGER | 0       | NULL       | 0  |
        
        let columns = try self.columns(in: tableName)
        
        let primaryKey: PrimaryKeyInfo
        let pkColumns = columns
            .filter { $0.primaryKeyIndex > 0 }
            .sorted { $0.primaryKeyIndex < $1.primaryKeyIndex }
        
        switch pkColumns.count {
        case 0:
            // No explicit primary key => primary key is hidden rowID column
            primaryKey = .hiddenRowID
        case 1:
            // Single column
            let pkColumn = pkColumns.first!
            
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
            // FIXME: We ignore the exception, and consider all INTEGER primary
            // keys as aliases for the rowid:
            if pkColumn.type.uppercased() == "INTEGER" {
                primaryKey = .rowID(pkColumn.name)
            } else {
                primaryKey = .regular([pkColumn.name])
            }
        default:
            // Multi-columns primary key
            primaryKey = .regular(pkColumns.map { $0.name })
        }
        
        schemaCache.set(primaryKey: primaryKey, forTable: tableName)
        return primaryKey
    }
    
    /// The number of columns in the table named `tableName`.
    ///
    /// - throws: A DatabaseError if table does not exist.
    public func columnCount(in tableName: String) throws -> Int {
        return try columns(in: tableName).count
    }
    
    /// The columns in the table named `tableName`.
    ///
    /// - throws: A DatabaseError if table does not exist.
    func columns(in tableName: String) throws -> [ColumnInfo] {
        if let columns = schemaCache.columns(in: tableName) {
            return columns
        }
        
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
        // CREATE TABLE players (
        //   id INTEGER PRIMARY KEY,
        //   firstName TEXT,
        //   lastName TEXT)
        //
        // PRAGMA table_info("players")
        //
        // cid | name  | type    | notnull | dflt_value | pk |
        // 0   | id    | INTEGER | 0       | NULL       | 1  |
        // 1   | name  | TEXT    | 0       | NULL       | 0  |
        // 2   | score | INTEGER | 0       | NULL       | 0  |

        if sqlite3_libversion_number() < 3008005 {
            // Work around a bug in SQLite where PRAGMA table_info would
            // return a result even after the table was deleted.
            if try !tableExists(tableName) {
                throw DatabaseError(message: "no such table: \(tableName)")
            }
        }
        let columns = try ColumnInfo.fetchAll(self, "PRAGMA table_info(\(tableName.quotedDatabaseIdentifier))")
        guard columns.count > 0 else {
            throw DatabaseError(message: "no such table: \(tableName)")
        }
        
        schemaCache.set(columns: columns, forTable: tableName)
        return columns
    }
    
    /// The indexes on table named `tableName`; returns the empty array if the
    /// table does not exist.
    ///
    /// Note: SQLite does not define any index for INTEGER PRIMARY KEY columns:
    /// this method does not return any index that represents this primary key.
    ///
    /// If you want to know if a set of columns uniquely identify a row, prefer
    /// table(_:hasUniqueKey:) instead.
    public func indexes(on tableName: String) throws -> [IndexInfo] {
        if let indexes = schemaCache.indexes(on: tableName) {
            return indexes
        }
        
        let indexes = try Row.fetchAll(self, "PRAGMA index_list(\(tableName.quotedDatabaseIdentifier))").map { row -> IndexInfo in
            let indexName: String = row[1]
            let unique: Bool = row[2]
            let columns = try Row.fetchAll(self, "PRAGMA index_info(\(indexName.quotedDatabaseIdentifier))")
                .map { ($0[0] as Int, $0[2] as String) }
                .sorted { $0.0 < $1.0 }
                .map { $0.1 }
            return IndexInfo(name: indexName, columns: columns, unique: unique)
        }
        
        schemaCache.set(indexes: indexes, forTable: tableName)
        return indexes
    }
    
    /// If there exists a unique key on columns, return the columns
    /// ordered as the matching index (or primay key). Case of returned columns
    /// is not guaranteed.
    func columnsForUniqueKey<T: Sequence>(_ columns: T, in tableName: String) throws -> [String]? where T.Iterator.Element == String {
        let primaryKey = try self.primaryKey(tableName) // first, so that we fail early and consistently should the table not exist
        let lowercasedColumns = Set(columns.map { $0.lowercased() })
        if Set(primaryKey.columns.map { $0.lowercased() }) == lowercasedColumns {
            return primaryKey.columns
        }
        if let index = try indexes(on: tableName).first(where: { index in index.isUnique && Set(index.columns.map { $0.lowercased() }) == lowercasedColumns }) {
            // There is an explicit unique index on the columns
            return index.columns
        }
        return nil
    }
    
    /// True if a sequence of columns uniquely identifies a row, that is to say
    /// if the columns are the primary key, or if there is a unique index on them.
    public func table<T: Sequence>(_ tableName: String, hasUniqueKey columns: T) throws -> Bool where T.Iterator.Element == String {
        return try columnsForUniqueKey(Array(columns), in: tableName) != nil
    }
    
    /// The foreign keys defined on table named `tableName`.
    public func foreignKeys(on tableName: String) throws -> [ForeignKeyInfo] {
        if let foreignKeys = schemaCache.foreignKeys(on: tableName) {
            return foreignKeys
        }
        
        var rawForeignKeys: [(destinationTable: String, mapping: [(origin: String, destination: String?, seq: Int)])] = []
        var previousId: Int? = nil
        for row in try Row.fetchAll(self, "PRAGMA foreign_key_list(\(tableName.quotedDatabaseIdentifier))") {
            // row = <Row id:0 seq:0 table:"parents" from:"parentId" to:"id" on_update:"..." on_delete:"..." match:"...">
            let id: Int = row[0]
            let seq: Int = row[1]
            let table: String = row[2]
            let origin: String = row[3]
            let destination: String? = row[4]
            
            if previousId == id {
                rawForeignKeys[rawForeignKeys.count - 1].mapping.append((origin: origin, destination: destination, seq: seq))
            } else {
                rawForeignKeys.append((destinationTable: table, mapping: [(origin: origin, destination: destination, seq: seq)]))
                previousId = id
            }
        }
        
        let foreignKeys = try rawForeignKeys.map { (destinationTable, columnMapping) -> ForeignKeyInfo in
            let orderedMapping = columnMapping
                .sorted { $0.seq < $1.seq }
                .map { (origin: $0.origin, destination: $0 .destination) }
            
            let completeMapping: [(origin: String, destination: String)]
            if orderedMapping.contains(where: { (_, destination) in destination == nil }) {
                let pk = try primaryKey(destinationTable)
                completeMapping = zip(pk.columns, orderedMapping).map { (pkColumn, arrow) in
                    (origin: arrow.origin, destination: pkColumn)
                }
            } else {
                completeMapping = orderedMapping.map { (origin, destination) in
                    (origin: origin, destination: destination!)
                }
            }
            return ForeignKeyInfo(destinationTable: destinationTable, mapping: completeMapping)
        }
        
        schemaCache.set(foreignKeys: foreignKeys, forTable: tableName)
        return foreignKeys
    }
}

/// A column of a table
struct ColumnInfo : RowConvertible {
    // CREATE TABLE players (
    //   id INTEGER PRIMARY KEY,
    //   firstName TEXT,
    //   lastName TEXT)
    //
    // PRAGMA table_info("players")
    //
    // cid | name  | type    | notnull | dflt_value | pk |
    // 0   | id    | INTEGER | 0       | NULL       | 1  |
    // 1   | name  | TEXT    | 0       | NULL       | 0  |
    // 2   | score | INTEGER | 0       | NULL       | 0  |
    let name: String
    let type: String
    let notNull: Bool
    let defaultDatabaseValue: DatabaseValue
    let primaryKeyIndex: Int
    
    init(row: Row) {
        name = row["name"]
        type = row["type"]
        notNull = row["notnull"]
        defaultDatabaseValue = row["dflt_value"]
        primaryKeyIndex = row["pk"]
    }
}

/// An index on a database table.
///
/// See `Database.indexes(on:)`
public struct IndexInfo {
    /// The name of the index
    public let name: String
    
    /// The indexed columns
    public let columns: [String]
    
    /// True if the index is unique
    public let isUnique: Bool
    
    init(name: String, columns: [String], unique: Bool) {
        self.name = name
        self.columns = columns
        self.isUnique = unique
    }
}

/// Primary keys are returned from the Database.primaryKey(_:) method.
///
/// When the table's primary key is the rowid:
///
///     // CREATE TABLE items (name TEXT)
///     let pk = try db.primaryKey("items")
///     pk.columns     // ["rowid"]
///     pk.rowIDColumn // nil
///     pk.isRowID     // true
///
///     // CREATE TABLE citizens (
///     //   id INTEGER PRIMARY KEY,
///     //   name TEXT
///     // )
///     let pk = try db.primaryKey("citizens")!
///     pk.columns     // ["id"]
///     pk.rowIDColumn // "id"
///     pk.isRowID     // true
///
/// When the table's primary key is not the rowid:
///
///     // CREATE TABLE countries (
///     //   isoCode TEXT NOT NULL PRIMARY KEY
///     //   name TEXT
///     // )
///     let pk = db.primaryKey("countries")!
///     pk.columns     // ["isoCode"]
///     pk.rowIDColumn // nil
///     pk.isRowID     // false
///
///     // CREATE TABLE citizenships (
///     //   citizenID INTEGER NOT NULL REFERENCES citizens(id)
///     //   countryIsoCode TEXT NOT NULL REFERENCES countries(isoCode)
///     //   PRIMARY KEY (citizenID, countryIsoCode)
///     // )
///     let pk = db.primaryKey("citizenships")!
///     pk.columns     // ["citizenID", "countryIsoCode"]
///     pk.rowIDColumn // nil
///     pk.isRowID     // false
public struct PrimaryKeyInfo {
    private enum Impl {
        /// The hidden rowID.
        case hiddenRowID
        
        /// An INTEGER PRIMARY KEY column that aliases the Row ID.
        /// Associated string is the column name.
        case rowID(String)
        
        /// Any primary key, but INTEGER PRIMARY KEY.
        /// Associated strings are column names.
        case regular([String])
    }
    
    private let impl: Impl
    
    static func rowID(_ column: String) -> PrimaryKeyInfo {
        return PrimaryKeyInfo(impl: .rowID(column))
    }
    
    static func regular(_ columns: [String]) -> PrimaryKeyInfo {
        assert(!columns.isEmpty)
        return PrimaryKeyInfo(impl: .regular(columns))
    }
    
    static let hiddenRowID = PrimaryKeyInfo(impl: .hiddenRowID)
    
    /// The columns in the primary key; this array is never empty.
    public var columns: [String] {
        switch impl {
        case .hiddenRowID:
            return [Column.rowID.name]
        case .rowID(let column):
            return [column]
        case .regular(let columns):
            return columns
        }
    }
    
    /// When not nil, the name of the column that contains the INTEGER PRIMARY KEY.
    public var rowIDColumn: String? {
        switch impl {
        case .hiddenRowID:
            return nil
        case .rowID(let column):
            return column
        case .regular:
            return nil
        }
    }
    
    /// When true, the primary key is the rowid:
    public var isRowID: Bool {
        switch impl {
        case .hiddenRowID:
            return true
        case .rowID:
            return true
        case .regular:
            return false
        }
    }
}

/// You get foreign keys from table names, with the
/// `foreignKeys(on:)` method.
public struct ForeignKeyInfo {
    /// The name of the destination table
    public let destinationTable: String
    
    /// The column to column mapping
    public let mapping: [(origin: String, destination: String)]
    
    /// The origin columns
    public var originColumns: [String] {
        return mapping.map { $0.origin }
    }
    
    /// The destination columns
    public var destinationColumns: [String] {
        return mapping.map { $0.destination }
    }
}


// =========================================================================
// MARK: - StatementAuthorizer

/// A protocol around sqlite3_set_authorizer
protocol StatementAuthorizer : class {
    func authorize(_ actionCode: Int32, _ cString1: UnsafePointer<Int8>?, _ cString2: UnsafePointer<Int8>?, _ cString3: UnsafePointer<Int8>?, _ cString4: UnsafePointer<Int8>?) -> Int32
}

/// A class that gathers information about a statement during its compilation.
final class StatementCompilationAuthorizer : StatementAuthorizer {
    /// A dictionary [tablename: Set<columnName>] of accessed columns
    var selectionInfo = SelectStatement.SelectionInfo()
    
    /// What this statement does to the database
    var databaseEventKinds: [DatabaseEventKind] = []
    
    /// True if a statement alter the schema in a way that required schema cache
    /// invalidation. Adding a column to a table does invalidate the schema
    /// cache, but not adding a table.
    var invalidatesDatabaseSchemaCache = false
    
    /// Not nil if a statement is a BEGIN/COMMIT/ROLLBACK/RELEASE transaction/savepoint statement.
    var transactionStatementInfo: UpdateStatement.TransactionStatementInfo?
    
    var needsTruncateOptimizationPreventionDuringExecution = false
    
    private var isDropTableStatement = false
    
    func authorize(_ actionCode: Int32, _ cString1: UnsafePointer<Int8>?, _ cString2: UnsafePointer<Int8>?, _ cString3: UnsafePointer<Int8>?, _ cString4: UnsafePointer<Int8>?) -> Int32 {
        // print("StatementCompilationAuthorizer: \(actionCode) \([cString1, cString2, cString3, cString4].flatMap { $0.map({ String(cString: $0) }) })")
        
        switch actionCode {
        case SQLITE_DROP_TABLE, SQLITE_DROP_TEMP_TABLE, SQLITE_DROP_TEMP_VIEW, SQLITE_DROP_VIEW, SQLITE_DETACH, SQLITE_ALTER_TABLE, SQLITE_DROP_VTABLE, SQLITE_CREATE_INDEX, SQLITE_CREATE_TEMP_INDEX, SQLITE_DROP_INDEX, SQLITE_DROP_TEMP_INDEX:
            if actionCode == SQLITE_DROP_TABLE || actionCode == SQLITE_DROP_VTABLE {
                isDropTableStatement = true
            }
            invalidatesDatabaseSchemaCache = true
            return SQLITE_OK
        case SQLITE_READ:
            guard let tableName = cString1.map({ String(cString: $0) }) else { return SQLITE_OK }
            guard let columnName = cString2.map({ String(cString: $0) }) else { return SQLITE_OK }
            if columnName.isEmpty {
                // SELECT COUNT(*) FROM table
                selectionInfo.insert(allColumnsOfTable: tableName)
            } else {
                // SELECT column FROM table
                selectionInfo.insert(column: columnName, ofTable: tableName)
            }
            return SQLITE_OK
        case SQLITE_INSERT:
            guard let tableName = cString1.map({ String(cString: $0) }) else { return SQLITE_OK }
            databaseEventKinds.append(.insert(tableName: tableName))
            return SQLITE_OK
        case SQLITE_DELETE:
            guard !isDropTableStatement else { return SQLITE_OK }
            guard let tableName = cString1.map({ String(cString: $0) }), tableName != "sqlite_master" else { return SQLITE_OK }
            databaseEventKinds.append(.delete(tableName: tableName))
            // Prevent the [truncate optimization](https://www.sqlite.org/lang_delete.html#truncateopt)
            // See TruncateOptimizationBlocker
            needsTruncateOptimizationPreventionDuringExecution = true
            return SQLITE_IGNORE
        case SQLITE_UPDATE:
            guard let tableName = cString1.map({ String(cString: $0) }) else { return SQLITE_OK }
            guard let columnName = cString2.map({ String(cString: $0) }) else { return SQLITE_OK }
            insertUpdateEventKind(tableName: tableName, columnName: columnName)
            return SQLITE_OK
        case SQLITE_TRANSACTION:
            guard let rawAction = cString1.map({ String(cString: $0) }) else { return SQLITE_OK }
            let action = UpdateStatement.TransactionStatementInfo.TransactionAction(rawValue: rawAction)!
            transactionStatementInfo = .transaction(action: action)
            return SQLITE_OK
        case SQLITE_SAVEPOINT:
            guard let rawAction = cString1.map({ String(cString: $0) }) else { return SQLITE_OK }
            guard let savepointName = cString2.map({ String(cString: $0) }) else { return SQLITE_OK }
            let action = UpdateStatement.TransactionStatementInfo.SavepointAction(rawValue: rawAction)!
            transactionStatementInfo = .savepoint(name: savepointName, action: action)
            return SQLITE_OK
        case SQLITE_FUNCTION:
            // Starting SQLite 3.19.0, `SELECT COUNT(*) FROM table` triggers
            // an authorization callback for SQLITE_READ with an empty
            // column: http://www.sqlite.org/changes.html#version_3_19_0
            //
            // Before SQLite 3.19.0, `SELECT COUNT(*) FROM table` does not
            // trigger any authorization callback that tells about the
            // counted table: any use of the COUNT function makes the
            // selection undetermined.
            guard sqlite3_libversion_number() < 3019000 else { return SQLITE_OK }
            guard let functionName = cString2.map({ String(cString: $0) }) else { return SQLITE_OK }
            if functionName.uppercased() == "COUNT" {
                selectionInfo = SelectStatement.SelectionInfo.unknown()
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
/// Warning: to perform well, this authorizer requires that:
//
/// - It is used during statement execution, not during statement compilation.
/// - Statement compilation was authorized with a StatementCompilationAuthorizer
///   that has set its needsTruncateOptimizationPreventionDuringExecution flag.
final class TruncateOptimizationBlocker : StatementAuthorizer {
    func authorize(_ actionCode: Int32, _ cString1: UnsafePointer<Int8>?, _ cString2: UnsafePointer<Int8>?, _ cString3: UnsafePointer<Int8>?, _ cString4: UnsafePointer<Int8>?) -> Int32 {
        // print("TruncateOptimizationBlocker: \(actionCode) \([cString1, cString2, cString3, cString4].flatMap { $0.map({ String(cString: $0) }) })")
        return (actionCode == SQLITE_DELETE) ? SQLITE_IGNORE : SQLITE_OK
    }
}


// =========================================================================
// MARK: - Transactions & Savepoint

extension Database {
    
    /// The extent of a transaction observation
    ///
    /// See Database.add(transactionObserver:extent:)
    public enum TransactionObservationExtent {
        /// Observation lasts until observer is deallocated
        case observerLifetime
        /// Observation lasts until the next transaction
        case nextTransaction
        /// Observation lasts until the database is closed
        case databaseLifetime
    }
    
    /// Executes a block inside a database transaction.
    ///
    ///     try dbQueue.inDatabase do {
    ///         try db.inTransaction {
    ///             try db.execute("INSERT ...")
    ///             return .commit
    ///         }
    ///     }
    ///
    /// If the block throws an error, the transaction is rollbacked and the
    /// error is rethrown.
    ///
    /// This method is not reentrant: you can't nest transactions.
    ///
    /// - parameters:
    ///     - kind: The transaction type (default nil). If nil, the transaction
    ///       type is configuration.defaultTransactionKind, which itself
    ///       defaults to .immediate. See https://www.sqlite.org/lang_transaction.html
    ///       for more information.
    ///     - block: A block that executes SQL statements and return either
    ///       .commit or .rollback.
    /// - throws: The error thrown by the block.
    public func inTransaction(_ kind: TransactionKind? = nil, _ block: () throws -> TransactionCompletion) throws {
        // Begin transaction
        try beginTransaction(kind)
        
        // Now that transaction has begun, we'll rollback in case of error.
        // But we'll throw the first caught error, so that user knows
        // what happened.
        var firstError: Error? = nil
        let needsRollback: Bool
        do {
            let completion = try block()
            switch completion {
            case .commit:
                try commit()
                needsRollback = false
            case .rollback:
                needsRollback = true
            }
        } catch {
            firstError = error
            needsRollback = true
        }
        
        if needsRollback {
            do {
                try rollback()
            } catch {
                if firstError == nil {
                    firstError = error
                }
            }
        }

        if let firstError = firstError {
            throw firstError
        }
    }
    
    /// Executes a block inside a savepoint.
    ///
    ///     try dbQueue.inDatabase do {
    ///         try db.inSavepoint {
    ///             try db.execute("INSERT ...")
    ///             return .commit
    ///         }
    ///     }
    ///
    /// If the block throws an error, the savepoint is rollbacked and the
    /// error is rethrown.
    ///
    /// This method is reentrant: you can nest savepoints.
    ///
    /// - parameter block: A block that executes SQL statements and return
    ///   either .commit or .rollback.
    /// - throws: The error thrown by the block.
    public func inSavepoint(_ block: () throws -> TransactionCompletion) throws {
        // By default, top level SQLite savepoints open a deferred transaction.
        //
        // But GRDB database configuration mandates a default transaction kind
        // that we have to honor.
        //
        // So when the default GRDB transaction kind is not deferred, we open a
        // transaction instead
        guard isInsideTransaction || configuration.defaultTransactionKind == .deferred else {
            return try inTransaction(nil, block)
        }

        // If the savepoint is top-level, we'll use ROLLBACK TRANSACTION in
        // order to perform the special error handling of rollbacks (see
        // the rollback method).
        let topLevelSavepoint = !isInsideTransaction
        
        // Begin savepoint
        //
        // We use a single name for savepoints because there is no need
        // using unique savepoint names. User could still mess with them
        // with raw SQL queries, but let's assume that it is unlikely that
        // the user uses "grdb" as a savepoint name.
        try execute("SAVEPOINT grdb")
        
        // Now that savepoint has begun, we'll rollback in case of error.
        // But we'll throw the first caught error, so that user knows
        // what happened.
        var firstError: Error? = nil
        let needsRollback: Bool
        do {
            let completion = try block()
            switch completion {
            case .commit:
                try execute("RELEASE SAVEPOINT grdb")
                needsRollback = false
            case .rollback:
                needsRollback = true
            }
        } catch {
            firstError = error
            needsRollback = true
        }
        
        if needsRollback {
            do {
                if topLevelSavepoint {
                    try rollback()
                } else {
                    // Rollback, and release the savepoint.
                    // Rollback alone is not enough to clear the savepoint from
                    // the SQLite savepoint stack.
                    try execute("ROLLBACK TRANSACTION TO SAVEPOINT grdb")
                    try execute("RELEASE SAVEPOINT grdb")
                }
            } catch {
                if firstError == nil {
                    firstError = error
                }
            }
        }
        
        if let firstError = firstError {
            throw firstError
        }
    }
    
    func beginTransaction(_ kind: TransactionKind? = nil) throws {
        switch kind ?? configuration.defaultTransactionKind {
        case .deferred:
            try execute("BEGIN DEFERRED TRANSACTION")
        case .immediate:
            try execute("BEGIN IMMEDIATE TRANSACTION")
        case .exclusive:
            try execute("BEGIN EXCLUSIVE TRANSACTION")
        }
    }
    
    private func rollback() throws {
        // The SQLite documentation contains two related but distinct techniques
        // to handle rollbacks and errors:
        //
        // https://www.sqlite.org/lang_transaction.html#immediate
        //
        // > Response To Errors Within A Transaction
        // >
        // > If certain kinds of errors occur within a transaction, the
        // > transaction may or may not be rolled back automatically.
        // > The errors that can cause an automatic rollback include:
        // >
        // > - SQLITE_FULL: database or disk full
        // > - SQLITE_IOERR: disk I/O error
        // > - SQLITE_BUSY: database in use by another process
        // > - SQLITE_NOMEM: out or memory
        // >
        // > [...] It is recommended that applications respond to the
        // > errors listed above by explicitly issuing a ROLLBACK
        // > command. If the transaction has already been rolled back
        // > automatically by the error response, then the ROLLBACK
        // > command will fail with an error, but no harm is caused
        // > by this.
        //
        // https://sqlite.org/c3ref/get_autocommit.html
        //
        // > The sqlite3_get_autocommit() interface returns non-zero or zero if
        // > the given database connection is or is not in autocommit mode,
        // > respectively.
        // > 
        // > [...] If certain kinds of errors occur on a statement within a
        // > multi-statement transaction (errors including SQLITE_FULL,
        // > SQLITE_IOERR, SQLITE_NOMEM, SQLITE_BUSY, and SQLITE_INTERRUPT) then
        // > the transaction might be rolled back automatically. The only way to
        // > find out whether SQLite automatically rolled back the transaction
        // > after an error is to use this function.
        //
        // The second technique is more robust, because we don't have to guess
        // which rollback errors should be ignored, and which rollback errors
        // should be exposed to the library user.
        if sqlite3_get_autocommit(sqliteConnection) == 0 {
            try execute("ROLLBACK TRANSACTION")
        }
    }
    
    func commit() throws {
        try execute("COMMIT TRANSACTION")
    }
    
    /// Add a transaction observer, so that it gets notified of
    /// database changes.
    ///
    /// - parameter transactionObserver: A transaction observer.
    /// - parameter extent: The duration of the observation. The default is
    ///   the observer lifetime (observation lasts until observer
    ///   is deallocated).
    public func add(transactionObserver: TransactionObserver, extent: TransactionObservationExtent = .observerLifetime) {
        SchedulingWatchdog.preconditionValidQueue(self)
        transactionObservers.append(ManagedTransactionObserver(observer: transactionObserver, extent: extent))
        if transactionObservers.count == 1 {
            installUpdateHook()
        }
    }
    
    /// Remove a transaction observer.
    public func remove(transactionObserver: TransactionObserver) {
        SchedulingWatchdog.preconditionValidQueue(self)
        transactionObservers.removeFirst { $0.isWrapping(transactionObserver) }
        if transactionObservers.isEmpty {
            uninstallUpdateHook()
        }
    }
    
    /// Registers a closure to be executed after the next or current
    /// transaction completion.
    ///
    ///     dbQueue.inTransaction { db in
    ///         db.afterNextTransactionCommit { _ in
    ///             print("commit did succeed")
    ///         }
    ///         ...
    ///         return .commit // prints "commit did succeed"
    ///     }
    ///
    /// If the transaction is rollbacked, the closure is not executed.
    ///
    /// If the transaction is committed, the closure is executed in a protected
    /// dispatch queue, serialized will all database updates.
    public func afterNextTransactionCommit(_ closure: @escaping (Database) -> ()) {
        class CommitHandler : TransactionObserver {
            let closure: (Database) -> ()
            
            init(_ closure: @escaping (Database) -> ()) {
                self.closure = closure
            }
            
            // Ignore individual changes and transaction rollbacks
            func observes(eventsOfKind eventKind: DatabaseEventKind) -> Bool { return false }
            #if SQLITE_ENABLE_PREUPDATE_HOOK
            func databaseWillChange(with event: DatabasePreUpdateEvent) { }
            #endif
            func databaseDidChange(with event: DatabaseEvent) { }
            func databaseWillCommit() throws { }
            func databaseDidRollback(_ db: Database) { }
            
            // On commit, run closure
            func databaseDidCommit(_ db: Database) {
                closure(db)
            }
        }
        
        add(transactionObserver: CommitHandler(closure), extent: .nextTransaction)
    }
    
    /// Remove transaction observers that have stopped observing transaction,
    /// and uninstall SQLite update hooks if there is no remaining observers.
    private func cleanupTransactionObservers() {
        transactionObservers = transactionObservers.filter { $0.isObserving }
        if transactionObservers.isEmpty {
            uninstallUpdateHook()
        }
    }
    
    /// Checks that a SQL query is valid for a select statement.
    ///
    /// Select statements do not call database.updateStatementDidExecute().
    /// Here we make sure that the update statements we track are not hidden in
    /// a select statement.
    ///
    /// An INSERT statement will pass, but not DROP TABLE (which invalidates the
    /// database cache), or RELEASE SAVEPOINT (which alters the savepoint stack)
    static func preconditionValidSelectStatement(sql: String, authorizer: StatementCompilationAuthorizer) {
        GRDBPrecondition(authorizer.invalidatesDatabaseSchemaCache == false, "Invalid statement type for query \(String(reflecting: sql)): use UpdateStatement instead.")
        GRDBPrecondition(authorizer.transactionStatementInfo == nil, "Invalid statement type for query \(String(reflecting: sql)): use UpdateStatement instead.")
        
        // Don't check for authorizer.databaseEventKinds.isEmpty
        //
        // When authorizer.databaseEventKinds.isEmpty is NOT empty, this means
        // that the database is changed by the statement.
        //
        // It thus looks like the statement should be performed by an
        // UpdateStatement, not a SelectStatement: transaction authorizers are not
        // notified of database changes when they are executed by
        // a SelectStatement.
        //
        // However https://github.com/groue/GRDB.swift/issues/80 and
        // https://github.com/groue/GRDB.swift/issues/82 have shown that SELECT
        // statements on virtual tables can generate database changes.
        //
        // :-(
        //
        // OK, this is getting very difficult to protect the user against
        // himself: just give up, and allow SelectStatement to execute database
        // changes. We'll cope with eventual troubles later, when they occur.
        //
        // GRDBPrecondition(authorizer.databaseEventKinds.isEmpty, "Invalid statement type for query \(String(reflecting: sql)): use UpdateStatement instead.")
    }
    
    func updateStatementWillExecute(_ statement: UpdateStatement) {
        // Grab the transaction observers that are interested in the actions
        // performed by the statement.
        let databaseEventKinds = statement.databaseEventKinds
        activeTransactionObservers = transactionObservers.filter { observer in
            return databaseEventKinds.contains(where: observer.observes)
        }
    }
    
    func selectStatementDidFail(_ statement: SelectStatement) {
        // Failed statements can not be reused, because sqlite3_reset won't
        // be able to restore the statement to its initial state:
        // https://www.sqlite.org/c3ref/reset.html
        //
        // So make sure we clear this statement from the cache.
        grdbStatementCache.remove(statement)
        userStatementCache.remove(statement)
    }
    
    /// Some failed statements interest transaction observers.
    func updateStatementDidFail(_ statement: UpdateStatement) throws {
        // Wait for next statement
        activeTransactionObservers = []
        
        // Reset transactionHookState before didRollback eventually executes
        // other statements.
        let transactionHookState = self.transactionHookState
        self.transactionHookState = .pending
        
        // Failed statements can not be reused, because sqlite3_reset won't
        // be able to restore the statement to its initial state:
        // https://www.sqlite.org/c3ref/reset.html
        //
        // So make sure we clear this statement from the cache.
        grdbStatementCache.remove(statement)
        userStatementCache.remove(statement)
        
        switch transactionHookState {
        case .rollback:
            // Don't notify observers because we're in a failed implicit
            // transaction here (like an INSERT which fails with
            // SQLITE_CONSTRAINT error)
            didRollback(notifyTransactionObservers: false)
        case .cancelledCommit(let error):
            didRollback(notifyTransactionObservers: true)
            throw error
        default:
            break
        }
    }
    
    /// Some succeeded statements invalidate the database cache, others interest
    /// transaction observers, and others modify the savepoint stack.
    func updateStatementDidExecute(_ statement: UpdateStatement) {
        // Wait for next statement
        activeTransactionObservers = []
        
        if statement.invalidatesDatabaseSchemaCache {
            clearSchemaCache()
        }
        
        if let transactionStatementInfo = statement.transactionStatementInfo {
            switch transactionStatementInfo {
            case .transaction(action: let action):
                switch action {
                case .begin:
                    break
                case .commit:
                    if case .pending = self.transactionHookState {
                        // A COMMIT statement has ended a deferred transaction
                        // that did not open, and sqlite_commit_hook was not
                        // called.
                        //
                        //  BEGIN DEFERRED TRANSACTION
                        //  COMMIT
                        self.transactionHookState = .commit
                    }
                case .rollback:
                    break
                }
            case .savepoint(name: let name, action: let action):
                switch action {
                case .begin:
                    savepointStack.beginSavepoint(named: name)
                case .release:
                    savepointStack.releaseSavepoint(named: name)
                    if savepointStack.isEmpty {
                        let eventsBuffer = savepointStack.eventsBuffer
                        savepointStack.clear()
                        for (event, observers) in eventsBuffer {
                            for observer in observers {
                                event.send(to: observer)
                            }
                        }
                    }
                case .rollback:
                    savepointStack.rollbackSavepoint(named: name)
                }
            }
        }
        
        // Reset transactionHookState before didCommit or didRollback eventually
        // execute other statements.
        let transactionHookState = self.transactionHookState
        self.transactionHookState = .pending
        
        switch transactionHookState {
        case .commit:
            didCommit()
        case .rollback:
            didRollback(notifyTransactionObservers: true)
        default:
            break
        }
    }
    
    /// See sqlite3_commit_hook
    func willCommit() throws {
        let eventsBuffer = savepointStack.eventsBuffer
        savepointStack.clear()

        for (event, observers) in eventsBuffer {
            for observer in observers {
                event.send(to: observer)
            }
        }
        for observer in transactionObservers {
            try observer.databaseWillCommit()
        }
    }
    
#if SQLITE_ENABLE_PREUPDATE_HOOK
    /// See sqlite3_preupdate_hook
    private func willChange(with event: DatabasePreUpdateEvent) {
        if savepointStack.isEmpty {
            // Notify all interested transactionObservers.
            for observer in activeTransactionObservers {
                observer.databaseWillChange(with: event)
            }
        } else {
            // Buffer both event and the observers that should be notified of the event.
            savepointStack.eventsBuffer.append((event: event.copy(), observers: activeTransactionObservers))
        }
    }
#endif
    
    /// See sqlite3_update_hook
    private func didChange(with event: DatabaseEvent) {
        if savepointStack.isEmpty {
            // Notify all interested transactionObservers.
            for observer in activeTransactionObservers {
                observer.databaseDidChange(with: event)
            }
        } else {
            // Buffer both event and the observers that should be notified of the event.
            savepointStack.eventsBuffer.append((event: event.copy(), observers: activeTransactionObservers))
        }
    }
    
    private func didCommit() {
        savepointStack.clear()
        
        for observer in transactionObservers {
            observer.databaseDidCommit(self)
        }
        cleanupTransactionObservers()
    }
    
    private func didRollback(notifyTransactionObservers: Bool) {
        savepointStack.clear()
        
        if notifyTransactionObservers {
            for observer in transactionObservers {
                observer.databaseDidRollback(self)
            }
        }
        cleanupTransactionObservers()
    }
    
    private func installUpdateHook() {
        let dbPointer = Unmanaged.passUnretained(self).toOpaque()
        sqlite3_update_hook(sqliteConnection, { (dbPointer, updateKind, databaseNameCString, tableNameCString, rowID) in
            let db = Unmanaged<Database>.fromOpaque(dbPointer!).takeUnretainedValue()
            db.didChange(with: DatabaseEvent(
                kind: DatabaseEvent.Kind(rawValue: updateKind)!,
                rowID: rowID,
                databaseNameCString: databaseNameCString,
                tableNameCString: tableNameCString))
        }, dbPointer)
        
        #if SQLITE_ENABLE_PREUPDATE_HOOK
            sqlite3_preupdate_hook(sqliteConnection, { (dbPointer, databaseConnection, updateKind, databaseNameCString, tableNameCString, initialRowID, finalRowID) in
                let db = Unmanaged<Database>.fromOpaque(dbPointer!).takeUnretainedValue()
                db.willChange(with: DatabasePreUpdateEvent(
                    connection: databaseConnection!,
                    kind: DatabasePreUpdateEvent.Kind(rawValue: updateKind)!,
                    initialRowID: initialRowID,
                    finalRowID: finalRowID,
                    databaseNameCString: databaseNameCString,
                    tableNameCString: tableNameCString))
            }, dbPointer)
        #endif
    }
    
    private func uninstallUpdateHook() {
        sqlite3_update_hook(sqliteConnection, nil, nil)
        #if SQLITE_ENABLE_PREUPDATE_HOOK
            sqlite3_preupdate_hook(sqliteConnection, nil, nil)
        #endif
    }
}


/// A transaction observer is notified of all changes and transactions committed
/// or rollbacked on a database.
///
/// Adopting types must be a class.
public protocol TransactionObserver : class {
    
    /// Filters database changes that should be notified the the
    /// databaseDidChange(with:) method.
    func observes(eventsOfKind eventKind: DatabaseEventKind) -> Bool
    
    /// Notifies a database change (insert, update, or delete).
    ///
    /// The change is pending until the end of the current transaction, notified
    /// to databaseWillCommit, databaseDidCommit and databaseDidRollback.
    ///
    /// This method is called on the database queue.
    ///
    /// The event is only valid for the duration of this method call. If you
    /// need to keep it longer, store a copy of its properties.
    ///
    /// - warning: this method must not change the database.
    func databaseDidChange(with event: DatabaseEvent)
    
    /// When a transaction is about to be committed, the transaction observer
    /// has an opportunity to rollback pending changes by throwing an error.
    ///
    /// This method is called on the database queue.
    ///
    /// - warning: this method must not change the database.
    ///
    /// - throws: An eventual error that rollbacks pending changes.
    func databaseWillCommit() throws
    
    /// Database changes have been committed.
    ///
    /// This method is called on the database queue. It can change the database.
    func databaseDidCommit(_ db: Database)
    
    /// Database changes have been rollbacked.
    ///
    /// This method is called on the database queue. It can change the database.
    func databaseDidRollback(_ db: Database)
    
    #if SQLITE_ENABLE_PREUPDATE_HOOK
    /// Notifies before a database change (insert, update, or delete)
    /// with change information (initial / final values for the row's
    /// columns). (Called *before* databaseDidChangeWithEvent.)
    ///
    /// The change is pending until the end of the current transaction,
    /// and you always get a second chance to get basic event information in
    /// the databaseDidChangeWithEvent callback.
    ///
    /// This callback is mostly useful for calculating detailed change
    /// information for a row, and provides the initial / final values.
    ///
    /// This method is called on the database queue.
    ///
    /// The event is only valid for the duration of this method call. If you
    /// need to keep it longer, store a copy of its properties.
    ///
    /// - warning: this method must not change the database.
    ///
    /// Availability Info:
    ///
    ///     Requires SQLite 3.13.0 +
    ///     Compiled with option SQLITE_ENABLE_PREUPDATE_HOOK
    ///
    ///     As of OSX 10.11.5, and iOS 9.3.2, the built-in SQLite library
    ///     does not have this enabled, so you'll need to compile your own
    ///     copy using GRDBCustomSQLite. See the README.md in /SQLiteCustom/
    ///
    ///     The databaseDidChangeWithEvent callback is always available,
    ///     and may provide most/all of what you need.
    ///     (For example, FetchedRecordsController is built without using
    ///     this functionality.)
    ///
    func databaseWillChange(with event: DatabasePreUpdateEvent)
    #endif
}

/// This class manages the observation extent of a transaction observer
private final class ManagedTransactionObserver : TransactionObserver {
    let extent: Database.TransactionObservationExtent
    private weak var weakObserver: TransactionObserver?
    private var strongObserver: TransactionObserver?
    private var observer: TransactionObserver? { return strongObserver ?? weakObserver }
    
    fileprivate var isObserving: Bool {
        return observer != nil
    }
    
    init(observer: TransactionObserver, extent: Database.TransactionObservationExtent) {
        self.extent = extent
        switch extent {
        case .observerLifetime:
            weakObserver = observer
        case .nextTransaction:
            // This strong reference will be released in databaseDidCommit() and databaseDidRollback()
            strongObserver = observer
        case .databaseLifetime:
            strongObserver = observer
        }
    }
    
    func isWrapping(_ observer: TransactionObserver) -> Bool {
        return self.observer === observer
    }
    
    func observes(eventsOfKind eventKind: DatabaseEventKind) -> Bool {
        return observer?.observes(eventsOfKind: eventKind) ?? false
    }
    
    func databaseDidChange(with event: DatabaseEvent) {
        observer?.databaseDidChange(with: event)
    }
    
    func databaseWillCommit() throws {
        try observer?.databaseWillCommit()
    }
    
    func databaseDidCommit(_ db: Database) {
        switch extent {
        case .observerLifetime, .databaseLifetime:
            observer?.databaseDidCommit(db)
        case .nextTransaction:
            if let observer = self.observer {
                // make sure observer is no longer notified
                strongObserver = nil
                observer.databaseDidCommit(db)
            }
        }
    }
    
    func databaseDidRollback(_ db: Database) {
        switch extent {
        case .observerLifetime, .databaseLifetime:
            observer?.databaseDidRollback(db)
        case .nextTransaction:
            if let observer = self.observer {
                // make sure observer is no longer notified
                strongObserver = nil
                observer.databaseDidRollback(db)
            }
        }
    }
    
    #if SQLITE_ENABLE_PREUPDATE_HOOK
    func databaseWillChange(with event: DatabasePreUpdateEvent) {
        observer?.databaseWillChange(with: event)
    }
    #endif
}

/// A kind of database event. See Database.add(transactionObserver:)
/// and DatabaseWriter.add(transactionObserver:).
public enum DatabaseEventKind {
    /// The insertion of a row in a database table
    case insert(tableName: String)
    
    /// The deletion of a row in a database table
    case delete(tableName: String)
    
    /// The update of a set of columns in a database table
    case update(tableName: String, columnNames: Set<String>)
    
    /// Returns whether event has any impact on tables and columns described
    /// by selectionInfo.
    public func impacts(_ selectionInfo: SelectStatement.SelectionInfo) -> Bool {
        switch self {
        case .delete(let tableName):
            return selectionInfo.contains(anyColumnFrom: tableName)
        case .insert(let tableName):
            return selectionInfo.contains(anyColumnFrom: tableName)
        case .update(let tableName, let updatedColumnNames):
            return selectionInfo.contains(anyColumnIn: updatedColumnNames, from: tableName)
        }
    }

}

extension DatabaseEventKind {
    /// The impacted database table
    public var tableName: String {
        switch self {
        case .insert(tableName: let tableName): return tableName
        case .delete(tableName: let tableName): return tableName
        case .update(tableName: let tableName, columnNames: _): return tableName
        }
    }
}

protocol DatabaseEventProtocol {
    func send(to observer: TransactionObserver)
}

/// A database event, notified to TransactionObserver.
public struct DatabaseEvent {
    
    /// An event kind
    public enum Kind: Int32 {
        /// SQLITE_INSERT
        case insert = 18
        
        /// SQLITE_DELETE
        case delete = 9
        
        /// SQLITE_UPDATE
        case update = 23
    }
    
    /// The event kind
    public let kind: Kind
    
    /// The database name
    public var databaseName: String { return impl.databaseName }

    /// The table name
    public var tableName: String { return impl.tableName }
    
    /// The rowID of the changed row.
    public let rowID: Int64
    
    /// Returns an event that can be stored:
    ///
    ///     class MyObserver: TransactionObserver {
    ///         var events: [DatabaseEvent]
    ///         func databaseDidChange(with event: DatabaseEvent) {
    ///             events.append(event.copy())
    ///         }
    ///     }
    public func copy() -> DatabaseEvent {
        return impl.copy(self)
    }
    
    fileprivate init(kind: Kind, rowID: Int64, impl: DatabaseEventImpl) {
        self.kind = kind
        self.rowID = rowID
        self.impl = impl
    }
    
    init(kind: Kind, rowID: Int64, databaseNameCString: UnsafePointer<Int8>?, tableNameCString: UnsafePointer<Int8>?) {
        self.init(kind: kind, rowID: rowID, impl: MetalDatabaseEventImpl(databaseNameCString: databaseNameCString, tableNameCString: tableNameCString))
    }
    
    private let impl: DatabaseEventImpl
}

extension DatabaseEvent : DatabaseEventProtocol {
    func send(to observer: TransactionObserver) {
        observer.databaseDidChange(with: self)
    }
}

/// Protocol for internal implementation of DatabaseEvent
private protocol DatabaseEventImpl {
    var databaseName: String { get }
    var tableName: String { get }
    func copy(_ event: DatabaseEvent) -> DatabaseEvent
}

/// Optimization: MetalDatabaseEventImpl does not create Swift strings from raw
/// SQLite char* until actually asked for databaseName or tableName.
private struct MetalDatabaseEventImpl : DatabaseEventImpl {
    let databaseNameCString: UnsafePointer<Int8>?
    let tableNameCString: UnsafePointer<Int8>?

    var databaseName: String { return String(cString: databaseNameCString!) }
    var tableName: String { return String(cString: tableNameCString!) }
    func copy(_ event: DatabaseEvent) -> DatabaseEvent {
        return DatabaseEvent(kind: event.kind, rowID: event.rowID, impl: CopiedDatabaseEventImpl(databaseName: databaseName, tableName: tableName))
    }
}

/// Impl for DatabaseEvent that contains copies of event strings.
private struct CopiedDatabaseEventImpl : DatabaseEventImpl {
    let databaseName: String
    let tableName: String
    func copy(_ event: DatabaseEvent) -> DatabaseEvent {
        return event
    }
}

#if SQLITE_ENABLE_PREUPDATE_HOOK

    public struct DatabasePreUpdateEvent {
        
        /// An event kind
        public enum Kind: Int32 {
            /// SQLITE_INSERT
            case insert = 18
            
            /// SQLITE_DELETE
            case delete = 9
            
            /// SQLITE_UPDATE
            case update = 23
        }
        
        /// The event kind
        public let kind: Kind
        
        /// The database name
        public var databaseName: String { return impl.databaseName }
        
        /// The table name
        public var tableName: String { return impl.tableName }
        
        /// The number of columns in the row that is being inserted, updated, or deleted.
        public var count: Int { return Int(impl.columnsCount) }
        
        /// The triggering depth of the row update
        /// Returns: 
        ///     0  if the preupdate callback was invoked as a result of a direct insert,
        //         update, or delete operation;
        ///     1  for inserts, updates, or deletes invoked by top-level triggers;
        ///     2  for changes resulting from triggers called by top-level triggers;
        ///     ... and so forth
        public var depth: CInt { return impl.depth }
        
        /// The initial rowID of the row being changed for .Update and .Delete changes,
        /// and nil for .Insert changes.
        public let initialRowID: Int64?
        
        /// The final rowID of the row being changed for .Update and .Insert changes,
        /// and nil for .Delete changes.
        public let finalRowID: Int64?
        
        /// The initial database values in the row.
        ///
        /// Values appear in the same order as the columns in the table.
        ///
        /// The result is nil if the event is an .Insert event.
        public var initialDatabaseValues: [DatabaseValue]? {
            guard (kind == .update || kind == .delete) else { return nil }
            return impl.initialDatabaseValues
        }
        
        /// Returns the initial `DatabaseValue` at given index.
        ///
        /// Indexes span from 0 for the leftmost column to (row.count - 1) for the
        /// righmost column.
        ///
        /// The result is nil if the event is an .Insert event.
        public func initialDatabaseValue(atIndex index: Int) -> DatabaseValue? {
            GRDBPrecondition(index >= 0 && index < count, "row index out of range")
            guard (kind == .update || kind == .delete) else { return nil }
            return impl.initialDatabaseValue(atIndex: index)
        }
        
        /// The final database values in the row.
        ///
        /// Values appear in the same order as the columns in the table.
        ///
        /// The result is nil if the event is a .Delete event.
        public var finalDatabaseValues: [DatabaseValue]? {
            guard (kind == .update || kind == .insert) else { return nil }
            return impl.finalDatabaseValues
        }
        
        /// Returns the final `DatabaseValue` at given index.
        ///
        /// Indexes span from 0 for the leftmost column to (row.count - 1) for the
        /// righmost column.
        ///
        /// The result is nil if the event is a .Delete event.
        public func finalDatabaseValue(atIndex index: Int) -> DatabaseValue? {
            GRDBPrecondition(index >= 0 && index < count, "row index out of range")
            guard (kind == .update || kind == .insert) else { return nil }
            return impl.finalDatabaseValue(atIndex: index)
        }
        
        /// Returns an event that can be stored:
        ///
        ///     class MyObserver: TransactionObserver {
        ///         var events: [DatabasePreUpdateEvent]
        ///         func databaseWillChange(with event: DatabasePreUpdateEvent) {
        ///             events.append(event.copy())
        ///         }
        ///     }
        public func copy() -> DatabasePreUpdateEvent {
            return impl.copy(self)
        }
        
        fileprivate init(kind: Kind, initialRowID: Int64?, finalRowID: Int64?, impl: DatabasePreUpdateEventImpl) {
            self.kind = kind
            self.initialRowID = (kind == .update || kind == .delete ) ? initialRowID : nil
            self.finalRowID = (kind == .update || kind == .insert ) ? finalRowID : nil
            self.impl = impl
        }
        
        init(connection: SQLiteConnection, kind: Kind, initialRowID: Int64, finalRowID: Int64, databaseNameCString: UnsafePointer<Int8>?, tableNameCString: UnsafePointer<Int8>?) {
            self.init(kind: kind,
                      initialRowID: (kind == .update || kind == .delete ) ? finalRowID : nil,
                      finalRowID: (kind == .update || kind == .insert ) ? finalRowID : nil,
                      impl: MetalDatabasePreUpdateEventImpl(connection: connection, kind: kind, databaseNameCString: databaseNameCString, tableNameCString: tableNameCString))
        }
        
        private let impl: DatabasePreUpdateEventImpl
    }
    
    extension DatabasePreUpdateEvent : DatabaseEventProtocol {
        func send(to observer: TransactionObserver) {
            observer.databaseWillChange(with: self)
        }
    }
    
    /// Protocol for internal implementation of DatabaseEvent
    private protocol DatabasePreUpdateEventImpl {
        var databaseName: String { get }
        var tableName: String { get }
        
        var columnsCount: CInt { get }
        var depth: CInt { get }
        var initialDatabaseValues: [DatabaseValue]? { get }
        var finalDatabaseValues: [DatabaseValue]? { get }
        
        func initialDatabaseValue(atIndex index: Int) -> DatabaseValue?
        func finalDatabaseValue(atIndex index: Int) -> DatabaseValue?
        
        func copy(_ event: DatabasePreUpdateEvent) -> DatabasePreUpdateEvent
    }
    
    /// Optimization: MetalDatabasePreUpdateEventImpl does not create Swift strings from raw
    /// SQLite char* until actually asked for databaseName or tableName,
    /// nor does it request other data via the sqlite3_preupdate_* APIs
    /// until asked.
    private struct MetalDatabasePreUpdateEventImpl : DatabasePreUpdateEventImpl {
        let connection: SQLiteConnection
        let kind: DatabasePreUpdateEvent.Kind
        
        let databaseNameCString: UnsafePointer<Int8>?
        let tableNameCString: UnsafePointer<Int8>?
        
        var databaseName: String { return String(cString: databaseNameCString!) }
        var tableName: String { return String(cString: tableNameCString!) }
        
        var columnsCount: CInt { return sqlite3_preupdate_count(connection) }
        var depth: CInt { return sqlite3_preupdate_depth(connection) }
        var initialDatabaseValues: [DatabaseValue]? {
            guard (kind == .update || kind == .delete) else { return nil }
            return preupdate_getValues_old(connection)
        }
        
        var finalDatabaseValues: [DatabaseValue]? {
            guard (kind == .update || kind == .insert) else { return nil }
            return preupdate_getValues_new(connection)
        }
        
        func initialDatabaseValue(atIndex index: Int) -> DatabaseValue? {
            let columnCount = columnsCount
            precondition(index >= 0 && index < Int(columnCount), "row index out of range")
            return getValue(connection, column: CInt(index), sqlite_func: { (connection: SQLiteConnection, column: CInt, value: inout SQLiteValue? ) -> CInt in
                return sqlite3_preupdate_old(connection, column, &value)
            })
        }
        
        func finalDatabaseValue(atIndex index: Int) -> DatabaseValue? {
            let columnCount = columnsCount
            precondition(index >= 0 && index < Int(columnCount), "row index out of range")
            return getValue(connection, column: CInt(index), sqlite_func: { (connection: SQLiteConnection, column: CInt, value: inout SQLiteValue? ) -> CInt in
                return sqlite3_preupdate_new(connection, column, &value)
            })
        }
        
        func copy(_ event: DatabasePreUpdateEvent) -> DatabasePreUpdateEvent {
            return DatabasePreUpdateEvent(kind: event.kind, initialRowID: event.initialRowID, finalRowID: event.finalRowID, impl: CopiedDatabasePreUpdateEventImpl(
                    databaseName: databaseName,
                    tableName: tableName,
                    columnsCount: columnsCount,
                    depth: depth,
                    initialDatabaseValues: initialDatabaseValues,
                    finalDatabaseValues: finalDatabaseValues))
        }
    
        private func preupdate_getValues(_ connection: SQLiteConnection, sqlite_func: (_ connection: SQLiteConnection, _ column: CInt, _ value: inout SQLiteValue? ) -> CInt ) -> [DatabaseValue]? {
            let columnCount = sqlite3_preupdate_count(connection)
            guard columnCount > 0 else { return nil }
            
            var columnValues = [DatabaseValue]()
            
            for i in 0..<columnCount {
                let value = getValue(connection, column: i, sqlite_func: sqlite_func)!
                columnValues.append(value)
            }
            
            return columnValues
        }
        
        private func getValue(_ connection: SQLiteConnection, column: CInt, sqlite_func: (_ connection: SQLiteConnection, _ column: CInt, _ value: inout SQLiteValue? ) -> CInt ) -> DatabaseValue? {
            var value : SQLiteValue? = nil
            guard sqlite_func(connection, column, &value) == SQLITE_OK else { return nil }
            if let value = value {
                return DatabaseValue(sqliteValue: value)
            }
            return nil
        }
        
        private func preupdate_getValues_old(_ connection: SQLiteConnection) -> [DatabaseValue]? {
            return preupdate_getValues(connection, sqlite_func: { (connection: SQLiteConnection, column: CInt, value: inout SQLiteValue? ) -> CInt in
                return sqlite3_preupdate_old(connection, column, &value)
            })
        }
        
        private func preupdate_getValues_new(_ connection: SQLiteConnection) -> [DatabaseValue]? {
            return preupdate_getValues(connection, sqlite_func: { (connection: SQLiteConnection, column: CInt, value: inout SQLiteValue? ) -> CInt in
                return sqlite3_preupdate_new(connection, column, &value)
            })
        }
    }
    
    /// Impl for DatabasePreUpdateEvent that contains copies of all event data.
    private struct CopiedDatabasePreUpdateEventImpl : DatabasePreUpdateEventImpl {
        let databaseName: String
        let tableName: String
        let columnsCount: CInt
        let depth: CInt
        let initialDatabaseValues: [DatabaseValue]?
        let finalDatabaseValues: [DatabaseValue]?
        
        func initialDatabaseValue(atIndex index: Int) -> DatabaseValue? { return initialDatabaseValues?[index] }
        func finalDatabaseValue(atIndex index: Int) -> DatabaseValue? { return finalDatabaseValues?[index] }
        
        func copy(_ event: DatabasePreUpdateEvent) -> DatabasePreUpdateEvent {
            return event
        }
    }

#endif

/// The SQLite savepoint stack is described at
/// https://www.sqlite.org/lang_savepoint.html
///
/// This class reimplements the SQLite stack, so that we can:
///
/// - know if there are currently active savepoints (isEmpty)
/// - buffer database events when a savepoint is active, in order to avoid
///   notifying transaction observers of database events that could be
///   rollbacked.
class SavepointStack {
    /// The buffered events. See Database.didChange(with:)
    fileprivate var eventsBuffer: [(event: DatabaseEventProtocol, observers: [TransactionObserver])] = []
    
    /// The savepoint stack, as an array of tuples (savepointName, index in the eventsBuffer array).
    /// Indexes let us drop rollbacked events from the event buffer.
    private var savepoints: [(name: String, index: Int)] = []
    
    var isEmpty: Bool { return savepoints.isEmpty }
    
    func clear() {
        eventsBuffer.removeAll()
        savepoints.removeAll()
    }
    
    func beginSavepoint(named name: String) {
        savepoints.append((name: name.lowercased(), index: eventsBuffer.count))
    }
    
    // https://www.sqlite.org/lang_savepoint.html
    // > The ROLLBACK command with a TO clause rolls back transactions going
    // > backwards in time back to the most recent SAVEPOINT with a matching
    // > name. The SAVEPOINT with the matching name remains on the transaction
    // > stack, but all database changes that occurred after that SAVEPOINT was
    // > created are rolled back. If the savepoint-name in a ROLLBACK TO
    // > command does not match any SAVEPOINT on the stack, then the ROLLBACK
    // > command fails with an error and leaves the state of the
    // > database unchanged.
    func rollbackSavepoint(named name: String) {
        let name = name.lowercased()
        while let pair = savepoints.last, pair.name != name {
            savepoints.removeLast()
        }
        if let savepoint = savepoints.last {
            eventsBuffer.removeLast(eventsBuffer.count - savepoint.index)
        }
        assert(!savepoints.isEmpty || eventsBuffer.isEmpty)
    }
    
    // https://www.sqlite.org/lang_savepoint.html
    // > The RELEASE command starts with the most recent addition to the
    // > transaction stack and releases savepoints backwards in time until it
    // > releases a savepoint with a matching savepoint-name. Prior savepoints,
    // > even savepoints with matching savepoint-names, are unchanged.
    func releaseSavepoint(named name: String) {
        let name = name.lowercased()
        while let pair = savepoints.last, pair.name != name {
            savepoints.removeLast()
        }
        if !savepoints.isEmpty {
            savepoints.removeLast()
        }
    }
}
