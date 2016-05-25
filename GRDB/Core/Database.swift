import Foundation

#if !SQLITE_HAS_CODEC
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
    
    // MARK: - Database Information
    
    /// The database configuration
    public let configuration: Configuration
    
    /// The raw SQLite connection, suitable for the SQLite C API.
    public let sqliteConnection: SQLiteConnection
    
    /// The rowID of the most recent successful INSERT.
    ///
    /// If no successful INSERT has ever occurred on the database connection,
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
    
    /// True if the database connection is currently in a transaction.
    public private(set) var isInsideTransaction: Bool = false
    
    var lastErrorCode: Int32 {
        return sqlite3_errcode(sqliteConnection)
    }
    
    var lastErrorMessage: String? {
        return String.fromCString(sqlite3_errmsg(sqliteConnection))
    }
    
    private var functions = Set<DatabaseFunction>()
    private var collations = Set<DatabaseCollation>()
    
    var schemaCache: DatabaseSchemaCacheType    // internal so that it can be tested
    private var selectStatementCache: [String: SelectStatement] = [:]
    private var updateStatementCache: [String: UpdateStatement] = [:]
    
    /// See setupTransactionHooks(), updateStatementDidFail(), updateStatementDidExecute()
    private var transactionState: TransactionState = .WaitForTransactionCompletion
    
    /// The transaction observers
    private var transactionObservers = [WeakTransactionObserver]()
    
    /// See setupBusyMode()
    private var busyCallback: BusyCallback?
    
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
    
    private var isClosed: Bool = false
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
        // Add support for Swift String functions.
        //
        // Those functions are used by query's interface:
        //
        ///     let nameColumn = SQLColumn("name")
        ///     let request = Person.select(nameColumn.capitalizedString)
        ///     let names = String.fetchAll(dbQueue, request)   // [String]
        
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
        // Add support for Swift String comparison functions.
        //
        // Those collations are readily available when creating tables:
        //
        //      let collationName = DatabaseCollation.localizedCaseInsensitiveCompare.name
        //      dbQueue.execute(
        //          "CREATE TABLE persons (" +
        //              "name TEXT COLLATE \(collationName)" +
        //          ")"
        //      )
        
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
        let code = sqlite3_close_v2(sqliteConnection)
        if code != SQLITE_OK {
            let message = String.fromCString(sqlite3_errmsg(sqliteConnection))
            NSLog("%@", "GRDB could not close database with error \(code): \(message ?? "")")
        }
    } else {
        let code = sqlite3_close(sqliteConnection)
        if code != SQLITE_OK {
            let message = String.fromCString(sqlite3_errmsg(sqliteConnection))
            NSLog("%@", "GRDB could not close database with error \(code): \(message ?? "")")
            var stmt: SQLiteStatement = sqlite3_next_stmt(sqliteConnection, nil)
            while stmt != nil {
                NSLog("%@", "GRDB unfinalised statement: \(String.fromCString(sqlite3_sql(stmt))!)")
                stmt = sqlite3_next_stmt(sqliteConnection, stmt)
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
    /// This method may throw a DatabaseError.
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
        // authorization callbacks in order to observe schema changes.
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
                
                let sqlData = NSData(bytesNoCopy: UnsafeMutablePointer<Void>(statementStart), length: statementEnd - statementStart, freeWhenDone: false)
                let sql = String(data: sqlData, encoding: NSUTF8StringEncoding)!.stringByTrimmingCharactersInSet(.whitespaceAndNewlineCharacterSet())
                guard !sql.isEmpty else {
                    break
                }
                
                do {
                    let statement = UpdateStatement(database: self, sqliteStatement: sqliteStatement, invalidatesDatabaseSchemaCache: observer.invalidatesDatabaseSchemaCache)
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

protocol DatabaseSchemaCacheType {
    mutating func clear()
    
    func primaryKey(tableName tableName: String) -> PrimaryKey?
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

/// A primary key
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
    
    /// The columns in the primary key. Can not be empty.
    public var columns: [String] {
        switch impl {
        case .RowID(let column):
            return [column]
        case .Regular(let columns):
            return columns
        }
    }
    
    /// The name of the INTEGER PRIMARY KEY
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

// A class that uses sqlite3_set_authorizer to fetch information about a statement.
final class StatementCompilationObserver {
    let database: Database
    var sourceTables: Set<String> = []
    var invalidatesDatabaseSchemaCache = false
    
    init(_ database: Database) {
        self.database = database
    }
    
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
            default:
                break
            }
            return SQLITE_OK
            }, observerPointer)
    }
    
    func stop() {
        sqlite3_set_authorizer(database.sqliteConnection, nil, nil)
    }
    
    func reset() {
        sourceTables = []
        invalidatesDatabaseSchemaCache = false
    }
}


// =========================================================================
// MARK: - Transactions

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
        
        // Now that transcation is open, we'll rollback in case of error.
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
            if let firstError = firstError {
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
                do {
                    try rollback()
                } catch {
                    if let error = firstError as? DatabaseError where [SQLITE_FULL, SQLITE_IOERR, SQLITE_BUSY, SQLITE_NOMEM].contains(Int32(error.code)) {
                        isInsideTransaction = false
                    }
                }
            } else {
                try rollback()
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
        isInsideTransaction = true
    }
    
    private func rollback() throws {
        try execute("ROLLBACK TRANSACTION")
        isInsideTransaction = false
    }
    
    private func commit() throws {
        try execute("COMMIT TRANSACTION")
        isInsideTransaction = false
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
    
    private func cleanupTransactionObservers() {
        transactionObservers = transactionObservers.filter { $0.observer != nil }
        if transactionObservers.isEmpty {
            uninstallTransactionObserverHooks()
        }
    }
    
    func updateStatementDidFail() throws {
        // Reset transactionState before didRollback eventually executes
        // other statements.
        let transactionState = self.transactionState
        self.transactionState = .WaitForTransactionCompletion
        
        switch transactionState {
        case .RollbackFromTransactionObserver(let error):
            didRollback()
            throw error
        default:
            break
        }
    }
    
    func updateStatementDidExecute(statement: UpdateStatement) {
        if statement.invalidatesDatabaseSchemaCache {
            clearSchemaCache()
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
    
    private func willCommit() throws {
        for observer in transactionObservers.flatMap({ $0.observer }) {
            try observer.databaseWillCommit()
        }
    }
    
    private func didChangeWithEvent(event: DatabaseEvent) {
        for observer in transactionObservers.flatMap({ $0.observer }) {
            observer.databaseDidChangeWithEvent(event)
        }
    }
    
    private func didCommit() {
        for observer in transactionObservers.flatMap({ $0.observer }) {
            observer.databaseDidCommit(self)
        }
        cleanupTransactionObservers()
    }
    
    private func didRollback() {
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
                databaseNameCString: databaseNameCString,
                tableNameCString: tableNameCString,
                kind: DatabaseEvent.Kind(rawValue: updateKind)!,
                rowID: rowID))
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
    }
    
    private func uninstallTransactionObserverHooks() {
        sqlite3_update_hook(sqliteConnection, nil, nil)
        sqlite3_commit_hook(sqliteConnection, nil, nil)
        sqlite3_rollback_hook(sqliteConnection, nil, nil)
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
}

class WeakTransactionObserver {
    weak var observer: TransactionObserverType?
    init(_ observer: TransactionObserverType) {
        self.observer = observer
    }
}


/// A database event, notified to TransactionObserverType.
///
/// See https://www.sqlite.org/c3ref/update_hook.html for more information.
public struct DatabaseEvent {
    private let databaseNameCString: UnsafePointer<Int8>
    private let tableNameCString: UnsafePointer<Int8>
    
    /// An event kind
    public enum Kind: Int32 {
        case Insert = 18    // SQLITE_INSERT
        case Delete = 9     // SQLITE_DELETE
        case Update = 23    // SQLITE_UPDATE
    }
    
    /// The event kind
    public let kind: Kind
    
    /// The database name
    public var databaseName: String { return String.fromCString(databaseNameCString)! }

    /// The table name
    public var tableName: String { return String.fromCString(tableNameCString)! }
    
    /// The rowID of the changed row.
    public let rowID: Int64
}
