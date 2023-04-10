import Foundation

/// A raw SQLite statement, suitable for the SQLite C API.
public typealias SQLiteStatement = OpaquePointer

extension String {
    /// SQL statements are separated by semicolons and white spaces.
    ///
    /// This character set is not an accurate representation of actual SQLite
    /// separators (which do not include non-ASCII white spaces for example),
    /// and must not be used for parsing. Its only purpose is to trim compiled
    /// SQL statements with `String.trimmedSQLStatement`.
    private static let sqlStatementSeparators = CharacterSet(charactersIn: ";").union(.whitespacesAndNewlines)
    
    /// Returns a string trimmed from SQL statement separators.
    ///
    /// For example:
    ///
    ///     // "SELECT * FROM player"
    ///     " SELECT * FROM player;".trimmedSQLStatement
    ///
    /// - precondition: the input string is a successfully compiled SQL statement.
    var trimmedSQLStatement: String {
        trimmingCharacters(in: String.sqlStatementSeparators)
    }
}

public final class Statement {
    enum TransactionEffect {
        case beginTransaction
        case commitTransaction
        case rollbackTransaction
        case beginSavepoint(String)
        case releaseSavepoint(String)
        case rollbackSavepoint(String)
    }
    
    /// The raw SQLite statement, suitable for the SQLite C API.
    public let sqliteStatement: SQLiteStatement
    
    /// The SQL query.
    public var sql: String {
        SchedulingWatchdog.preconditionValidQueue(database)
        
        // trim white space and semicolumn for homogeneous output
        return String(cString: sqlite3_sql(sqliteStatement)).trimmedSQLStatement
    }
    
    /// The column names, ordered from left to right.
    public lazy var columnNames: [String] = {
        let sqliteStatement = self.sqliteStatement
        return (0..<CInt(self.columnCount)).map { String(cString: sqlite3_column_name(sqliteStatement, $0)) }
    }()
    
    // The database region is reported by `sqlite3_set_authorizer`, and maybe
    // refined in `SQLQueryGenerator.makeStatement(_:)` when we have enough
    // information about the statement.
    /// The database region that the statement looks into.
    ///
    /// The returned region describes the tables and columns read by
    /// the statement. It does not describe the columns that the statement
    /// writes into. For example:
    ///
    /// ```swift
    /// // Reads score, writes bonus
    /// let statement = db.makeStatement(sql: """
    ///     UPDATE player SET bonus = 0 WHERE score = 0
    ///     """)
    ///
    /// // Prints "player(score)"
    /// print(statement.databaseRegion)
    /// ```
    public internal(set) var databaseRegion = DatabaseRegion()
    
    /// If true, the database schema cache gets invalidated after this statement
    /// is executed (reported by `sqlite3_set_authorizer`).
    private(set) var invalidatesDatabaseSchemaCache = false
    
    /// The eventual effect of transactions, as reported by `sqlite3_set_authorizer`.
    private(set) var transactionEffect: TransactionEffect?
    
    /// The effects on the database (reported by `sqlite3_set_authorizer`).
    private(set) var authorizerEventKinds: [DatabaseEventKind] = []
    
    /// A boolean value indicating if the prepared statement makes no direct
    /// changes to the content of the database file.
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/c3ref/stmt_readonly.html>.
    public var isReadonly: Bool {
        sqlite3_stmt_readonly(sqliteStatement) != 0
    }
    
    /// A boolean value indicating if the statement deletes some rows.
    var isDeleteStatement: Bool {
        authorizerEventKinds.contains(where: \.isDelete)
    }
    
    @usableFromInline
    unowned let database: Database
    
    /// Cache for index(ofColumn:). Keys are lowercase.
    private lazy var columnIndexes: [String: Int] = {
        Dictionary(
            self.columnNames.enumerated().map { ($0.element.lowercased(), $0.offset) },
            uniquingKeysWith: { (left, _) in left }) // keep leftmost indexes
    }()
    
    /// Creates a prepared statement. Returns nil if the compiled string is
    /// blank or empty.
    ///
    /// - parameter database: A database connection.
    /// - parameter statementStart: A pointer to a UTF-8 encoded C string
    ///   containing SQL.
    /// - parameter statementEnd: Upon success, the pointer to the next
    ///   statement in the C string.
    /// - parameter prepFlags: Flags for sqlite3_prepare_v3 (available from
    ///   SQLite 3.20.0, see <http://www.sqlite.org/c3ref/prepare.html>)
    /// - throws: DatabaseError in case of compilation error.
    required init?(
        database: Database,
        statementStart: UnsafePointer<Int8>,
        statementEnd: UnsafeMutablePointer<UnsafePointer<Int8>?>,
        prepFlags: CUnsignedInt) throws
    {
        SchedulingWatchdog.preconditionValidQueue(database)
        
        // Reset authorizer before preparing the statement
        let authorizer = database.authorizer
        authorizer.reset()
        
        var sqliteStatement: SQLiteStatement? = nil
        let code: CInt
        // sqlite3_prepare_v3 was introduced in SQLite 3.20.0 http://www.sqlite.org/changes.html#version_3_20
#if GRDBCUSTOMSQLITE || GRDBCIPHER
        code = sqlite3_prepare_v3(
            database.sqliteConnection, statementStart, -1, prepFlags,
            &sqliteStatement, statementEnd)
#else
        if #available(iOS 12, macOS 10.14, tvOS 12, watchOS 5, *) { // SQLite 3.20+
            code = sqlite3_prepare_v3(
                database.sqliteConnection, statementStart, -1, prepFlags,
                &sqliteStatement, statementEnd)
        } else {
            code = sqlite3_prepare_v2(database.sqliteConnection, statementStart, -1, &sqliteStatement, statementEnd)
        }
#endif
        
        guard code == SQLITE_OK else {
            throw DatabaseError(
                resultCode: code,
                message: database.lastErrorMessage,
                sql: String(cString: statementStart))
        }
        
        guard let sqliteStatement else {
            return nil
        }
        
        self.database = database
        self.sqliteStatement = sqliteStatement
        self.databaseRegion = authorizer.selectedRegion
        self.invalidatesDatabaseSchemaCache = authorizer.invalidatesDatabaseSchemaCache
        self.transactionEffect = authorizer.transactionEffect
        self.authorizerEventKinds = authorizer.databaseEventKinds
    }
    
    deinit {
        sqlite3_finalize(sqliteStatement)
    }
    
    // MARK: Arguments
    
    /// Whether arguments are valid and bound inside the SQLite statement.
    ///
    /// If true, arguments are considered valid, and they are bound in
    /// the SQLite statement:
    ///
    /// - **Valid**: Arguments match the statement expectations, or the user has
    ///   called ``setUncheckedArguments(_:)``.
    /// - **Bound**: The SQLite bindings are set. String and blob arguments
    ///   are bound with SQLITE_TRANSIENT (copied and managed by SQLite).
    ///
    /// When false, arguments have not been validated yet, or they are
    /// not bound.
    ///
    /// - Not validated yet: this is the initial default (non-validated
    ///   empty arguments)
    ///
    ///     ```swift
    ///     // Default arguments are empty, argumentsAreValidAndBound is
    ///     // false. The statement needs one argument.
    ///     let statement = try db.makeStatement(sql: """
    ///         INSERT INTO t VALUES (?)
    ///         """)
    ///
    ///     // Because argumentsAreValidAndBound is false, we validate the
    ///     // empty arguments, and throw SQLITE_MISUSE: wrong number
    ///     // of statement arguments.
    ///     try statement.execute()
    ///     ```
    ///
    /// - Not bound: this is the case after we have performed an optimized
    ///   execution with temporary bindings that avoid copying strings
    ///   and blobs:
    ///
    ///     ```swift
    ///     let statement = try db.makeStatement(sql: """
    ///         INSERT INTO t VALUES (?)
    ///         """)
    ///     // Arguments are set, and execution is performed with
    ///     // temporary bindings.
    ///     try statement.execute(arguments: ["Hello"])
    ///     // <- Here statement.arguments is ["Hello"]
    ///     // <- Here statement.argumentsAreValidAndBound is false
    ///     ```
    ///
    ///     See `withArguments(_:do:)`.
    private var argumentsAreValidAndBound = false
    
    /// The statement arguments. They may be bound, or not, in the SQLite
    /// statement. See `argumentsAreValidAndBound`.
    private var _arguments = StatementArguments()
    
    lazy var sqliteArgumentCount: Int = {
        Int(sqlite3_bind_parameter_count(self.sqliteStatement))
    }()
    
    // Returns ["id", nil, "name"] for "INSERT INTO table VALUES (:id, ?, :name)"
    fileprivate lazy var sqliteArgumentNames: [String?] = {
        (1..<CInt(sqliteArgumentCount + 1)).map {
            guard let cString = sqlite3_bind_parameter_name(sqliteStatement, $0) else {
                return nil
            }
            return String(cString: cString + 1) // Drop initial ":", "@", "$"
        }
    }()
    
    /// The statement arguments.
    ///
    /// For example:
    ///
    /// ```swift
    /// // This statement expects two arguments
    /// let statement = try db.makeUpdateArgument(sql: """
    ///     INSERT INTO player (id, name) VALUES (?, ?)
    ///     """)
    ///
    /// // Set arguments
    /// statement.arguments = [1, "Arthur"]
    ///
    /// // Prints [1, "Arthur"]
    /// print(statement.arguments)
    /// ```
    ///
    /// If is a programmer error to set arguments that do not provide all
    /// values expected by the statement:
    ///
    /// ```swift
    /// // Fatal error
    /// statement.arguments = [1]
    /// statement.arguments = [1, "Arthur", Date()]
    /// ```
    ///
    /// Prefer ``setArguments(_:)`` when you are not sure that
    /// arguments match, because it throws an error instead of raising a
    /// fatal error.
    public var arguments: StatementArguments {
        get { _arguments }
        set {
            // Force arguments validity: it is a programmer error to provide
            // arguments that do not match the statement.
            try! setArguments(newValue)
        }
    }
    
    /// Throws a ``DatabaseError`` of code `SQLITE_ERROR` if the provided
    /// arguments do not provide all values expected by the statement.
    ///
    /// For example:
    ///
    /// ```swift
    /// // This statement expects two arguments
    /// let statement = try db.makeUpdateArgument(sql: """
    ///     INSERT INTO player (id, name) VALUES (?, ?)
    ///     """)
    ///
    /// // OK
    /// statement.validateArguments([1, "Arthur"])
    ///
    /// // Throws
    /// try statement.setArguments([1])
    /// try statement.setArguments([1, "Arthur", Date()])
    /// ```
    ///
    /// See also ``setArguments(_:)``.
    ///
    /// - throws: A ``DatabaseError`` if `arguments` don't fit the expected ones.
    public func validateArguments(_ arguments: StatementArguments) throws {
        var arguments = arguments
        _ = try arguments.extractBindings(forStatement: self, allowingRemainingValues: false)
    }
    
    /// Set arguments without any validation. Trades safety for performance.
    ///
    /// Only call this method if you are sure input arguments provide all
    /// values expected by the statement.
    ///
    /// For example:
    ///
    /// ```swift
    /// // This statement expects two arguments
    /// let statement = try db.makeUpdateArgument(sql: """
    ///     INSERT INTO player (id, name) VALUES (?, ?)
    ///     """)
    ///
    /// // OK
    /// statement.setUncheckedArguments([1, "Arthur"])
    ///
    /// // OK
    /// let arguments = ... // some untrusted arguments
    /// try statement.validateArguments(arguments)
    /// statement.setUncheckedArguments(arguments)
    ///
    /// // NOT OK
    /// statement.setUncheckedArguments([1])
    /// statement.setUncheckedArguments([1, "Arthur", Date()])
    /// ```
    public func setUncheckedArguments(_ arguments: StatementArguments) {
        // Reset and bind arguments
        try! reset()
        _arguments = arguments
        argumentsAreValidAndBound = true
        clearBindings()
        
        var valuesIterator = arguments.values.makeIterator()
        for (index, argumentName) in zip(CInt(1)..., sqliteArgumentNames) {
            if let argumentName, let value = arguments.namedValues[argumentName] {
                bind(value, at: index)
            } else if let value = valuesIterator.next() {
                bind(value, at: index)
            }
        }
    }
    
    /// Validates and sets the statement arguments.
    ///
    /// This method throws a ``DatabaseError`` of code `SQLITE_MISUSE` if
    /// the provided arguments do not provide all values expected by
    /// the statement.
    ///
    /// For example:
    ///
    /// ```swift
    /// // This statement expects two arguments
    /// let statement = try db.makeUpdateArgument(sql: """
    ///     INSERT INTO player (id, name) VALUES (?, ?)
    ///     """)
    ///
    /// // OK
    /// try statement.setArguments([1, "Arthur"])
    ///
    /// // Throws
    /// try statement.setArguments([1])
    /// try statement.setArguments([1, "Arthur", Date()])
    /// ```
    ///
    /// - throws: A ``DatabaseError`` if `arguments` don't fit the expected ones.
    public func setArguments(_ arguments: StatementArguments) throws {
        // Validate
        var consumedArguments = arguments
        let bindings = try consumedArguments.extractBindings(forStatement: self, allowingRemainingValues: false)
        
        // Reset and bind arguments
        try reset()
        _arguments = arguments
        argumentsAreValidAndBound = true
        clearBindings()
        
        for (index, dbValue) in zip(CInt(1)..., bindings) {
            bind(dbValue, at: index)
        }
    }
    
    /// Resets, sets arguments, and calls the given closure after performing
    /// temporary bindings that avoid copying strings and blobs.
    ///
    /// The bindings are valid only during the execution of this method.
    /// After it returns, the SQLite statement bindings are cleared (but the
    /// statement arguments are set).
    func withArguments<T>(_ arguments: StatementArguments, do body: () throws -> T) throws -> T {
        // Validate
        var consumedArguments = arguments
        let bindings = try consumedArguments.extractBindings(forStatement: self, allowingRemainingValues: false)
        
        // Reset and bind arguments (temporarily)
        try reset()
        _arguments = arguments
        argumentsAreValidAndBound = false
        clearBindings()
        
        defer {
            // Don't leave the SQLite statement in an invalid state
            // (temporary bindings that point to undefined memory).
            clearBindings()
        }
        
        return try withBindings(bindings, to: sqliteStatement, do: body)
    }
    
    // 1-based index
    func bind(_ value: some StatementBinding, at index: CInt) {
        let code = value.bind(to: sqliteStatement, at: index)
        
        // It looks like sqlite3_bind_xxx() functions do not access the file system.
        // They should thus succeed, unless a GRDB bug: there is no point throwing any error.
        guard code == SQLITE_OK else {
            fatalError(DatabaseError(resultCode: code, message: database.lastErrorMessage, sql: sql))
        }
    }
    
    // Don't make this one public unless we keep the arguments property in sync.
    func clearBindings() {
        // It looks like sqlite3_clear_bindings() does not access the file system.
        // This function call should thus succeed, unless a GRDB bug: there is
        // no point throwing any error.
        let code = sqlite3_clear_bindings(sqliteStatement)
        guard code == SQLITE_OK else {
            fatalError(DatabaseError(resultCode: code, message: database.lastErrorMessage, sql: sql))
        }
    }
    
    // MARK: Execution
    
    func reset() throws {
        SchedulingWatchdog.preconditionValidQueue(database)
        let code = sqlite3_reset(sqliteStatement)
        guard code == SQLITE_OK else {
            throw DatabaseError(resultCode: code, message: database.lastErrorMessage, sql: sql)
        }
    }
    
    /// Convenience method that resets, sets arguments if needed, and checks
    /// arguments validity.
    ///
    /// - parameter newArguments: if not nil, this method sets arguments.
    func prepareExecution(withArguments newArguments: StatementArguments? = nil) throws {
        if let newArguments {
            try setArguments(newArguments) // calls reset()
            return
        }
        
        if argumentsAreValidAndBound {
            try reset()
        } else {
            // Arguments needs to be validated, or bound.
            if arguments.isEmpty {
                // Only reset and perform validation.
                try reset()
                try validateArguments(arguments)
            } else {
                // The `setArguments` method binds and validates, and that's
                // exactly what we want to do.
                //
                // To get there, perform statement.execute() after
                // statement.execute(arguments:):
                //
                //      // Step 1
                //      // Optimized execution with temporary bindings in order
                //      // to avoid copying strings and blobs: after execution,
                //      // arguments are set, but bindings have been cleared,
                //      // and argumentsAreValidAndBound is false.
                //      try statement.execute(arguments: StatementArguments(person)!)
                //
                //      // Step 2 (we are here). Stop using temporary
                //      // bindings because user explicitly opt ins for
                //      // permanent ones.
                //      try statement.execute()
                try setArguments(arguments) // calls reset()
            }
        }
    }
    
    /// Executes the prepared statement.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.write { db in
    ///     // Statement without argument
    ///     let statement = try db.makeStatement(sql: """
    ///         CREATE TABLE player (
    ///           id INTEGER PRIMARY KEY AUTOINCREMENT,
    ///           name TEXT NOT NULL
    ///         )
    ///         """)
    ///     try statement.execute()
    /// }
    ///
    /// try dbQueue.write { db in
    ///     // Statement with argument
    ///     let statement = try db.makeStatement(sql: """
    ///         INSERT INTO player (name) VALUES (?)
    ///         """)
    ///
    ///     // Set argument and execute
    ///     try statement.setArguments(["Arthur"])
    ///     try statement.execute()
    ///
    ///     // Set argument and execute in one shot
    ///     try statement.execute(arguments: ["Barbara"])
    /// }
    /// ```
    ///
    /// When arguments are set at the moment of execution, with an non-nil
    /// `arguments` parameter, it is assumed that the statement won't be
    /// reused with the same arguments. When the number of arguments is
    /// small, execution is performed with temporary SQLite bindings that
    /// avoid copying strings and blobs arguments.
    ///
    /// For more information, see [`SQLITE_STATIC` and `SQLITE_TRANSIENT`](https://www.sqlite.org/c3ref/c_static.html).
    /// Compare:
    ///
    /// ```swift
    /// // Uses SQLITE_STATIC if there are few arguments,
    /// // SQLITE_TRANSIENT otherwise.
    /// try statement.execute(arguments: ["Barbara"])
    ///
    /// // Always uses SQLITE_TRANSIENT
    /// try statement.setArguments(["Arthur"])
    /// try statement.execute()
    /// ```
    ///
    /// Both techniques have the same results, but when you care about
    /// performances, monitor your application in order to make the
    /// best choice.
    ///
    /// - parameter arguments: Optional statement arguments.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public func execute(arguments: StatementArguments? = nil) throws {
        if let arguments {
            // Assume that the statement won't be reused with the same arguments.
            //
            // Avoid a stack overflow, and don't perform an unbounded nesting
            // of `withBinding(to:at:do:)` methods: only use temporary bindings
            // for less than 20 arguments. This number 20 is completely
            // arbitrary!
            // See <https://forums.swift.org/t/avoiding-stack-overflow-when-nesting-string-withcstring-how-to-handle-an-arbitrary-number-of-temp-values-in-general/63663>
            if sqliteArgumentCount <= 20 {
                // Perform an optimized execution with temporary bindings
                // in order to avoid copying strings and blobs.
                try withArguments(arguments) {
                    try executeAllSteps()
                }
            } else {
                try setArguments(arguments)
                try executeAllSteps()
            }
        } else {
            try prepareExecution()
            try executeAllSteps()
        }
    }
    
    private func executeAllSteps() throws {
        try database.statementWillExecute(self)
        
        // Iterate all rows, since they may execute side effects.
        while true {
            switch sqlite3_step(sqliteStatement) {
            case SQLITE_DONE:
                try database.statementDidExecute(self)
                return
            case SQLITE_ROW:
                break
            case let code:
                try database.statementDidFail(self, withResultCode: code)
            }
        }
    }
    
    /// Calls the given closure after each successful call to `sqlite3_step()`.
    ///
    /// This method is slighly faster than calling `step(_:)` repeatedly, due
    /// to the single `sqlite3_stmt_busy` check.
    @usableFromInline
    func forEachStep(_ body: (SQLiteStatement) throws -> Void) throws {
        SchedulingWatchdog.preconditionValidQueue(database)
        
        if sqlite3_stmt_busy(sqliteStatement) == 0 {
            try database.statementWillExecute(self)
        }
        
        while true {
            switch sqlite3_step(sqliteStatement) {
            case SQLITE_DONE:
                try database.statementDidExecute(self)
                return
            case SQLITE_ROW:
                try body(sqliteStatement)
            case let code:
                try database.statementDidFail(self, withResultCode: code)
            }
        }
    }
    
    /// Calls the given closure after one successful call to `sqlite3_step()`.
    @usableFromInline
    func step<T>(_ body: (SQLiteStatement) throws -> T) throws -> T? {
        if sqlite3_stmt_busy(sqliteStatement) == 0 {
            try database.statementWillExecute(self)
        }
        
        switch sqlite3_step(sqliteStatement) {
        case SQLITE_DONE:
            try database.statementDidExecute(self)
            return nil
        case SQLITE_ROW:
            return try body(sqliteStatement)
        case let code:
            try database.statementDidFail(self, withResultCode: code)
        }
    }
}

extension Statement: CustomStringConvertible {
    public var description: String {
        SchedulingWatchdog.allows(database) ? sql : "Statement"
    }
}

// MARK: - Select Statements

extension Statement {
    /// The number of columns in the resulting rows.
    public var columnCount: Int {
        Int(sqlite3_column_count(self.sqliteStatement))
    }
    
    /// Returns the index of the leftmost column with the given name.
    ///
    /// This method is case-insensitive.
    public func index(ofColumn name: String) -> Int? {
        columnIndexes[name.lowercased()]
    }
    
    /// Creates a cursor over the statement which does not produce any
    /// value. Each call to the next() cursor method calls the sqlite3_step()
    /// C function.
    func makeCursor(arguments: StatementArguments? = nil) throws -> StatementCursor {
        try StatementCursor(statement: self, arguments: arguments)
    }
}

// MARK: - Cursors

/// A cursor that lazily iterates the results of a prepared ``Statement``.
///
/// ## Overview
///
/// To get a `DatabaseCursor` instance, use one of the `fetchCursor` methods.
/// For example:
///
/// - A cursor of ``Row`` built from a prepared ``Statement``:
///
///     ```swift
///     try dbQueue.read { db in
///         let statement = try db.makeStatement(sql: "SELECT * FROM player")
///         let rows = try Row.fetchCursor(statement)
///         while let row = try rows.next() {
///             let id: Int64 = row["id"]
///             let name: String = row["name"]
///         }
///     }
///     ```
///
/// - A cursor of `Int` built from an SQL string (see ``DatabaseValueConvertible``):
///
///     ```swift
///     try dbQueue.read { db in
///         let sql = "SELECT score FROM player"
///         let scores = try Int.fetchCursor(db, sql: sql)
///         while let score = try scores.next() {
///             print(score)
///         }
///     }
///     ```
///
/// - A cursor of `Player` records built from a request (see ``FetchableRecord`` and ``FetchRequest``):
///
///     ```swift
///     try dbQueue.read { db in
///         let request = Player.all()
///         let players = try request.fetchCursor(db)
///         while let player = try players.next() {
///             print(player.name, player.score)
///         }
///     }
///     ```
///
/// A database cursor is valid only during the current database access (read or
/// write). Do not store or escape a cursor for later use.
///
/// A database cursor resets its underlying prepared statement with
/// [`sqlite3_reset`](https://www.sqlite.org/c3ref/reset.html) when the cursor
/// is created, and when it is deallocated. Don't share the same prepared
/// statement between two cursors!
public protocol DatabaseCursor: Cursor {
    /// Must be initialized to false.
    var _isDone: Bool { get set }
    
    /// The statement iterated by the cursor
    var _statement: Statement { get }
    
    /// Called after one successful call to `sqlite3_step()`. Returns the
    /// element for the current statement step.
    func _element(sqliteStatement: SQLiteStatement) throws -> Element
}

// Read-only access to statement information. We don't want the user to modify
// a statement through a cursor, in case this would mess with the cursor state.
extension DatabaseCursor {
    /// The SQL query.
    public var sql: String { _statement.sql }
    
    /// The statement arguments.
    public var arguments: StatementArguments { _statement.arguments }
    
    /// The column names, ordered from left to right.
    public var columnNames: [String] { _statement.columnNames }
    
    /// The number of columns in the resulting rows.
    public var columnCount: Int { _statement.columnCount }
    
    /// The database region that the cursor looks into.
    public var databaseRegion: DatabaseRegion { _statement.databaseRegion }
}

extension DatabaseCursor {
    @inlinable
    public func next() throws -> Element? {
        if _isDone {
            return nil
        }
        if let element = try _statement.step(_element) {
            return element
        }
        _isDone = true
        return nil
    }
    
    // Specific implementation of `forEach`, for a slight performance
    // improvement due to the single `sqlite3_stmt_busy` check.
    @inlinable
    public func forEach(_ body: (Element) throws -> Void) throws {
        if _isDone { return }
        try _statement.forEachStep {
            try body(_element(sqliteStatement: $0))
        }
        _isDone = true
    }
}

/// A cursor that iterates a database statement without producing any value.
/// Each call to the `next()` method calls the `sqlite3_step()` C function.
///
/// For example:
///
/// ```swift
/// try dbQueue.read { db in
///     let statement = try db.makeStatement(sql: "SELECT performSideEffect()")
///     let cursor = statement.makeCursor()
///     try cursor.next()
/// }
/// ```
final class StatementCursor: DatabaseCursor {
    typealias Element = Void
    let _statement: Statement
    var _isDone = false
    
    // Use Statement.makeCursor() instead
    init(statement: Statement, arguments: StatementArguments? = nil) throws {
        self._statement = statement
        
        // Assume cursor is created for immediate iteration: reset and set arguments
        try statement.prepareExecution(withArguments: arguments)
    }
    
    deinit {
        // Statement reset fails when sqlite3_step has previously failed.
        // Just ignore reset error.
        try? _statement.reset()
    }
    
    @inlinable
    func _element(sqliteStatement: SQLiteStatement) throws { }
}

// MARK: - Update Statements

extension Statement {
    var releasesDatabaseLock: Bool {
        guard let transactionEffect else {
            return false
        }
        
        switch transactionEffect {
        case .commitTransaction, .rollbackTransaction,
             .releaseSavepoint, .rollbackSavepoint:
            // Not technically correct:
            // - ROLLBACK TRANSACTION TO SAVEPOINT does not release any lock
            // - RELEASE SAVEPOINT does not always release lock
            //
            // But both move in the direction of releasing locks :-)
            return true
        default:
            return false
        }
    }
}

// MARK: - StatementBinding

/// A type that can bind a statement argument.
///
/// Related SQLite documentation: <https://www.sqlite.org/c3ref/bind_blob.html>
public protocol StatementBinding {
    /// Binds a statement argument.
    ///
    /// - parameter sqliteStatement: An SQLite statement.
    /// - parameter index: 1-based index to statement arguments.
    /// - returns: the code returned by the `sqlite3_bind_xxx` function.
    func bind(to sqliteStatement: SQLiteStatement, at index: CInt) -> CInt
}

/// Helper function for `withBinding(to:at:do:)` methods.
func checkBindingSuccess(code: CInt, sqliteStatement: SQLiteStatement) throws {
    if code == SQLITE_OK { return }
    let message = String(cString: sqlite3_errmsg(sqlite3_db_handle(sqliteStatement)))
    let sql = String(cString: sqlite3_sql(sqliteStatement)).trimmedSQLStatement
    throw DatabaseError(resultCode: code, message: message, sql: sql)
}

/// Calls the given closure after performing temporary bindings that avoid
/// copying strings and blobs.
///
/// The bindings are valid only during the execution of this method.
///
/// - parameter bindings: The bindings
/// - parameter sqliteStatement: The SQLite statement
/// - parameter index: The index of the first binding.
/// - parameter body: The closure to execute when arguments are bound.
@usableFromInline
func withBindings<C, T>(
    _ bindings: C,
    to sqliteStatement: SQLiteStatement,
    from index: CInt = 1,
    do body: () throws -> T)
throws -> T
where C: Collection, C.Element == DatabaseValue
{
    guard let binding = bindings.first else {
        return try body()
    }
    
    return try binding.withBinding(to: sqliteStatement, at: index) {
        try withBindings(
            bindings.dropFirst(),
            to: sqliteStatement,
            from: index + 1,
            do: body)
    }
}

// MARK: - StatementArguments

/// An instance of `StatementArguments` provides the values for argument
/// placeholders in a prepared `Statement`.
///
/// Argument placeholders can take several forms in SQL queries (see
/// <https://www.sqlite.org/lang_expr.html#varparam> for more information):
///
/// - `?NNN` (e.g. `?2`): the NNN-th argument (starts at 1)
/// - `?`: the N-th argument, where N is one greater than the largest argument
///    number already assigned
/// - `:AAAA` (e.g. `:name`): named argument
/// - `@AAAA` (e.g. `@name`): named argument
/// - `$AAAA` (e.g. `$name`): named argument
///
/// All forms are supported,  but GRDB does not allow to distinguish between
/// the `:AAAA`, `@AAAA`, and `$AAAA` syntaxes. You are encouraged to write
/// named arguments with a colon prefix: `:name`.
///
/// ## Positional Arguments
///
/// To fill question marks placeholders, feed `StatementArguments` with an array:
///
/// ```swift
/// try db.execute(
///     sql: "INSERT INTO player (name, score) VALUES (?, ?)",
///     arguments: StatementArguments(["Arthur", 41]))
///
/// // Array literals are automatically converted:
/// try db.execute(
///     sql: "INSERT INTO player (name, score) VALUES (?, ?)",
///     arguments: ["Arthur", 41])
/// ```
///
/// ## Named Arguments
///
/// To fill named arguments, feed `StatementArguments` with a dictionary:
///
/// ```swift
/// try db.execute(
///     sql: "INSERT INTO player (name, score) VALUES (:name, :score)",
///     arguments: StatementArguments(["name": "Arthur", "score": 41]))
///
/// // Dictionary literals are automatically converted:
/// try db.execute(
///     sql: "INSERT INTO player (name, score) VALUES (:name, :score)",
///     arguments: ["name": "Arthur", "score": 41])
/// ```
///
/// ## Concatenating Arguments
///
/// Several arguments can be concatenated and mixed with the
/// ``append(contentsOf:)`` method and the `+`, `&+`, `+=` operators:
///
/// ```swift
/// var arguments: StatementArguments = ["Arthur"]
/// arguments += [41]
/// try db.execute(
///     sql: "INSERT INTO player (name, score) VALUES (?, ?)",
///     arguments: arguments)
/// ```
///
/// The `+` and `+=` operators consider that overriding named arguments is a
/// programmer error:
///
/// ```swift
/// var arguments: StatementArguments = ["name": "Arthur"]
///
/// // fatal error: already defined statement argument: name
/// arguments += ["name": "Barbara"]
/// ```
///
/// On the other side, `&+` and ``append(contentsOf:)`` allow overriding
/// named arguments:
///
/// ```swift
/// var arguments: StatementArguments = ["name": "Arthur"]
/// arguments = arguments &+ ["name": "Barbara"]
///
/// // Prints ["name": "Barbara"]
/// print(arguments)
/// ```
///
/// ## Mixed Arguments
///
/// It is possible to mix named and positional arguments. Yet this is usually
/// confusing, and it is best to avoid this practice:
///
/// ```swift
/// let sql = "SELECT ?2 AS two, :foo AS foo, ?1 AS one, :foo AS foo2, :bar AS bar"
/// var arguments: StatementArguments = [1, 2, "bar"] + ["foo": "foo"]
/// let row = try Row.fetchOne(db, sql: sql, arguments: arguments)!
///
/// // Prints [two:2 foo:"foo" one:1 foo2:"foo" bar:"bar"]
/// print(row)
/// ```
///
/// Mixed arguments exist as a support for requests like the following:
///
/// ```swift
/// let players = try Player
///     .filter(sql: "team = :team", arguments: ["team": "Blue"])
///     .filter(sql: "score > ?", arguments: [1000])
///     .fetchAll(db)
/// ```
public struct StatementArguments: Hashable {
    private(set) var values: [DatabaseValue]
    private(set) var namedValues: [String: DatabaseValue]
    
    public var isEmpty: Bool {
        values.isEmpty && namedValues.isEmpty
    }
    
    
    // MARK: Empty Arguments
    
    /// Creates an empty `StatementArguments`.
    public init() {
        values = .init()
        namedValues = .init()
    }
    
    // MARK: Positional Arguments
    
    /// Creates a `StatementArguments` from a sequence of values.
    ///
    /// For example:
    ///
    /// ```swift
    /// let values: [(any DatabaseValueConvertible)?] = ["foo", 1, nil]
    /// db.execute(sql: "INSERT ... (?,?,?)", arguments: StatementArguments(values))
    /// ```
    public init<S>(_ sequence: S)
    where S: Sequence, S.Element == (any DatabaseValueConvertible)?
    {
        values = sequence.map { $0?.databaseValue ?? .null }
        namedValues = .init()
    }
    
    /// Creates a `StatementArguments` from a sequence of values.
    ///
    /// For example:
    ///
    /// ```swift
    /// let values: [String] = ["foo", "bar"]
    /// db.execute(sql: "INSERT ... (?,?)", arguments: StatementArguments(values))
    /// ```
    public init<S>(_ sequence: S)
    where S: Sequence, S.Element: DatabaseValueConvertible
    {
        values = sequence.map(\.databaseValue)
        namedValues = .init()
    }
    
    /// Creates a `StatementArguments` from an array.
    ///
    /// The result is nil unless all array elements conform to the
    /// ``DatabaseValueConvertible`` protocol.
    public init?(_ array: [Any]) {
        var values = [(any DatabaseValueConvertible)?]()
        for value in array {
            guard let dbValue = DatabaseValue(value: value) else {
                return nil
            }
            values.append(dbValue)
        }
        self.init(values)
    }
    
    private mutating func set(databaseValues: [DatabaseValue]) {
        self.values = databaseValues
        namedValues.removeAll(keepingCapacity: true)
    }
    
    // MARK: Named Arguments
    
    /// Creates a `StatementArguments` of named arguments from a dictionary.
    ///
    /// For example:
    ///
    /// ```swift
    /// let values: [String: (any DatabaseValueConvertible)?] = ["firstName": nil, "lastName": "Miller"]
    /// db.execute(sql: "INSERT ... (:firstName, :lastName)", arguments: StatementArguments(values))
    /// ```
    public init(_ dictionary: [String: (any DatabaseValueConvertible)?]) {
        namedValues = dictionary.mapValues { $0?.databaseValue ?? .null }
        values = .init()
    }
    
    /// Creates a `StatementArguments` of named arguments from a sequence of
    /// (key, value) pairs.
    public init<S>(_ sequence: S)
    where S: Sequence, S.Element == (String, (any DatabaseValueConvertible)?)
    {
        namedValues = .init(minimumCapacity: sequence.underestimatedCount)
        for (key, value) in sequence {
            namedValues[key] = value?.databaseValue ?? .null
        }
        values = .init()
    }
    
    /// Creates a `StatementArguments` from a dictionary.
    ///
    /// The result is nil unless all dictionary keys are strings, and values
    /// adopt DatabaseValueConvertible.
    ///
    /// - parameter dictionary: A dictionary.
    public init?(_ dictionary: [AnyHashable: Any]) {
        var initDictionary = [String: (any DatabaseValueConvertible)?]()
        for (key, value) in dictionary {
            guard let columnName = key as? String else {
                return nil
            }
            guard let dbValue = DatabaseValue(value: value) else {
                return nil
            }
            initDictionary[columnName] = dbValue
        }
        self.init(initDictionary)
    }
    
    
    // MARK: Adding arguments
    
    /// Appends statement arguments.
    ///
    /// Positional arguments are concatenated:
    ///
    /// ```swift
    /// var arguments: StatementArguments = [1]
    /// arguments.append(contentsOf: [2, 3])
    ///
    /// // Prints [1, 2, 3]
    /// print(arguments)
    /// ```
    ///
    /// Named arguments are inserted or updated:
    ///
    /// ```swift
    /// var arguments: StatementArguments = ["foo": 1]
    /// arguments.append(contentsOf: ["bar": 2])
    ///
    /// // Prints ["foo": 1, "bar": 2]
    /// print(arguments)
    /// ```
    ///
    /// Named arguments that were replaced, if any, are returned:
    ///
    /// ```swift
    /// var arguments: StatementArguments = ["foo": 1, "bar": 2]
    /// let replacedValues = arguments.append(contentsOf: ["foo": 3])
    ///
    /// // Prints ["foo": 3, "bar": 2]
    /// print(arguments)
    ///
    /// // Prints ["foo": 1]
    /// print(replacedValues)
    /// ```
    ///
    /// You can mix named and positional arguments (see the documentation of
    /// the ``StatementArguments`` type for more information about
    /// mixed arguments):
    ///
    /// ```swift
    /// var arguments: StatementArguments = ["foo": 1]
    /// arguments.append(contentsOf: [2, 3])
    ///
    /// // Prints ["foo": 1, 2, 3]
    /// print(arguments)
    /// ```
    public mutating func append(contentsOf arguments: StatementArguments) -> [String: DatabaseValue] {
        var replacedValues: [String: DatabaseValue] = [:]
        values.append(contentsOf: arguments.values)
        for (name, value) in arguments.namedValues {
            if let replacedValue = namedValues.updateValue(value, forKey: name) {
                replacedValues[name] = replacedValue
            }
        }
        return replacedValues
    }
    
    /// Creates a new `StatementArguments` by extending the left-hand size
    /// arguments with the right-hand side arguments.
    ///
    /// Positional arguments are concatenated:
    ///
    /// ```swift
    /// let arguments: StatementArguments = [1] + [2, 3]
    ///
    /// // Prints [1, 2, 3]
    /// print(arguments)
    /// ```
    ///
    /// Named arguments are inserted:
    ///
    /// ```swift
    /// let arguments: StatementArguments = ["foo": 1] + ["bar": 2]
    ///
    /// // Prints ["foo": 1, "bar": 2]
    /// print(arguments)
    /// ```
    ///
    /// If the arguments on the right-hand side has named parameters that are
    /// already defined on the left, a fatal error is raised:
    ///
    /// ```swift
    /// let arguments: StatementArguments = ["foo": 1] + ["foo": 2]
    /// // fatal error: already defined statement argument: foo
    /// ```
    ///
    /// This fatal error can be avoided with the &+ operator, or the
    /// ``append(contentsOf:)`` method.
    ///
    /// You can mix named and positional arguments (see the documentation of
    /// the ``StatementArguments`` type for more information about
    /// mixed arguments):
    ///
    /// ```swift
    /// let arguments: StatementArguments = ["foo": 1] + [2, 3]
    ///
    /// // Prints ["foo": 1, 2, 3]
    /// print(arguments)
    /// ```
    public static func + (lhs: StatementArguments, rhs: StatementArguments) -> StatementArguments {
        var lhs = lhs
        lhs += rhs
        return lhs
    }
    
    /// Creates a new `StatementArguments` by extending the left-hand size
    /// arguments with the right-hand side arguments.
    ///
    /// Positional arguments are concatenated:
    ///
    /// ```swift
    /// let arguments: StatementArguments = [1] &+ [2, 3]
    ///
    /// // Prints [1, 2, 3]
    /// print(arguments)
    /// ```
    ///
    /// Named arguments are inserted or updated:
    ///
    /// ```swift
    /// let arguments: StatementArguments = ["foo": 1] &+ ["bar": 2]
    ///
    /// // Prints ["foo": 1, "bar": 2]
    /// print(arguments)
    /// ```
    ///
    /// If a named arguments is defined in both arguments, the right-hand
    /// side wins:
    ///
    /// ```swift
    /// let arguments: StatementArguments = ["foo": 1] &+ ["foo": 2]
    ///
    /// // Prints ["foo": 2]
    /// print(arguments)
    /// ```
    ///
    /// You can mix named and positional arguments (see the documentation of
    /// the ``StatementArguments`` type for more information about
    /// mixed arguments):
    ///
    /// ```swift
    /// let arguments: StatementArguments = ["foo": 1] &+ [2, 3]
    /// // Prints ["foo": 1, 2, 3]
    /// print(arguments)
    /// ```
    public static func &+ (lhs: StatementArguments, rhs: StatementArguments) -> StatementArguments {
        var lhs = lhs
        _ = lhs.append(contentsOf: rhs)
        return lhs
    }
    
    /// Extends the left-hand size arguments with the right-hand side arguments.
    ///
    /// Positional arguments are concatenated:
    ///
    /// ```swift
    /// var arguments: StatementArguments = [1]
    /// arguments += [2, 3]
    ///
    /// // Prints [1, 2, 3]
    /// print(arguments)
    /// ```
    ///
    /// Named arguments are inserted:
    ///
    /// ```swift
    /// var arguments: StatementArguments = ["foo": 1]
    /// arguments += ["bar": 2]
    ///
    /// // Prints ["foo": 1, "bar": 2]
    /// print(arguments)
    /// ```
    ///
    /// If the arguments on the right-hand side has named parameters that are
    /// already defined on the left, a fatal error is raised:
    ///
    /// ```swift
    /// var arguments: StatementArguments = ["foo": 1]
    ///
    /// // fatal error: already defined statement argument: foo
    /// arguments += ["foo": 2]
    /// ```
    ///
    /// This fatal error can be avoided with the &+ operator, or the
    /// ``append(contentsOf:)`` method.
    ///
    /// You can mix named and positional arguments (see the documentation of
    /// the ``StatementArguments`` type for more information about
    /// mixed arguments):
    ///
    /// ```swift
    /// var arguments: StatementArguments = ["foo": 1]
    /// arguments.append(contentsOf: [2, 3])
    ///
    /// // Prints ["foo": 1, 2, 3]
    /// print(arguments)
    /// ```
    public static func += (lhs: inout StatementArguments, rhs: StatementArguments) {
        let replacedValues = lhs.append(contentsOf: rhs)
        GRDBPrecondition(
            replacedValues.isEmpty,
            "already defined statement argument: \(replacedValues.keys.joined(separator: ", "))")
    }
    
    
    // MARK: Not Public
    
    mutating func extractBindings(
        forStatement statement: Statement,
        allowingRemainingValues: Bool)
    throws -> [DatabaseValue]
    {
        var iterator = values.makeIterator()
        var consumedValuesCount = 0
        let bindings = try statement.sqliteArgumentNames.map { argumentName -> DatabaseValue in
            if let argumentName {
                if let dbValue = namedValues[argumentName] {
                    return dbValue
                } else if let value = iterator.next() {
                    consumedValuesCount += 1
                    return value
                } else {
                    throw DatabaseError(
                        resultCode: .SQLITE_MISUSE,
                        message: "missing statement argument: \(argumentName)",
                        sql: statement.sql)
                }
            } else if let value = iterator.next() {
                consumedValuesCount += 1
                return value
            } else {
                throw DatabaseError(
                    resultCode: .SQLITE_MISUSE,
                    message: "wrong number of statement arguments: \(values.count)",
                    sql: statement.sql)
            }
        }
        if !allowingRemainingValues && iterator.next() != nil {
            throw DatabaseError(
                resultCode: .SQLITE_MISUSE,
                message: "wrong number of statement arguments: \(values.count)",
                sql: statement.sql)
        }
        if consumedValuesCount == values.count {
            values.removeAll()
        } else {
            values = Array(values[consumedValuesCount...])
        }
        return bindings
    }
}

extension StatementArguments: ExpressibleByArrayLiteral {
    /// Creates a `StatementArguments` from an array literal.
    ///
    /// For example:
    ///
    /// ```swift
    /// let arguments: StatementArguments = ["Arthur", 41]
    /// try db.execute(
    ///     sql: "INSERT INTO player (name, score) VALUES (?, ?)"
    ///     arguments: arguments)
    /// ```
    public init(arrayLiteral elements: (any DatabaseValueConvertible)?...) {
        self.init(elements)
    }
}

extension StatementArguments: ExpressibleByDictionaryLiteral {
    /// Creates a `StatementArguments` from a dictionary literal.
    ///
    /// For example:
    ///
    /// ```swift
    /// let arguments: StatementArguments = ["name": "Arthur", "score": 41]
    /// try db.execute(
    ///     sql: "INSERT INTO player (name, score) VALUES (:name, :score)"
    ///     arguments: arguments)
    /// ```
    public init(dictionaryLiteral elements: (String, (any DatabaseValueConvertible)?)...) {
        self.init(elements)
    }
}

extension StatementArguments: CustomStringConvertible {
    public var description: String {
        let valuesDescriptions = values.map(\.description)
        let namedValuesDescriptions = namedValues.map { (key, value) in
            "\(String(reflecting: key)): \(value)"
        }
        return "[" + (namedValuesDescriptions + valuesDescriptions).joined(separator: ", ") + "]"
    }
}

extension StatementArguments: Sendable { }
