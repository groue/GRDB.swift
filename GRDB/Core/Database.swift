import Foundation
#if SWIFT_PACKAGE
import CSQLite
#elseif GRDBCIPHER
import SQLCipher
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
///     try dbQueue.write { db in
///         try Player(...).insert(db)
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
    public static var logError: LogErrorFunction? = nil {
        didSet {
            if logError != nil {
                registerErrorLogCallback { (_, code, message) in
                    guard let logError = Database.logError else { return }
                    guard let message = message.map(String.init) else { return }
                    let resultCode = ResultCode(rawValue: code)
                    logError(resultCode, message)
                }
            } else {
                registerErrorLogCallback(nil)
            }
        }
    }
    
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
        //
        // > If another thread changes the autocommit status of the database
        // > connection while this routine is running, then the return value
        // > is undefined.
        SchedulingWatchdog.preconditionValidQueue(self)
        if isClosed { return false } // Support for SerializedDatabase.deinit
        return sqlite3_get_autocommit(sqliteConnection) == 0
    }
    
    // MARK: - Internal properties
    
    // Caches
    var schemaCache: DatabaseSchemaCache    // internal so that it can be tested
    lazy var internalStatementCache = StatementCache(database: self)
    lazy var publicStatementCache = StatementCache(database: self)
    
    /// The last error code
    public var lastErrorCode: ResultCode { return ResultCode(rawValue: sqlite3_errcode(sqliteConnection)) }
    
    /// The last error message
    public var lastErrorMessage: String? { return String(cString: sqlite3_errmsg(sqliteConnection)) }
    
    /// Statement authorizer. Use withAuthorizer(_:_:).
    fileprivate var _authorizer: StatementAuthorizer?
    
    // Transaction observers management
    lazy var observationBroker = DatabaseObservationBroker(self)
    
    /// The list of compile options used when building SQLite
    static let sqliteCompileOptions: Set<String> = DatabaseQueue().inDatabase {
        try! Set(String.fetchCursor($0, sql: "PRAGMA COMPILE_OPTIONS"))
    }
    
    /// If true, select statement execution is recorded.
    /// Use recordingSelectedRegion(_:), see `selectStatementWillExecute(_:)`
    var _isRecordingSelectedRegion: Bool = false
    var _selectedRegion = DatabaseRegion()
    
    /// Support for checkForAbortedTransaction()
    var isInsideTransactionBlock = false
    
    /// Support for checkForSuspensionViolation(from:)
    var isSuspended = LockedBox<Bool>(value: false)
    
    /// Support for checkForSuspensionViolation(from:)
    /// This cache is never cleared: we assume journal mode never changes.
    var journalModeCache: String?
    
    // MARK: - Private properties
    
    private var busyCallback: BusyCallback?
    
    private var functions = Set<DatabaseFunction>()
    private var collations = Set<DatabaseCollation>()
    private var _readOnlyDepth = 0 // Modify with beginReadOnly/endReadOnly
    private var isClosed: Bool = false
    
    // MARK: - Initializer
    
    init(path: String, configuration: Configuration, schemaCache: DatabaseSchemaCache) throws {
        self.sqliteConnection = try Database.openConnection(path: path, flags: configuration.SQLiteOpenFlags)
        self.configuration = configuration
        self.schemaCache = schemaCache
    }
    
    deinit {
        assert(isClosed)
    }
    
    // MARK: - Database Opening
    
    private static func openConnection(path: String, flags: Int32) throws -> SQLiteConnection {
        // See https://www.sqlite.org/c3ref/open.html
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
            sqlite3_close(sqliteConnection)
            throw DatabaseError(resultCode: code)
        }
        if let sqliteConnection = sqliteConnection {
            return sqliteConnection
        }
        throw DatabaseError(resultCode: .SQLITE_INTERNAL) // WTF SQLite?
    }
    
    // MARK: - Database Setup
    
    /// This method must be called after database initialization
    func setup() throws {
        // Setup trace first, so that setup queries are traced.
        setupTrace()
        setupDoubleQuotedStringLiterals()
        try setupForeignKeys()
        setupBusyMode()
        setupDefaultFunctions()
        setupDefaultCollations()
        setupAuthorizer()
        observationBroker.installCommitAndRollbackHooks()
        try activateExtendedCodes()
        
        #if SQLITE_HAS_CODEC
        try validateSQLCipher()
        if let passphrase = configuration._passphrase {
            try _usePassphrase(passphrase)
        }
        #endif
        
        // Last step before we can start accessing the database.
        try configuration.prepareDatabase?(self)
        
        try validateFormat()
        configuration.SQLiteConnectionDidOpen?()
    }
    
    private func setupTrace() {
        guard configuration.trace != nil else {
            return
        }
        // sqlite3_trace_v2 and sqlite3_expanded_sql were introduced in SQLite 3.14.0
        // http://www.sqlite.org/changes.html#version_3_14
        // It is available from iOS 10.0 and OS X 10.12
        // https://github.com/yapstudios/YapDatabase/wiki/SQLite-version-(bundled-with-OS)
        #if GRDBCUSTOMSQLITE || GRDBCIPHER
        let dbPointer = Unmanaged.passUnretained(self).toOpaque()
        sqlite3_trace_v2(
            sqliteConnection,
            UInt32(SQLITE_TRACE_STMT),
            { (mask, dbPointer, stmt, unexpandedSQL) -> Int32 in
                Database.trace_v2(mask, dbPointer, stmt, unexpandedSQL, sqlite3_expanded_sql)
        },
            dbPointer)
        #elseif os(Linux)
        setupTrace_v1()
        #else
        if #available(iOS 10.0, OSX 10.12, tvOS 10.0, watchOS 3.0, *) {
            let dbPointer = Unmanaged.passUnretained(self).toOpaque()
            sqlite3_trace_v2(
                sqliteConnection,
                UInt32(SQLITE_TRACE_STMT),
                { (mask, dbPointer, stmt, unexpandedSQL) -> Int32 in
                    Database.trace_v2(mask, dbPointer, stmt, unexpandedSQL, sqlite3_expanded_sql)
            },
                dbPointer)
        } else {
            setupTrace_v1()
        }
        #endif
    }
    
    // Precondition: configuration.trace != nil
    private func setupTrace_v1() {
        let dbPointer = Unmanaged.passUnretained(self).toOpaque()
        sqlite3_trace(sqliteConnection, { (dbPointer, sql) in
            guard let sql = sql.map(String.init) else { return }
            let db = Unmanaged<Database>.fromOpaque(dbPointer!).takeUnretainedValue()
            db.configuration.trace!(sql)
        }, dbPointer)
    }
    
    // Precondition: configuration.trace != nil
    private static func trace_v2(
        _ mask: UInt32,
        _ dbPointer: UnsafeMutableRawPointer?,
        _ stmt: UnsafeMutableRawPointer?,
        _ unexpandedSQL: UnsafeMutableRawPointer?,
        _ sqlite3_expanded_sql: @convention(c) (OpaquePointer?) -> UnsafeMutablePointer<Int8>?)
        -> Int32
    {
        guard let stmt = stmt else { return SQLITE_OK }
        guard let expandedSQLCString = sqlite3_expanded_sql(OpaquePointer(stmt)) else { return SQLITE_OK }
        let sql = String(cString: expandedSQLCString)
        sqlite3_free(expandedSQLCString)
        let db = Unmanaged<Database>.fromOpaque(dbPointer!).takeUnretainedValue()
        db.configuration.trace!(sql)
        return SQLITE_OK
    }
    
    private func setupDoubleQuotedStringLiterals() {
        if configuration.acceptsDoubleQuotedStringLiterals {
            enableDoubleQuotedStringLiterals(sqliteConnection)
        } else {
            disableDoubleQuotedStringLiterals(sqliteConnection)
        }
    }
    
    private func setupForeignKeys() throws {
        // Foreign keys are disabled by default with SQLite3
        if configuration.foreignKeysEnabled {
            try execute(sql: "PRAGMA foreign_keys = ON")
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
    
    private func setupAuthorizer() {
        // SQLite authorizer is set only once per database connection.
        //
        // This is because authorizer changes have SQLite invalidate statements,
        // with undesired side effects. See:
        //
        // - DatabaseCursorTests.testIssue583()
        // - http://sqlite.1065341.n5.nabble.com/Issue-report-sqlite3-set-authorizer-triggers-error-4-516-SQLITE-ABORT-ROLLBACK-during-statement-itern-td107972.html
        // swiftlint:disable:previous line_length
        let dbPointer = Unmanaged.passUnretained(self).toOpaque()
        sqlite3_set_authorizer(
            sqliteConnection,
            { (dbPointer, actionCode, cString1, cString2, cString3, cString4) -> Int32 in
                let db = Unmanaged<Database>.fromOpaque(dbPointer.unsafelyUnwrapped).takeUnretainedValue()
                guard let authorizer = db._authorizer else {
                    return SQLITE_OK
                }
                return authorizer.authorize(actionCode, cString1, cString2, cString3, cString4)
        },
            dbPointer)
    }
    
    
    private func activateExtendedCodes() throws {
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
        try makeSelectStatement(sql: "SELECT * FROM sqlite_master LIMIT 1").makeCursor().next()
    }
    
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
        // sqlite3_close_v2 was added in SQLite 3.7.14 http://www.sqlite.org/changes.html#version_3_7_14
        // It is available from iOS 8.2 and OS X 10.10
        // https://github.com/yapstudios/YapDatabase/wiki/SQLite-version-(bundled-with-OS)
        #if GRDBCUSTOMSQLITE || GRDBCIPHER
        closeConnection_v2(sqliteConnection, sqlite3_close_v2)
        #else
        if #available(iOS 8.2, OSX 10.10, OSXApplicationExtension 10.10, *) {
            closeConnection_v2(sqliteConnection, sqlite3_close_v2)
        } else {
            closeConnection_v1(sqliteConnection)
        }
        #endif
    }
    
    private static func closeConnection_v1(_ sqliteConnection: SQLiteConnection) {
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
    
    private static func closeConnection_v2(
        _ sqliteConnection: SQLiteConnection,
        _ sqlite3_close_v2: @convention(c) (OpaquePointer?) -> Int32)
    {
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
    ///     try Int.fetchOne(db, sql: "SELECT succ(1)")! // 2
    public func add(function: DatabaseFunction) {
        functions.update(with: function)
        function.install(in: self)
    }
    
    /// Remove an SQL function.
    public func remove(function: DatabaseFunction) {
        functions.remove(function)
        function.uninstall(in: self)
    }
    
    // MARK: - Collations
    
    /// Add or redefine a collation.
    ///
    ///     let collation = DatabaseCollation("localized_standard") { (string1, string2) in
    ///         return (string1 as NSString).localizedStandardCompare(string2)
    ///     }
    ///     db.add(collation: collation)
    ///     try db.execute(sql: "CREATE TABLE files (name TEXT COLLATE localized_standard")
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
    
    // MARK: - Read-Only Access
    
    func beginReadOnly() throws {
        if configuration.readonly { return }
        if _readOnlyDepth == 0 {
            // PRAGMA query_only was added in SQLite 3.8.0 http://www.sqlite.org/changes.html#version_3_8_0
            // It is available from iOS 8.2 and OS X 10.10
            // https://github.com/yapstudios/YapDatabase/wiki/SQLite-version-(bundled-with-OS)
            try internalCachedUpdateStatement(sql: "PRAGMA query_only = 1").execute()
        }
        _readOnlyDepth += 1
    }
    
    func endReadOnly() throws {
        if configuration.readonly { return }
        _readOnlyDepth -= 1
        if _readOnlyDepth == 0 {
            // PRAGMA query_only was added in SQLite 3.8.0 http://www.sqlite.org/changes.html#version_3_8_0
            // It is available from iOS 8.2 and OS X 10.10
            // https://github.com/yapstudios/YapDatabase/wiki/SQLite-version-(bundled-with-OS)
            try internalCachedUpdateStatement(sql: "PRAGMA query_only = 0").execute()
        }
    }
    
    /// Grants read-only access, starting SQLite 3.8.0
    func readOnly<T>(_ block: () throws -> T) throws -> T {
        try beginReadOnly()
        return try throwingFirstError(
            execute: block,
            finally: endReadOnly)
    }
    
    // MARK: - Authorizer
    
    func withAuthorizer<T>(_ authorizer: StatementAuthorizer?, _ block: () throws -> T) rethrows -> T {
        SchedulingWatchdog.preconditionValidQueue(self)
        let old = self._authorizer
        self._authorizer = authorizer
        defer { self._authorizer = old }
        return try block()
    }
    
    // MARK: - Recording of the selected region
    
    func recordingSelectedRegion<T>(_ block: () throws -> T) rethrows -> (T, DatabaseRegion) {
        SchedulingWatchdog.preconditionValidQueue(self)
        let oldFlag = self._isRecordingSelectedRegion
        let oldRegion = self._selectedRegion
        self._isRecordingSelectedRegion = true
        self._selectedRegion = DatabaseRegion()
        defer {
            self._isRecordingSelectedRegion = oldFlag
            if self._isRecordingSelectedRegion {
                self._selectedRegion = oldRegion.union(self._selectedRegion)
            } else {
                self._selectedRegion = oldRegion
            }
        }
        return try (block(), _selectedRegion)
    }
    
    // MARK: - Checkpoints
    
    func checkpoint(_ kind: Database.CheckpointMode) throws {
        let code = sqlite3_wal_checkpoint_v2(sqliteConnection, nil, kind.rawValue, nil, nil)
        guard code == SQLITE_OK else {
            throw DatabaseError(resultCode: code, message: lastErrorMessage)
        }
    }
    
    // MARK: - Interrupt
    
    // See https://www.sqlite.org/c3ref/interrupt.html
    func interrupt() {
        sqlite3_interrupt(sqliteConnection)
    }
    
    // MARK: - Database Suspension
    
    /// When this notification is posted, databases which were opened with the
    /// `Configuration.observesSuspensionNotifications` flag are suspended.
    ///
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    public static let suspendNotification = Notification.Name("GRDB.Database.Suspend")
    
    /// When this notification is posted, databases which were opened with the
    /// `Configuration.observesSuspensionNotifications` flag are resumed.
    ///
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    public static let resumeNotification = Notification.Name("GRDB.Database.Resume")
    
    /// Suspends the database. A suspended database prevents database locks in
    /// order to avoid the [`0xdead10cc`
    /// exception](https://developer.apple.com/library/archive/technotes/tn2151/_index.html).
    ///
    /// This method can be called from any thread.
    ///
    /// During suspension, any lock is released as soon as possible, and
    /// lock acquisition is prevented. All database accesses may throw a
    /// DatabaseError of code `SQLITE_INTERRUPT`, or `SQLITE_ABORT`, except
    /// reads in WAL mode.
    ///
    /// Suspension ends with resume().
    func suspend() {
        isSuspended.write { isSuspended in
            if isSuspended {
                return
            }
            
            // Prevent future lock acquisition
            isSuspended = true
            
            // Interrupt the database because this may trigger an
            // SQLITE_INTERRUPT error which may itself abort a transaction and
            // release a lock. See https://www.sqlite.org/c3ref/interrupt.html
            interrupt()
            
            // Now what about the eventual remaining lock? We'll issue a
            // rollback on next database access which requires a lock, in
            // checkForSuspensionViolation(from:).
        }
    }
    
    /// Resumes the database. A resumed database stops preventing database locks
    /// in order to avoid the [`0xdead10cc`
    /// exception](https://developer.apple.com/library/archive/technotes/tn2151/_index.html).
    ///
    /// This method can be called from any thread.
    ///
    /// See suspend().
    func resume() {
        isSuspended.write { isSuspended in
            isSuspended = false
        }
    }
    
    /// Support for checkForSuspensionViolation(from:)
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
    
    /// Throws SQLITE_ABORT for suspended databases, if statement would lock
    /// the database, in order to avoid the [`0xdead10cc`
    /// exception](https://developer.apple.com/library/archive/technotes/tn2151/_index.html).
    func checkForSuspensionViolation(from statement: Statement) throws {
        try isSuspended.read { isSuspended in
            guard isSuspended else {
                return
            }
            
            if try journalMode() == "wal" && statement.isReadonly {
                // In WAL mode, accept read-only statements:
                // - SELECT ...
                // - BEGIN DEFERRED TRANSACTION
                //
                // Those are not read-only:
                // - INSERT ...
                // - BEGIN IMMEDIATE TRANSACTION
                return
            }
            
            if
                let updateStatement = statement as? UpdateStatement,
                updateStatement.releasesDatabaseLock
            {
                // Accept statements that release locks:
                // - COMMIT
                // - ROLLBACK
                // - ROLLBACK TRANSACTION TO SAVEPOINT
                // - RELEASE SAVEPOINT
                return
            }
            
            // Attempt at releasing an eventual lock with ROLLBACk,
            // as explained in Database.suspend().
            //
            // Use sqlite3_exec instead of `try? rollback()` in order to avoid
            // an infinite loop in checkForSuspensionViolation(from:)
            _ = sqlite3_exec(sqliteConnection, "ROLLBACK", nil, nil, nil)
            
            throw DatabaseError(
                resultCode: .SQLITE_ABORT,
                message: "Database is suspended",
                sql: statement.sql,
                arguments: statement.arguments)
        }
    }
    
    // MARK: - Transactions & Savepoint
    
    /// Throws SQLITE_ABORT if called from a transaction-wrapping method and
    /// transaction has been aborted (for example, by `sqlite3_interrupt`, or a
    /// `ON CONFLICT ROLLBACK` clause.
    ///
    ///     try db.inTransaction {
    ///         do {
    ///             // Aborted by sqlite3_interrupt or any other
    ///             // SQLite error which leaves transaction
    ///             ...
    ///         } catch { ... }
    ///
    ///         // <- Here we're inside an aborted transaction.
    ///         try checkForAbortedTransaction(...) // throws
    ///         ...
    ///
    ///         return .commit
    ///     }
    func checkForAbortedTransaction(
        sql: @autoclosure () -> String? = nil,
        arguments: @autoclosure () -> StatementArguments? = nil)
        throws
    {
        if isInsideTransactionBlock && !isInsideTransaction {
            throw DatabaseError(
                resultCode: .SQLITE_ABORT,
                message: "Transaction was aborted",
                sql: sql(),
                arguments: arguments())
        }
    }
    
    /// Executes a block inside a database transaction.
    ///
    ///     try dbQueue.inDatabase do {
    ///         try db.inTransaction {
    ///             try db.execute(sql: "INSERT ...")
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
    ///       defaults to .deferred. See https://www.sqlite.org/lang_transaction.html
    ///       for more information.
    ///     - block: A block that executes SQL statements and return either
    ///       .commit or .rollback.
    /// - throws: The error thrown by the block.
    public func inTransaction(_ kind: TransactionKind? = nil, _ block: () throws -> TransactionCompletion) throws {
        // Begin transaction
        try beginTransaction(kind)
        
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
            let completion = try block()
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
        
        if let firstError = firstError {
            throw firstError
        }
    }
    
    /// Executes a block inside a savepoint.
    ///
    ///     try dbQueue.inDatabase do {
    ///         try db.inSavepoint {
    ///             try db.execute(sql: "INSERT ...")
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
            try inTransaction(configuration.defaultTransactionKind, block)
            return
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
        try execute(sql: "SAVEPOINT grdb")
        
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
            let completion = try block()
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
                assert(!topLevelSavepoint || !isInsideTransaction)
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
                    try execute(sql: "ROLLBACK TRANSACTION TO SAVEPOINT grdb")
                    try execute(sql: "RELEASE SAVEPOINT grdb")
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
    
    /// Begins a database transaction.
    ///
    /// - parameter kind: The transaction type (default nil). If nil, the
    ///   transaction type is configuration.defaultTransactionKind, which itself
    ///   defaults to .deferred. See https://www.sqlite.org/lang_transaction.html
    ///   for more information.
    /// - throws: The error thrown by the block.
    public func beginTransaction(_ kind: TransactionKind? = nil) throws {
        let kind = kind ?? configuration.defaultTransactionKind
        try execute(sql: "BEGIN \(kind.rawValue) TRANSACTION")
        assert(isInsideTransaction)
    }
    
    /// Begins a database transaction and take a snapshot of the last committed
    /// database state.
    func beginSnapshotTransaction() throws {
        // https://www.sqlite.org/isolation.html
        //
        // > In WAL mode, SQLite exhibits "snapshot isolation". When a read
        // > transaction starts, that reader continues to see an unchanging
        // > "snapshot" of the database file as it existed at the moment in time
        // > when the read transaction started. Any write transactions that
        // > commit while the read transaction is active are still invisible to
        // > the read transaction, because the reader is seeing a snapshot of
        // > database file from a prior moment in time.
        //
        // That's exactly what we need. But what does "when read transaction
        // starts" mean?
        //
        // http://www.sqlite.org/lang_transaction.html
        //
        // > Deferred [transaction] means that no locks are acquired on the
        // > database until the database is first accessed. [...] Locks are not
        // > acquired until the first read or write operation. [...] Because the
        // > acquisition of locks is deferred until they are needed, it is
        // > possible that another thread or process could create a separate
        // > transaction and write to the database after the BEGIN on the
        // > current thread has executed.
        //
        // Now that's precise enough: SQLite defers "snapshot isolation" until
        // the first SELECT:
        //
        //     Reader                       Writer
        //     BEGIN DEFERRED TRANSACTION
        //                                  UPDATE ... (1)
        //     Here the change (1) is visible
        //     SELECT ...
        //                                  UPDATE ... (2)
        //     Here the change (2) is not visible
        //
        // We thus have to perform a select that establishes the
        // snapshot isolation before we release the writer queue:
        //
        //     Reader                       Writer
        //     BEGIN DEFERRED TRANSACTION
        //     SELECT anything
        //                                  UPDATE ...
        //     Here the change is not visible by GRDB user
        try beginTransaction(.deferred)
        try internalCachedSelectStatement(sql: "SELECT rootpage FROM sqlite_master LIMIT 1").makeCursor().next()
    }
    
    /// Rollbacks a database transaction.
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
        assert(!isInsideTransaction)
    }
    
    /// Commits a database transaction.
    public func commit() throws {
        try execute(sql: "COMMIT TRANSACTION")
        assert(!isInsideTransaction)
    }
    
    // MARK: - Memory Management
    
    func releaseMemory() {
        sqlite3_db_release_memory(sqliteConnection)
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
    
    func backup(
        to dbDest: Database,
        afterBackupInit: (() -> Void)? = nil,
        afterBackupStep: (() -> Void)? = nil)
        throws
    {
        guard let backup = sqlite3_backup_init(dbDest.sqliteConnection, "main", sqliteConnection, "main") else {
            throw DatabaseError(resultCode: dbDest.lastErrorCode, message: dbDest.lastErrorMessage)
        }
        guard Int(bitPattern: backup) != Int(SQLITE_ERROR) else {
            throw DatabaseError()
        }
        
        afterBackupInit?()
        
        do {
            backupLoop: while true {
                switch sqlite3_backup_step(backup, -1) {
                case SQLITE_DONE:
                    afterBackupStep?()
                    break backupLoop
                case SQLITE_OK:
                    afterBackupStep?()
                case let code:
                    throw DatabaseError(resultCode: code, message: dbDest.lastErrorMessage)
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
            throw DatabaseError(resultCode: code, message: dbDest.lastErrorMessage)
        }
        
        // The schema of the destination database has changed:
        dbDest.clearSchemaCache()
    }
}

#if SQLITE_HAS_CODEC
extension Database {
    
    // MARK: - Encryption
    
    /// Sets the passphrase used to crypt and decrypt an SQLCipher database.
    ///
    /// Call this method from Configuration.prepareDatabase, as in the example below:
    ///
    ///     var config = Configuration()
    ///     config.prepareDatabase = { db in
    ///         try db.usePassphrase("secret")
    ///     }
    public func usePassphrase(_ passphrase: String) throws {
        // Support for the deprecated method change(passphrase:).
        // After it has been called, the passphrase used for opening the
        // database must be ignored.
        if configuration._passphrase != nil {
            return
        }
        try _usePassphrase(passphrase)
    }
    
    /// See usePassphrase(_:)
    private func _usePassphrase(_ passphrase: String) throws {
        let data = passphrase.data(using: .utf8)!
        #if swift(>=5.0)
        let code = data.withUnsafeBytes {
            sqlite3_key(sqliteConnection, $0.baseAddress, Int32($0.count))
        }
        #else
        let code = data.withUnsafeBytes {
            sqlite3_key(sqliteConnection, $0, Int32(data.count))
        }
        #endif
        guard code == SQLITE_OK else {
            throw DatabaseError(resultCode: code, message: String(cString: sqlite3_errmsg(sqliteConnection)))
        }
    }
    
    /// Changes the passphrase used by an SQLCipher encrypted database.
    public func changePassphrase(_ passphrase: String) throws {
        // FIXME: sqlite3_rekey is discouraged.
        //
        // https://github.com/ccgus/fmdb/issues/547#issuecomment-259219320
        //
        // > We (Zetetic) have been discouraging the use of sqlite3_rekey in
        // > favor of attaching a new database with the desired encryption
        // > options and using sqlcipher_export() to migrate the contents and
        // > schema of the original db into the new one:
        // > https://discuss.zetetic.net/t/how-to-encrypt-a-plaintext-sqlite-database-to-use-sqlcipher-and-avoid-file-is-encrypted-or-is-not-a-database-errors/
        // swiftlint:disable:previous line_length
        let data = passphrase.data(using: .utf8)!
        #if swift(>=5.0)
        let code = data.withUnsafeBytes {
            sqlite3_rekey(sqliteConnection, $0.baseAddress, Int32($0.count))
        }
        #else
        let code = data.withUnsafeBytes {
            sqlite3_rekey(sqliteConnection, $0, Int32(data.count))
        }
        #endif
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
    ///     // Wait 1 second before failing with SQLITE_BUSY
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
        /// locked for more than the specified duration (in seconds).
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
    public struct CollationName: RawRepresentable, Hashable {
        /// :nodoc:
        public let rawValue: String
        
        /// :nodoc:
        public init(rawValue: String) {
            self.rawValue = rawValue
        }
        
        public init(_ rawValue: String) {
            self.rawValue = rawValue
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
    ///     try db.create(table: "player") { t in
    ///         t.autoIncrementedPrimaryKey("id")
    ///         t.column("title", .text)
    ///     }
    ///
    /// See https://www.sqlite.org/datatype3.html
    public struct ColumnType: RawRepresentable, Hashable {
        /// :nodoc:
        public let rawValue: String
        
        /// :nodoc:
        public init(rawValue: String) {
            self.rawValue = rawValue
        }
        
        public init(_ rawValue: String) {
            self.rawValue = rawValue
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
    public enum ConflictResolution: String {
        case rollback = "ROLLBACK"
        case abort = "ABORT"
        case fail = "FAIL"
        case ignore = "IGNORE"
        case replace = "REPLACE"
    }
    
    /// A foreign key action.
    ///
    /// See https://www.sqlite.org/foreignkeys.html
    public enum ForeignKeyAction: String {
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
    public enum TransactionKind: String {
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
