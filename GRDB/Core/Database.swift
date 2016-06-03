import Foundation

#if !USING_BUILTIN_SQLITE
    #if os(OSX)
        import SQLiteMacOSX
    #elseif os(iOS)
        #if (arch(i386) || arch(x86_64))
            import SQLiteiPhoneSimulator
        #else
            import SQLiteiPhoneOS
        #endif
    #endif
#endif

/// A raw SQLite connection, suitable for the SQLite C API.
public typealias SQLiteConnection = COpaquePointer

/// A raw SQLite function argument.
typealias SQLiteValue = COpaquePointer


/// A Database connection.
///
/// You don't create a database directly. Instead, you use a DatabaseQueue, or
/// a DatabasePool:
///
///     let dbQueue = DatabaseQueue(...)
///
///     // The Database is the `db` in the closure:
///     dbQueue.inDatabase { db in
///         db.execute(...)
///     }
public final class Database {
    // The Database class is not thread-safe. An instance should always be
    // used through a SerializedDatabase.
    
    // MARK: - Database Information
    
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
        DatabaseScheduler.preconditionValidQueue(self)
        return sqlite3_last_insert_rowid(sqliteConnection)
    }
    
    /// The number of rows modified, inserted or deleted by the most recent
    /// successful INSERT, UPDATE or DELETE statement.
    ///
    /// For more detailed information, see https://www.sqlite.org/c3ref/changes.html
    public var changesCount: Int {
        DatabaseScheduler.preconditionValidQueue(self)
        return Int(sqlite3_changes(sqliteConnection))
    }
    
    /// The total number of rows modified, inserted or deleted by all successful
    /// INSERT, UPDATE or DELETE statements since the database connection was
    /// opened.
    ///
    /// For more detailed information, see https://www.sqlite.org/c3ref/total_changes.html
    public var totalChangesCount: Int {
        DatabaseScheduler.preconditionValidQueue(self)
        return Int(sqlite3_total_changes(sqliteConnection))
    }
    
    var lastErrorCode: Int32 { return sqlite3_errcode(sqliteConnection) }
    var lastErrorMessage: String? { return String.fromCString(sqlite3_errmsg(sqliteConnection)) }
    
    /// True if the database connection is currently in a transaction.
    public var isInsideTransaction: Bool { return isInsideExplicitTransaction || !savepointStack.isEmpty }
    
    // Set by beginTransaction, rollback and commit. Not set by savepoints.
    private var isInsideExplicitTransaction: Bool = false
    
    // Transaction observers
    private var transactionObservers = [WeakTransactionObserver]()
    private var transactionState: TransactionState = .WaitForTransactionCompletion
    private var savepointStack = SavePointStack()
    
    /// See setupBusyMode()
    private var busyCallback: BusyCallback?
    
    /// Available functions
    private var functions = Set<DatabaseFunction>()
    
    /// Available collations
    private var collations = Set<DatabaseCollation>()
    
    /// Schema Cache
    var schemaCache: DatabaseSchemaCacheType    // internal so that it can be tested
    
    /// Statement cache. Not part of the schema cache because statements belong
    /// to this connection, while schema cache can be shared with
    /// other connections.
    private var selectStatementCache: [String: SelectStatement] = [:]
    private var updateStatementCache: [String: UpdateStatement] = [:]
    
    init(path: String, configuration: Configuration, schemaCache: DatabaseSchemaCacheType) throws {
        // See https://www.sqlite.org/c3ref/open.html
        var sqliteConnection: SQLiteConnection = nil
        let code = sqlite3_open_v2(path, &sqliteConnection, configuration.SQLiteOpenFlags, nil)
        guard code == SQLITE_OK else {
            throw DatabaseError(code: code, message: String.fromCString(sqlite3_errmsg(sqliteConnection)))
        }
        
        do {
            #if SQLITE_HAS_CODEC
                if let passphrase = configuration.passphrase {
                    try Database.setPassphrase(passphrase, forConnection: sqliteConnection)
                }
            #endif
            
            // Users are surprised when they open a picture as a database and
            // see no error (https://github.com/groue/GRDB.swift/issues/54).
            //
            // So let's fail early if file is not a database, or encrypted with
            // another passphrase.
            let readCode = sqlite3_exec(sqliteConnection, "SELECT * FROM sqlite_master LIMIT 1", nil, nil, nil)
            guard readCode == SQLITE_OK else {
                throw DatabaseError(code: readCode, message: String.fromCString(sqlite3_errmsg(sqliteConnection)))
            }
        } catch {
            closeConnection(sqliteConnection)
            throw error
        }
        
        self.configuration = configuration
        self.schemaCache = schemaCache
        self.sqliteConnection = sqliteConnection
        
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
    }
    
    /// This method must be called before database deallocation
    func close() {
        DatabaseScheduler.preconditionValidQueue(self)
        assert(!isClosed)
        
        configuration.SQLiteConnectionWillClose?(sqliteConnection)
        updateStatementCache = [:]
        selectStatementCache = [:]
        closeConnection(sqliteConnection)
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
        updateStatementCache = [:]
        selectStatementCache = [:]
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
        let dbPointer = unsafeBitCast(self, UnsafeMutablePointer<Void>.self)
        sqlite3_trace(sqliteConnection, { (dbPointer, sql) in
            let database = unsafeBitCast(dbPointer, Database.self)
            database.configuration.trace!(String.fromCString(sql)!)
            }, dbPointer)
    }
    
    private func setupBusyMode() {
        switch configuration.busyMode {
        case .ImmediateError:
            break
            
        case .Timeout(let duration):
            let milliseconds = Int32(duration * 1000)
            sqlite3_busy_timeout(sqliteConnection, milliseconds)
            
        case .Callback(let callback):
            let dbPointer = unsafeBitCast(self, UnsafeMutablePointer<Void>.self)
            busyCallback = callback
            
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
    
    private func setupDefaultFunctions() {
        addFunction(.capitalizedString)
        addFunction(.lowercaseString)
        addFunction(.uppercaseString)
        
        if #available(iOS 9.0, OSX 10.11, *) {
            addFunction(.localizedCapitalizedString)
            addFunction(.localizedLowercaseString)
            addFunction(.localizedUppercaseString)
        }
    }
    
    private func setupDefaultCollations() {
        addCollation(.unicodeCompare)
        addCollation(.caseInsensitiveCompare)
        addCollation(.localizedCaseInsensitiveCompare)
        addCollation(.localizedCompare)
        addCollation(.localizedStandardCompare)
    }
}

private func closeConnection(sqliteConnection: SQLiteConnection) {
    // sqlite3_close_v2 was added in SQLite 3.7.14 http://www.sqlite.org/changes.html#version_3_7_14
    // It is available from iOS 8.2 and OS X 10.10 https://github.com/yapstudios/YapDatabase/wiki/SQLite-version-(bundled-with-OS)
    if #available(iOS 8.2, OSX 10.10, *) {
        // https://www.sqlite.org/c3ref/close.html
        // > If sqlite3_close_v2() is called with unfinalized prepared
        // > statements and/or unfinished sqlite3_backups, then the database
        // > connection becomes an unusable "zombie" which will automatically
        // > be deallocated when the last prepared statement is finalized or the
        // > last sqlite3_backup is finished.
        let code = sqlite3_close_v2(sqliteConnection)
        if code != SQLITE_OK {
            // A rare situation where GRDB doesn't fatalError on unprocessed
            // errors.
            let message = String.fromCString(sqlite3_errmsg(sqliteConnection))
            NSLog("%@", "GRDB could not close database with error \(code): \(message ?? "")")
        }
    } else {
        // https://www.sqlite.org/c3ref/close.html
        // > If the database connection is associated with unfinalized prepared
        // > statements or unfinished sqlite3_backup objects then
        // > sqlite3_close() will leave the database connection open and
        // > return SQLITE_BUSY.
        let code = sqlite3_close(sqliteConnection)
        if code != SQLITE_OK {
            // A rare situation where GRDB doesn't fatalError on unprocessed
            // errors.
            let message = String.fromCString(sqlite3_errmsg(sqliteConnection))
            NSLog("%@", "GRDB could not close database with error \(code): \(message ?? "")")
            if code == SQLITE_BUSY {
                // Let the user know about unfinalized statements that did
                // prevent the connection from closing properly.
                var stmt: SQLiteStatement = sqlite3_next_stmt(sqliteConnection, nil)
                while stmt != nil {
                    NSLog("%@", "GRDB unfinalized statement: \(String.fromCString(sqlite3_sql(stmt))!)")
                    stmt = sqlite3_next_stmt(sqliteConnection, stmt)
                }
            }
        }
    }
}


/// An SQLite threading mode. See https://www.sqlite.org/threadsafe.html.
enum ThreadingMode {
    case Default
    case MultiThread
    case Serialized
    
    var SQLiteOpenFlags: Int32 {
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
// MARK: - Statements

extension Database {
    
    /// Returns a new prepared statement that can be reused.
    ///
    ///     let statement = try db.selectStatement("SELECT COUNT(*) FROM persons WHERE age > ?")
    ///     let moreThanTwentyCount = Int.fetchOne(statement, arguments: [20])!
    ///     let moreThanThirtyCount = Int.fetchOne(statement, arguments: [30])!
    ///
    /// - parameter sql: An SQL query.
    /// - returns: A SelectStatement.
    /// - throws: A DatabaseError whenever SQLite could not parse the sql query.
    @warn_unused_result
    public func selectStatement(sql: String) throws -> SelectStatement {
        return try SelectStatement(database: self, sql: sql)
    }
    
    /// Returns a prepared statement that can be reused.
    ///
    ///     let statement = try db.cachedSelectStatement("SELECT COUNT(*) FROM persons WHERE age > ?")
    ///     let moreThanTwentyCount = Int.fetchOne(statement, arguments: [20])!
    ///     let moreThanThirtyCount = Int.fetchOne(statement, arguments: [30])!
    ///
    /// The returned statement may have already been used: it may or may not
    /// contain values for its eventual arguments.
    ///
    /// - parameter sql: An SQL query.
    /// - returns: An UpdateStatement.
    /// - throws: A DatabaseError whenever SQLite could not parse the sql query.
    @warn_unused_result
    public func cachedSelectStatement(sql: String) throws -> SelectStatement {
        if let statement = selectStatementCache[sql] {
            return statement
        }
        
        let statement = try selectStatement(sql)
        selectStatementCache[sql] = statement
        return statement
    }
    
    /// Returns a new prepared statement that can be reused.
    ///
    ///     let statement = try db.updateStatement("INSERT INTO persons (name) VALUES (?)")
    ///     try statement.execute(arguments: ["Arthur"])
    ///     try statement.execute(arguments: ["Barbara"])
    ///
    /// - parameter sql: An SQL query.
    /// - returns: An UpdateStatement.
    /// - throws: A DatabaseError whenever SQLite could not parse the sql query.
    @warn_unused_result
    public func updateStatement(sql: String) throws -> UpdateStatement {
        return try UpdateStatement(database: self, sql: sql)
    }
    
    /// Returns a prepared statement that can be reused.
    ///
    ///     let statement = try db.cachedUpdateStatement("INSERT INTO persons (name) VALUES (?)")
    ///     try statement.execute(arguments: ["Arthur"])
    ///     try statement.execute(arguments: ["Barbara"])
    ///
    /// The returned statement may have already been used: it may or may not
    /// contain values for its eventual arguments.
    ///
    /// - parameter sql: An SQL query.
    /// - returns: An UpdateStatement.
    /// - throws: A DatabaseError whenever SQLite could not parse the sql query.
    @warn_unused_result
    public func cachedUpdateStatement(sql: String) throws -> UpdateStatement {
        if let statement = updateStatementCache[sql] {
            return statement
        }
        
        let statement = try updateStatement(sql)
        updateStatementCache[sql] = statement
        return statement
    }
    
    /// Executes one or several SQL statements, separated by semi-colons.
    ///
    ///     try db.execute(
    ///         "INSERT INTO persons (name) VALUES (:name)",
    ///         arguments: ["name": "Arthur"])
    ///
    ///     try db.execute(
    ///         "INSERT INTO persons (name) VALUES (?);" +
    ///         "INSERT INTO persons (name) VALUES (?);" +
    ///         "INSERT INTO persons (name) VALUES (?);",
    ///         arguments; ['Arthur', 'Barbara', 'Craig'])
    ///
    /// This method may throw a DatabaseError.
    ///
    /// - parameters:
    ///     - sql: An SQL query.
    ///     - arguments: Optional statement arguments.
    /// - throws: A DatabaseError whenever an SQLite error occurs.
    public func execute(sql: String, arguments: StatementArguments? = nil) throws {
        // This method is like sqlite3_exec (https://www.sqlite.org/c3ref/exec.html)
        // It adds support for arguments.
        
        DatabaseScheduler.preconditionValidQueue(self)
        
        // The tricky part is to consume arguments as statements are executed.
        //
        // Here we build two functions:
        // - consumeArguments returns arguments for a statement
        // - validateRemainingArguments validates the remaining arguments, after
        //   all statements have been executed, in the same way
        //   as Statement.validateArguments()
        let consumeArguments: UpdateStatement -> StatementArguments
        let validateRemainingArguments: () throws -> ()
        
        if let arguments = arguments {
            switch arguments.kind {
            case .Values(let values):
                // Extract as many values as needed, statement after statement:
                var remainingValues = values
                consumeArguments = { (statement: UpdateStatement) -> StatementArguments in
                    let argumentCount = statement.sqliteArgumentCount
                    defer {
                        if remainingValues.count >= argumentCount {
                            remainingValues = Array(remainingValues.suffixFrom(argumentCount))
                        } else {
                            remainingValues = []
                        }
                    }
                    return StatementArguments(remainingValues.prefix(argumentCount))
                }
                // It's not OK if there remains unused arguments:
                validateRemainingArguments = {
                    if !remainingValues.isEmpty {
                        throw DatabaseError(code: SQLITE_MISUSE, message: "wrong number of statement arguments: \(values.count)")
                    }
                }
            case .NamedValues:
                // Reuse the dictionary argument for all statements:
                consumeArguments = { _ in return arguments }
                validateRemainingArguments = { _ in }
            }
        } else {
            // Empty arguments for all statements:
            consumeArguments = { _ in return [] }
            validateRemainingArguments = { _ in }
        }
        
        
        // Execute statements
        
        let sqlCodeUnits = sql.nulTerminatedUTF8
        var error: ErrorType?
        
        // During the execution of sqlite3_prepare_v2, the observer listens to
        // authorization callbacks in order to recognize "interesting"
        // statements. See updateStatementDidExecute().
        let observer = StatementCompilationObserver(self)
        observer.start()
        
        sqlCodeUnits.withUnsafeBufferPointer { codeUnits in
            let sqlStart = UnsafePointer<Int8>(codeUnits.baseAddress)
            let sqlEnd = sqlStart + sqlCodeUnits.count
            var statementStart = sqlStart
            while statementStart < sqlEnd - 1 {
                observer.reset()
                var statementEnd: UnsafePointer<Int8> = nil
                var sqliteStatement: SQLiteStatement = nil
                let code = sqlite3_prepare_v2(sqliteConnection, statementStart, -1, &sqliteStatement, &statementEnd)
                guard code == SQLITE_OK else {
                    error = DatabaseError(code: code, message: lastErrorMessage, sql: sql)
                    break
                }
                
                guard sqliteStatement != nil else {
                    // The remaining string contains only whitespace
                    assert(String(data: NSData(bytesNoCopy: UnsafeMutablePointer<Void>(statementStart), length: statementEnd - statementStart, freeWhenDone: false), encoding: NSUTF8StringEncoding)!.stringByTrimmingCharactersInSet(.whitespaceAndNewlineCharacterSet()).isEmpty)
                    break
                }
                
                do {
                    let statement = UpdateStatement(
                        database: self,
                        sqliteStatement: sqliteStatement,
                        invalidatesDatabaseSchemaCache: observer.invalidatesDatabaseSchemaCache,
                        savepointAction: observer.savepointAction)
                    try statement.execute(arguments: consumeArguments(statement))
                } catch let statementError {
                    error = statementError
                    break
                }
                
                statementStart = statementEnd
            }
        }
        
        observer.stop()
        
        if let error = error {
            throw error
        }
        
        // Force arguments validity. See UpdateStatement.execute(), and SelectStatement.fetchSequence()
        try! validateRemainingArguments()
    }
}


// =========================================================================
// MARK: - Functions

extension Database {
    
    /// Add or redefine an SQL function.
    ///
    ///     let fn = DatabaseFunction("succ", argumentCount: 1) { databaseValues in
    ///         let dbv = databaseValues.first!
    ///         guard let int = dbv.value() as Int? else {
    ///             return nil
    ///         }
    ///         return int + 1
    ///     }
    ///     db.addFunction(fn)
    ///     Int.fetchOne(db, "SELECT succ(1)")! // 2
    public func addFunction(function: DatabaseFunction) {
        functions.remove(function)
        functions.insert(function)
        let functionPointer = unsafeBitCast(function, UnsafeMutablePointer<Void>.self)
        let code = sqlite3_create_function_v2(
            sqliteConnection,
            function.name,
            function.argumentCount,
            SQLITE_UTF8 | function.eTextRep,
            functionPointer,
            { (context, argc, argv) in
                let function = unsafeBitCast(sqlite3_user_data(context), DatabaseFunction.self)
                do {
                    let result = try function.function(argc, argv)
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
            fatalError(DatabaseError(code: code, message: lastErrorMessage).description)
        }
    }
    
    /// Remove an SQL function.
    public func removeFunction(function: DatabaseFunction) {
        functions.remove(function)
        let code = sqlite3_create_function_v2(
            sqliteConnection,
            function.name,
            function.argumentCount,
            SQLITE_UTF8 | function.eTextRep,
            nil, nil, nil, nil, nil)
        guard code == SQLITE_OK else {
            fatalError(DatabaseError(code: code, message: lastErrorMessage).description)
        }
    }
}


/// An SQL function.
public final class DatabaseFunction {
    public let name: String
    let argumentCount: Int32
    let pure: Bool
    let function: (Int32, UnsafeMutablePointer<COpaquePointer>) throws -> DatabaseValue
    var eTextRep: Int32 { return pure ? SQLITE_DETERMINISTIC : 0 }
    
    /// Returns an SQL function.
    ///
    ///     let fn = DatabaseFunction("succ", argumentCount: 1) { databaseValues in
    ///         let dbv = databaseValues.first!
    ///         guard let int = dbv.value() as Int? else {
    ///             return nil
    ///         }
    ///         return int + 1
    ///     }
    ///     db.addFunction(fn)
    ///     Int.fetchOne(db, "SELECT succ(1)")! // 2
    ///
    /// - parameters:
    ///     - name: The function name.
    ///     - argumentCount: The number of arguments of the function. If
    ///       omitted, or nil, the function accepts any number of arguments.
    ///     - pure: Whether the function is "pure", which means that its results
    ///       only depends on its inputs. When a function is pure, SQLite has
    ///       the opportunity to perform additional optimizations. Default value
    ///       is false.
    ///     - function: A function that takes an array of DatabaseValue
    ///       arguments, and returns an optional DatabaseValueConvertible such
    ///       as Int, String, NSDate, etc. The array is guaranteed to have
    ///       exactly *argumentCount* elements, provided *argumentCount* is
    ///       not nil.
    public init(_ name: String, argumentCount: Int32? = nil, pure: Bool = false, function: [DatabaseValue] throws -> DatabaseValueConvertible?) {
        self.name = name
        self.argumentCount = argumentCount ?? -1
        self.pure = pure
        self.function = { (argc, argv) in
            let arguments = (0..<Int(argc)).map { index in DatabaseValue(sqliteValue: argv[index]) }
            return try function(arguments)?.databaseValue ?? .Null
        }
    }
}

extension DatabaseFunction : Hashable {
    /// The hash value.
    public var hashValue: Int {
        return name.hashValue ^ argumentCount.hashValue
    }
}

/// Two functions are equal if they share the same name and argumentCount.
public func ==(lhs: DatabaseFunction, rhs: DatabaseFunction) -> Bool {
    return lhs.name == rhs.name && lhs.argumentCount == rhs.argumentCount
}


// =========================================================================
// MARK: - Collations

extension Database {
    
    /// Add or redefine a collation.
    ///
    ///     let collation = DatabaseCollation("localized_standard") { (string1, string2) in
    ///         return (string1 as NSString).localizedStandardCompare(string2)
    ///     }
    ///     db.addCollation(collation)
    ///     try db.execute("CREATE TABLE files (name TEXT COLLATE localized_standard")
    public func addCollation(collation: DatabaseCollation) {
        collations.remove(collation)
        collations.insert(collation)
        let collationPointer = unsafeBitCast(collation, UnsafeMutablePointer<Void>.self)
        let code = sqlite3_create_collation_v2(
            sqliteConnection,
            collation.name,
            SQLITE_UTF8,
            collationPointer,
            { (collationPointer, length1, buffer1, length2, buffer2) -> Int32 in
                let collation = unsafeBitCast(collationPointer, DatabaseCollation.self)
                return Int32(collation.function(length1, buffer1, length2, buffer2).rawValue)
            }, nil)
        guard code == SQLITE_OK else {
            fatalError(DatabaseError(code: code, message: lastErrorMessage).description)
        }
    }
    
    /// Remove a collation.
    public func removeCollation(collation: DatabaseCollation) {
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
    let function: (Int32, UnsafePointer<Void>, Int32, UnsafePointer<Void>) -> NSComparisonResult
    
    /// Returns a collation.
    ///
    ///     let collation = DatabaseCollation("localized_standard") { (string1, string2) in
    ///         return (string1 as NSString).localizedStandardCompare(string2)
    ///     }
    ///     db.addCollation(collation)
    ///     try db.execute("CREATE TABLE files (name TEXT COLLATE localized_standard")
    ///
    /// - parameters:
    ///     - name: The function name.
    ///     - function: A function that compares two strings.
    public init(_ name: String, function: (String, String) -> NSComparisonResult) {
        self.name = name
        self.function = { (length1, buffer1, length2, buffer2) in
            // Buffers are not C strings: they do not end with \0.
            let string1 = String(bytesNoCopy: UnsafeMutablePointer<Void>(buffer1), length: Int(length1), encoding: NSUTF8StringEncoding, freeWhenDone: false)!
            let string2 = String(bytesNoCopy: UnsafeMutablePointer<Void>(buffer2), length: Int(length2), encoding: NSUTF8StringEncoding, freeWhenDone: false)!
            return function(string1, string2)
        }
    }
}

extension DatabaseCollation : Hashable {
    /// The hash value.
    public var hashValue: Int {
        // We can't compute a hash since the equality is based on the opaque
        // sqlite3_strnicmp SQLite function.
        return 0
    }
}

/// Two collations are equal if they share the same name (case insensitive)
public func ==(lhs: DatabaseCollation, rhs: DatabaseCollation) -> Bool {
    // See https://www.sqlite.org/c3ref/create_collation.html
    return sqlite3_stricmp(lhs.name, lhs.name) == 0
}


// =========================================================================
// MARK: - Encryption

#if SQLITE_HAS_CODEC
extension Database {
    private class func setPassphrase(passphrase: String, forConnection sqliteConnection: SQLiteConnection) throws {
        let data = passphrase.dataUsingEncoding(NSUTF8StringEncoding)!
        let code = sqlite3_key(sqliteConnection, data.bytes, Int32(data.length))
        guard code == SQLITE_OK else {
            throw DatabaseError(code: code, message: String.fromCString(sqlite3_errmsg(sqliteConnection)))
        }
    }

    func changePassphrase(passphrase: String) throws {
        let data = passphrase.dataUsingEncoding(NSUTF8StringEncoding)!
        let code = sqlite3_rekey(sqliteConnection, data.bytes, Int32(data.length))
        guard code == SQLITE_OK else {
            throw DatabaseError(code: code, message: String.fromCString(sqlite3_errmsg(sqliteConnection)))
        }
    }
}
#endif


// =========================================================================
// MARK: - Database Schema

/// The protocol for schema cache.
///
/// This protocol must not contain values that are valid for a single connection
/// only, because several connections can share the same schema cache.
protocol DatabaseSchemaCacheType {
    mutating func clear()
    
    func primaryKey(tableName tableName: String) -> PrimaryKey??
    mutating func setPrimaryKey(primaryKey: PrimaryKey?, forTableName tableName: String)
}

extension Database {
    
    /// Clears the database schema cache.
    ///
    /// You may need to clear the cache manually if the database schema is
    /// modified by another connection.
    public func clearSchemaCache() {
        DatabaseScheduler.preconditionValidQueue(self)
        schemaCache.clear()
        
        // We also clear updateStatementCache and selectStatementCache despite
        // the automatic statement recompilation (see https://www.sqlite.org/c3ref/prepare.html)
        // because the automatic statement recompilation only happens a
        // limited number of times.
        updateStatementCache = [:]
        selectStatementCache = [:]
    }
    
    /// Returns whether a table exists.
    public func tableExists(tableName: String) -> Bool {
        DatabaseScheduler.preconditionValidQueue(self)
        
        // SQlite identifiers are case-insensitive, case-preserving (http://www.alberton.info/dbms_identifiers_and_case_sensitivity.html)
        return Row.fetchOne(self,
            "SELECT sql FROM sqlite_master WHERE type = 'table' AND LOWER(name) = ?",
            arguments: [tableName.lowercaseString]) != nil
    }
    
    /// The primary key for table named `tableName`; nil if table has no
    /// primary key.
    ///
    /// - throws: A DatabaseError if table does not exist.
    public func primaryKey(tableName: String) throws -> PrimaryKey? {
        DatabaseScheduler.preconditionValidQueue(self)
        
        if let primaryKey = schemaCache.primaryKey(tableName: tableName) {
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
        
        if #available(iOS 8.2, OSX 10.10, *) { } else {
            // Work around a bug in SQLite where PRAGMA table_info would
            // return a result even after the table was deleted.
            if !tableExists(tableName) {
                throw DatabaseError(message: "no such table: \(tableName)")
            }
        }
        let columnInfos = ColumnInfo.fetchAll(self, "PRAGMA table_info(\(tableName.quotedDatabaseIdentifier))")
        guard columnInfos.count > 0 else {
            throw DatabaseError(message: "no such table: \(tableName)")
        }
        
        let primaryKey: PrimaryKey?
        let pkColumnInfos = columnInfos
            .filter { $0.primaryKeyIndex > 0 }
            .sort { $0.primaryKeyIndex < $1.primaryKeyIndex }
        
        switch pkColumnInfos.count {
        case 0:
            // No primary key column
            primaryKey = nil
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
            // FIXME: We ignore the exception, and consider all INTEGER primary
            // keys as aliases for the rowid:
            if pkColumnInfo.type.uppercaseString == "INTEGER" {
                primaryKey = .rowID(pkColumnInfo.name)
            } else {
                primaryKey = .regular([pkColumnInfo.name])
            }
        default:
            // Multi-columns primary key
            primaryKey = .regular(pkColumnInfos.map { $0.name })
        }
        
        schemaCache.setPrimaryKey(primaryKey, forTableName: tableName)
        return primaryKey
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
        
        init(_ row: Row) {
            name = row.value(named: "name")
            type = row.value(named: "type")
            notNull = row.value(named: "notnull")
            defaultDatabaseValue = row.databaseValue(named: "dflt_value")!
            primaryKeyIndex = row.value(named: "pk")
        }
    }
}

/// You get primary keys from table names, with the Database.primaryKey(_)
/// method.
///
/// Primary key is nil when table has no primary key:
///
///     // CREATE TABLE items (name TEXT)
///     let itemPk = try db.primaryKey("items") // nil
///
/// Primary keys have one or several columns. When the primary key has a single
/// column, it may contain the row id:
///
///     // CREATE TABLE persons (
///     //   id INTEGER PRIMARY KEY,
///     //   name TEXT
///     // )
///     let personPk = try db.primaryKey("persons")!
///     personPk.columns     // ["id"]
///     personPk.rowIDColumn // "id"
///
///     // CREATE TABLE countries (
///     //   isoCode TEXT NOT NULL PRIMARY KEY
///     //   name TEXT
///     // )
///     let countryPk = db.primaryKey("countries")!
///     countryPk.columns     // ["isoCode"]
///     countryPk.rowIDColumn // nil
///
///     // CREATE TABLE citizenships (
///     //   personID INTEGER NOT NULL REFERENCES persons(id)
///     //   countryIsoCode TEXT NOT NULL REFERENCES countries(isoCode)
///     //   PRIMARY KEY (personID, countryIsoCode)
///     // )
///     let citizenshipsPk = db.primaryKey("citizenships")!
///     citizenshipsPk.columns     // ["personID", "countryIsoCode"]
///     citizenshipsPk.rowIDColumn // nil
public struct PrimaryKey {
    private enum Impl {
        /// An INTEGER PRIMARY KEY column that aliases the Row ID.
        /// Associated string is the column name.
        case RowID(String)
        
        /// Any primary key, but INTEGER PRIMARY KEY.
        /// Associated strings are column names.
        case Regular([String])
    }
    
    private let impl: Impl
    
    static func rowID(column: String) -> PrimaryKey {
        return PrimaryKey(impl: .RowID(column))
    }
    
    static func regular(columns: [String]) -> PrimaryKey {
        assert(!columns.isEmpty)
        return PrimaryKey(impl: .Regular(columns))
    }
    
    /// The columns in the primary key; this array is never empty.
    public var columns: [String] {
        switch impl {
        case .RowID(let column):
            return [column]
        case .Regular(let columns):
            return columns
        }
    }
    
    /// When not nil, the name of the column that contains the INTEGER PRIMARY KEY.
    public var rowIDColumn: String? {
        switch impl {
        case .RowID(let column):
            return column
        case .Regular:
            return nil
        }
    }
}


// =========================================================================
// MARK: - StatementCompilationObserver

/// A class that gathers information about a statement during its compilation.
final class StatementCompilationObserver {
    let database: Database
    
    // The list of tables queried by a statement
    var sourceTables: Set<String> = []
    
    // True if a statement alter the schema in a way that required schema cache
    // invalidation. Adding a column to a table does invalidate the schema
    // cache, but not adding a table.
    var invalidatesDatabaseSchemaCache = false
    
    // Not nil if a statement is a BEGIN/RELEASE/ROLLBACK savepoint statement.
    var savepointAction: (name: String, action: SavepointActionKind)?
    
    init(_ database: Database) {
        self.database = database
    }
    
    // Call this method before calling sqlite3_prepare_v2()
    func start() {
        let observerPointer = unsafeBitCast(self, UnsafeMutablePointer<Void>.self)
        sqlite3_set_authorizer(database.sqliteConnection, { (observerPointer, actionCode, CString1, CString2, CString3, CString4) -> Int32 in
            switch actionCode {
            case SQLITE_DROP_TABLE, SQLITE_DROP_TEMP_TABLE, SQLITE_DROP_TEMP_VIEW, SQLITE_DROP_VIEW, SQLITE_DETACH, SQLITE_ALTER_TABLE, SQLITE_DROP_VTABLE:
                let observer = unsafeBitCast(observerPointer, StatementCompilationObserver.self)
                observer.invalidatesDatabaseSchemaCache = true
            case SQLITE_READ:
                let observer = unsafeBitCast(observerPointer, StatementCompilationObserver.self)
                observer.sourceTables.insert(String.fromCString(CString1)!)
            case SQLITE_SAVEPOINT:
                let observer = unsafeBitCast(observerPointer, StatementCompilationObserver.self)
                let name = String.fromCString(CString2)!
                let action = SavepointActionKind(rawValue: String.fromCString(CString1)!)!
                observer.savepointAction = (name: name, action: action)
            default:
                break
            }
            return SQLITE_OK
            }, observerPointer)
    }
    
    // Call this method between two calls to calling sqlite3_prepare_v2()
    func reset() {
        sourceTables = []
        invalidatesDatabaseSchemaCache = false
        savepointAction = nil
    }
    
    func stop() {
        sqlite3_set_authorizer(database.sqliteConnection, nil, nil)
    }
}

enum SavepointActionKind : String {
    case Begin = "BEGIN"
    case Release = "RELEASE"
    case Rollback = "ROLLBACK"
}


// =========================================================================
// MARK: - Transactions & Savepoint

extension Database {
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
    /// - parameters:
    ///     - kind: The transaction type (default nil). If nil, the transaction
    ///       type is configuration.defaultTransactionKind, which itself
    ///       defaults to .Immediate. See https://www.sqlite.org/lang_transaction.html
    ///       for more information.
    ///     - block: A block that executes SQL statements and return either
    ///       .Commit or .Rollback.
    /// - throws: The error thrown by the block.
    public func inTransaction(kind: TransactionKind? = nil, @noescape _ block: () throws -> TransactionCompletion) throws {
        // Begin transaction
        try beginTransaction(kind ?? configuration.defaultTransactionKind)
        
        // Now that transaction has begun, we'll rollback in case of error.
        // But we'll throw the first caught error, so that user knows
        // what happened.
        var firstError: ErrorType? = nil
        let needsRollback: Bool
        do {
            let completion = try block()
            switch completion {
            case .Commit:
                try commit()
                needsRollback = false
            case .Rollback:
                needsRollback = true
            }
        } catch {
            firstError = error
            needsRollback = true
        }
        
        if needsRollback {
            do {
                try rollback(underlyingError: firstError)
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
    ///             return .Commit
    ///         }
    ///     }
    ///
    /// If the block throws an error, the savepoint is rollbacked and the
    /// error is rethrown.
    ///
    /// This method is reentrant: you can nest savepoints.
    ///
    /// - parameter block: A block that executes SQL statements and return
    ///   either .Commit or .Rollback.
    /// - throws: The error thrown by the block.
    public func inSavepoint(@noescape block: () throws -> TransactionCompletion) throws {
        // By default, top level SQLite savepoints open a deferred transaction.
        //
        // But GRDB database configuration mandates a default transaction kind
        // that we have to honor.
        //
        // So when the default GRDB transaction kind is not deferred, we wrap
        // open a transaction instead
        guard isInsideTransaction || configuration.defaultTransactionKind == .Deferred else {
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
        var firstError: ErrorType? = nil
        let needsRollback: Bool
        do {
            let completion = try block()
            switch completion {
            case .Commit:
                try execute("RELEASE SAVEPOINT grdb")
                needsRollback = false
            case .Rollback:
                needsRollback = true
            }
        } catch {
            firstError = error
            needsRollback = true
        }
        
        if needsRollback {
            do {
                if topLevelSavepoint {
                    try rollback(underlyingError: firstError)
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
    
    private func beginTransaction(kind: TransactionKind) throws {
        switch kind {
        case .Deferred:
            try execute("BEGIN DEFERRED TRANSACTION")
        case .Immediate:
            try execute("BEGIN IMMEDIATE TRANSACTION")
        case .Exclusive:
            try execute("BEGIN EXCLUSIVE TRANSACTION")
        }
        isInsideExplicitTransaction = true
    }
    
    private func rollback(underlyingError underlyingError: ErrorType? = nil) throws {
        do {
            try execute("ROLLBACK TRANSACTION")
        } catch {
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
            // Rollback and ignore error because we'll throw firstError.
            guard let underlyingError = underlyingError as? DatabaseError where [SQLITE_FULL, SQLITE_IOERR, SQLITE_BUSY, SQLITE_NOMEM].contains(Int32(underlyingError.code)) else {
                throw error
            }
        }
        
        savepointStack.clear()  // TODO: write tests that fail when we remove this line. Hint: those tests must not use any transaction observer because savepointStack.clear() is already called in willCommit() and didRollback()
        isInsideExplicitTransaction = false
    }
    
    private func commit() throws {
        try execute("COMMIT TRANSACTION")
        savepointStack.clear()  // TODO: write tests that fail when we remove this line. Hint: those tests must not use any transaction observer because savepointStack.clear() is already called in willCommit() and didRollback()
        isInsideExplicitTransaction = false
    }
    
    /// Add a transaction observer, so that it gets notified of all
    /// database changes.
    ///
    /// The transaction observer is weakly referenced: it is not retained, and
    /// stops getting notifications after it is deallocated.
    public func addTransactionObserver(transactionObserver: TransactionObserverType) {
        DatabaseScheduler.preconditionValidQueue(self)
        transactionObservers.append(WeakTransactionObserver(transactionObserver))
        if transactionObservers.count == 1 {
            installTransactionObserverHooks()
        }
    }
    
    /// Remove a transaction observer.
    public func removeTransactionObserver(transactionObserver: TransactionObserverType) {
        DatabaseScheduler.preconditionValidQueue(self)
        transactionObservers.removeFirst { $0.observer === transactionObserver }
        if transactionObservers.isEmpty {
            uninstallTransactionObserverHooks()
        }
    }
    
    /// Clears references to deallocated observers, and uninstall transaction
    /// hooks if there is no remaining observers.
    private func cleanupTransactionObservers() {
        transactionObservers = transactionObservers.filter { $0.observer != nil }
        if transactionObservers.isEmpty {
            uninstallTransactionObserverHooks()
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
    static func preconditionValidSelectStatement(sql sql: String, observer: StatementCompilationObserver) {
        GRDBPrecondition(!observer.invalidatesDatabaseSchemaCache, "Invalid statement type for query \(String(reflecting: sql)): use UpdateStatement instead.")
        GRDBPrecondition(observer.savepointAction == nil, "Invalid statement type for query \(String(reflecting: sql)): use UpdateStatement instead.")
    }
    
    /// Some failed statements interest transaction observers.
    func updateStatementDidFail(statement: UpdateStatement) throws {
        // Reset transactionState before didRollback eventually executes
        // other statements.
        let transactionState = self.transactionState
        self.transactionState = .WaitForTransactionCompletion
        
        // Failed statements can not be reused, because sqlite3_reset won't
        // be able to restore the statement to its initial state:
        // https://www.sqlite.org/c3ref/reset.html
        //
        // So make sure we clear this statement from the cache.
        if let index = updateStatementCache.indexOf({ $0.1 === statement }) {
            updateStatementCache.removeAtIndex(index)
        }
        
        switch transactionState {
        case .RollbackFromTransactionObserver(let error):
            didRollback()
            throw error
        default:
            break
        }
    }
    
    /// Some succeeded statements invalidate the database cache, others interest
    /// transaction observers, and others modify the savepoint stack.
    func updateStatementDidExecute(statement: UpdateStatement) {
        if statement.invalidatesDatabaseSchemaCache {
            clearSchemaCache()
        }
        
        if let savepointAction = statement.savepointAction {
            switch savepointAction.action {
            case .Begin:
                savepointStack.beginSavepoint(named: savepointAction.name)
            case .Release:
                savepointStack.releaseSavepoint(named: savepointAction.name)
                if savepointStack.isEmpty {
                    let eventsBuffer = savepointStack.eventsBuffer
                    savepointStack.clear()
                    for observer in transactionObservers.flatMap({ $0.observer }) {
                        for event in eventsBuffer {
                            event.send(to: observer)
                        }
                    }
                }
            case .Rollback:
                savepointStack.rollbackSavepoint(named: savepointAction.name)
            }
        }
        
        // Reset transactionState before didCommit or didRollback eventually
        // execute other statements.
        let transactionState = self.transactionState
        self.transactionState = .WaitForTransactionCompletion
        
        switch transactionState {
        case .Commit:
            didCommit()
        case .Rollback:
            didRollback()
        default:
            break
        }
    }
    
    /// Transaction hook
    private func willCommit() throws {
        let eventsBuffer = savepointStack.eventsBuffer
        savepointStack.clear()
        for observer in transactionObservers.flatMap({ $0.observer }) {
            for event in eventsBuffer {
                event.send(to: observer)
            }
            try observer.databaseWillCommit()
        }
    }
    
#if SQLITE_ENABLE_PREUPDATE_HOOK
    /// Transaction hook
    private func willChangeWithEvent(event: DatabasePreUpdateEvent)
    {
        if savepointStack.isEmpty {
            for observer in transactionObservers.flatMap({ $0.observer }) {
                observer.databaseWillChangeWithEvent(event)
            }
        } else {
            savepointStack.eventsBuffer.append(event.copy())
        }
    }
#endif
    
    /// Transaction hook
    private func didChangeWithEvent(event: DatabaseEvent) {
        if savepointStack.isEmpty {
            for observer in transactionObservers.flatMap({ $0.observer }) {
                observer.databaseDidChangeWithEvent(event)
            }
        } else {
            savepointStack.eventsBuffer.append(event.copy())
        }
    }
    
    /// Transaction hook
    private func didCommit() {
        for observer in transactionObservers.flatMap({ $0.observer }) {
            observer.databaseDidCommit(self)
        }
        cleanupTransactionObservers()
    }
    
    /// Transaction hook
    private func didRollback() {
        savepointStack.clear()
        for observer in transactionObservers.flatMap({ $0.observer }) {
            observer.databaseDidRollback(self)
        }
        cleanupTransactionObservers()
    }
    
    private func installTransactionObserverHooks() {
        let dbPointer = unsafeBitCast(self, UnsafeMutablePointer<Void>.self)
        
        sqlite3_update_hook(sqliteConnection, { (dbPointer, updateKind, databaseNameCString, tableNameCString, rowID) in
            let db = unsafeBitCast(dbPointer, Database.self)
            db.didChangeWithEvent(DatabaseEvent(
                kind: DatabaseEvent.Kind(rawValue: updateKind)!,
                rowID: rowID,
                databaseNameCString: databaseNameCString,
                tableNameCString: tableNameCString))
            }, dbPointer)
        
        
        sqlite3_commit_hook(sqliteConnection, { dbPointer in
            let db = unsafeBitCast(dbPointer, Database.self)
            do {
                try db.willCommit()
                db.transactionState = .Commit
                // Next step: updateStatementDidExecute()
                return 0
            } catch {
                db.transactionState = .RollbackFromTransactionObserver(error)
                // Next step: sqlite3_rollback_hook callback
                return 1
            }
            }, dbPointer)
        
        
        sqlite3_rollback_hook(sqliteConnection, { dbPointer in
            let db = unsafeBitCast(dbPointer, Database.self)
            switch db.transactionState {
            case .RollbackFromTransactionObserver:
                // Next step: updateStatementDidFail()
                break
            default:
                db.transactionState = .Rollback
                // Next step: updateStatementDidExecute()
            }
            }, dbPointer)
        
        #if SQLITE_ENABLE_PREUPDATE_HOOK
        sqlite3_preupdate_hook(sqliteConnection, { (dbPointer, databaseConnection, updateKind, databaseNameCString, tableNameCString, initialRowID, finalRowID) in
            let db = unsafeBitCast(dbPointer, Database.self)
            db.willChangeWithEvent(DatabasePreUpdateEvent(connection: databaseConnection,
                kind: DatabasePreUpdateEvent.Kind(rawValue: updateKind)!,
                initialRowID: initialRowID,
                finalRowID: finalRowID,
                databaseNameCString: databaseNameCString,
                tableNameCString: tableNameCString))
            }, dbPointer)
        #endif
    }
    
    private func uninstallTransactionObserverHooks() {
        sqlite3_update_hook(sqliteConnection, nil, nil)
        sqlite3_commit_hook(sqliteConnection, nil, nil)
        sqlite3_rollback_hook(sqliteConnection, nil, nil)
        #if SQLITE_ENABLE_PREUPDATE_HOOK
            sqlite3_preupdate_hook(sqliteConnection, nil, nil)
        #endif
    }
}


/// An SQLite transaction kind. See https://www.sqlite.org/lang_transaction.html
public enum TransactionKind {
    case Deferred
    case Immediate
    case Exclusive
}


/// The end of a transaction: Commit, or Rollback
public enum TransactionCompletion {
    case Commit
    case Rollback
}

/// The states that keep track of transaction completions in order to notify
/// transaction observers.
private enum TransactionState {
    case WaitForTransactionCompletion
    case Commit
    case Rollback
    case RollbackFromTransactionObserver(ErrorType)
}

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
    /// The event is only valid for the duration of this method call. If you
    /// need to keep it longer, store a copy of its properties.
    ///
    /// - warning: this method must not change the database.
    func databaseDidChangeWithEvent(event: DatabaseEvent)
    
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
    func databaseDidCommit(db: Database)
    
    /// Database changes have been rollbacked.
    ///
    /// This method is called on the database queue. It can change the database.
    func databaseDidRollback(db: Database)
    
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
    func databaseWillChangeWithEvent(event: DatabasePreUpdateEvent)
    #endif
}

/// Database stores WeakTransactionObserver so that it does not retain its
/// transaction observers.
class WeakTransactionObserver {
    weak var observer: TransactionObserverType?
    init(_ observer: TransactionObserverType) {
        self.observer = observer
    }
}

protocol DatabaseEventType {
    func send(to observer: TransactionObserverType)
}

/// A database event, notified to TransactionObserverType.
public struct DatabaseEvent {
    
    /// An event kind
    public enum Kind: Int32 {
        /// SQLITE_INSERT
        case Insert = 18
        
        /// SQLITE_DELETE
        case Delete = 9
        
        /// SQLITE_UPDATE
        case Update = 23
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
    ///     class MyObserver: TransactionObserverType {
    ///         var events: [DatabaseEvent]
    ///         func databaseDidChangeWithEvent(event: DatabaseEvent) {
    ///             events.append(event.copy())
    ///         }
    ///     }
    public func copy() -> DatabaseEvent {
        return impl.copy(self)
    }
    
    private init(kind: Kind, rowID: Int64, impl: DatabaseEventImpl) {
        self.kind = kind
        self.rowID = rowID
        self.impl = impl
    }
    
    init(kind: Kind, rowID: Int64, databaseNameCString: UnsafePointer<Int8>, tableNameCString: UnsafePointer<Int8>) {
        self.init(kind: kind, rowID: rowID, impl: MetalDatabaseEventImpl(databaseNameCString: databaseNameCString, tableNameCString: tableNameCString))
    }
    
    private let impl: DatabaseEventImpl
}

extension DatabaseEvent : DatabaseEventType {
    func send(to observer: TransactionObserverType) {
        observer.databaseDidChangeWithEvent(self)
    }
}

/// Protocol for internal implementation of DatabaseEvent
private protocol DatabaseEventImpl {
    var databaseName: String { get }
    var tableName: String { get }
    func copy(event: DatabaseEvent) -> DatabaseEvent
}

/// Optimization: MetalDatabaseEventImpl does not create Swift strings from raw
/// SQLite char* until actually asked for databaseName or tableName.
private struct MetalDatabaseEventImpl : DatabaseEventImpl {
    let databaseNameCString: UnsafePointer<Int8>
    let tableNameCString: UnsafePointer<Int8>

    var databaseName: String { return String.fromCString(databaseNameCString)! }
    var tableName: String { return String.fromCString(tableNameCString)! }
    func copy(event: DatabaseEvent) -> DatabaseEvent {
        return DatabaseEvent(kind: event.kind, rowID: event.rowID, impl: CopiedDatabaseEventImpl(databaseName: databaseName, tableName: tableName))
    }
}

/// Impl for DatabaseEvent that contains copies of event strings.
private struct CopiedDatabaseEventImpl : DatabaseEventImpl {
    private let databaseName: String
    private let tableName: String
    func copy(event: DatabaseEvent) -> DatabaseEvent {
        return event
    }
}

#if SQLITE_ENABLE_PREUPDATE_HOOK

    public struct DatabasePreUpdateEvent {
        
        /// An event kind
        public enum Kind: Int32 {
            /// SQLITE_INSERT
            case Insert = 18
            
            /// SQLITE_DELETE
            case Delete = 9
            
            /// SQLITE_UPDATE
            case Update = 23
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
        public var initialDatabaseValues: [DatabaseValue]?
        {
            guard (kind == .Update || kind == .Delete) else { return nil }
            return impl.initialDatabaseValues
        }
        
        /// Returns the initial `DatabaseValue` at given index.
        ///
        /// Indexes span from 0 for the leftmost column to (row.count - 1) for the
        /// righmost column.
        ///
        /// The result is nil if the event is an .Insert event.
        @warn_unused_result
        public func initialDatabaseValue(atIndex index: Int) -> DatabaseValue?
        {
            GRDBPrecondition(index >= 0 && index < count, "row index out of range")
            guard (kind == .Update || kind == .Delete) else { return nil }
            return impl.initialDatabaseValue(atIndex: index)
        }
        
        /// The final database values in the row.
        ///
        /// Values appear in the same order as the columns in the table.
        ///
        /// The result is nil if the event is a .Delete event.
        public var finalDatabaseValues: [DatabaseValue]?
        {
            guard (kind == .Update || kind == .Insert) else { return nil }
            return impl.finalDatabaseValues
        }
        
        /// Returns the final `DatabaseValue` at given index.
        ///
        /// Indexes span from 0 for the leftmost column to (row.count - 1) for the
        /// righmost column.
        ///
        /// The result is nil if the event is a .Delete event.
        @warn_unused_result
        public func finalDatabaseValue(atIndex index: Int) -> DatabaseValue?
        {
            GRDBPrecondition(index >= 0 && index < count, "row index out of range")
            guard (kind == .Update || kind == .Insert) else { return nil }
            return impl.finalDatabaseValue(atIndex: index)
        }
        
        /// Returns an event that can be stored:
        ///
        ///     class MyObserver: TransactionObserverType {
        ///         var pre_events: [DatabasePreUpdateEvent]
        ///         func databaseWillChangeWithEvent(event: DatabasePreUpdateEvent) {
        ///             pre_events.append(event.copy())
        ///         }
        ///     }
        public func copy() -> DatabasePreUpdateEvent {
            return impl.copy(self)
        }
        
        private init(kind: Kind, initialRowID: Int64?, finalRowID: Int64?, impl: DatabasePreUpdateEventImpl) {
            self.kind = kind
            self.initialRowID = (kind == .Update || kind == .Delete ) ? initialRowID : nil
            self.finalRowID = (kind == .Update || kind == .Insert ) ? finalRowID : nil
            self.impl = impl
        }
        
        init(connection: SQLiteConnection, kind: Kind, initialRowID: Int64, finalRowID: Int64, databaseNameCString: UnsafePointer<Int8>, tableNameCString: UnsafePointer<Int8>) {
            self.init(kind: kind,
                      initialRowID: (kind == .Update || kind == .Delete ) ? finalRowID : nil,
                      finalRowID: (kind == .Update || kind == .Insert ) ? finalRowID : nil,
                      impl: MetalDatabasePreUpdateEventImpl(connection: connection, kind: kind, databaseNameCString: databaseNameCString, tableNameCString: tableNameCString))
        }
        
        private let impl: DatabasePreUpdateEventImpl
    }
    
    extension DatabasePreUpdateEvent : DatabaseEventType {
        func send(to observer: TransactionObserverType) {
            observer.databaseWillChangeWithEvent(self)
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
        
        func copy(event: DatabasePreUpdateEvent) -> DatabasePreUpdateEvent
    }
    
    /// Optimization: MetalDatabasePreUpdateEventImpl does not create Swift strings from raw
    /// SQLite char* until actually asked for databaseName or tableName,
    /// nor does it request other data via the sqlite3_preupdate_* APIs
    /// until asked.
    private struct MetalDatabasePreUpdateEventImpl : DatabasePreUpdateEventImpl {
        private let connection: SQLiteConnection
        private let kind: DatabasePreUpdateEvent.Kind
        
        private let databaseNameCString: UnsafePointer<Int8>
        private let tableNameCString: UnsafePointer<Int8>
        
        var databaseName: String { return String.fromCString(databaseNameCString)! }
        var tableName: String { return String.fromCString(tableNameCString)! }
        
        var columnsCount: CInt { return sqlite3_preupdate_count(connection) }
        var depth: CInt { return sqlite3_preupdate_depth(connection) }
        var initialDatabaseValues: [DatabaseValue]? {
            guard (kind == .Update || kind == .Delete) else { return nil }
            return preupdate_getValues_old(connection)
        }
        
        var finalDatabaseValues: [DatabaseValue]? {
            guard (kind == .Update || kind == .Insert) else { return nil }
            return preupdate_getValues_new(connection)
        }
        
        func initialDatabaseValue(atIndex index: Int) -> DatabaseValue?
        {
            let columnCount = columnsCount
            precondition(index >= 0 && index < Int(columnCount), "row index out of range")
            return getValue(connection, column: CInt(index), sqlite_func: { (connection: SQLiteConnection, column: CInt, inout value: SQLiteValue ) -> CInt in
                return sqlite3_preupdate_old(connection, column, &value)
            })
        }
        
        func finalDatabaseValue(atIndex index: Int) -> DatabaseValue?
        {
            let columnCount = columnsCount
            precondition(index >= 0 && index < Int(columnCount), "row index out of range")
            return getValue(connection, column: CInt(index), sqlite_func: { (connection: SQLiteConnection, column: CInt, inout value: SQLiteValue ) -> CInt in
                return sqlite3_preupdate_new(connection, column, &value)
            })
        }
        
        func copy(event: DatabasePreUpdateEvent) -> DatabasePreUpdateEvent {
            return DatabasePreUpdateEvent(kind: event.kind, initialRowID: event.initialRowID, finalRowID: event.finalRowID, impl: CopiedDatabasePreUpdateEventImpl(
                    databaseName: databaseName,
                    tableName: tableName,
                    columnsCount: columnsCount,
                    depth: depth,
                    initialDatabaseValues: initialDatabaseValues,
                    finalDatabaseValues: finalDatabaseValues))
        }
    
        private func preupdate_getValues(connection: SQLiteConnection, sqlite_func: (connection: SQLiteConnection, column: CInt, inout value: SQLiteValue ) -> CInt ) -> [DatabaseValue]?
        {
            let columnCount = sqlite3_preupdate_count(connection)
            guard columnCount > 0 else { return nil }
            
            var columnValues = [DatabaseValue]()
            
            for i in 0..<columnCount {
                let value = getValue(connection, column: i, sqlite_func: sqlite_func)!
                columnValues.append(value)
            }
            
            return columnValues
        }
        
        private func getValue(connection: SQLiteConnection, column: CInt, sqlite_func: (connection: SQLiteConnection, column: CInt, inout value: SQLiteValue ) -> CInt ) -> DatabaseValue?
        {
            var value : SQLiteValue = nil
            guard sqlite_func(connection: connection, column: column, value: &value) == SQLITE_OK else { return nil }
            guard value != nil else { return nil }
            return DatabaseValue(sqliteValue: value)
        }
        
        private func preupdate_getValues_old(connection: SQLiteConnection) -> [DatabaseValue]?
        {
            return preupdate_getValues(connection, sqlite_func: { (connection: SQLiteConnection, column: CInt, inout value: SQLiteValue ) -> CInt in
                return sqlite3_preupdate_old(connection, column, &value)
            })
        }
        
        private func preupdate_getValues_new(connection: SQLiteConnection) -> [DatabaseValue]?
        {
            return preupdate_getValues(connection, sqlite_func: { (connection: SQLiteConnection, column: CInt, inout value: SQLiteValue ) -> CInt in
                return sqlite3_preupdate_new(connection, column, &value)
            })
        }
    }
    
    /// Impl for DatabasePreUpdateEvent that contains copies of all event data.
    private struct CopiedDatabasePreUpdateEventImpl : DatabasePreUpdateEventImpl {
        private let databaseName: String
        private let tableName: String
        private let columnsCount: CInt
        private let depth: CInt
        private let initialDatabaseValues: [DatabaseValue]?
        private let finalDatabaseValues: [DatabaseValue]?
        
        private func initialDatabaseValue(atIndex index: Int) -> DatabaseValue? { return initialDatabaseValues?[index] }
        private func finalDatabaseValue(atIndex index: Int) -> DatabaseValue? { return finalDatabaseValues?[index] }
        
        private func copy(event: DatabasePreUpdateEvent) -> DatabasePreUpdateEvent {
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
class SavePointStack {
    /// The buffered events. See Database.didChangeWithEvent()
    var eventsBuffer: [DatabaseEventType] = []
    
    /// The savepoint stack, as an array of tuples (savepointName, index in the eventsBuffer array).
    /// Indexes let us drop rollbacked events from the event buffer.
    private var savepoints: [(name: String, index: Int)] = []
    
    var isEmpty: Bool { return savepoints.isEmpty }
    
    func clear() {
        eventsBuffer.removeAll()
        savepoints.removeAll()
    }
    
    func beginSavepoint(named name: String) {
        savepoints.append((name: name.lowercaseString, index: eventsBuffer.count))
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
        let name = name.lowercaseString
        while let pair = savepoints.last where pair.name != name {
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
        let name = name.lowercaseString
        while let pair = savepoints.last where pair.name != name {
            savepoints.removeLast()
        }
        if !savepoints.isEmpty {
            savepoints.removeLast()
        }
    }
}
