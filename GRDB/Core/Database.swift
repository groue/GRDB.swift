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
    
    // MARK: - SQLite C API
    
    /// The raw SQLite connection, suitable for the SQLite C API.
    public let sqliteConnection: SQLiteConnection
    
    // MARK: - Configuration

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
    
    /// The database configuration
    public let configuration: Configuration
    
    // MARK: - Database Information
    
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
    
    // MARK: - Internal properties
    
    // Caches
    var schemaCache: DatabaseSchemaCache    // internal so that it can be tested
    lazy var internalStatementCache = StatementCache(database: self)
    lazy var publicStatementCache = StatementCache(database: self)
    
    // Errors
    var lastErrorCode: ResultCode { return ResultCode(rawValue: sqlite3_errcode(sqliteConnection)) }
    var lastErrorMessage: String? { return String(cString: sqlite3_errmsg(sqliteConnection)) }
    
    // Statement authorizer
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
    
    // Transaction observers management
    lazy var observationBroker = DatabaseObservationBroker(self)
    
    /// The list of compile options used when building SQLite
    static let sqliteCompileOptions: Set<String> = DatabaseQueue().inDatabase { try! Set(String.fetchCursor($0, "PRAGMA COMPILE_OPTIONS")) }
    
    // MARK: - Private properties
    
    private var busyCallback: BusyCallback?
    
    private var functions = Set<DatabaseFunction>()
    private var collations = Set<DatabaseCollation>()
    
    private var isClosed: Bool = false

    // MARK: - Initializer

    init(path: String, configuration: Configuration, schemaCache: DatabaseSchemaCache) throws {
        // Setup the global SQLite error log before connecting to the database.
        Database.setupGlobalErrorLog()
        
        let sqliteConnection = try Database.openConnection(path: path, flags: configuration.SQLiteOpenFlags)
        do {
            try Database.activateExtendedCodes(sqliteConnection)
            #if SQLITE_HAS_CODEC
                try Database.validateSQLCipher(sqliteConnection)
                if let passphrase = configuration.passphrase {
                    try Database.set(passphrase: passphrase, forConnection: sqliteConnection)
                }
            #endif
            try Database.validateDatabaseFormat(sqliteConnection)
        } catch {
            Database.closeConnection(sqliteConnection)
            throw error
        }
        
        self.sqliteConnection = sqliteConnection
        self.configuration = configuration
        self.schemaCache = schemaCache
        
        configuration.SQLiteConnectionDidOpen?()
    }
    
    deinit {
        assert(isClosed)
    }
}

extension Database {

    // MARK: - Database Opening
    
    /// Registers the public Database.logError function as the global SQLite
    /// error log, with sqlite3_config(SQLITE_CONFIG_LOG).
    ///
    /// See https://sqlite.org/c3ref/c_config_covering_index_scan.html#sqliteconfiglog
    private static func setupGlobalErrorLog() {
        // We use a Swift static variable as a way to ensure that the error log
        // is registered once and only once.
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
    
    private static func openConnection(path: String, flags: Int32) throws -> SQLiteConnection {
        // See https://www.sqlite.org/c3ref/open.html
        var sqliteConnection: SQLiteConnection? = nil
        let code = sqlite3_open_v2(path, &sqliteConnection, flags, nil)
        guard code == SQLITE_OK else {
            throw DatabaseError(resultCode: code)
        }
        if let sqliteConnection = sqliteConnection {
            return sqliteConnection
        }
        throw DatabaseError(resultCode: .SQLITE_INTERNAL) // WTF SQLite?
    }
    
    private static func activateExtendedCodes(_ sqliteConnection: SQLiteConnection) throws {
        let code = sqlite3_extended_result_codes(sqliteConnection, 1)
        guard code == SQLITE_OK else {
            throw DatabaseError(resultCode: code, message: String(cString: sqlite3_errmsg(sqliteConnection)))
        }
    }
    
    #if SQLITE_HAS_CODEC
    private static func validateSQLCipher(_ sqliteConnection: SQLiteConnection) throws {
        // https://discuss.zetetic.net/t/important-advisory-sqlcipher-with-xcode-8-and-new-sdks/1688
        //
        // > In order to avoid situations where SQLite might be used
        // > improperly at runtime, we strongly recommend that
        // > applications institute a runtime test to ensure that the
        // > application is actually using SQLCipher on the active
        // > connection.
        var sqliteStatement: SQLiteStatement? = nil
        let code = sqlite3_prepare_v2(sqliteConnection, "PRAGMA cipher_version", -1, &sqliteStatement, nil)
        guard code == SQLITE_OK else {
            throw DatabaseError(resultCode: code, message: String(cString: sqlite3_errmsg(sqliteConnection)))
        }
        defer {
            sqlite3_finalize(sqliteStatement)
        }
        if sqlite3_step(sqliteStatement) != SQLITE_ROW || (sqlite3_column_text(sqliteStatement, 0) == nil) {
            throw DatabaseError(resultCode: .SQLITE_MISUSE, message: """
                GRDB is not linked against SQLCipher. \
                Check https://discuss.zetetic.net/t/important-advisory-sqlcipher-with-xcode-8-and-new-sdks/1688
                """)
        }
    }
    
    private static func set(passphrase: String, forConnection sqliteConnection: SQLiteConnection) throws {
        let data = passphrase.data(using: .utf8)!
        let code = data.withUnsafeBytes { bytes in
            sqlite3_key(sqliteConnection, bytes, Int32(data.count))
        }
        guard code == SQLITE_OK else {
            throw DatabaseError(resultCode: code, message: String(cString: sqlite3_errmsg(sqliteConnection)))
        }
    }
    #endif
    
    private static func validateDatabaseFormat(_ sqliteConnection: SQLiteConnection) throws {
        // Users are surprised when they open a picture as a database and
        // see no error (https://github.com/groue/GRDB.swift/issues/54).
        //
        // So let's fail early if file is not a database, or encrypted with
        // another passphrase.
        let code = sqlite3_exec(sqliteConnection, "SELECT * FROM sqlite_master LIMIT 1", nil, nil, nil)
        guard code == SQLITE_OK else {
            throw DatabaseError(resultCode: code, message: String(cString: sqlite3_errmsg(sqliteConnection)))
        }
    }
}

extension Database {

    // MARK: - Database Setup
    
    /// This method must be called after database initialization
    func setup() throws {
        // Setup trace first, so that setup queries are traced.
        setupTrace()
        try setupForeignKeys()
        setupBusyMode()
        setupDefaultFunctions()
        setupDefaultCollations()
        observationBroker.setup()
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
    
    private func setupForeignKeys() throws {
        // Foreign keys are disabled by default with SQLite3
        if configuration.foreignKeysEnabled {
            try execute("PRAGMA foreign_keys = ON")
        }
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
}

extension Database {

    // MARK: - Database Closing
    
    /// This method must be called before database deallocation
    func close() {
        SchedulingWatchdog.preconditionValidQueue(self)
        assert(!isClosed)
        
        configuration.SQLiteConnectionWillClose?(sqliteConnection)
        internalStatementCache.clear()
        publicStatementCache.clear()
        Database.closeConnection(sqliteConnection)
        isClosed = true
        configuration.SQLiteConnectionDidClose?()
    }
    
    private static func closeConnection(_ sqliteConnection: SQLiteConnection) {
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

extension Database {

    // MARK: - Functions
    
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

extension Database {

    // MARK: - Collations
    
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

extension Database {

    // MARK: - Transactions & Savepoint
    
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
        try beginTransaction(kind ?? configuration.defaultTransactionKind)
        
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
        if !isInsideTransaction && configuration.defaultTransactionKind != .deferred {
            return try inTransaction(configuration.defaultTransactionKind, block)
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
    
    func beginTransaction(_ kind: TransactionKind) throws {
        try execute("BEGIN \(kind.rawValue) TRANSACTION")
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
}

extension Database {

    // MARK: - Memory Management
    
    func releaseMemory() {
        sqlite3_db_release_memory(sqliteConnection)
        schemaCache.clear()
        internalStatementCache.clear()
        publicStatementCache.clear()
    }
}

#if SQLITE_HAS_CODEC
    extension Database {

        // MARK: - Encryption
        
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

extension Database {
    
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
    
    /// A foreign key action.
    ///
    /// See https://www.sqlite.org/foreignkeys.html
    public enum ForeignKeyAction : String {
        case cascade = "CASCADE"
        case restrict = "RESTRICT"
        case setNull = "SET NULL"
        case setDefault = "SET DEFAULT"
    }
    
    /// log function that takes an error message.
    public typealias LogErrorFunction = (_ resultCode: ResultCode, _ message: String) -> Void
    
    /// The end of a transaction: Commit, or Rollback
    public enum TransactionCompletion {
        case commit
        case rollback
    }
    
    /// An SQLite transaction kind. See https://www.sqlite.org/lang_transaction.html
    public enum TransactionKind : String {
        case deferred = "DEFERRED"
        case immediate = "IMMEDIATE"
        case exclusive = "EXCLUSIVE"
    }
}

extension Database {
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
}
