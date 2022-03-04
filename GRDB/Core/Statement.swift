import Foundation

/// A raw SQLite statement, suitable for the SQLite C API.
public typealias SQLiteStatement = OpaquePointer

extension CharacterSet {
    /// Statements are separated by semicolons and white spaces
    static let sqlStatementSeparators = CharacterSet(charactersIn: ";").union(.whitespacesAndNewlines)
}

/// A statement represents an SQL query.
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
    
    /// The SQL query
    public var sql: String {
        SchedulingWatchdog.preconditionValidQueue(database)
        
        // trim white space and semicolumn for homogeneous output
        return String(cString: sqlite3_sql(sqliteStatement))
            .trimmingCharacters(in: .sqlStatementSeparators)
    }
    
    /// The column names, ordered from left to right.
    public lazy var columnNames: [String] = {
        let sqliteStatement = self.sqliteStatement
        return (0..<Int32(self.columnCount)).map { String(cString: sqlite3_column_name(sqliteStatement, $0)) }
    }()
    
    // Database region is computed during statement compilation, and maybe
    // extended for select statements compiled by QueryInterfaceRequest, in
    // order to perform focused database observation. See
    // SQLQueryGenerator.makeStatement(_:)
    /// The database region that the statement looks into.
    public internal(set) var databaseRegion = DatabaseRegion()
    
    /// If true, the database schema cache gets invalidated after this statement
    /// is executed.
    private(set) var invalidatesDatabaseSchemaCache = false
    private(set) var transactionEffect: TransactionEffect?
    private(set) var databaseEventKinds: [DatabaseEventKind] = []
    
    /// Returns true if and only if the prepared statement makes no direct
    /// changes to the content of the database file.
    ///
    /// See <https://www.sqlite.org/c3ref/stmt_readonly.html>.
    public var isReadonly: Bool {
        sqlite3_stmt_readonly(sqliteStatement) != 0
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
        prepFlags: Int32) throws
    {
        SchedulingWatchdog.preconditionValidQueue(database)
        
        // Reset authorizer before preparing the statement
        let authorizer = database.authorizer
        authorizer.reset()
        
        var sqliteStatement: SQLiteStatement? = nil
        let code: Int32
        // sqlite3_prepare_v3 was introduced in SQLite 3.20.0 http://www.sqlite.org/changes.html#version_3_20
#if GRDBCUSTOMSQLITE || GRDBCIPHER
        code = sqlite3_prepare_v3(
            database.sqliteConnection, statementStart, -1, UInt32(bitPattern: prepFlags),
            &sqliteStatement, statementEnd)
#else
        if #available(iOS 12.0, OSX 10.14, tvOS 12.0, watchOS 5.0, *) {
            code = sqlite3_prepare_v3(
                database.sqliteConnection, statementStart, -1, UInt32(bitPattern: prepFlags),
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
        
        guard let statement = sqliteStatement else {
            return nil
        }
        
        self.database = database
        self.sqliteStatement = statement
        self.databaseRegion = authorizer.selectedRegion
        self.invalidatesDatabaseSchemaCache = authorizer.invalidatesDatabaseSchemaCache
        self.transactionEffect = authorizer.transactionEffect
        self.databaseEventKinds = authorizer.databaseEventKinds
    }
    
    deinit {
        sqlite3_finalize(sqliteStatement)
    }
    
    // MARK: Arguments
    
    private var argumentsNeedValidation = true
    
    private var _arguments = StatementArguments()
    
    lazy var sqliteArgumentCount: Int = {
        Int(sqlite3_bind_parameter_count(self.sqliteStatement))
    }()
    
    // Returns ["id", nil", "name"] for "INSERT INTO table VALUES (:id, ?, :name)"
    fileprivate lazy var sqliteArgumentNames: [String?] = {
        (0..<Int32(self.sqliteArgumentCount)).map {
            guard let cString = sqlite3_bind_parameter_name(self.sqliteStatement, $0 + 1) else {
                return nil
            }
            return String(String(cString: cString).dropFirst()) // Drop initial ":", "@", "$"
        }
    }()
    
    /// The statement arguments.
    ///
    /// It is a programmer error to provide arguments that do not fill all
    /// arguments needed by the statement: doing so will raise a fatal error.
    ///
    /// For example:
    ///
    ///     let statement = try db.makeUpdateArgument(sql: """
    ///         INSERT INTO player (id, name) VALUES (?, ?)
    ///         """)
    ///
    ///     // OK
    ///     try statement.arguments = [1, "Arthur"]
    ///
    ///     // Fatal Error
    ///     try statement.arguments = [1]
    ///
    /// If you are not sure of your arguments input, prefer the throwing
    /// `setArguments(_:)` method.
    public var arguments: StatementArguments {
        get { _arguments }
        set {
            // Force arguments validity: it is a programmer error to provide
            // arguments that do not match the statement.
            try! setArguments(newValue)
        }
    }
    
    /// Throws a DatabaseError of code SQLITE_ERROR if arguments don't fill all
    /// statement arguments.
    ///
    /// For example:
    ///
    ///     let statement = try db.makeUpdateArgument(sql: """
    ///         INSERT INTO player (id, name) VALUES (?, ?)
    ///         """)
    ///
    ///     // OK
    ///     statement.validateArguments([1, "Arthur"])
    ///
    ///     // Throws
    ///     statement.validateArguments([1])
    ///
    /// See also setArguments(_:)
    public func validateArguments(_ arguments: StatementArguments) throws {
        var arguments = arguments
        _ = try arguments.extractBindings(forStatement: self, allowingRemainingValues: false)
    }
    
    /// Set arguments without any validation. Trades safety for performance.
    ///
    /// Only call this method if you are sure input arguments match all expected
    /// arguments of the statement.
    ///
    /// For example:
    ///
    ///     let statement = try db.makeUpdateArgument(sql: """
    ///         INSERT INTO player (id, name) VALUES (?, ?)
    ///         """)
    ///
    ///     // OK
    ///     statement.setUncheckedArguments([1, "Arthur"])
    ///
    ///     // OK
    ///     let arguments: StatementArguments = ... // some untrusted arguments
    ///     try statement.validateArguments(arguments)
    ///     statement.setUncheckedArguments(arguments)
    ///
    ///     // NOT OK
    ///     statement.setUncheckedArguments([1])
    public func setUncheckedArguments(_ arguments: StatementArguments) {
        _arguments = arguments
        argumentsNeedValidation = false
        
        try! reset()
        clearBindings()
        
        var valuesIterator = arguments.values.makeIterator()
        for (index, argumentName) in zip(Int32(1)..., sqliteArgumentNames) {
            if let argumentName = argumentName, let value = arguments.namedValues[argumentName] {
                bind(value, at: index)
            } else if let value = valuesIterator.next() {
                bind(value, at: index)
            }
        }
    }
    
    /// Set the statement arguments, or throws a DatabaseError of code
    /// SQLITE_ERROR if arguments don't fill all statement arguments.
    ///
    /// For example:
    ///
    ///     let statement = try db.makeUpdateArgument(sql: """
    ///         INSERT INTO player (id, name) VALUES (?, ?)
    ///         """)
    ///
    ///     // OK
    ///     try statement.setArguments([1, "Arthur"])
    ///
    ///     // Throws an error
    ///     try statement.setArguments([1])
    public func setArguments(_ arguments: StatementArguments) throws {
        // Validate
        var consumedArguments = arguments
        let bindings = try consumedArguments.extractBindings(forStatement: self, allowingRemainingValues: false)
        
        // Apply
        _arguments = arguments
        argumentsNeedValidation = false
        try reset()
        clearBindings()
        for (index, dbValue) in zip(Int32(1)..., bindings) {
            bind(dbValue, at: index)
        }
    }
    
    // 1-based index
    func bind<T: StatementBinding>(_ value: T, at index: CInt) {
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
    
    func reset(withArguments arguments: StatementArguments?) throws {
        // Force arguments validity: it is a programmer error to provide
        // arguments that do not match the statement.
        if let arguments = arguments {
            try setArguments(arguments)
        } else if argumentsNeedValidation {
            try reset()
            try validateArguments(self.arguments)
        }
    }
    
    /// Executes the prepared statement.
    ///
    /// - parameter arguments: Optional statement arguments.
    /// - throws: A DatabaseError whenever an SQLite error occurs.
    public func execute(arguments: StatementArguments? = nil) throws {
        try reset(withArguments: arguments)
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
    /// Unlike multiple calls to `step(_:)`, this method is able to deal with
    /// statements that need a specific authorizer.
    ///
    /// That's how we deal with TransactionObservers that observe deletion:
    /// the authorizer prevents the truncate optimization
    /// <https://www.sqlite.org/lang_delete.html#the_truncate_optimization>.
    ///
    /// That's also how we deal with <https://github.com/groue/GRDB.swift/issues/1124>,
    /// in four steps:
    ///
    /// 1. `T.fetchAll(...)` calls `Array(T.fetchCursor(...))`
    /// 2. `Array(T.fetchCursor(...))` calls `Cursor.forEach(...)`
    /// 3. `DatabaseCursor.forEach(...)` calls `Statement.forEachStep(...)`
    /// 4. `Statement.forEachStep(...)` deals with the eventual authorizer.
    @usableFromInline
    func forEachStep(_ body: (SQLiteStatement) throws -> Void) throws {
        SchedulingWatchdog.preconditionValidQueue(database)
        try database.statementWillExecute(self)
        
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
    ///
    /// This method is unable to deal with statements that need a specific
    /// authorizer. See `forEachStep(_:)`.
    @usableFromInline
    func step<Element>(_ body: (SQLiteStatement) throws -> Element) throws -> Element? {
        // This check takes 0 time when profiled. It is, practically speaking, free.
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
    
    /// Returns the index of the leftmost column named `name`, in a
    /// case-insensitive way.
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

/// Implementation details of `DatabaseCursor`.
///
/// :nodoc:
public protocol _DatabaseCursor: Cursor {
    /// Reserved to `_DatabaseCursor` implementation.
    /// Must be initialized to false.
    var _isDone: Bool { get set }
    
    /// Called after one successful call to `sqlite3_step()`. Returns the
    /// element for the current statement step.
    func _element(sqliteStatement: SQLiteStatement) throws -> Element
}

/// A protocol for cursors that iterate a database statement.
public protocol DatabaseCursor: _DatabaseCursor {
    /// The statement iterated by the cursor
    var statement: Statement { get }
}

extension DatabaseCursor {
    @inlinable
    public func next() throws -> Element? {
        if _isDone {
            return nil
        }
        if let element = try statement.step(_element) {
            return element
        }
        _isDone = true
        return nil
    }
    
    // Specific implementation of `forEach` in order to deal with
    // <https://github.com/groue/GRDB.swift/issues/1124>.
    // See `Statement.forEachStep(_:)` for more information.
    @inlinable
    public func forEach(_ body: (Element) throws -> Void) throws {
        if _isDone { return }
        try statement.forEachStep { try body(_element(sqliteStatement: $0)) }
        _isDone = true
    }
}

/// A cursor that iterates a database statement without producing any value.
/// Each call to the next() cursor method calls the sqlite3_step() C function.
///
/// For example:
///
///     try dbQueue.read { db in
///         let statement = db.makeStatement(sql: "SELECT performSideEffect()")
///         let cursor = statement.makeCursor()
///         try cursor.next()
///     }
final class StatementCursor: DatabaseCursor {
    typealias Element = Void
    let statement: Statement
    var _isDone = false
    
    // Use Statement.makeCursor() instead
    init(statement: Statement, arguments: StatementArguments? = nil) throws {
        self.statement = statement
        
        // Assume cursor is created for immediate iteration: reset and set arguments
        try statement.reset(withArguments: arguments)
    }
    
    deinit {
        // Statement reset fails when sqlite3_step has previously failed.
        // Just ignore reset error.
        try? statement.reset()
    }
    
    @usableFromInline
    func _element(sqliteStatement: SQLiteStatement) throws { }
}

// MARK: - Update Statements

extension Statement {
    var releasesDatabaseLock: Bool {
        guard let transactionEffect = transactionEffect else {
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

public protocol StatementBinding {
    /// Binds a statement argument.
    ///
    /// - parameter sqliteStatement: An SQLite statement.
    /// - parameter index: 1-based index to statement arguments
    /// - returns: the code returned by the `sqlite3_bind_xxx` function.
    func bind(to sqliteStatement: SQLiteStatement, at index: CInt) -> CInt
}

// MARK: - StatementArguments

/// StatementArguments provide values to argument placeholders in raw
/// SQL queries.
///
/// Placeholders can take several forms (see <https://www.sqlite.org/lang_expr.html#varparam>
/// for more information):
///
/// - `?NNN` (e.g. `?2`): the NNN-th argument (starts at 1)
/// - `?`: the N-th argument, where N is one greater than the largest argument
///    number already assigned
/// - `:AAAA` (e.g. `:name`): named argument
/// - `@AAAA` (e.g. `@name`): named argument
/// - `$AAAA` (e.g. `$name`): named argument
///
/// ## Positional Arguments
///
/// To fill question marks placeholders, feed StatementArguments with an array:
///
///     db.execute(
///         sql: "INSERT ... (?, ?)",
///         arguments: StatementArguments(["Arthur", 41]))
///
///     // Array literals are automatically converted:
///     db.execute(
///         sql: "INSERT ... (?, ?)",
///         arguments: ["Arthur", 41])
///
/// ## Named Arguments
///
/// To fill named arguments, feed StatementArguments with a dictionary:
///
///     db.execute(
///         sql: "INSERT ... (:name, :score)",
///         arguments: StatementArguments(["name": "Arthur", "score": 41]))
///
///     // Dictionary literals are automatically converted:
///     db.execute(
///         sql: "INSERT ... (:name, :score)",
///         arguments: ["name": "Arthur", "score": 41])
///
/// ## Concatenating Arguments
///
/// Several arguments can be concatenated and mixed with the
/// `append(contentsOf:)` method and the `+`, `&+`, `+=` operators:
///
///     var arguments: StatementArguments = ["Arthur"]
///     arguments += [41]
///     db.execute(sql: "INSERT ... (?, ?)", arguments: arguments)
///
/// `+` and `+=` operators consider that overriding named arguments is a
/// programmer error:
///
///     var arguments: StatementArguments = ["name": "Arthur"]
///     arguments += ["name": "Barbara"]
///     // fatal error: already defined statement argument: name
///
/// `&+` and `append(contentsOf:)` allow overriding named arguments:
///
///     var arguments: StatementArguments = ["name": "Arthur"]
///     arguments = arguments &+ ["name": "Barbara"]
///     print(arguments)
///     // Prints ["name": "Barbara"]
///
/// ## Mixed Arguments
///
/// It is possible to mix named and positional arguments. Yet this is usually
/// confusing, and it is best to avoid this practice:
///
///     let sql = "SELECT ?2 AS two, :foo AS foo, ?1 AS one, :foo AS foo2, :bar AS bar"
///     var arguments: StatementArguments = [1, 2, "bar"] + ["foo": "foo"]
///     let row = try Row.fetchOne(db, sql: sql, arguments: arguments)!
///     print(row)
///     // Prints [two:2 foo:"foo" one:1 foo2:"foo" bar:"bar"]
///
/// Mixed arguments exist as a support for requests like the following:
///
///     let players = try Player
///         .filter(sql: "team = :team", arguments: ["team": "Blue"])
///         .filter(sql: "score > ?", arguments: [1000])
///         .fetchAll(db)
public struct StatementArguments: CustomStringConvertible, Equatable,
                                  ExpressibleByArrayLiteral, ExpressibleByDictionaryLiteral
{
    private(set) var values: [DatabaseValue]
    private(set) var namedValues: [String: DatabaseValue]
    
    public var isEmpty: Bool {
        values.isEmpty && namedValues.isEmpty
    }
    
    
    // MARK: Empty Arguments
    
    /// Creates empty StatementArguments.
    public init() {
        values = .init()
        namedValues = .init()
    }
    
    // MARK: Positional Arguments
    
    /// Creates statement arguments from a sequence of optional values.
    ///
    ///     let values: [DatabaseValueConvertible?] = ["foo", 1, nil]
    ///     db.execute(sql: "INSERT ... (?,?,?)", arguments: StatementArguments(values))
    ///
    /// - parameter sequence: A sequence of DatabaseValueConvertible values.
    /// - returns: A StatementArguments.
    public init<Sequence: Swift.Sequence>(_ sequence: Sequence) where Sequence.Element == DatabaseValueConvertible? {
        values = sequence.map { $0?.databaseValue ?? .null }
        namedValues = .init()
    }
    
    /// Creates statement arguments from a sequence of optional values.
    ///
    ///     let values: [String] = ["foo", "bar"]
    ///     db.execute(sql: "INSERT ... (?,?)", arguments: StatementArguments(values))
    ///
    /// - parameter sequence: A sequence of DatabaseValueConvertible values.
    /// - returns: A StatementArguments.
    public init<Sequence: Swift.Sequence>(_ sequence: Sequence) where Sequence.Element: DatabaseValueConvertible {
        values = sequence.map(\.databaseValue)
        namedValues = .init()
    }
    
    /// Creates statement arguments from any array. The result is nil unless all
    /// array elements adopt DatabaseValueConvertible.
    ///
    /// - parameter array: An array
    /// - returns: A StatementArguments.
    public init?(_ array: [Any]) {
        var values = [DatabaseValueConvertible?]()
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
    
    /// Creates statement arguments from a sequence of (key, value) dictionary,
    /// such as a dictionary.
    ///
    ///     let values: [String: DatabaseValueConvertible?] = ["firstName": nil, "lastName": "Miller"]
    ///     db.execute(sql: "INSERT ... (:firstName, :lastName)", arguments: StatementArguments(values))
    ///
    /// - parameter sequence: A sequence of (key, value) pairs
    /// - returns: A StatementArguments.
    public init(_ dictionary: [String: DatabaseValueConvertible?]) {
        namedValues = dictionary.mapValues { $0?.databaseValue ?? .null }
        values = .init()
    }
    
    /// Creates statement arguments from a sequence of (key, value) pairs, such
    /// as a dictionary.
    ///
    ///     let values: [String: DatabaseValueConvertible?] = ["firstName": nil, "lastName": "Miller"]
    ///     db.execute(sql: "INSERT ... (:firstName, :lastName)", arguments: StatementArguments(values))
    ///
    /// - parameter sequence: A sequence of (key, value) pairs
    /// - returns: A StatementArguments.
    public init<Sequence>(_ sequence: Sequence)
    where Sequence: Swift.Sequence, Sequence.Element == (String, DatabaseValueConvertible?)
    {
        namedValues = .init(minimumCapacity: sequence.underestimatedCount)
        for (key, value) in sequence {
            namedValues[key] = value?.databaseValue ?? .null
        }
        values = .init()
    }
    
    /// Creates statement arguments from [AnyHashable: Any].
    ///
    /// The result is nil unless all dictionary keys are strings, and values
    /// adopt DatabaseValueConvertible.
    ///
    /// - parameter dictionary: A dictionary.
    /// - returns: A StatementArguments.
    public init?(_ dictionary: [AnyHashable: Any]) {
        var initDictionary = [String: DatabaseValueConvertible?]()
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
    
    /// Extends statement arguments with other arguments.
    ///
    /// Positional arguments (provided as arrays) are concatenated:
    ///
    ///     var arguments: StatementArguments = [1]
    ///     arguments.append(contentsOf: [2, 3])
    ///     print(arguments)
    ///     // Prints [1, 2, 3]
    ///
    /// Named arguments (provided as dictionaries) are updated:
    ///
    ///     var arguments: StatementArguments = ["foo": 1]
    ///     arguments.append(contentsOf: ["bar": 2])
    ///     print(arguments)
    ///     // Prints ["foo": 1, "bar": 2]
    ///
    /// Arguments that were replaced, if any, are returned:
    ///
    ///     var arguments: StatementArguments = ["foo": 1, "bar": 2]
    ///     let replacedValues = arguments.append(contentsOf: ["foo": 3])
    ///     print(arguments)
    ///     // Prints ["foo": 3, "bar": 2]
    ///     print(replacedValues)
    ///     // Prints ["foo": 1]
    ///
    /// You can mix named and positional arguments (see documentation of
    /// the StatementArguments type for more information about mixed arguments):
    ///
    ///     var arguments: StatementArguments = ["foo": 1]
    ///     arguments.append(contentsOf: [2, 3])
    ///     print(arguments)
    ///     // Prints ["foo": 1, 2, 3]
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
    
    /// Creates a new StatementArguments by extending the left-hand size
    /// arguments with the right-hand side arguments.
    ///
    /// Positional arguments (provided as arrays) are concatenated:
    ///
    ///     let arguments: StatementArguments = [1] + [2, 3]
    ///     print(arguments)
    ///     // Prints [1, 2, 3]
    ///
    /// Named arguments (provided as dictionaries) are updated:
    ///
    ///     let arguments: StatementArguments = ["foo": 1] + ["bar": 2]
    ///     print(arguments)
    ///     // Prints ["foo": 1, "bar": 2]
    ///
    /// You can mix named and positional arguments (see documentation of
    /// the StatementArguments type for more information about mixed arguments):
    ///
    ///     let arguments: StatementArguments = ["foo": 1] + [2, 3]
    ///     print(arguments)
    ///     // Prints ["foo": 1, 2, 3]
    ///
    /// If the arguments on the right-hand side has named parameters that are
    /// already defined on the left, a fatal error is raised:
    ///
    ///     let arguments: StatementArguments = ["foo": 1] + ["foo": 2]
    ///     // fatal error: already defined statement argument: foo
    ///
    /// This fatal error can be avoided with the &+ operator, or the
    /// append(contentsOf:) method.
    public static func + (lhs: StatementArguments, rhs: StatementArguments) -> StatementArguments {
        var lhs = lhs
        lhs += rhs
        return lhs
    }
    
    /// Creates a new StatementArguments by extending the left-hand size
    /// arguments with the right-hand side arguments.
    ///
    /// Positional arguments (provided as arrays) are concatenated:
    ///
    ///     let arguments: StatementArguments = [1] &+ [2, 3]
    ///     print(arguments)
    ///     // Prints [1, 2, 3]
    ///
    /// Named arguments (provided as dictionaries) are updated:
    ///
    ///     let arguments: StatementArguments = ["foo": 1] &+ ["bar": 2]
    ///     print(arguments)
    ///     // Prints ["foo": 1, "bar": 2]
    ///
    /// You can mix named and positional arguments (see documentation of
    /// the StatementArguments type for more information about mixed arguments):
    ///
    ///     let arguments: StatementArguments = ["foo": 1] &+ [2, 3]
    ///     print(arguments)
    ///     // Prints ["foo": 1, 2, 3]
    ///
    /// If a named arguments is defined in both arguments, the right-hand
    /// side wins:
    ///
    ///     let arguments: StatementArguments = ["foo": 1] &+ ["foo": 2]
    ///     print(arguments)
    ///     // Prints ["foo": 2]
    public static func &+ (lhs: StatementArguments, rhs: StatementArguments) -> StatementArguments {
        var lhs = lhs
        _ = lhs.append(contentsOf: rhs)
        return lhs
    }
    
    /// Extends the left-hand size arguments with the right-hand side arguments.
    ///
    /// Positional arguments (provided as arrays) are concatenated:
    ///
    ///     var arguments: StatementArguments = [1]
    ///     arguments += [2, 3]
    ///     print(arguments)
    ///     // Prints [1, 2, 3]
    ///
    /// Named arguments (provided as dictionaries) are updated:
    ///
    ///     var arguments: StatementArguments = ["foo": 1]
    ///     arguments += ["bar": 2]
    ///     print(arguments)
    ///     // Prints ["foo": 1, "bar": 2]
    ///
    /// You can mix named and positional arguments (see documentation of
    /// the StatementArguments type for more information about mixed arguments):
    ///
    ///     var arguments: StatementArguments = ["foo": 1]
    ///     arguments.append(contentsOf: [2, 3])
    ///     print(arguments)
    ///     // Prints ["foo": 1, 2, 3]
    ///
    /// If the arguments on the right-hand side has named parameters that are
    /// already defined on the left, a fatal error is raised:
    ///
    ///     var arguments: StatementArguments = ["foo": 1]
    ///     arguments += ["foo": 2]
    ///     // fatal error: already defined statement argument: foo
    ///
    /// This fatal error can be avoided with the &+ operator, or the
    /// append(contentsOf:) method.
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
        let initialValuesCount = values.count
        let bindings = try statement.sqliteArgumentNames.map { argumentName -> DatabaseValue in
            if let argumentName = argumentName {
                if let dbValue = namedValues[argumentName] {
                    return dbValue
                } else if values.isEmpty {
                    throw DatabaseError(
                        resultCode: .SQLITE_MISUSE,
                        message: "missing statement argument: \(argumentName)",
                        sql: statement.sql)
                } else {
                    return values.removeFirst()
                }
            } else {
                if values.isEmpty {
                    throw DatabaseError(
                        resultCode: .SQLITE_MISUSE,
                        message: "wrong number of statement arguments: \(initialValuesCount)",
                        sql: statement.sql)
                } else {
                    return values.removeFirst()
                }
            }
        }
        if !allowingRemainingValues && !values.isEmpty {
            throw DatabaseError(
                resultCode: .SQLITE_MISUSE,
                message: "wrong number of statement arguments: \(initialValuesCount)",
                sql: statement.sql)
        }
        return bindings
    }
}

// ExpressibleByArrayLiteral
extension StatementArguments {
    /// Returns a StatementArguments from an array literal:
    ///
    ///     let arguments: StatementArguments = ["Arthur", 41]
    ///     try db.execute(
    ///         sql: "INSERT INTO player (name, score) VALUES (?, ?)"
    ///         arguments: arguments)
    public init(arrayLiteral elements: DatabaseValueConvertible?...) {
        self.init(elements)
    }
}

// ExpressibleByDictionaryLiteral
extension StatementArguments {
    /// Returns a StatementArguments from a dictionary literal:
    ///
    ///     let arguments: StatementArguments = ["name": "Arthur", "score": 41]
    ///     try db.execute(
    ///         sql: "INSERT INTO player (name, score) VALUES (:name, :score)"
    ///         arguments: arguments)
    public init(dictionaryLiteral elements: (String, DatabaseValueConvertible?)...) {
        self.init(elements)
    }
}

// CustomStringConvertible
extension StatementArguments {
    /// :nodoc:
    public var description: String {
        let valuesDescriptions = values.map(\.description)
        let namedValuesDescriptions = namedValues.map { (key, value) -> String in
            "\(String(reflecting: key)): \(value)"
        }
        return "[" + (namedValuesDescriptions + valuesDescriptions).joined(separator: ", ") + "]"
    }
}

extension StatementArguments: Sendable { }
