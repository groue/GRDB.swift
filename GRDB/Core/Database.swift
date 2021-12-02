import Foundation

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
public final class Database: CustomStringConvertible, CustomDebugStringConvertible {
    // The Database class is not thread-safe. An instance should always be
    // used through a SerializedDatabase.
    
    // MARK: - SQLite C API
    
    /// The raw SQLite connection, suitable for the SQLite C API.
    /// It is constant, until close() sets it to nil.
    public var sqliteConnection: SQLiteConnection?
    
    // MARK: - Configuration
    
    /// The error logging function.
    ///
    /// Quoting <https://www.sqlite.org/errlog.html>:
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
    
    /// See `Configuration.label`
    public let description: String
    
    public var debugDescription: String { "<Database: \(description)>" }
    
    // MARK: - Database Information
    
    /// The rowID of the most recently inserted row.
    ///
    /// If no row has ever been inserted using this database connection,
    /// returns zero.
    ///
    /// For more detailed information, see <https://www.sqlite.org/c3ref/last_insert_rowid.html>
    public var lastInsertedRowID: Int64 {
        SchedulingWatchdog.preconditionValidQueue(self)
        return sqlite3_last_insert_rowid(sqliteConnection)
    }
    
    /// The number of rows modified, inserted or deleted by the most recent
    /// successful INSERT, UPDATE or DELETE statement.
    ///
    /// For more detailed information, see <https://www.sqlite.org/c3ref/changes.html>
    public var changesCount: Int {
        SchedulingWatchdog.preconditionValidQueue(self)
        return Int(sqlite3_changes(sqliteConnection))
    }
    
    /// The total number of rows modified, inserted or deleted by all successful
    /// INSERT, UPDATE or DELETE statements since the database connection was
    /// opened.
    ///
    /// For more detailed information, see <https://www.sqlite.org/c3ref/total_changes.html>
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
        if sqliteConnection == nil { return false } // Support for SerializedDatabase.deinit
        return sqlite3_get_autocommit(sqliteConnection) == 0
    }
    
    /// The last error code
    public var lastErrorCode: ResultCode { ResultCode(rawValue: sqlite3_errcode(sqliteConnection)) }
    
    /// The last error message
    public var lastErrorMessage: String? { String(cString: sqlite3_errmsg(sqliteConnection)) }
    
    // MARK: - Internal properties
    
    // Caches
    struct SchemaCache {
        var schemaIdentifiers: [SchemaIdentifier]?
        fileprivate var schemas: [SchemaIdentifier: DatabaseSchemaCache] = [:]
        
        subscript(schemaID: SchemaIdentifier) -> DatabaseSchemaCache { // internal so that it can be tested
            get {
                schemas[schemaID] ?? DatabaseSchemaCache()
            }
            set {
                schemas[schemaID] = newValue
            }
        }
        
        mutating func clear() {
            schemaIdentifiers = nil
            schemas.removeAll()
        }
    }
    
    var _lastSchemaVersion: Int32? // Support for clearSchemaCacheIfNeeded()
    var schemaCache = SchemaCache()
    lazy var internalStatementCache = StatementCache(database: self)
    lazy var publicStatementCache = StatementCache(database: self)
    
    /// Statement authorizer. Use withAuthorizer(_:_:).
    fileprivate var _authorizer: StatementAuthorizer?
    
    // Transaction observers management
    lazy var observationBroker = DatabaseObservationBroker(self)
    
    /// The list of compile options used when building SQLite
    static let sqliteCompileOptions: Set<String> = DatabaseQueue().inDatabase {
        try! Set(String.fetchCursor($0, sql: "PRAGMA COMPILE_OPTIONS"))
    }
    
    /// If true, select statement execution is recorded.
    /// Use recordingSelectedRegion(_:), see `statementWillExecute(_:)`
    var _isRecordingSelectedRegion = false
    var _selectedRegion = DatabaseRegion()
    
    /// Support for checkForAbortedTransaction()
    var isInsideTransactionBlock = false
    
    /// Support for checkForSuspensionViolation(from:)
    @LockedBox var isSuspended = false
    
    /// Support for checkForSuspensionViolation(from:)
    /// This cache is never cleared: we assume journal mode never changes.
    var journalModeCache: String?
    
    // MARK: - Private properties
    
    private var busyCallback: BusyCallback?
    private var trace: ((TraceEvent) -> Void)?
    private var functions = Set<DatabaseFunction>()
    private var collations = Set<DatabaseCollation>()
    private var _readOnlyDepth = 0 // Modify with beginReadOnly/endReadOnly
    
    // MARK: - Initializer
    
    init(
        path: String,
        description: String,
        configuration: Configuration) throws
    {
        self.sqliteConnection = try Database.openConnection(path: path, flags: configuration.SQLiteOpenFlags)
        self.description = description
        self.configuration = configuration
    }
    
    deinit {
        assert(sqliteConnection == nil)
    }
    
    // MARK: - Database Opening
    
    private static func openConnection(path: String, flags: Int32) throws -> SQLiteConnection {
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
        if let sqliteConnection = sqliteConnection {
            return sqliteConnection
        }
        throw DatabaseError(resultCode: .SQLITE_INTERNAL) // WTF SQLite?
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
        observationBroker.installCommitAndRollbackHooks()
        try activateExtendedCodes()
        
        #if SQLITE_HAS_CODEC
        try validateSQLCipher()
        #endif
        
        // Last step before we can start accessing the database.
        try configuration.setUp(self)
        
        try validateFormat()
        configuration.SQLiteConnectionDidOpen?()
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
        let busyMode = configuration.readonly
            ? configuration.readonlyBusyMode ?? configuration.busyMode
            : configuration.busyMode
        switch busyMode {
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
        
        if #available(OSX 10.11, watchOS 3.0, *) {
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
        try makeStatement(sql: "SELECT * FROM sqlite_master LIMIT 1").makeCursor().next()
    }
    
    // MARK: - Database Closing
    
    /// Closes a connection with `sqlite3_close`. This method is intended for
    /// the public `close()` function. It may fail.
    func close() throws {
        SchedulingWatchdog.preconditionValidQueue(self)
        
        guard let sqliteConnection = sqliteConnection else {
            // Already closed
            return
        }
        
        configuration.SQLiteConnectionWillClose?(sqliteConnection)
        internalStatementCache.clear()
        publicStatementCache.clear()
        
        // https://www.sqlite.org/c3ref/close.html
        // > If the database connection is associated with unfinalized prepared
        // > statements or unfinished sqlite3_backup objects then
        // > sqlite3_close() will leave the database connection open and
        // > return SQLITE_BUSY.
        let code = sqlite3_close(sqliteConnection)
        guard code == SQLITE_OK else {
            if let log = Self.logError {
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
            
            throw DatabaseError(resultCode: code, message: lastErrorMessage)
        }
        
        self.sqliteConnection = nil
        configuration.SQLiteConnectionDidClose?()
    }
    
    /// Closes a connection with `sqlite3_close_v2`. This method is intended for
    /// deallocated connections.
    func close_v2() {
        SchedulingWatchdog.preconditionValidQueue(self)
        
        guard let sqliteConnection = sqliteConnection else {
            // Already closed
            return
        }
        
        configuration.SQLiteConnectionWillClose?(sqliteConnection)
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
    ///     let ids: [Int] = ...
    ///     try dbQueue.write { db in
    ///         try Player.deleteAll(db, keys: ids)
    ///     }
    ///
    /// See <https://www.sqlite.org/limits.html>
    /// and `SQLITE_LIMIT_VARIABLE_NUMBER`.
    public var maximumStatementArgumentCount: Int {
        Int(sqlite3_limit(sqliteConnection, SQLITE_LIMIT_VARIABLE_NUMBER, -1))
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
            fatalError(DatabaseError(resultCode: code, message: lastErrorMessage))
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
            try internalCachedStatement(sql: "PRAGMA query_only = 1").execute()
        }
        _readOnlyDepth += 1
    }
    
    func endReadOnly() throws {
        if configuration.readonly { return }
        _readOnlyDepth -= 1
        if _readOnlyDepth == 0 {
            try internalCachedStatement(sql: "PRAGMA query_only = 0").execute()
        }
    }
    
    /// Grants read-only access, starting SQLite 3.8.0
    func readOnly<T>(_ block: () throws -> T) throws -> T {
        try beginReadOnly()
        return try throwingFirstError(
            execute: block,
            finally: endReadOnly)
    }
    
    // MARK: - Snapshots
    
    #if SQLITE_ENABLE_SNAPSHOT
    /// Returns a snapshot that must be freed with `sqlite3_snapshot_free`.
    ///
    /// See <https://www.sqlite.org/c3ref/snapshot.html>
    func takeVersionSnapshot() throws -> UnsafeMutablePointer<sqlite3_snapshot> {
        var snapshot: UnsafeMutablePointer<sqlite3_snapshot>?
        let code = withUnsafeMutablePointer(to: &snapshot) {
            sqlite3_snapshot_get(sqliteConnection, "main", $0)
        }
        guard code == SQLITE_OK else {
            throw DatabaseError(resultCode: code, message: lastErrorMessage)
        }
        if let snapshot = snapshot {
            return snapshot
        } else {
            throw DatabaseError(resultCode: .SQLITE_INTERNAL) // WTF SQLite?
        }
    }
    
    func wasChanged(since initialSnapshot: UnsafeMutablePointer<sqlite3_snapshot>) throws -> Bool {
        let secondSnapshot = try takeVersionSnapshot()
        defer {
            sqlite3_snapshot_free(secondSnapshot)
        }
        let cmp = sqlite3_snapshot_cmp(initialSnapshot, secondSnapshot)
        assert(cmp <= 0, "Unexpected snapshot ordering")
        return cmp < 0
    }
    #endif
    
    // MARK: - Authorizer
    
    func withAuthorizer<T>(_ authorizer: StatementAuthorizer?, _ block: () throws -> T) rethrows -> T {
        SchedulingWatchdog.preconditionValidQueue(self)
        let old = self._authorizer
        self._authorizer = authorizer
        defer { self._authorizer = old }
        return try block()
    }
    
    // MARK: - Recording of the selected region
    
    func recordingSelection<T>(_ region: inout DatabaseRegion, _ block: () throws -> T) rethrows -> T {
        if region.isFullDatabase {
            return try block()
        }
        
        let oldFlag = self._isRecordingSelectedRegion
        let oldRegion = self._selectedRegion
        _isRecordingSelectedRegion = true
        _selectedRegion = DatabaseRegion()
        defer {
            region.formUnion(_selectedRegion)
            _isRecordingSelectedRegion = oldFlag
            if _isRecordingSelectedRegion {
                _selectedRegion = oldRegion.union(_selectedRegion)
            } else {
                _selectedRegion = oldRegion
            }
        }
        return try block()
    }
    
    // MARK: - Trace
    
    /// Registers a tracing function.
    ///
    /// For example:
    ///
    ///     // Trace all SQL statements executed by the database
    ///     var configuration = Configuration()
    ///     configuration.prepareDatabase { db in
    ///         db.trace(options: .statement) { event in
    ///             print("SQL: \(event)")
    ///         }
    ///     }
    ///     let dbQueue = try DatabaseQueue(path: "...", configuration: configuration)
    ///
    /// Pass an empty options set in order to stop database tracing:
    ///
    ///     // Stop tracing
    ///     db.trace(options: [])
    ///
    /// See <https://www.sqlite.org/c3ref/trace_v2.html> for more information.
    ///
    /// - parameter options: The set of desired event kinds. Defaults to
    ///   `.statement`, which notifies all executed database statements.
    /// - parameter trace: the tracing function.
    public func trace(options: TracingOptions = .statement, _ trace: ((TraceEvent) -> Void)? = nil) {
        SchedulingWatchdog.preconditionValidQueue(self)
        self.trace = trace
        
        if options.isEmpty || trace == nil {
            #if GRDBCUSTOMSQLITE || GRDBCIPHER || os(iOS)
            sqlite3_trace_v2(sqliteConnection, 0, nil, nil)
            #elseif os(Linux)
            sqlite3_trace(sqliteConnection, nil)
            #else
            if #available(OSX 10.12, tvOS 10.0, watchOS 3.0, *) {
                sqlite3_trace_v2(sqliteConnection, 0, nil, nil)
            } else {
                sqlite3_trace(sqliteConnection, nil, nil)
            }
            #endif
            return
        }
        
        // sqlite3_trace_v2 and sqlite3_expanded_sql were introduced in SQLite 3.14.0
        // http://www.sqlite.org/changes.html#version_3_14
        // It is available from macOS 10.12, tvOS 10.0, watchOS 3.0
        // https://github.com/yapstudios/YapDatabase/wiki/SQLite-version-(bundled-with-OS)
        #if GRDBCUSTOMSQLITE || GRDBCIPHER || os(iOS)
        let dbPointer = Unmanaged.passUnretained(self).toOpaque()
        sqlite3_trace_v2(sqliteConnection, UInt32(bitPattern: options.rawValue), { (mask, dbPointer, p, x) in
            let db = Unmanaged<Database>.fromOpaque(dbPointer!).takeUnretainedValue()
            db.trace_v2(CInt(bitPattern: mask), p, x, sqlite3_expanded_sql)
            return SQLITE_OK
        }, dbPointer)
        #elseif os(Linux)
        setupTrace_v1()
        #else
        if #available(OSX 10.12, tvOS 10.0, watchOS 3.0, *) {
            let dbPointer = Unmanaged.passUnretained(self).toOpaque()
            sqlite3_trace_v2(sqliteConnection, UInt32(bitPattern: options.rawValue), { (mask, dbPointer, p, x) in
                let db = Unmanaged<Database>.fromOpaque(dbPointer!).takeUnretainedValue()
                db.trace_v2(CInt(bitPattern: mask), p, x, sqlite3_expanded_sql)
                return SQLITE_OK
            }, dbPointer)
        } else {
            setupTrace_v1()
        }
        #endif
    }
    
    #if !(GRDBCUSTOMSQLITE || GRDBCIPHER || os(iOS))
    private func setupTrace_v1() {
        let dbPointer = Unmanaged.passUnretained(self).toOpaque()
        sqlite3_trace(sqliteConnection, { (dbPointer, sql) in
            guard let sql = sql.map(String.init(cString:)) else { return }
            let db = Unmanaged<Database>.fromOpaque(dbPointer!).takeUnretainedValue()
            db.trace?(Database.TraceEvent.statement(TraceEvent.Statement(impl: .trace_v1(sql))))
        }, dbPointer)
    }
    #endif
    
    // Precondition: configuration.trace != nil
    private func trace_v2(
        _ mask: CInt,
        _ p: UnsafeMutableRawPointer?,
        _ x: UnsafeMutableRawPointer?,
        _ sqlite3_expanded_sql: @escaping @convention(c) (OpaquePointer?) -> UnsafeMutablePointer<Int8>?)
    {
        guard let trace = trace else { return }
        
        switch mask {
        case SQLITE_TRACE_STMT:
            if let sqliteStatement = p, let unexpandedSQL = x {
                let statement = TraceEvent.Statement(
                    impl: .trace_v2(
                        sqliteStatement: OpaquePointer(sqliteStatement),
                        unexpandedSQL: UnsafePointer(unexpandedSQL.assumingMemoryBound(to: CChar.self)),
                        sqlite3_expanded_sql: sqlite3_expanded_sql))
                trace(TraceEvent.statement(statement))
            }
        case SQLITE_TRACE_PROFILE:
            if let sqliteStatement = p, let durationP = x?.assumingMemoryBound(to: Int64.self) {
                let statement = TraceEvent.Statement(
                    impl: .trace_v2(
                        sqliteStatement: OpaquePointer(sqliteStatement),
                        unexpandedSQL: nil,
                        sqlite3_expanded_sql: sqlite3_expanded_sql))
                let duration = TimeInterval(durationP.pointee) / 1.0e9
                
                #if GRDBCUSTOMSQLITE || GRDBCIPHER || os(iOS)
                trace(TraceEvent.profile(statement: statement, duration: duration))
                #elseif os(Linux)
                #else
                if #available(OSX 10.12, tvOS 10.0, watchOS 3.0, *) {
                    trace(TraceEvent.profile(statement: statement, duration: duration))
                }
                #endif
            }
        default:
            break
        }
    }
    
    // MARK: - WAL Checkpoints
    
    /// Runs a WAL checkpoint.
    ///
    /// See <https://www.sqlite.org/wal.html> and
    /// <https://www.sqlite.org/c3ref/wal_checkpoint_v2.html> for
    /// more information.
    ///
    /// - parameter kind: The checkpoint mode (default passive)
    /// - parameter dbName: The database name (default "main")
    /// - returns: A tuple:
    ///     - `walFrameCount`: the total number of frames in the log file
    ///     - `checkpointedFrameCount`: the total number of checkpointed frames
    ///       in the log file
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
    /// exception](https://developer.apple.com/documentation/xcode/understanding-the-exception-types-in-a-crash-report).
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
        $isSuspended.update { isSuspended in
            if isSuspended {
                return
            }
            
            // Prevent future lock acquisition
            isSuspended = true
            
            // Interrupt the database because this may trigger an
            // SQLITE_INTERRUPT error which may itself abort a transaction and
            // release a lock. See <https://www.sqlite.org/c3ref/interrupt.html>
            interrupt()
            
            // Now what about the eventual remaining lock? We'll issue a
            // rollback on next database access which requires a lock, in
            // checkForSuspensionViolation(from:).
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
        isSuspended = false
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
    /// exception](https://developer.apple.com/documentation/xcode/understanding-the-exception-types-in-a-crash-report).
    func checkForSuspensionViolation(from statement: Statement) throws {
        try $isSuspended.read { isSuspended in
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
            
            if statement.releasesDatabaseLock {
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
        if isInsideTransactionBlock && sqlite3_get_autocommit(sqliteConnection) != 0 {
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
    ///       defaults to .deferred. See <https://www.sqlite.org/lang_transaction.html>
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
    
    /// Runs the block with an isolation level equal or greater than
    /// snapshot isolation.
    func isolated<T>(readOnly: Bool = false, _ block: () throws -> T) throws -> T {
        var result: T?
        try inSavepoint {
            if readOnly {
                result = try self.readOnly(block)
            } else {
                result = try block()
            }
            return .commit
        }
        return result!
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
        if !isInsideTransaction {
            // By default, top level SQLite savepoints open a
            // deferred transaction.
            //
            // But GRDB database configuration mandates a default transaction
            // kind that we have to honor.
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
            try inTransaction(configuration.defaultTransactionKind, block)
            return
        }
        
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
        
        if let firstError = firstError {
            throw firstError
        }
    }
    
    /// Begins a database transaction.
    ///
    /// - parameter kind: The transaction type (default nil). If nil, the
    ///   transaction type is configuration.defaultTransactionKind, which itself
    ///   defaults to .deferred. See <https://www.sqlite.org/lang_transaction.html>
    ///   for more information.
    /// - throws: The error thrown by the block.
    public func beginTransaction(_ kind: TransactionKind? = nil) throws {
        let kind = kind ?? configuration.defaultTransactionKind
        try execute(sql: "BEGIN \(kind.rawValue) TRANSACTION")
        assert(sqlite3_get_autocommit(sqliteConnection) == 0)
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
        assert(sqlite3_get_autocommit(sqliteConnection) != 0)
    }
    
    /// Commits a database transaction.
    public func commit() throws {
        try execute(sql: "COMMIT TRANSACTION")
        assert(sqlite3_get_autocommit(sqliteConnection) != 0)
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
            sqlite3_key(sqliteConnection, $0.baseAddress, Int32($0.count))
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
            sqlite3_rekey(sqliteConnection, $0.baseAddress, Int32($0.count))
        }
        guard code == SQLITE_OK else {
            throw DatabaseError(resultCode: code, message: lastErrorMessage)
        }
    }
}
#endif

extension Database {
    
    // MARK: - Database-Related Types
    
    /// See BusyMode and <https://www.sqlite.org/c3ref/busy_handler.html>
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
    /// - <https://www.sqlite.org/c3ref/busy_timeout.html>
    /// - <https://www.sqlite.org/c3ref/busy_handler.html>
    /// - <https://www.sqlite.org/lang_transaction.html>
    /// - <https://www.sqlite.org/wal.html>
    public enum BusyMode {
        /// The SQLITE_BUSY error is immediately returned to the connection that
        /// tries to access the locked database.
        case immediateError
        
        /// The SQLITE_BUSY error will be returned only if the database remains
        /// locked for more than the specified duration (in seconds).
        case timeout(TimeInterval)
        
        /// A custom callback that is called when a database is locked.
        /// See <https://www.sqlite.org/c3ref/busy_handler.html>
        case callback(BusyCallback)
    }
    
    /// The available [checkpoint modes](https://www.sqlite.org/c3ref/wal_checkpoint_v2.html).
    public enum CheckpointMode: Int32 {
        /// The `SQLITE_CHECKPOINT_PASSIVE` mode
        case passive = 0
        
        /// The `SQLITE_CHECKPOINT_FULL` mode
        case full = 1
        
        /// The `SQLITE_CHECKPOINT_RESTART` mode
        case restart = 2
        
        /// The `SQLITE_CHECKPOINT_TRUNCATE` mode
        case truncate = 3
    }
    
    /// A built-in SQLite collation.
    ///
    /// See <https://www.sqlite.org/datatype3.html#collation>
    public struct CollationName: RawRepresentable, Hashable {
        /// :nodoc:
        public let rawValue: String
        
        /// Creates a built-in collation name.
        public init(rawValue: String) {
            self.rawValue = rawValue
        }
        
        /// The `BINARY` built-in SQL collation
        public static let binary = CollationName(rawValue: "BINARY")
        
        /// The `NOCASE` built-in SQL collation
        public static let nocase = CollationName(rawValue: "NOCASE")
        
        /// The `RTRIM` built-in SQL collation
        public static let rtrim = CollationName(rawValue: "RTRIM")
    }
    
    /// An SQL column type.
    ///
    ///     try db.create(table: "player") { t in
    ///         t.autoIncrementedPrimaryKey("id")
    ///         t.column("title", .text)
    ///     }
    ///
    /// See <https://www.sqlite.org/datatype3.html>
    public struct ColumnType: RawRepresentable, Hashable {
        /// :nodoc:
        public let rawValue: String
        
        /// Creates an SQL column type.
        public init(rawValue: String) {
            self.rawValue = rawValue
        }
        
        /// The `TEXT` SQL column type
        public static let text = ColumnType(rawValue: "TEXT")
        
        /// The `INTEGER` SQL column type
        public static let integer = ColumnType(rawValue: "INTEGER")
        
        /// The `DOUBLE` SQL column type
        public static let double = ColumnType(rawValue: "DOUBLE")
        
        /// The `NUMERIC` SQL column type
        public static let numeric = ColumnType(rawValue: "NUMERIC")
        
        /// The `BOOLEAN` SQL column type
        public static let boolean = ColumnType(rawValue: "BOOLEAN")
        
        /// The `BLOB` SQL column type
        public static let blob = ColumnType(rawValue: "BLOB")
        
        /// The `DATE` SQL column type
        public static let date = ColumnType(rawValue: "DATE")
        
        /// The `DATETIME` SQL column type
        public static let datetime = ColumnType(rawValue: "DATETIME")
    }
    
    /// An SQLite conflict resolution.
    ///
    /// See <https://www.sqlite.org/lang_conflict.html>
    public enum ConflictResolution: String {
        /// The `ROLLBACK` conflict resolution
        case rollback = "ROLLBACK"
        
        /// The `ABORT` conflict resolution
        case abort = "ABORT"
        
        /// The `FAIL` conflict resolution
        case fail = "FAIL"
        
        /// The `IGNORE` conflict resolution
        case ignore = "IGNORE"
        
        /// The `REPLACE` conflict resolution
        case replace = "REPLACE"
    }
    
    /// A foreign key action.
    ///
    /// See <https://www.sqlite.org/foreignkeys.html>
    public enum ForeignKeyAction: String {
        /// The `CASCADE` foreign key action
        case cascade = "CASCADE"
        
        /// The `RESTRICT` foreign key action
        case restrict = "RESTRICT"
        
        /// The `SET NULL` foreign key action
        case setNull = "SET NULL"
        
        /// The `SET DEFAULT` foreign key action
        case setDefault = "SET DEFAULT"
    }
    
    /// An error log function that takes an error code and message.
    public typealias LogErrorFunction = (_ resultCode: ResultCode, _ message: String) -> Void
    
    /// An option for `Database.trace(options:_:)`
    public struct TracingOptions: OptionSet {
        /// The raw "Trace Event Code".
        ///
        /// See <https://www.sqlite.org/c3ref/c_trace.html>
        public let rawValue: CInt
        
        /// Creates a `TracingOptions` from a raw "Trace Event Code".
        ///
        /// See:
        /// - <https://www.sqlite.org/c3ref/c_trace.html>
        /// - `Database.trace(options:_:)`
        public init(rawValue: CInt) {
            self.rawValue = rawValue
        }
        
        /// Reports executed statements.
        ///
        /// See `Database.trace(options:_:)`
        public static let statement = TracingOptions(rawValue: SQLITE_TRACE_STMT)
        
        #if GRDBCUSTOMSQLITE || GRDBCIPHER || os(iOS)
        /// Reports executed statements and the estimated duration that the
        /// statement took to run.
        ///
        /// See `Database.trace(options:_:)`
        public static let profile = TracingOptions(rawValue: SQLITE_TRACE_PROFILE)
        #elseif os(Linux)
        #else
        /// Reports executed statements and the estimated duration that the
        /// statement took to run.
        ///
        /// See `Database.trace(options:_:)`
        @available(OSX 10.12, tvOS 10.0, watchOS 3.0, *)
        public static let profile = TracingOptions(rawValue: SQLITE_TRACE_PROFILE)
        #endif
    }
    
    /// An event reported by `Database.trace(options:_:)`
    public enum TraceEvent: CustomStringConvertible {
        
        /// Information about a statement reported by `Database.trace(options:_:)`
        public struct Statement {
            enum Impl {
                case trace_v1(String)
                case trace_v2(
                        sqliteStatement: SQLiteStatement,
                        unexpandedSQL: UnsafePointer<CChar>?,
                        sqlite3_expanded_sql: @convention(c) (OpaquePointer?) -> UnsafeMutablePointer<Int8>?)
            }
            let impl: Impl
            
            #if GRDBCUSTOMSQLITE || GRDBCIPHER || os(iOS)
            /// The executed SQL, where bound parameters are not expanded.
            ///
            /// For example:
            ///
            ///     UPDATE player SET score = ? WHERE id = ?
            public var sql: String { _sql }
            #elseif os(Linux)
            #else
            /// The executed SQL, where bound parameters are not expanded.
            ///
            /// For example:
            ///
            ///     UPDATE player SET score = ? WHERE id = ?
            @available(OSX 10.12, tvOS 10.0, watchOS 3.0, *)
            public var sql: String { _sql }
            #endif
            
            var _sql: String {
                switch impl {
                case .trace_v1:
                    // Likely a GRDB bug
                    fatalError("Not get statement SQL")
                    
                case let .trace_v2(sqliteStatement, unexpandedSQL, _):
                    if let unexpandedSQL = unexpandedSQL {
                        return String(cString: unexpandedSQL)
                            .trimmingCharacters(in: .sqlStatementSeparators)
                    } else {
                        return String(cString: sqlite3_sql(sqliteStatement))
                            .trimmingCharacters(in: .sqlStatementSeparators)
                    }
                }
            }
            
            /// The executed SQL, where bound parameters are expanded.
            ///
            /// For example:
            ///
            ///     UPDATE player SET score = 1000 WHERE id = 1
            public var expandedSQL: String {
                switch impl {
                case let .trace_v1(expandedSQL):
                    return expandedSQL
                    
                case let .trace_v2(sqliteStatement, _, sqlite3_expanded_sql):
                    guard let cString = sqlite3_expanded_sql(sqliteStatement) else {
                        return ""
                    }
                    defer { sqlite3_free(cString) }
                    return String(cString: cString)
                        .trimmingCharacters(in: .sqlStatementSeparators)
                }
            }
        }
        
        /// An event reported by `TracingOptions.statement`.
        case statement(Statement)
        
        /// An event reported by `TracingOptions.profile`.
        case profile(statement: Statement, duration: TimeInterval)
        
        public var description: String {
            switch self {
            case let .statement(statement):
                return statement.expandedSQL
            case let .profile(statement: statement, duration: duration):
                let durationString = String(format: "%.3f", duration)
                return "\(durationString)s \(statement.expandedSQL)"
            }
        }
    }
    
    /// Confirms or cancels the changes performed by a transaction or savepoint.
    @frozen
    public enum TransactionCompletion {
        /// Confirms changes
        case commit
        
        /// Cancel changes
        case rollback
    }
    
    /// An SQLite transaction kind. See <https://www.sqlite.org/lang_transaction.html>
    public enum TransactionKind: String {
        /// The `DEFERRED` transaction kind
        case deferred = "DEFERRED"
        
        /// The `IMMEDIATE` transaction kind
        case immediate = "IMMEDIATE"
        
        /// The `EXCLUSIVE` transaction kind
        case exclusive = "EXCLUSIVE"
    }
    
    /// An SQLite threading mode. See <https://www.sqlite.org/threadsafe.html>.
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
