// Import C SQLite functions
#if SWIFT_PACKAGE
import GRDBSQLite
#elseif GRDBCIPHER
import SQLCipher
#elseif !GRDBCUSTOMSQLITE && !GRDBCIPHER
import SQLite3
#endif

import Foundation

/// A raw SQLite connection, suitable for the SQLite C API.
public typealias SQLiteConnection = OpaquePointer

/// A raw SQLite function argument.
typealias SQLiteValue = OpaquePointer

let SQLITE_TRANSIENT = unsafeBitCast(OpaquePointer(bitPattern: -1), to: sqlite3_destructor_type.self)

/// An SQLite connection.
///
/// You don't create `Database` instances directly. Instead, you connect to a
/// database with one of the <doc:DatabaseConnections>, and you use a database
/// access method. For example:
///
/// ```swift
/// let dbQueue = try DatabaseQueue()
///
/// try dbQueue.write { (db: Database) in
///     try Player(name: "Arthur").insert(db)
/// }
/// ```
///
/// `Database` methods that modify, query, or validate the database schema are
/// listed in <doc:DatabaseSchema>.
///
/// ## Topics
///
/// ### Database Information
///
/// - ``changesCount``
/// - ``configuration``
/// - ``debugDescription``
/// - ``description``
/// - ``lastErrorCode``
/// - ``lastErrorMessage``
/// - ``lastInsertedRowID``
/// - ``maximumStatementArgumentCount``
/// - ``sqliteConnection``
/// - ``totalChangesCount``
/// - ``SQLiteConnection``
///
/// ### Database Statements
///
/// - ``allStatements(literal:)``
/// - ``allStatements(sql:arguments:)``
/// - ``cachedStatement(literal:)``
/// - ``cachedStatement(sql:)``
/// - ``execute(literal:)``
/// - ``execute(sql:arguments:)``
/// - ``makeStatement(literal:)``
/// - ``makeStatement(sql:)``
/// - ``SQLStatementCursor``
///
/// ### Database Transactions
///
/// - ``beginTransaction(_:)``
/// - ``commit()``
/// - ``inSavepoint(_:)``
/// - ``inTransaction(_:_:)``
/// - ``isInsideTransaction``
/// - ``readOnly(_:)``
/// - ``rollback()``
/// - ``transactionDate``
/// - ``TransactionCompletion``
/// - ``TransactionKind``
///
/// ### Printing Database Content
///
/// - ``dumpContent(format:to:)``
/// - ``dumpRequest(_:format:to:)``
/// - ``dumpSchema(to:)``
/// - ``dumpSQL(_:format:to:)``
/// - ``dumpTables(_:format:tableHeader:stableOrder:to:)``
/// - ``DumpFormat``
/// - ``DumpTableHeaderOptions``
///
/// ### Database Observation
///
/// - ``add(transactionObserver:extent:)``
/// - ``remove(transactionObserver:)``
/// - ``afterNextTransaction(onCommit:onRollback:)``
/// - ``notifyChanges(in:)``
/// - ``registerAccess(to:)``
///
/// ### Collations
///
/// - ``add(collation:)``
/// - ``reindex(collation:)-171fj``
/// - ``reindex(collation:)-2hxil``
/// - ``remove(collation:)``
/// - ``CollationName``
/// - ``DatabaseCollation``
///
/// ### SQL Functions
///
/// - ``add(function:)``
/// - ``remove(function:)``
/// - ``DatabaseFunction``
///
/// ### Notifications
///
/// - ``resumeNotification``
/// - ``suspendNotification``
///
/// ### Other Database Operations
///
/// - ``add(tokenizer:)``
/// - ``backup(to:pagesPerStep:progress:)``
/// - ``checkpoint(_:on:)``
/// - ``clearSchemaCache()``
/// - ``logError``
/// - ``releaseMemory()``
/// - ``sqliteLibVersionNumber``
/// - ``trace(options:_:)``
///
/// ### Supporting Types
///
/// - ``BusyCallback``
/// - ``BusyMode``
/// - ``CheckpointMode``
/// - ``DatabaseBackupProgress``
/// - ``LogErrorFunction``
/// - ``StorageClass``
/// - ``TraceEvent``
/// - ``TracingOptions``
public final class Database: CustomStringConvertible, CustomDebugStringConvertible {
    // The Database class is not thread-safe. An instance should always be
    // used through a SerializedDatabase.
    
    // MARK: - SQLite C API
    
    /// The raw SQLite connection, suitable for the SQLite C API.
    ///
    /// The result is nil after the database has been successfully closed with
    /// ``DatabaseReader/close()``.
    public private(set) var sqliteConnection: SQLiteConnection?
    
    // MARK: - Configuration
    
    /// The error logging function.
    ///
    /// SQLite can be configured to invoke a callback function containing
    /// an error code and a terse error message whenever anomalies occur.
    ///
    /// This global error callback must be configured early in the lifetime
    /// of your application:
    ///
    /// ```swift
    /// Database.logError = { (resultCode, message) in
    ///     NSLog("%@", "SQLite error \(resultCode): \(message)")
    /// }
    /// ```
    ///
    /// - warning: Database.logError must be set before any database
    ///   connection is opened. This includes the connections that your
    ///   application opens with GRDB, but also connections opened by
    ///   other tools, such as third-party libraries. Setting it after a
    ///   connection has been opened is an SQLite misuse, and has no effect.
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/errlog.html>
    nonisolated(unsafe) public static var logError: LogErrorFunction? = nil {
        didSet {
            if logError != nil {
                _registerErrorLogCallback { (_, code, message) in
                    guard let logError = Database.logError else { return }
                    guard let message = message.map(String.init) else { return }
                    let resultCode = ResultCode(rawValue: code)
                    logError(resultCode, message)
                }
            } else {
                _registerErrorLogCallback(nil)
            }
        }
    }
    
    /// The database configuration.
    public let configuration: Configuration
    
    /// A description of this database connection.
    ///
    /// The returned string is based on the ``Configuration/label``
    /// of ``configuration``.
    public let description: String
    
    public var debugDescription: String { "<Database: \(description)>" }
    
    // MARK: - Database Information
    
    /// The rowID of the most recently inserted row.
    ///
    /// If no row has ever been inserted using this database connection,
    /// the last inserted rowID is zero.
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/c3ref/last_insert_rowid.html>
    public var lastInsertedRowID: Int64 {
        SchedulingWatchdog.preconditionValidQueue(self)
        return sqlite3_last_insert_rowid(sqliteConnection)
    }
    
    /// The number of rows modified, inserted or deleted by the most recent
    /// successful INSERT, UPDATE or DELETE statement.
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/c3ref/changes.html>
    public var changesCount: Int {
        SchedulingWatchdog.preconditionValidQueue(self)
        return Int(sqlite3_changes(sqliteConnection))
    }
    
    /// The total number of rows modified, inserted or deleted by all successful
    /// INSERT, UPDATE or DELETE statements since the database connection was
    /// opened.
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/c3ref/total_changes.html>
    public var totalChangesCount: Int {
        SchedulingWatchdog.preconditionValidQueue(self)
        return Int(sqlite3_total_changes(sqliteConnection))
    }
    
    /// A Boolean value indicating whether the database connection is currently
    /// inside a transaction.
    ///
    /// A database is inside a transaction if and only if it is not in the
    /// autocommit mode. See <https://sqlite.org/c3ref/get_autocommit.html>.
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
        //
        // > If another thread changes the autocommit status of the database
        // > connection while this routine is running, then the return value
        // > is undefined.
        SchedulingWatchdog.preconditionValidQueue(self)
        if sqliteConnection == nil { return false } // Support for SerializedDatabase.deinit
        return sqlite3_get_autocommit(sqliteConnection) == 0
    }
    
    /// The last error code.
    public var lastErrorCode: ResultCode { ResultCode(rawValue: sqlite3_errcode(sqliteConnection)) }
    
    /// The last error message.
    public var lastErrorMessage: String? { String(cString: sqlite3_errmsg(sqliteConnection)) }
    
    // MARK: - Internal properties
    
    let path: String
    
    /// Support for schema changes performed with ``DatabasePool``: each read
    /// access needs to clear the schema cache if the schema has been modified
    /// by the writer connection since the previous read. This property is reset
    /// to `PRAGMA schema_version` at the beginning of each DatabasePool read.
    ///
    /// DatabasePool writer connection and DatabaseQueue do not perform such
    /// automatic schema management: they won't clear their schema cache if an
    /// external connection modifies the schema.
    /// 
    /// See `clearSchemaCacheIfNeeded()`.
    var lastSchemaVersion: Int32?
    
    /// The cache for the available database schemas (main, temp, attached databases).
    var schemaCache = SchemaCache()
    
    /// The cache for statements managed by GRDB. It is distinct from
    /// `publicStatementCache` so that we do not mess with statement arguments
    /// set by the user.
    lazy var internalStatementCache = StatementCache(database: self)
    
    /// The cache for statements managed by the user.
    lazy var publicStatementCache = StatementCache(database: self)
    
    /// The database authorizer provides information about compiled
    /// database statements, and prevents the truncate optimization when
    /// row deletions are observed by transaction observers.
    lazy var authorizer = StatementAuthorizer(self)
    
    /// The observation broker supports database observation and
    /// transaction observers.
    ///
    /// It is nil in read-only connections, because we do not report read-only
    /// transactions to transaction observers.
    private(set) var observationBroker: DatabaseObservationBroker?
    
    /// The list of compile options used when building SQLite
    static func sqliteCompileOptions() throws -> Set<String> {
        try DatabaseQueue().inDatabase {
            try Set(String.fetchCursor($0, sql: "PRAGMA COMPILE_OPTIONS"))
        }
    }
    
    
    /// An integer equal to [`SQLITE_VERSION_NUMBER`](https://www.sqlite.org/c3ref/c_source_id.html).
    ///
    /// This property returns the result of `sqlite3_libversion_number()`.
    ///
    /// ```swift
    /// // Prints, for example, "3048000"
    /// print(Database.sqliteLibVersionNumber)
    /// ```
    @inline(__always)
    @inlinable
    public static var sqliteLibVersionNumber: CInt {
        sqlite3_libversion_number()
    }
    
    /// Whether the database region selected by statement execution is
    /// recorded into `selectedRegion` by `track(_:)`.
    ///
    /// To start recording the selected region, use `recordingSelection(_:_:)`.
    private(set) var isRecordingSelectedRegion = false
    
    /// The database region selected by statement execution, when
    /// `isRecordingSelectedRegion` is true.
    var selectedRegion = DatabaseRegion()
    
    /// Support for `checkForSuspensionViolation(from:)`
    /// This cache is never cleared: we assume journal mode never changes.
    var journalModeCache: String?
    
    // MARK: - Suspension
    
    struct Suspension {
        /// If true, the database is suspended and should not acquire any
        /// write lock in order to avoid the 0xDEAD10CC exception.
        var isSuspended: Bool
        
        /// If true, the database access has been cancelled.
        var isCancelled: Bool
        
        /// If true, the database throws an error when it is cancelled.
        var interruptsWhenCancelled: Bool
        
        func checkCancellation() throws {
            if isCancelled, interruptsWhenCancelled {
                throw CancellationError()
            }
        }
    }
    
    /// Support for `checkForSuspensionViolation(from:)`
    let suspensionMutex = Mutex(Suspension(
        isSuspended: false,
        isCancelled: false,
        interruptsWhenCancelled: true))
    
    // MARK: - Transaction Date
    
    /// Support for `checkForAbortedTransaction()`
    var isInsideTransactionBlock = false
    
    enum AutocommitState {
        case off
        case on
    }
    
    /// The state of the auto-commit mode, as left by the last
    /// executed statement.
    ///
    /// The goal of this property is to detect changes in the auto-commit mode.
    /// When you need to know if the database is currently in the auto-commit
    /// mode, always prefer ``isInsideTransaction``.
    var autocommitState = AutocommitState.on
    
    /// The date of the current transaction, wrapped in a result that is an
    /// error if there was an error grabbing this date when the transaction has
    /// started.
    ///
    /// Invariant: `transactionDateResult` is nil iff connection is not
    /// inside a transaction.
    var transactionDateResult: Result<Date, Error>?
    
    /// The date of the current transaction.
    ///
    /// The returned date is constant at any point during a transaction. It is
    /// set when the database leaves the
    /// [autocommit mode](https://www.sqlite.org/c3ref/get_autocommit.html) with
    /// a `BEGIN` statement.
    ///
    /// When the database is not currently in a transaction, a new date is
    /// returned on each call.
    ///
    /// See <doc:RecordTimestamps> for an example of usage.
    ///
    /// The transaction date, by default, is the start date of the current
    /// transaction. You can override this default behavior by configuring
    /// ``Configuration/transactionClock``.
    public var transactionDate: Date {
        get throws {
            SchedulingWatchdog.preconditionValidQueue(self)
            
            // Check invariant: `transactionDateResult` is nil iff connection
            // is not inside a transaction.
            assert(isInsideTransaction || transactionDateResult == nil)
            
            if let transactionDateResult {
                return try transactionDateResult.get()
            } else {
                return try configuration.transactionClock.now(self)
            }
        }
    }
    
    // MARK: - Private properties
    
    /// Support for ``Configuration/busyMode``.
    private var busyCallback: BusyCallback?
    
    /// Support for ``trace(options:_:)``.
    private var trace: ((TraceEvent) -> Void)?
    
    /// The registered custom SQL functions.
    private var functions: [DatabaseFunction.ID: DatabaseFunction] = [:]
    
    /// The registered custom SQL collations.
    private var collations: [DatabaseCollation.ID: DatabaseCollation] = [:]
    
    /// Support for `beginReadOnly()` and `endReadOnly()`.
    private var readOnlyDepth = 0
    
    // MARK: - Initializer
    
    init(
        path: String,
        description: String,
        configuration: Configuration) throws
    {
        self.sqliteConnection = try Database.openConnection(path: path, flags: configuration.SQLiteOpenFlags)
        self.description = description
        self.configuration = configuration
        self.path = path
        
        // We do not report read-only transactions to transaction observers, so
        // don't bother installing the observation broker for read-only connections.
        if !configuration.readonly {
            observationBroker = DatabaseObservationBroker(self)
        }
    }
    
    deinit {
        assert(sqliteConnection == nil)
    }
    
    // MARK: - Database Opening
    
    private static func openConnection(path: String, flags: CInt) throws -> SQLiteConnection {
        // See <https://www.sqlite.org/c3ref/open.html>
        var sqliteConnection: SQLiteConnection? = nil
        let code = sqlite3_open_v2(path, &sqliteConnection, flags, nil)
        guard code == SQLITE_OK else {
            // https://www.sqlite.org/c3ref/open.html
            // > Whether or not an error occurs when it is opened, resources
            // > associated with the database connection handle should be
            // > released by passing it to sqlite3_close() when it is no
            // > longer required.
            //
            // https://www.sqlite.org/c3ref/close.html
            // > Calling sqlite3_close() or sqlite3_close_v2() with a NULL
            // > pointer argument is a harmless no-op.
            _ = sqlite3_close(sqliteConnection) // ignore result code
            throw DatabaseError(resultCode: code)
        }
        guard let sqliteConnection else {
            throw DatabaseError(resultCode: .SQLITE_INTERNAL) // WTF SQLite?
        }
        return sqliteConnection
    }
    
    // MARK: - Database Setup
    
    /// This method must be called after database initialization
    func setUp() throws {
        setupBusyMode()
        setupDoubleQuotedStringLiterals()
        try setupForeignKeys()
        setupDefaultFunctions()
        setupDefaultCollations()
        setupAuthorizer()
        observationBroker?.installCommitAndRollbackHooks()
        try activateExtendedCodes()
        
        #if SQLITE_HAS_CODEC
        try validateSQLCipher()
        #endif
        
        // Last step before we can start accessing the database.
        try configuration.setUp(self)
        
        try validateFormat()
        configuration.SQLiteConnectionDidOpen?()
    }
    
    /// Performs ``Configuration/JournalModeConfiguration/wal``.
    func setUpWALMode() throws {
        let journalMode = try String.fetchOne(self, sql: "PRAGMA journal_mode = WAL")
        guard journalMode == "wal" else {
            throw DatabaseError(message: "could not activate WAL Mode at path: \(path)")
        }
        
        // https://www.sqlite.org/pragma.html#pragma_synchronous
        // > Many applications choose NORMAL when in WAL mode
        try execute(sql: "PRAGMA synchronous = NORMAL")
        
        // Make sure a non-empty wal file exists.
        //
        // The presence of the wal file avoids an SQLITE_CANTOPEN (14)
        // error when the user opens a pool and reads from it.
        // See <https://github.com/groue/GRDB.swift/issues/102>.
        //
        // The non-empty wal file avoids an SQLITE_ERROR (1) error
        // when the user opens a pool and creates a wal snapshot
        // (which happens when starting a ValueObservation).
        // See <https://github.com/groue/GRDB.swift/issues/1383>.
        let walPath = path + "-wal"
        if try FileManager.default.fileExists(atPath: walPath) == false
            || (URL(fileURLWithPath: walPath).resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) == 0
        {
            try inSavepoint {
                try execute(sql: """
                    CREATE TABLE grdb_issue_102 (id INTEGER PRIMARY KEY);
                    DROP TABLE grdb_issue_102;
                    """)
                return .commit
            }
        }
    }
    
    private func setupDoubleQuotedStringLiterals() {
        if configuration.acceptsDoubleQuotedStringLiterals {
            _enableDoubleQuotedStringLiterals(sqliteConnection)
        } else {
            _disableDoubleQuotedStringLiterals(sqliteConnection)
        }
    }
    
    private func setupForeignKeys() throws {
        // Foreign keys are disabled by default with SQLite3
        if configuration.foreignKeysEnabled {
            try execute(sql: "PRAGMA foreign_keys = ON")
        }
    }
    
    private func setupBusyMode() {
        let busyMode = configuration.readonly
            ? configuration.readonlyBusyMode ?? configuration.busyMode
            : configuration.busyMode
        switch busyMode {
        case .immediateError:
            break
            
        case .timeout(let duration):
            let milliseconds = CInt(duration * 1000)
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
        add(function: .localizedCapitalize)
        add(function: .localizedLowercase)
        add(function: .localizedUppercase)
    }
    
    private func setupDefaultCollations() {
        add(collation: .unicodeCompare)
        add(collation: .caseInsensitiveCompare)
        add(collation: .localizedCaseInsensitiveCompare)
        add(collation: .localizedCompare)
        add(collation: .localizedStandardCompare)
    }
    
    private func setupAuthorizer() {
        // SQLite authorizer is set only once per database connection.
        //
        // This is because authorizer changes have SQLite invalidate statements,
        // with undesired side effects. See:
        //
        // - DatabaseCursorTests.testIssue583()
        // - http://sqlite.1065341.n5.nabble.com/Issue-report-sqlite3-set-authorizer-triggers-error-4-516-SQLITE-ABORT-ROLLBACK-during-statement-itern-td107972.html
        authorizer.register()
    }
    
    private func activateExtendedCodes() throws {
        if (configuration.SQLiteOpenFlags & 0x02000000 /* SQLITE_OPEN_EXRESCODE */) != 0 {
            // Nothing to do
            return
        }
        let code = sqlite3_extended_result_codes(sqliteConnection, 1)
        guard code == SQLITE_OK else {
            throw DatabaseError(resultCode: code, message: String(cString: sqlite3_errmsg(sqliteConnection)))
        }
    }
    
    #if SQLITE_HAS_CODEC
    private func validateSQLCipher() throws {
        // https://discuss.zetetic.net/t/important-advisory-sqlcipher-with-xcode-8-and-new-sdks/1688
        //
        // > In order to avoid situations where SQLite might be used
        // > improperly at runtime, we strongly recommend that
        // > applications institute a runtime test to ensure that the
        // > application is actually using SQLCipher on the active
        // > connection.
        if try String.fetchOne(self, sql: "PRAGMA cipher_version") == nil {
            throw DatabaseError(resultCode: .SQLITE_MISUSE, message: """
                GRDB is not linked against SQLCipher. \
                Check https://discuss.zetetic.net/t/important-advisory-sqlcipher-with-xcode-8-and-new-sdks/1688
                """)
        }
    }
    #endif
    
    private func validateFormat() throws {
        // Users are surprised when they open a picture as a database and
        // see no error (https://github.com/groue/GRDB.swift/issues/54).
        //
        // So let's fail early if file is not a database, or encrypted with
        // another passphrase.
        try makeStatement(sql: "SELECT * FROM sqlite_master LIMIT 1").makeCursor().next()
    }
    
    // MARK: - Database Closing
    
    /// Closes a connection with `sqlite3_close`. This method is intended for
    /// the public `close()` function. It may fail.
    func close() throws {
        SchedulingWatchdog.preconditionValidQueue(self)
        
        guard let sqliteConnection else {
            // Already closed
            return
        }
        
        configuration.SQLiteConnectionWillClose?(sqliteConnection)
        
        // Finalize all cached statements since they would prevent
        // immediate connection closing.
        internalStatementCache.clear()
        publicStatementCache.clear()
        
        // https://www.sqlite.org/c3ref/close.html
        // > If the database connection is associated with unfinalized prepared
        // > statements or unfinished sqlite3_backup objects then
        // > sqlite3_close() will leave the database connection open and
        // > return SQLITE_BUSY.
        let code = sqlite3_close(sqliteConnection)
        guard code == SQLITE_OK else {
            // So there remain some unfinalized prepared statement somewhere.
            if let log = Self.logError {
                if ResultCode(rawValue: code).primaryResultCode == .SQLITE_BUSY {
                    // Let the user know about unfinalized statements that did
                    // prevent the connection from closing properly.
                    var stmt: SQLiteStatement? = sqlite3_next_stmt(sqliteConnection, nil)
                    while stmt != nil {
                        log(ResultCode(rawValue: code), "unfinalized statement: \(String(cString: sqlite3_sql(stmt)))")
                        stmt = sqlite3_next_stmt(sqliteConnection, stmt)
                    }
                }
            }
            
            throw DatabaseError(resultCode: code, message: lastErrorMessage)
        }
        
        self.sqliteConnection = nil
        configuration.SQLiteConnectionDidClose?()
    }
    
    /// Closes a connection with `sqlite3_close_v2`. This method is intended for
    /// deallocated connections.
    func close_v2() {
        SchedulingWatchdog.preconditionValidQueue(self)
        
        guard let sqliteConnection else {
            // Already closed
            return
        }
        
        configuration.SQLiteConnectionWillClose?(sqliteConnection)
        
        // Finalize all cached statements since they would prevent
        // immediate connection closing.
        internalStatementCache.clear()
        publicStatementCache.clear()
        
        // https://www.sqlite.org/c3ref/close.html
        // > If sqlite3_close_v2() is called with unfinalized prepared
        // > statements and/or unfinished sqlite3_backups, then the database
        // > connection becomes an unusable "zombie" which will automatically
        // > be deallocated when the last prepared statement is finalized or the
        // > last sqlite3_backup is finished.
        // >
        // > The sqlite3_close_v2() interface is intended for use with host
        // > languages that are garbage collected, and where the order in which
        // > destructors are called is arbitrary.
        let code = sqlite3_close_v2(sqliteConnection)
        if code != SQLITE_OK, let log = Self.logError {
            // A rare situation where GRDB doesn't fatalError on
            // unprocessed errors.
            let message = String(cString: sqlite3_errmsg(sqliteConnection))
            log(ResultCode(rawValue: code), "could not close database: \(message)")
        }
        
        self.sqliteConnection = nil
        configuration.SQLiteConnectionDidClose?()
    }
    
    // MARK: - Limits
    
    /// The maximum number of arguments accepted by an SQLite statement.
    ///
    /// For example, requests such as the one below must make sure the `ids`
    /// array does not contain more than `maximumStatementArgumentCount`
    /// elements:
    ///
    /// ```swift
    /// // DELETE FROM player WHERE id IN (?, ?, ...)
    /// let ids: [Int] = ...
    /// try dbQueue.write { db in
    ///     try Player.deleteAll(db, keys: ids)
    /// }
    /// ```
    ///
    /// Related SQLite documentation: see `SQLITE_LIMIT_VARIABLE_NUMBER` in
    /// <https://www.sqlite.org/limits.html>.
    public var maximumStatementArgumentCount: Int {
        Int(sqlite3_limit(sqliteConnection, SQLITE_LIMIT_VARIABLE_NUMBER, -1))
    }
    
    // MARK: - Functions
    
    /// Adds or redefines a custom SQL function.
    ///
    /// When you want to add a function to all connections created by a
    /// ``DatabasePool``, add the function in
    /// ``Configuration/prepareDatabase(_:)``:
    ///
    /// ```swift
    /// var config = Configuration()
    /// config.prepareDatabase { db in
    ///     // Add the function to both writer and readers connections.
    ///     db.add(function: ...)
    /// }
    /// let dbPool = try DatabasePool(path: ..., configuration: config)
    /// ```
    public func add(function: DatabaseFunction) {
        functions[function.id] = function
        function.install(in: self)
    }
    
    /// Removes a custom SQL function.
    public func remove(function: DatabaseFunction) {
        functions.removeValue(forKey: function.id)
        function.uninstall(in: self)
    }
    
    // MARK: - Collations
    
    /// Adds or redefines a collation.
    ///
    /// When you want to add a collation to all connections created by a
    /// ``DatabasePool``, add the collation in
    /// ``Configuration/prepareDatabase(_:)``:
    ///
    /// ```swift
    /// var config = Configuration()
    /// config.prepareDatabase { db in
    ///     // Add the collation to both writer and readers connections.
    ///     db.add(collation: ...)
    /// }
    /// let dbPool = try DatabasePool(path: ..., configuration: config)
    /// ```
    public func add(collation: DatabaseCollation) {
        collations[collation.id] = collation
        let collationPointer = Unmanaged.passUnretained(collation).toOpaque()
        let code = sqlite3_create_collation_v2(
            sqliteConnection,
            collation.name,
            SQLITE_UTF8,
            collationPointer,
            { (collationPointer, length1, buffer1, length2, buffer2) in
                let collation = Unmanaged<DatabaseCollation>.fromOpaque(collationPointer!).takeUnretainedValue()
                return CInt(collation.function(length1, buffer1, length2, buffer2).rawValue)
            }, nil)
        guard code == SQLITE_OK else {
            // Assume a GRDB bug: there is no point throwing any error.
            fatalError(DatabaseError(resultCode: code, message: lastErrorMessage))
        }
    }
    
    /// Removes a collation.
    public func remove(collation: DatabaseCollation) {
        collations.removeValue(forKey: collation.id)
        sqlite3_create_collation_v2(
            sqliteConnection,
            collation.name,
            SQLITE_UTF8,
            nil, nil, nil)
    }
    
    // MARK: - Read-Only Access
    
    /// MUST be balanced with `endReadOnly()`.
    func beginReadOnly() throws {
        if configuration.readonly { return }
        if readOnlyDepth == 0 {
            try internalCachedStatement(sql: "PRAGMA query_only = 1").execute()
        }
        readOnlyDepth += 1
    }
    
    /// MUST balance `beginReadOnly()`.
    func endReadOnly() throws {
        if configuration.readonly { return }
        readOnlyDepth -= 1
        assert(readOnlyDepth >= 0, "unbalanced endReadOnly()")
        if readOnlyDepth == 0 {
            try internalCachedStatement(sql: "PRAGMA query_only = 0").execute()
        }
    }
    
    /// Executes read-only database operations, and returns their result
    /// after they have finished executing.
    ///
    /// Attempts to write throw a ``DatabaseError`` with
    /// resultCode `SQLITE_READONLY`.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.write do { db in
    ///     // Write OK
    ///     try Player(...).insert(db)
    ///
    ///     try db.readOnly {
    ///         // Read OK
    ///         let players = try Player.fetchAll(db)
    ///
    ///         // Throws SQLITE_READONLY
    ///         try Player(...).insert(db)
    ///     }
    /// }
    /// ```
    ///
    /// This method is reentrant.
    ///
    /// - parameter value: A closure that reads from the database.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs, or the
    ///   error thrown by `value`.
    public func readOnly<T>(_ value: () throws -> T) throws -> T {
        try beginReadOnly()
        return try throwingFirstError(
            execute: value,
            finally: endReadOnly)
    }
    
    /// Returns whether database connection is read-only (due to
    /// `SQLITE_OPEN_READONLY` or `PRAGMA query_only=1`).
    var isReadOnly: Bool {
        readOnlyDepth > 0 || configuration.readonly
    }
    
    // MARK: - Database Observation
    
    /// Reports the database region to ``ValueObservation``.
    ///
    /// Calling this method does not fetch any database values. It just
    /// helps optimizing `ValueObservation`. See
    /// ``ValueObservation/trackingConstantRegion(_:)`` for more
    /// information, and some examples of usage.
    ///
    /// For example:
    ///
    /// ```swift
    /// let observation = ValueObservation.tracking { db in
    ///     // All changes to the 'player' and 'team' tables
    ///     // will trigger the observation.
    ///     try db.registerAccess(to: Player.all())
    ///     try db.registerAccess(to: Team.all())
    /// }
    /// ```
    ///
    /// This method has no effect on a `ValueObservation` created with
    /// ``ValueObservation/tracking(regions:fetch:)``. In the example below,
    /// only the `player` table is tracked:
    ///
    /// ```swift
    /// // Observes the 'player' table only
    /// let observation = ValueObservation.tracking(region: Player.all()) { db in
    ///     // Ignored
    ///     try db.registerAccess(to: Team.all())
    /// }
    /// ```
    public func registerAccess(to region: @autoclosure () -> some DatabaseRegionConvertible) throws {
        if isRecordingSelectedRegion {
            try selectedRegion.formUnion(region().databaseRegion(self))
        }
    }
    
    /// Notifies that some changes were performed in the provided
    /// database region.
    ///
    /// This method makes it possible to notify undetected changes, such as
    /// changes performed by another process, changes performed by
    /// direct calls to SQLite C functions, or changes to the
    /// database schema.
    /// See <doc:GRDB/TransactionObserver#Dealing-with-Undetected-Changes>
    /// for a detailed list of undetected database modifications.
    ///
    /// It triggers active transaction observers (``TransactionObserver``).
    /// In particular, ``ValueObservation`` that observe the input `region`
    /// will fetch and notify a fresh value.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.write { db in
    ///     // Notify observers that some changes were performed in the database
    ///     try db.notifyChanges(in: .fullDatabase)
    ///
    ///     // Notify observers that some changes were performed in the player table
    ///     try db.notifyChanges(in: Player.all())
    ///
    ///     // Equivalent alternative
    ///     try db.notifyChanges(in: Table("player"))
    /// }
    /// ```
    ///
    /// This method has no effect when called from a read-only
    /// database access.
    ///
    /// > Caveat: Individual rowids in the input region are ignored.
    /// > Notifying a change to a specific rowid is the same as notifying a
    /// > change in the whole table:
    /// >
    /// > ```swift
    /// > try dbQueue.write { db in
    /// >     // Equivalent
    /// >     try db.notifyChanges(in: Player.all())
    /// >     try db.notifyChanges(in: Player.filter(id: 1))
    /// > }
    /// > ```
    public func notifyChanges(in region: some DatabaseRegionConvertible) throws {
        // Don't do anything when read-only, because read-only transactions
        // are not notified. We don't want to notify transactions observers
        // of changes, and have them wait for a commit notification that
        // will never come.
        if !isReadOnly, let observationBroker {
            let eventKinds = try region
                .databaseRegion(self)
                // Use canonical table names for case insensitivity of the input.
                .canonicalTables(self)
                .impactfulEventKinds(self)
            
            try observationBroker.notifyChanges(withEventsOfKind: eventKinds)
        }
    }
    
    /// Extends the `region` argument with the database region selected by all
    /// statements executed by the closure, and all regions explicitly tracked
    /// with the ``registerAccess(to:)`` method.
    ///
    /// For example:
    ///
    /// ```swift
    /// var region = DatabaseRegion()
    /// try db.recordingSelection(&region) {
    ///     let players = try Player.fetchAll(db)
    ///     let team = try Team.fetchOne(db, id: 42)
    ///     try db.registerAccess(to: Table("awards"))
    /// }
    /// print(region) // awards,player(*),team(*)[42]
    /// ```
    ///
    /// This method is used by ``ValueObservation``:
    ///
    /// ```swift
    /// let playersObservation = ValueObservation.tracking { db in
    ///     // Here all fetches are recorded, so that we know what is the
    ///     // database region that must be observed.
    ///     try Player.fetchAll(db)
    /// }
    /// ```
    func recordingSelection<T>(_ region: inout DatabaseRegion, _ block: () throws -> T) rethrows -> T {
        if region.isFullDatabase {
            return try block()
        }
        
        let oldFlag = self.isRecordingSelectedRegion
        let oldRegion = self.selectedRegion
        isRecordingSelectedRegion = true
        selectedRegion = DatabaseRegion()
        defer {
            region.formUnion(selectedRegion)
            isRecordingSelectedRegion = oldFlag
            if isRecordingSelectedRegion {
                selectedRegion = oldRegion.union(selectedRegion)
            } else {
                selectedRegion = oldRegion
            }
        }
        return try block()
    }
    
    // MARK: - Trace
    
    /// Registers a tracing function.
    ///
    /// For example:
    ///
    /// ```swift
    /// // Trace all SQL statements executed by the database
    /// var config = Configuration()
    /// config.prepareDatabase { db in
    ///     db.trace(options: .statement) { event in
    ///         print("SQL: \(event)")
    ///     }
    /// }
    /// let dbQueue = try DatabaseQueue(path: ..., configuration: config)
    /// ```
    ///
    /// Pass an empty options set in order to stop database tracing:
    ///
    /// ```swift
    /// // Stop tracing
    /// db.trace(options: [])
    /// ```
    ///
    /// If you want to see statement arguments in the traced events, you will
    /// need to set the ``Configuration/publicStatementArguments`` flag in the
    /// database ``configuration``.
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/c3ref/trace_v2.html>
    ///
    /// - parameter options: The set of desired event kinds. Defaults to
    ///   `.statement`, which notifies all executed database statements.
    /// - parameter trace: the tracing function.
    public func trace(options: TracingOptions = .statement, _ trace: ((TraceEvent) -> Void)? = nil) {
        SchedulingWatchdog.preconditionValidQueue(self)
        self.trace = trace
        
        if options.isEmpty || trace == nil {
            sqlite3_trace_v2(sqliteConnection, 0, nil, nil)
            return
        }
        
        let dbPointer = Unmanaged.passUnretained(self).toOpaque()
        sqlite3_trace_v2(sqliteConnection, CUnsignedInt(bitPattern: options.rawValue), { (mask, dbPointer, p, x) in
            let db = Unmanaged<Database>.fromOpaque(dbPointer!).takeUnretainedValue()
            db.trace_v2(CInt(bitPattern: mask), p, x, sqlite3_expanded_sql)
            return SQLITE_OK
        }, dbPointer)
    }
    
    // Precondition: configuration.trace != nil
    private func trace_v2(
        _ mask: CInt,
        _ p: UnsafeMutableRawPointer?,
        _ x: UnsafeMutableRawPointer?,
        _ sqlite3_expanded_sql: @escaping @convention(c) (OpaquePointer?) -> UnsafeMutablePointer<CChar>?)
    {
        guard let trace else { return }
        
        switch mask {
        case SQLITE_TRACE_STMT:
            if let sqliteStatement = p, let unexpandedSQL = x {
                let statement = TraceEvent.Statement(
                    sqliteStatement: OpaquePointer(sqliteStatement),
                    unexpandedSQL: UnsafePointer(unexpandedSQL.assumingMemoryBound(to: CChar.self)),
                    sqlite3_expanded_sql: sqlite3_expanded_sql,
                    publicStatementArguments: configuration.publicStatementArguments)
                trace(TraceEvent.statement(statement))
            }
        case SQLITE_TRACE_PROFILE:
            if let sqliteStatement = p, let durationP = x?.assumingMemoryBound(to: Int64.self) {
                let statement = TraceEvent.Statement(
                    sqliteStatement: OpaquePointer(sqliteStatement),
                    unexpandedSQL: nil,
                    sqlite3_expanded_sql: sqlite3_expanded_sql,
                    publicStatementArguments: configuration.publicStatementArguments)
                let duration = TimeInterval(durationP.pointee) / 1.0e9
                
                trace(TraceEvent.profile(statement: statement, duration: duration))
            }
        default:
            break
        }
    }
    
    // MARK: - WAL Checkpoints
    
    /// Runs a WAL checkpoint.
    ///
    /// Related SQLite documentation:
    /// - <https://www.sqlite.org/wal.html>
    /// - <https://www.sqlite.org/c3ref/wal_checkpoint_v2.html>
    ///
    /// - parameter kind: The checkpoint mode (default passive)
    /// - parameter dbName: The database name (default "main")
    /// - returns: A tuple where `walFrameCount` is the total number of frames
    ///   in the log file and `checkpointedFrameCount` is the total number of
    ///   checkpointed frames in the log file
    @discardableResult
    public func checkpoint(_ kind: Database.CheckpointMode = .passive, on dbName: String? = "main") throws
    -> (walFrameCount: Int, checkpointedFrameCount: Int)
    {
        SchedulingWatchdog.preconditionValidQueue(self)
        var walFrameCount: CInt = -1
        var checkpointedFrameCount: CInt = -1
        let code = sqlite3_wal_checkpoint_v2(sqliteConnection, dbName, kind.rawValue,
                                             &walFrameCount, &checkpointedFrameCount)
        switch code {
        case SQLITE_OK:
            return (walFrameCount: Int(walFrameCount), checkpointedFrameCount: Int(checkpointedFrameCount))
        case SQLITE_MISUSE:
            throw DatabaseError(resultCode: code)
        default:
            throw DatabaseError(resultCode: code, message: lastErrorMessage)
        }
    }
    
    // MARK: - Interrupt
    
    // See <https://www.sqlite.org/c3ref/interrupt.html>
    func interrupt() {
        sqlite3_interrupt(sqliteConnection)
    }
    
    // MARK: - Database Suspension
    
    /// When this notification is posted, databases which were opened with the
    /// ``Configuration/observesSuspensionNotifications`` configuration flag
    /// are suspended.
    ///
    /// - note: [**🔥 EXPERIMENTAL**](https://github.com/groue/GRDB.swift/blob/master/README.md#what-are-experimental-features)
    ///
    /// A suspended database makes everything to avoid acquiring a lock on the
    /// database. All database operations may throw a ``DatabaseError`` of code
    /// `SQLITE_INTERRUPT` or `SQLITE_ABORT`, except reads in WAL mode.
    ///
    /// See <doc:DatabaseSharing#How-to-limit-the-0xDEAD10CC-exception> for
    /// more information.
    public static let suspendNotification = Notification.Name("GRDB.Database.Suspend")
    
    /// When this notification is posted, databases which were opened with the
    /// ``Configuration/observesSuspensionNotifications`` configuration flag
    /// are resumed.
    ///
    /// - note: [**🔥 EXPERIMENTAL**](https://github.com/groue/GRDB.swift/blob/master/README.md#what-are-experimental-features)
    public static let resumeNotification = Notification.Name("GRDB.Database.Resume")
    
    /// Suspends the database. A suspended database prevents database locks in
    /// order to avoid the [`0xdead10cc`
    /// exception](https://developer.apple.com/documentation/xcode/understanding-the-exception-types-in-a-crash-report).
    ///
    /// This method can be called from any thread.
    ///
    /// During suspension, any lock is released as soon as possible, and
    /// lock acquisition is prevented. All database accesses may throw a
    /// DatabaseError of code `SQLITE_INTERRUPT`, or `SQLITE_ABORT`, except
    /// reads in WAL mode.
    ///
    /// Suspension ends with `resume()`.
    func suspend() {
        let needsInterrupt = suspensionMutex.withLock { suspension in
            if suspension.isSuspended {
                return false
            }
            
            suspension.isSuspended = true
            return true
        }
        
        if needsInterrupt {
            // Interrupting the database can trigger an SQLITE_INTERRUPT
            // error which may itself abort a transaction and
            // release a database lock, which is our goal.
            // See <https://www.sqlite.org/c3ref/interrupt.html>
            //
            // Maybe interrupt will not release any lock. To address this,
            // we'll issue a rollback on next database access which requires
            // a lock. See `checkForSuspensionViolation(from:).`
            interrupt()
        }
    }
    
    /// Resumes the database. A resumed database stops preventing database locks
    /// in order to avoid the [`0xdead10cc`
    /// exception](https://developer.apple.com/documentation/xcode/understanding-the-exception-types-in-a-crash-report).
    ///
    /// This method can be called from any thread.
    ///
    /// See suspend().
    func resume() {
        suspensionMutex.withLock {
            $0.isSuspended = false
        }
    }
    
    /// Cancels the current database access. All statements but ROLLBACK
    /// will throw `CancellationError`, until `uncancel()` is called.
    ///
    /// This method can be called from any thread.
    func cancel() {
        let needsInterrupt = suspensionMutex.withLock { suspension in
            if suspension.isCancelled {
                return false
            }
            
            suspension.isCancelled = true
            return suspension.interruptsWhenCancelled
        }
        
        if needsInterrupt {
            interrupt()
        }
    }
    
    /// Undo `cancel()`.
    func uncancel() {
        suspensionMutex.withLock {
            $0.isCancelled = false
        }
    }
    
    /// Within the given closure, Task cancellation does not interrupt
    /// database accesses.
    func ignoringCancellation<T>(_ value: () throws -> T) rethrows -> T {
        let previous = suspensionMutex.withLock {
            let previous = $0.interruptsWhenCancelled
            $0.interruptsWhenCancelled = false
            return previous
        }
        
        defer {
            suspensionMutex.withLock {
                $0.interruptsWhenCancelled = previous
            }
        }
        
        return try value()
    }
    
    /// Support for `checkForSuspensionViolation(from:)`
    private func journalMode() throws -> String {
        if let journalMode = journalModeCache {
            return journalMode
        }
        
        // Don't return String.fetchOne(self, sql: "PRAGMA journal_mode"), so
        // that we don't create an infinite loop in checkForSuspensionViolation(from:)
        var statement: SQLiteStatement? = nil
        let sql = "PRAGMA journal_mode"
        sqlite3_prepare_v2(sqliteConnection, sql, -1, &statement, nil)
        defer { sqlite3_finalize(statement) }
        sqlite3_step(statement)
        guard let cString = sqlite3_column_text(statement, 0) else {
            throw DatabaseError(resultCode: lastErrorCode, message: lastErrorMessage, sql: sql)
        }
        let journalMode = String(cString: cString)
        journalModeCache = journalMode
        return journalMode
    }
    
    /// Prevents a statement from running, if the database is suspended, or
    /// if the current database access is cancelled by Task cancellation.
    ///
    /// Transaction rollbacks are always allowed. For other statements:
    ///
    /// - When database access is cancelled, this method
    ///   throws `CancellationError`.
    ///
    /// - When database is suspensed, and if the statement would lock the
    ///   database in a way that may trigger the 0xDEAD10CC exception, this
    ///   method rollbacks the current transaction and throws `SQLITE_ABORT`.
    ///
    /// See `cancel()`, `suspend()` and
    /// ``Configuration/observesSuspensionNotifications``.
    func checkForSuspensionViolation(from statement: Statement) throws {
        // No reason for suspension should prevent rollbacks:
        //
        // - A rollback releases the write lock when the database
        //  is interrupted, when preventing 0xDEAD10CC.
        //
        // - A rollback properly closes a transaction that fails because
        //   it runs in a Task that was cancelled.
        //
        // Finally, a rollback must be run by GRDB, not by a direct call
        // to `sqlite3_exec`, so that transaction observers are
        // properly notified.
        if statement.transactionEffect == .rollbackTransaction {
            return
        }
        
        // Suspension should not prevent adjusting the read-only mode.
        // See <https://github.com/groue/GRDB.swift/issues/1715>.
        if statement.isQueryOnlyPragma {
            return
        }
        
        // How should we interrupt the statement?
        enum Interrupt {
            case abort  // Rollback and throw SQLITE_ABORT
            case cancel // Throw CancellationError
        }
        
        let interrupt: Interrupt? = try suspensionMutex.withLock { suspension in
            // Check for cancellation first, so that the only error that
            // a user sees when a Task is cancelled is CancellationError.
            if suspension.isCancelled, suspension.interruptsWhenCancelled {
                return .cancel
            }
            
            guard suspension.isSuspended else {
                return nil
            }
            
            if try journalMode() == "wal" && statement.isReadonly {
                // In WAL mode, accept read-only statements:
                // - SELECT ...
                // - BEGIN DEFERRED TRANSACTION
                //
                // Those are not read-only:
                // - INSERT ...
                // - BEGIN IMMEDIATE TRANSACTION
                return nil
            }
            
            if statement.releasesDatabaseLock {
                // Accept statements that release locks:
                // - COMMIT
                // - ROLLBACK
                // - ROLLBACK TRANSACTION TO SAVEPOINT
                // - RELEASE SAVEPOINT
                return nil
            }
            
            // Assume statement can acquire a write lock: abort.
            return .abort
        }
        
        switch interrupt {
        case nil:
            break
            
        case .cancel:
            throw CancellationError()
            
        case .abort:
            // Attempt at releasing an eventual lock with ROLLBACk,
            // as explained in Database.suspend().
            try? rollback()
            
            throw DatabaseError(
                resultCode: .SQLITE_ABORT,
                message: "Database is suspended",
                sql: statement.sql,
                arguments: statement.arguments,
                publicStatementArguments: configuration.publicStatementArguments)
        }
    }
    
    // MARK: - Transactions & Savepoint
    
    /// Throws `SQLITE_ABORT` if called from a transaction-wrapping method and
    /// transaction has been aborted (for example, by `sqlite3_interrupt`, or a
    /// `ON CONFLICT ROLLBACK` clause.
    ///
    /// For example:
    ///
    ///     try db.inTransaction {
    ///         do {
    ///             // Throws an error because the transaction was rollbacked.
    ///             try ...
    ///         } catch {
    ///             // Catch the error and continue.
    ///             ...
    ///         }
    ///
    ///         // <- Here we're inside an aborted transaction.
    ///         try checkForAbortedTransaction(...) // throws SQLITE_ABORT
    ///         ...
    ///     }
    func checkForAbortedTransaction(
        sql: @autoclosure () -> String? = nil,
        arguments: @autoclosure () -> StatementArguments? = nil)
    throws
    {
        if isInsideTransactionBlock && sqlite3_get_autocommit(sqliteConnection) != 0 {
            throw DatabaseError(
                resultCode: .SQLITE_ABORT,
                message: "Transaction was aborted",
                sql: sql(),
                arguments: arguments(),
                publicStatementArguments: configuration.publicStatementArguments)
        }
    }
    
    /// Wraps database operations inside a database transaction.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.writeWithoutTransaction do { db in
    ///     try db.inTransaction {
    ///         try db.execute(sql: "INSERT ...")
    ///         return .commit
    ///     }
    /// }
    /// ```
    ///
    /// If `operations` throws an error, the transaction is rollbacked and the
    /// error is rethrown. If it returns ``TransactionCompletion/rollback``, the
    /// transaction is also rollbacked, but no error is thrown.
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/lang_transaction.html>
    ///
    /// - warning: This method is not reentrant: you can not nest transactions.
    ///   Use ``inSavepoint(_:)`` instead.
    ///
    /// - parameters:
    ///     - kind: The transaction type.
    ///
    ///       If nil, the transaction kind is DEFERRED when the current
    ///       database access is read-only, and IMMEDIATE otherwise.
    ///     - operations: A function that executes SQL statements and returns
    ///       either ``TransactionCompletion/commit`` or ``TransactionCompletion/rollback``.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs, or the
    ///   error thrown by `operations`.
    public func inTransaction(_ kind: TransactionKind? = nil, _ operations: () throws -> TransactionCompletion) throws {
        // Begin transaction
        try beginTransaction(kind)
        
        // Support for `checkForAbortedTransaction()`.
        let wasInsideTransactionBlock = isInsideTransactionBlock
        isInsideTransactionBlock = true
        defer {
            isInsideTransactionBlock = wasInsideTransactionBlock
        }
        
        // Now that transaction has begun, we'll rollback in case of error.
        // But we'll throw the first caught error, so that user knows
        // what happened.
        var firstError: Error? = nil
        let needsRollback: Bool
        do {
            let completion = try operations()
            switch completion {
            case .commit:
                // In case of aborted transaction, throw SQLITE_ABORT instead
                // of the generic SQLITE_ERROR "cannot commit - no transaction is active"
                try checkForAbortedTransaction()
                
                // Leave transaction block now, so that transaction observers
                // can execute statements without getting errors from
                // checkForAbortedTransaction().
                isInsideTransactionBlock = wasInsideTransactionBlock
                
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
        
        if let firstError {
            throw firstError
        }
    }
    
    /// Runs the block with an isolation level equal or greater than
    /// snapshot isolation.
    ///
    /// - parameter readOnly: If true, writes are forbidden.
    func isolated<T>(readOnly: Bool = false, _ block: () throws -> T) throws -> T {
        if sqlite3_get_autocommit(sqliteConnection) == 0 {
            // Spare savepoints
            if readOnly {
                return try self.readOnly(block)
            } else {
                return try block()
            }
        } else {
            var result: T?
            if readOnly {
                // Enter read-only mode before starting a transaction, so that the
                // transaction commit does not trigger database observation.
                // See <https://github.com/groue/GRDB.swift/pull/1213>.
                try self.readOnly {
                    try inSavepoint {
                        result = try block()
                        return .commit
                    }
                }
            } else {
                try inSavepoint {
                    result = try block()
                    return .commit
                }
            }
            return result!
        }
    }
    
    /// Wraps database operations inside a savepoint.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.write do {
    ///     try db.inSavepoint {
    ///         try db.execute(sql: "INSERT ...")
    ///         return .commit
    ///     }
    /// }
    /// ```
    ///
    /// If `operations` throws an error, the savepoint is rollbacked and the
    /// error is rethrown. If it returns ``TransactionCompletion/rollback``, the
    /// savepoint is also rollbacked, but no error is thrown.
    ///
    /// This method is reentrant: you can nest savepoints.
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/lang_savepoint.html>
    ///
    /// - parameter operations: A function that executes SQL statements and
    ///   returns either ``TransactionCompletion/commit`` or
    ///   ``TransactionCompletion/rollback``.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs, or the
    ///   error thrown by `operations`.
    public func inSavepoint(_ operations: () throws -> TransactionCompletion) throws {
        if !isInsideTransaction {
            // By default, top level SQLite savepoints open a
            // deferred transaction.
            //
            // But GRDB prefers immediate transactions for writes.
            //
            // Besides, starting some (?) SQLCipher/SQLite version, SQLite has a
            // bug. Returning 1 from `sqlite3_commit_hook` does not leave the
            // database in the autocommit mode, as expected after a rollback.
            // This bug only happens, as far as we know, when a transaction is
            // started with a savepoint:
            //
            //      SAVEPOINT test;
            //      CREATE TABLE t(a);
            //      -- Rollbacked with sqlite3_commit_hook:
            //      RELEASE SAVEPOINT test;
            //      -- Not in the autocommit mode here!
            //
            // For those two reasons, we open a transaction instead of a
            // top-level savepoint.
            try inTransaction { try operations() }
            return
        }
        
        // Begin savepoint
        //
        // We use a single name for savepoints because there is no need
        // using unique savepoint names. User could still mess with them
        // with raw SQL queries, but let's assume that it is unlikely that
        // the user uses "grdb" as a savepoint name.
        try execute(sql: "SAVEPOINT grdb")
        
        // Support for `checkForAbortedTransaction()`.
        let wasInsideTransactionBlock = isInsideTransactionBlock
        isInsideTransactionBlock = true
        defer {
            isInsideTransactionBlock = wasInsideTransactionBlock
        }
        
        // Now that savepoint has begun, we'll rollback in case of error.
        // But we'll throw the first caught error, so that user knows
        // what happened.
        var firstError: Error? = nil
        let needsRollback: Bool
        do {
            let completion = try operations()
            switch completion {
            case .commit:
                // In case of aborted transaction, throw SQLITE_ABORT instead
                // of the generic SQLITE_ERROR "cannot commit - no transaction is active"
                try checkForAbortedTransaction()
                
                // Leave transaction block now, so that transaction observers
                // can execute statements without getting errors from
                // checkForAbortedTransaction().
                isInsideTransactionBlock = wasInsideTransactionBlock
                
                try execute(sql: "RELEASE SAVEPOINT grdb")
                assert(sqlite3_get_autocommit(sqliteConnection) == 0)
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
                // Rollback, and release the savepoint.
                // Rollback alone is not enough to clear the savepoint from
                // the SQLite savepoint stack.
                try execute(sql: "ROLLBACK TRANSACTION TO SAVEPOINT grdb")
                try execute(sql: "RELEASE SAVEPOINT grdb")
            } catch {
                if firstError == nil {
                    firstError = error
                }
            }
        }
        
        if let firstError {
            throw firstError
        }
    }
    
    /// Begins a database transaction.
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/lang_transaction.html>
    ///
    /// - parameters:
    ///     - kind: The transaction type.
    ///
    ///       If nil, the transaction kind is DEFERRED when the current
    ///       database access is read-only, and IMMEDIATE otherwise.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public func beginTransaction(_ kind: TransactionKind? = nil) throws {
        // SQLite throws an error for non-deferred transactions when read-only.
        // We prefer immediate transactions for writes, so that write
        // transactions can not overlap. This reduces the opportunity for
        // SQLITE_BUSY, which is immediately thrown whenever a transaction
        // is upgraded after an initial read and a concurrent processes
        // has acquired the write lock beforehand. This SQLITE_BUSY error
        // can not be avoided with a busy timeout.
        //
        // See <https://github.com/groue/GRDB.swift/issues/1483>.
        let kind = kind ?? (isReadOnly ? .deferred : .immediate)
        try execute(sql: "BEGIN \(kind.rawValue) TRANSACTION")
        assert(sqlite3_get_autocommit(sqliteConnection) == 0)
    }
    
    /// Rollbacks a database transaction.
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/lang_transaction.html>
    ///
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public func rollback() throws {
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
        if isInsideTransaction {
            try execute(sql: "ROLLBACK TRANSACTION")
        }
        assert(sqlite3_get_autocommit(sqliteConnection) != 0)
    }
    
    /// Commits a database transaction.
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/lang_transaction.html>
    ///
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public func commit() throws {
        try execute(sql: "COMMIT TRANSACTION")
        assert(sqlite3_get_autocommit(sqliteConnection) != 0)
    }
    
    // MARK: - Memory Management
    
    /// Frees as much memory as possible.
    public func releaseMemory() {
        SchedulingWatchdog.preconditionValidQueue(self)
        if let sqliteConnection {
            sqlite3_db_release_memory(sqliteConnection)
        }
        schemaCache.clear()
        internalStatementCache.clear()
        publicStatementCache.clear()
    }
    
    // MARK: - Erasing
    
    func erase() throws {
        #if SQLITE_HAS_CODEC
        // SQLCipher does not support the backup API:
        // https://discuss.zetetic.net/t/using-the-sqlite-online-backup-api/2631
        // So we'll drop all database objects one after the other.
        
        // Prevent foreign keys from messing with drop table statements
        let foreignKeysEnabled = try Bool.fetchOne(self, sql: "PRAGMA foreign_keys")!
        if foreignKeysEnabled {
            try execute(sql: "PRAGMA foreign_keys = OFF")
        }
        
        try throwingFirstError(
            execute: {
                // Remove all database objects, one after the other
                try inTransaction {
                    let sql = "SELECT type, name FROM sqlite_master WHERE name NOT LIKE 'sqlite_%'"
                    while let row = try Row.fetchOne(self, sql: sql) {
                        let type: String = row["type"]
                        let name: String = row["name"]
                        try execute(sql: "DROP \(type) \(name.quotedDatabaseIdentifier)")
                    }
                    return .commit
                }
            },
            finally: {
                // Restore foreign keys if needed
                if foreignKeysEnabled {
                    try execute(sql: "PRAGMA foreign_keys = ON")
                }
            })
        #else
        try DatabaseQueue().backup(to: self)
        #endif
    }
    
    // MARK: - Backup
    
    /// Copies the database contents into another database.
    ///
    /// The `backup` method blocks the current thread until the destination
    /// database contains the same contents as the source database.
    ///
    /// Usage:
    ///
    /// ```swift
    /// let source: DatabaseQueue = ...
    /// let destination: DatabaseQueue = ...
    /// try source.write { sourceDb in
    ///     try destination.barrierWriteWithoutTransaction { destDb in
    ///         try sourceDb.backup(to: destDb)
    ///     }
    /// }
    /// ```
    ///
    /// When you're after progress reporting during backup, you'll want to
    /// perform the backup in several steps. Each step copies the number of
    /// _database pages_ you specify. See <https://www.sqlite.org/c3ref/backup_finish.html>
    /// for more information:
    ///
    /// ```swift
    /// // Backup with progress reporting
    /// try sourceDb.backup(to: destDb, pagesPerStep: ...) { progress in
    ///     print("Database backup progress:", progress)
    /// }
    /// ```
    ///
    /// The `progress` callback will be called at least once—when
    /// `backupProgress.isCompleted == true`. If the callback throws
    /// when `backupProgress.isCompleted == false`, the backup is aborted
    /// and the error is rethrown. If the callback throws when
    /// `backupProgress.isCompleted == true`, backup completion is
    /// unaffected and the error is silently ignored.
    ///
    /// See also ``DatabaseReader/backup(to:pagesPerStep:progress:)``.
    ///
    /// - parameters:
    ///     - destDb: The destination database.
    ///     - pagesPerStep: The number of database pages copied on each backup
    ///       step. By default, all pages are copied in one single step.
    ///     - progress: An optional function that is notified of the backup
    ///       progress.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs, or the
    ///   error thrown by `progress`.
    public func backup(
        to destDb: Database,
        pagesPerStep: CInt = -1,
        progress: ((DatabaseBackupProgress) throws -> Void)? = nil)
    throws
    {
        try backupInternal(
            to: destDb,
            pagesPerStep: pagesPerStep,
            afterBackupStep: progress)
    }
    
    func backupInternal(
        to destDb: Database,
        pagesPerStep: CInt = -1,
        afterBackupInit: (() -> Void)? = nil,
        afterBackupStep: ((DatabaseBackupProgress) throws -> Void)? = nil)
    throws
    {
        guard let backup = sqlite3_backup_init(destDb.sqliteConnection, "main", sqliteConnection, "main") else {
            throw DatabaseError(resultCode: destDb.lastErrorCode, message: destDb.lastErrorMessage)
        }
        guard Int(bitPattern: backup) != Int(SQLITE_ERROR) else {
            throw DatabaseError()
        }
        
        afterBackupInit?()
        
        do {
            backupLoop: while true {
                let rc = sqlite3_backup_step(backup, pagesPerStep)
                let totalPageCount = Int(sqlite3_backup_pagecount(backup))
                let remainingPageCount = Int(sqlite3_backup_remaining(backup))
                let progress = DatabaseBackupProgress(
                    remainingPageCount: remainingPageCount,
                    totalPageCount: totalPageCount,
                    isCompleted: rc == SQLITE_DONE)
                switch rc {
                case SQLITE_DONE:
                    try? afterBackupStep?(progress)
                    break backupLoop
                case SQLITE_OK:
                    try afterBackupStep?(progress)
                case let code:
                    throw DatabaseError(resultCode: code, message: destDb.lastErrorMessage)
                }
            }
        } catch {
            sqlite3_backup_finish(backup)
            throw error
        }
        
        switch sqlite3_backup_finish(backup) {
        case SQLITE_OK:
            break
        case let code:
            throw DatabaseError(resultCode: code, message: destDb.lastErrorMessage)
        }
        
        // The schema of the destination database has changed:
        destDb.clearSchemaCache()
    }
}

// Explicit non-conformance to Sendable: `Database` must be used from a
// serialized database access dispatch queue (see `SerializedDatabase`).
@available(*, unavailable)
extension Database: Sendable { }

#if SQLITE_HAS_CODEC
extension Database {
    
    // MARK: - Encryption
    
    /// Sets the passphrase used to crypt and decrypt an SQLCipher database.
    ///
    /// Call this method from `Configuration.prepareDatabase`,
    /// as in the example below:
    ///
    ///     var config = Configuration()
    ///     config.prepareDatabase { db in
    ///         try db.usePassphrase("secret")
    ///     }
    public func usePassphrase(_ passphrase: String) throws {
        guard var data = passphrase.data(using: .utf8) else {
            throw DatabaseError(message: "invalid passphrase")
        }
        defer {
            data.resetBytes(in: 0..<data.count)
        }
        try usePassphrase(data)
    }
    
    /// Sets the passphrase used to crypt and decrypt an SQLCipher database.
    ///
    /// Call this method from `Configuration.prepareDatabase`,
    /// as in the example below:
    ///
    ///     var config = Configuration()
    ///     config.prepareDatabase { db in
    ///         try db.usePassphrase(passphraseData)
    ///     }
    public func usePassphrase(_ passphrase: Data) throws {
        let code = passphrase.withUnsafeBytes {
            sqlite3_key(sqliteConnection, $0.baseAddress, CInt($0.count))
        }
        guard code == SQLITE_OK else {
            throw DatabaseError(resultCode: code, message: String(cString: sqlite3_errmsg(sqliteConnection)))
        }
    }
    
    /// Changes the passphrase used by an SQLCipher encrypted database.
    public func changePassphrase(_ passphrase: String) throws {
        guard var data = passphrase.data(using: .utf8) else {
            throw DatabaseError(message: "invalid passphrase")
        }
        defer {
            data.resetBytes(in: 0..<data.count)
        }
        try changePassphrase(data)
    }
    
    /// Changes the passphrase used by an SQLCipher encrypted database.
    public func changePassphrase(_ passphrase: Data) throws {
        // FIXME: sqlite3_rekey is discouraged.
        //
        // https://github.com/ccgus/fmdb/issues/547#issuecomment-259219320
        //
        // > We (Zetetic) have been discouraging the use of sqlite3_rekey in
        // > favor of attaching a new database with the desired encryption
        // > options and using sqlcipher_export() to migrate the contents and
        // > schema of the original db into the new one:
        // > https://discuss.zetetic.net/t/how-to-encrypt-a-plaintext-sqlite-database-to-use-sqlcipher-and-avoid-file-is-encrypted-or-is-not-a-database-errors/
        let code = passphrase.withUnsafeBytes {
            sqlite3_rekey(sqliteConnection, $0.baseAddress, CInt($0.count))
        }
        guard code == SQLITE_OK else {
            throw DatabaseError(resultCode: code, message: lastErrorMessage)
        }
    }
}
#endif

extension Database {
    
    // MARK: - Database-Related Types
    
    /// See ``BusyMode`` and <https://www.sqlite.org/c3ref/busy_handler.html>
    public typealias BusyCallback = @Sendable (_ numberOfTries: Int) -> Bool
    
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
    ///     // Wait 1 second before failing with SQLITE_BUSY
    ///     let configuration = Configuration(busyMode: .timeout(1))
    ///     let dbQueue = try DatabaseQueue(path: ..., configuration: configuration)
    ///
    /// Relevant SQLite documentation:
    ///
    /// - <https://www.sqlite.org/c3ref/busy_timeout.html>
    /// - <https://www.sqlite.org/c3ref/busy_handler.html>
    /// - <https://www.sqlite.org/lang_transaction.html>
    /// - <https://www.sqlite.org/wal.html>
    public enum BusyMode: Sendable {
        /// The `SQLITE_BUSY` error is immediately returned to the connection
        /// that tries to access the locked database.
        case immediateError
        
        /// The `SQLITE_BUSY` error will be returned only if the database
        /// remains locked for more than the specified duration (in seconds).
        case timeout(TimeInterval)
        
        /// A custom callback that is called when a database is locked.
        ///
        /// Related SQLite documentation: <https://www.sqlite.org/c3ref/busy_handler.html>
        case callback(BusyCallback)
    }
    
    /// The available checkpoint modes.
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/c3ref/wal_checkpoint_v2.html>
    public enum CheckpointMode: CInt, Sendable {
        /// The `SQLITE_CHECKPOINT_PASSIVE` mode.
        case passive = 0
        
        /// The `SQLITE_CHECKPOINT_FULL` mode.
        case full = 1
        
        /// The `SQLITE_CHECKPOINT_RESTART` mode.
        case restart = 2
        
        /// The `SQLITE_CHECKPOINT_TRUNCATE` mode.
        case truncate = 3
    }
    
    /// The name of a string comparison function used by SQLite.
    ///
    /// Related SQLite documentation:
    /// - <https://www.sqlite.org/datatype3.html#collating_sequences>
    /// - <https://www.sqlite.org/datatype3.html#collation>
    public struct CollationName: RawRepresentable, Hashable, Sendable {
        public let rawValue: String
        
        /// Creates a collation name.
        public init(rawValue: String) {
            self.rawValue = rawValue
        }
        
        /// The `BINARY` built-in SQL collation.
        public static let binary = CollationName(rawValue: "BINARY")
        
        /// The `NOCASE` built-in SQL collation.
        public static let nocase = CollationName(rawValue: "NOCASE")
        
        /// The `RTRIM` built-in SQL collation.
        public static let rtrim = CollationName(rawValue: "RTRIM")
    }
    
    /// An SQL column type.
    ///
    /// You use column types when you modify the database schema. For example:
    ///
    /// ```swift
    /// // CREATE TABLE player(
    /// //   id INTEGER PRIMARY KEY,
    /// //   name TEXT,
    /// //   creationDate DATETIME,
    /// // )
    /// try db.create(table: "player") { t in
    ///     t.primaryKey("id", .integer)
    ///     t.column("name", .text)
    ///     t.column("creationDate", .datetime)
    /// }
    /// ```
    ///
    /// For more information, see
    /// [Datatypes In SQLite](https://www.sqlite.org/datatype3.html).
    public struct ColumnType: RawRepresentable, Hashable, Sendable {
        /// The SQL for the column type (`"TEXT"`, `"BLOB"`, etc.)
        public let rawValue: String
        
        /// Creates an SQL column type.
        public init(rawValue: String) {
            self.rawValue = rawValue
        }
        
        /// The `TEXT` column type.
        public static let text = ColumnType(rawValue: "TEXT")
        
        /// The `TEXT` column type, suitable for JSON columns.
        ///
        /// SQLite JSON functions and operators are
        /// [documented](https://www.sqlite.org/json1.html#interface_overview)
        /// to throw errors if any of their arguments are binary blobs.
        /// That's the reason why it is recommended to store JSON as text.
        public static let jsonText = ColumnType(rawValue: "TEXT")
        
        /// The `BLOB` column type, suitable for JSONB columns.
        public static let jsonb = ColumnType(rawValue: "BLOB")
        
        /// The `INTEGER` column type.
        public static let integer = ColumnType(rawValue: "INTEGER")
        
        /// The `DOUBLE` column type.
        public static let double = ColumnType(rawValue: "DOUBLE")
        
        /// The `REAL` column type.
        public static let real = ColumnType(rawValue: "REAL")

        /// The `NUMERIC` column type.
        public static let numeric = ColumnType(rawValue: "NUMERIC")
        
        /// The `BOOLEAN` column type.
        public static let boolean = ColumnType(rawValue: "BOOLEAN")
        
        /// The `BLOB` column type.
        public static let blob = ColumnType(rawValue: "BLOB")
        
        /// The `DATE` column type.
        public static let date = ColumnType(rawValue: "DATE")
        
        /// The `DATETIME` column type.
        public static let datetime = ColumnType(rawValue: "DATETIME")
        
        /// The `ANY` column type.
        public static let any = ColumnType(rawValue: "ANY")
    }
    
    /// An SQLite conflict resolution.
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/lang_conflict.html>
    public enum ConflictResolution: String, Sendable {
        /// The `ROLLBACK` conflict resolution.
        case rollback = "ROLLBACK"
        
        /// The `ABORT` conflict resolution.
        case abort = "ABORT"
        
        /// The `FAIL` conflict resolution.
        case fail = "FAIL"
        
        /// The `IGNORE` conflict resolution.
        case ignore = "IGNORE"
        
        /// The `REPLACE` conflict resolution.
        case replace = "REPLACE"
    }
    
    /// A foreign key action.
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/foreignkeys.html>
    public enum ForeignKeyAction: String, Sendable {
        /// The `CASCADE` foreign key action.
        case cascade = "CASCADE"
        
        /// The `RESTRICT` foreign key action.
        case restrict = "RESTRICT"
        
        /// The `SET NULL` foreign key action.
        case setNull = "SET NULL"
        
        /// The `SET DEFAULT` foreign key action.
        case setDefault = "SET DEFAULT"
    }
    
    /// An error log function that takes an error code and message.
    public typealias LogErrorFunction = @Sendable (_ resultCode: ResultCode, _ message: String) -> Void
    
    /// An SQLite storage class.
    ///
    /// For more information, see
    /// [Datatypes In SQLite](https://www.sqlite.org/datatype3.html).
    public struct StorageClass: RawRepresentable, Hashable, Sendable {
        /// The SQL for the storage class (`"INTEGER"`, `"REAL"`, etc.)
        public let rawValue: String
        
        /// Creates an SQL storage class.
        public init(rawValue: String) {
            self.rawValue = rawValue
        }
        
        /// The `INTEGER` storage class.
        public static let integer = StorageClass(rawValue: "INTEGER")
        
        /// The `REAL` storage class.
        public static let real = StorageClass(rawValue: "REAL")
        
        /// The `TEXT` storage class.
        public static let text = StorageClass(rawValue: "TEXT")
        
        /// The `BLOB` storage class.
        public static let blob = StorageClass(rawValue: "BLOB")
    }
    
    /// An option for the SQLite tracing feature.
    ///
    /// You use `TracingOptions` with the `Database`
    /// ``Database/trace(options:_:)`` method.
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/c3ref/c_trace.html>
    public struct TracingOptions: OptionSet, Sendable {
        /// The raw trace event code.
        public let rawValue: CInt
        
        /// Creates a `TracingOptions` from a raw trace event code.
        public init(rawValue: CInt) {
            self.rawValue = rawValue
        }
        
        /// The option that reports executed statements.
        ///
        /// Trace event code: `SQLITE_TRACE_STMT`.
        public static let statement = TracingOptions(rawValue: SQLITE_TRACE_STMT)
        
        /// The option that reports executed statements and the estimated
        /// duration that the statement took to run.
        ///
        /// Trace event code: `SQLITE_TRACE_PROFILE`.
        public static let profile = TracingOptions(rawValue: SQLITE_TRACE_PROFILE)
    }
    
    /// A trace event.
    ///
    /// You get instances of `TraceEvent` from the `Database`
    /// ``Database/trace(options:_:)`` method.
    public enum TraceEvent: CustomStringConvertible {
        
        /// Information about an executed statement.
        public struct Statement: CustomStringConvertible {
            var sqliteStatement: SQLiteStatement
            var unexpandedSQL: UnsafePointer<CChar>?
            var sqlite3_expanded_sql: @convention(c) (OpaquePointer?) -> UnsafeMutablePointer<CChar>?
            var publicStatementArguments: Bool // See Configuration.publicStatementArguments
            
            /// The executed SQL, where bound parameters are not expanded.
            ///
            /// For example:
            ///
            /// ```sql
            /// SELECT * FROM player WHERE email = ?
            /// ```
            public var sql: String {
                if let unexpandedSQL {
                    let sql = String(cString: unexpandedSQL)
                    return sql.hasPrefix("--") ? sql : sql.trimmedSQLStatement
                } else {
                    return String(cString: sqlite3_sql(sqliteStatement)).trimmedSQLStatement
                }
            }
            
            /// The executed SQL, where bound parameters are expanded.
            ///
            /// For example:
            ///
            /// ```sql
            /// SELECT * FROM player WHERE email = 'arthur@example.com'
            /// ```
            ///
            /// - warning: It is your responsibility to prevent sensitive
            ///   information from leaking in unexpected locations, so use this
            ///   property with care.
            public var expandedSQL: String {
                if let unexpandedSQL {
                    let sql = String(cString: unexpandedSQL)
                    if sql.hasPrefix("--") { return sql }
                }
                guard let cString = sqlite3_expanded_sql(sqliteStatement) else {
                    return ""
                }
                defer { sqlite3_free(cString) }
                return String(cString: cString).trimmedSQLStatement
            }
            
            public var description: String {
                if publicStatementArguments {
                    return expandedSQL
                } else {
                    return sql
                }
            }
        }
        
        /// An event reported by the
        /// ``Database/TracingOptions/statement`` option.
        case statement(Statement)
        
        /// An event reported by the
        /// ``Database/TracingOptions/profile`` option.
        case profile(statement: Statement, duration: TimeInterval)
        
        /// A description of the trace event.
        ///
        /// For example:
        ///
        ///     SELECT * FROM player WHERE email = ?
        ///     0.1s SELECT * FROM player WHERE email = ?
        ///
        /// The format of the event description may change between GRDB releases,
        /// without notice: don't have your application rely on any specific format.
        public var description: String {
            switch self {
            case let .statement(statement):
                return statement.description
            case let .profile(statement: statement, duration: duration):
                let durationString = String(format: "%.3f", duration)
                return "\(durationString)s \(statement)"
            }
        }
        
        /// A description of the trace event, where bound parameters
        /// are expanded.
        ///
        /// For example:
        ///
        ///     SELECT * FROM player WHERE email = 'arthur@example.com'
        ///     0.1s SELECT * FROM player WHERE email = 'arthur@example.com'
        ///
        /// The format of the event description may change between GRDB releases,
        /// without notice: don't have your application rely on any specific format.
        ///
        /// - warning: It is your responsibility to prevent sensitive
        ///   information from leaking in unexpected locations, so use this
        ///   property with care.
        public var expandedDescription: String {
            switch self {
            case let .statement(statement):
                return statement.expandedSQL
            case let .profile(statement: statement, duration: duration):
                let durationString = String(format: "%.3f", duration)
                return "\(durationString)s \(statement.expandedSQL)"
            }
        }
    }
    
    /// A transaction commit, or rollback.
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/lang_transaction.html>.
    @frozen
    public enum TransactionCompletion: Sendable {
        case commit
        case rollback
    }
    
    /// A transaction kind.
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/lang_transaction.html>.
    public enum TransactionKind: String, Sendable {
        /// The `DEFERRED` transaction kind.
        case deferred = "DEFERRED"
        
        /// The `IMMEDIATE` transaction kind.
        case immediate = "IMMEDIATE"
        
        /// The `EXCLUSIVE` transaction kind.
        case exclusive = "EXCLUSIVE"
    }
    
    /// An SQLite threading mode. See <https://www.sqlite.org/threadsafe.html>.
    ///
    /// - Note: Only the multi-thread mode (`SQLITE_OPEN_NOMUTEX`) is currently
    /// supported, since all <doc:DatabaseConnections> access SQLite connections
    /// through a `SerializedDatabase`.
    enum ThreadingMode {
        case `default`
        case multiThread
        case serialized
        
        var SQLiteOpenFlags: CInt {
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

// Explicit non-conformance to Sendable: a trace event contains transient
// information.
@available(*, unavailable)
extension Database.TraceEvent: Sendable { }

// Explicit non-conformance to Sendable: a trace event contains transient
// information.
@available(*, unavailable)
extension Database.TraceEvent.Statement: Sendable { }
