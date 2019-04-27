import Foundation
#if SWIFT_PACKAGE
    import CSQLite
#elseif GRDBCIPHER
    import SQLCipher
#elseif !GRDBCUSTOMSQLITE && !GRDBCIPHER
    import SQLite3
#endif

/// A raw SQLite statement, suitable for the SQLite C API.
public typealias SQLiteStatement = OpaquePointer

extension CharacterSet {
    /// Statements are separated by semicolons and white spaces
    static let sqlStatementSeparators = CharacterSet(charactersIn: ";").union(.whitespacesAndNewlines)
}

/// A statement represents an SQL query.
///
/// It is the base class of UpdateStatement that executes *update statements*,
/// and SelectStatement that fetches rows.
public class Statement {
    
    /// The raw SQLite statement, suitable for the SQLite C API.
    public let sqliteStatement: SQLiteStatement
    
    /// The SQL query
    public var sql: String {
        // trim white space and semicolumn for homogeneous output
        return String(cString: sqlite3_sql(sqliteStatement))
            .trimmingCharacters(in: .sqlStatementSeparators)
    }
    
    unowned let database: Database
    
    /// Creates a prepared statement. Returns nil if the compiled string is
    /// blank or empty.
    ///
    /// - parameter database: A database connection.
    /// - parameter statementStart: A pointer to a UTF-8 encoded C string
    ///   containing SQL.
    /// - parameter statementEnd: Upon success, the pointer to the next
    ///   statement in the C string.
    /// - parameter prepFlags: Flags for sqlite3_prepare_v3 (available from
    ///   SQLite 3.20.0, see http://www.sqlite.org/c3ref/prepare.html)
    /// - throws: DatabaseError in case of compilation error.
    required init?(
        database: Database,
        statementStart: UnsafePointer<Int8>,
        statementEnd: UnsafeMutablePointer<UnsafePointer<Int8>?>,
        prepFlags: Int32,
        authorizer: StatementCompilationAuthorizer) throws
    {
        SchedulingWatchdog.preconditionValidQueue(database)
        
        var sqliteStatement: SQLiteStatement? = nil
        // sqlite3_prepare_v3 was introduced in SQLite 3.20.0 http://www.sqlite.org/changes.html#version_3_20
        #if GRDBCUSTOMSQLITE || GRDBCIPHER
        let code = sqlite3_prepare_v3(database.sqliteConnection, statementStart, -1, UInt32(bitPattern: prepFlags), &sqliteStatement, statementEnd)
        #else
        let code: Int32
        if #available(iOS 12.0, OSX 10.14, watchOS 5.0, *) {
            code = sqlite3_prepare_v3(database.sqliteConnection, statementStart, -1, UInt32(bitPattern: prepFlags), &sqliteStatement, statementEnd)
        } else {
            code = sqlite3_prepare_v2(database.sqliteConnection, statementStart, -1, &sqliteStatement, statementEnd)
        }
        #endif
        
        guard code == SQLITE_OK else {
            throw DatabaseError(resultCode: code, message: database.lastErrorMessage, sql: String(cString: statementStart))
        }
        
        guard let statement = sqliteStatement else {
            return nil
        }
        
        self.database = database
        self.sqliteStatement = statement
    }
    
    deinit {
        sqlite3_finalize(sqliteStatement)
    }
    
    final func reset() throws {
        SchedulingWatchdog.preconditionValidQueue(database)
        let code = sqlite3_reset(sqliteStatement)
        guard code == SQLITE_OK else {
            throw DatabaseError(resultCode: code, message: database.lastErrorMessage, sql: sql)
        }
    }
    
    
    // MARK: Arguments
    
    var argumentsNeedValidation = true
    var _arguments = StatementArguments()
    
    lazy var sqliteArgumentCount: Int = {
        Int(sqlite3_bind_parameter_count(self.sqliteStatement))
    }()
    
    // Returns ["id", nil", "name"] for "INSERT INTO table VALUES (:id, ?, :name)"
    fileprivate lazy var sqliteArgumentNames: [String?] = {
        return (0..<self.sqliteArgumentCount).map {
            guard let cString = sqlite3_bind_parameter_name(self.sqliteStatement, Int32($0 + 1)) else {
                return nil
            }
            return String(String(cString: cString).dropFirst()) // Drop initial ":", "@", "$"
        }
    }()
    
    /// The statement arguments.
    public var arguments: StatementArguments {
        get { return _arguments }
        set {
            // Force arguments validity: it is a programmer error to provide
            // arguments that do not match the statement.
            try! setArgumentsWithValidation(newValue)
        }
    }
    
    /// Throws a DatabaseError of code SQLITE_ERROR if arguments don't fill all
    /// statement arguments.
    public func validate(arguments: StatementArguments) throws {
        var arguments = arguments
        _ = try arguments.extractBindings(forStatement: self, allowingRemainingValues: false)
    }
    
    /// Set arguments without any validation. Trades safety for performance.
    public func unsafeSetArguments(_ arguments: StatementArguments) {
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
            } else {
                bind(.null, at: index)
            }
        }
    }
    
    func setArgumentsWithValidation(_ arguments: StatementArguments) throws {
        // Validate
        _arguments = arguments
        var arguments = arguments
        let bindings = try arguments.extractBindings(forStatement: self, allowingRemainingValues: false)
        argumentsNeedValidation = false
        
        // Apply
        try reset()
        clearBindings()
        for (index, dbValue) in zip(Int32(1)..., bindings) {
            bind(dbValue, at: index)
        }
    }
    
    // 1-based index
    private func bind(_ dbValue: DatabaseValue, at index: Int32) {
        let code: Int32
        switch dbValue.storage {
        case .null:
            code = sqlite3_bind_null(sqliteStatement, index)
        case .int64(let int64):
            code = sqlite3_bind_int64(sqliteStatement, index, int64)
        case .double(let double):
            code = sqlite3_bind_double(sqliteStatement, index, double)
        case .string(let string):
            code = sqlite3_bind_text(sqliteStatement, index, string, -1, SQLITE_TRANSIENT)
        case .blob(let data):
            #if swift(>=5.0)
            code = data.withUnsafeBytes {
                sqlite3_bind_blob(sqliteStatement, index, $0.baseAddress, Int32($0.count), SQLITE_TRANSIENT)
            }
            #else
            code = data.withUnsafeBytes {
                sqlite3_bind_blob(sqliteStatement, index, $0, Int32(data.count), SQLITE_TRANSIENT)
            }
            #endif
        }
        
        // It looks like sqlite3_bind_xxx() functions do not access the file system.
        // They should thus succeed, unless a GRDB bug: there is no point throwing any error.
        guard code == SQLITE_OK else {
            fatalError(DatabaseError(resultCode: code, message: database.lastErrorMessage, sql: sql).description)
        }
    }
    
    // Don't make this one public unless we keep the arguments property in sync.
    private func clearBindings() {
        // It looks like sqlite3_clear_bindings() does not access the file system.
        // This function call should thus succeed, unless a GRDB bug: there is
        // no point throwing any error.
        let code = sqlite3_clear_bindings(sqliteStatement)
        guard code == SQLITE_OK else {
            fatalError(DatabaseError(resultCode: code, message: database.lastErrorMessage, sql: sql).description)
        }
    }

    fileprivate func prepare(withArguments arguments: StatementArguments?) {
        // Force arguments validity: it is a programmer error to provide
        // arguments that do not match the statement.
        if let arguments = arguments {
            try! setArgumentsWithValidation(arguments)
        } else if argumentsNeedValidation {
            try! validate(arguments: self.arguments)
        }
    }
}

// MARK: - Statement Preparation

/// A common protocol for UpdateStatement and SelectStatement, only used as
/// support for SelectStatement.prepare(...) and UpdateStatement.prepare(...).
protocol StatementProtocol { }
extension Statement: StatementProtocol { }
extension StatementProtocol where Self: Statement {
    // Static method instead of an initializer because initializer can't run
    // inside `sqlCodeUnits.withUnsafeBufferPointer`.
    static func prepare(sql: String, prepFlags: Int32, in database: Database) throws -> Self {
        let authorizer = StatementCompilationAuthorizer()
        database.authorizer = authorizer
        defer { database.authorizer = nil }
        
        return try sql.utf8CString.withUnsafeBufferPointer { buffer in
            let statementStart = buffer.baseAddress!
            var statementEnd: UnsafePointer<Int8>? = nil
            guard let statement = try self.init(
                database: database,
                statementStart: statementStart,
                statementEnd: &statementEnd,
                prepFlags: prepFlags,
                authorizer: authorizer) else
            {
                throw DatabaseError(
                    resultCode: .SQLITE_ERROR,
                    message: "empty statement",
                    sql: sql,
                    arguments: nil)
            }
            
            let remainingSQL = String(cString: statementEnd!).trimmingCharacters(in: .sqlStatementSeparators)
            guard remainingSQL.isEmpty else {
                throw DatabaseError(
                    resultCode: .SQLITE_MISUSE,
                    message: "Multiple statements found. To execute multiple statements, use Database.execute(sql:) instead.",
                    sql: sql,
                    arguments: nil)
            }
            
            return statement
        }
    }
}

// MARK: - SelectStatement

/// A subclass of Statement that fetches database rows.
///
/// You create SelectStatement with the Database.makeSelectStatement() method:
///
///     try dbQueue.read { db in
///         let statement = try db.makeSelectStatement(sql: "SELECT COUNT(*) FROM player WHERE score > ?")
///         let moreThanTwentyCount = try Int.fetchOne(statement, arguments: [20])!
///         let moreThanThirtyCount = try Int.fetchOne(statement, arguments: [30])!
///     }
public final class SelectStatement : Statement {    
    /// The database region that the statement looks into.
    public private(set) var databaseRegion = DatabaseRegion()
    
    /// Creates a prepared statement. Returns nil if the compiled string is
    /// blank or empty.
    ///
    /// - parameter database: A database connection.
    /// - parameter statementStart: A pointer to a UTF-8 encoded C string
    ///   containing SQL.
    /// - parameter statementEnd: Upon success, the pointer to the next
    ///   statement in the C string.
    /// - parameter prepFlags: Flags for sqlite3_prepare_v3 (available from
    ///   SQLite 3.20.0, see http://www.sqlite.org/c3ref/prepare.html)
    /// - authorizer: A StatementCompilationAuthorizer
    /// - throws: DatabaseError in case of compilation error.
    required init?(
        database: Database,
        statementStart: UnsafePointer<Int8>,
        statementEnd: UnsafeMutablePointer<UnsafePointer<Int8>?>,
        prepFlags: Int32,
        authorizer: StatementCompilationAuthorizer) throws
    {
        try super.init(
            database: database,
            statementStart: statementStart,
            statementEnd: statementEnd,
            prepFlags: prepFlags,
            authorizer: authorizer)
        
        GRDBPrecondition(authorizer.invalidatesDatabaseSchemaCache == false, "Invalid statement type for query \(String(reflecting: sql)): use UpdateStatement instead.")
        GRDBPrecondition(authorizer.transactionEffect == nil, "Invalid statement type for query \(String(reflecting: sql)): use UpdateStatement instead.")
        
        self.databaseRegion = authorizer.databaseRegion
    }
    
    /// The number of columns in the resulting rows.
    public var columnCount: Int {
        return Int(sqlite3_column_count(self.sqliteStatement))
    }
    
    /// The column names, ordered from left to right.
    public lazy var columnNames: [String] = {
        let sqliteStatement = self.sqliteStatement
        return (0..<Int32(self.columnCount)).map { String(cString: sqlite3_column_name(sqliteStatement, $0)) }
    }()
    
    /// Cache for index(ofColumn:). Keys are lowercase.
    private lazy var columnIndexes: [String: Int] = {
        return Dictionary(
            self.columnNames.enumerated().map { ($0.element.lowercased(), $0.offset) },
            uniquingKeysWith: { (left, _) in left }) // keep leftmost indexes
    }()
    
    /// Returns the index of the leftmost column named `name`, in a
    /// case-insensitive way.
    public func index(ofColumn name: String) -> Int? {
        return columnIndexes[name.lowercased()]
    }
    
    /// Creates a cursor over the statement which does not produce any
    /// value. Each call to the next() cursor method calls the sqlite3_step()
    /// C function.
    func makeCursor(arguments: StatementArguments? = nil) -> StatementCursor {
        return StatementCursor(statement: self, arguments: arguments)
    }
    
    /// Utility function for cursors
    @usableFromInline
    func reset(withArguments arguments: StatementArguments? = nil) {
        prepare(withArguments: arguments)
        try! reset()
    }
    
    /// Utility function for cursors
    @usableFromInline
    func didFail(withResultCode resultCode: Int32) throws -> Never {
        database.selectStatementDidFail(self)
        throw DatabaseError(
            resultCode: resultCode,
            message: database.lastErrorMessage,
            sql: sql,
            arguments: arguments)

    }
}

/// A cursor that iterates a database statement without producing any value.
/// Each call to the next() cursor method calls the sqlite3_step() C function.
///
/// For example:
///
///     try dbQueue.read { db in
///         let statement = db.makeSelectStatement(sql: "SELECT performSideEffect()")
///         let cursor = statement.makeCursor()
///         try cursor.next()
///     }
final class StatementCursor: Cursor {
    @usableFromInline let _statement: SelectStatement
    @usableFromInline let _sqliteStatement: SQLiteStatement
    @usableFromInline var _done = false
    
    // Use SelectStatement.makeCursor() instead
    @inlinable
    init(statement: SelectStatement, arguments: StatementArguments? = nil) {
        _statement = statement
        _sqliteStatement = statement.sqliteStatement
        _statement.reset(withArguments: arguments)
    }
    
    deinit {
        // Statement reset fails when sqlite3_step has previously failed.
        // Just ignore reset error.
        try? _statement.reset()
    }
    
    /// :nodoc:
    @inlinable
    public func next() throws -> Void? {
        if _done {
            // make sure this instance never yields a value again, even if the
            // statement is reset by another cursor.
            return nil
        }
        switch sqlite3_step(_sqliteStatement) {
        case SQLITE_DONE:
            _done = true
            return nil
        case SQLITE_ROW:
            return .some(())
        case let code:
            try _statement.didFail(withResultCode: code)
        }
    }
}


// MARK: - UpdateStatement

/// A subclass of Statement that executes SQL queries.
///
/// You create UpdateStatement with the Database.makeUpdateStatement() method:
///
///     try dbQueue.inTransaction { db in
///         let statement = try db.makeUpdateStatement(sql: "INSERT INTO player (name) VALUES (?)")
///         try statement.execute(arguments: ["Arthur"])
///         try statement.execute(arguments: ["Barbara"])
///         return .commit
///     }
public final class UpdateStatement : Statement {
    enum TransactionEffect {
        case beginTransaction
        case commitTransaction
        case rollbackTransaction
        case beginSavepoint(String)
        case releaseSavepoint(String)
        case rollbackSavepoint(String)
    }
    
    /// If true, the database schema cache gets invalidated after this statement
    /// is executed.
    private(set) var invalidatesDatabaseSchemaCache: Bool = false
    
    private(set) var transactionEffect: TransactionEffect?
    private(set) var databaseEventKinds: [DatabaseEventKind] = []
    
    /// Creates a prepared statement. Returns nil if the compiled string is
    /// blank or empty.
    ///
    /// - parameter database: A database connection.
    /// - parameter statementStart: A pointer to a UTF-8 encoded C string
    ///   containing SQL.
    /// - parameter statementEnd: Upon success, the pointer to the next
    ///   statement in the C string.
    /// - parameter prepFlags: Flags for sqlite3_prepare_v3 (available from
    ///   SQLite 3.20.0, see http://www.sqlite.org/c3ref/prepare.html)
    /// - authorizer: A StatementCompilationAuthorizer
    /// - throws: DatabaseError in case of compilation error.
    required init?(
        database: Database,
        statementStart: UnsafePointer<Int8>,
        statementEnd: UnsafeMutablePointer<UnsafePointer<Int8>?>,
        prepFlags: Int32,
        authorizer: StatementCompilationAuthorizer) throws
    {
        try super.init(
            database: database,
            statementStart: statementStart,
            statementEnd: statementEnd,
            prepFlags: prepFlags,
            authorizer: authorizer)
        self.invalidatesDatabaseSchemaCache = authorizer.invalidatesDatabaseSchemaCache
        self.transactionEffect = authorizer.transactionEffect
        self.databaseEventKinds = authorizer.databaseEventKinds
    }
    
    /// Executes the SQL query.
    ///
    /// - parameter arguments: Optional statement arguments.
    /// - throws: A DatabaseError whenever an SQLite error occurs.
    public func execute(arguments: StatementArguments? = nil) throws {
        SchedulingWatchdog.preconditionValidQueue(database)
        prepare(withArguments: arguments)
        try reset()
        database.updateStatementWillExecute(self)
        
        while true {
            switch sqlite3_step(sqliteStatement) {
            case SQLITE_ROW:
                // The statement did return a row, and the user ignores the
                // content of this row:
                //
                //     try db.execute(sql: "SELECT ...")
                //
                // That's OK: maybe the selected rows perform side effects.
                // For example:
                //
                //      try db.execute(sql: "SELECT sqlcipher_export(...)")
                //
                // Or maybe the user doesn't know that the executed statement
                // return rows (https://github.com/groue/GRDB.swift/issues/15);
                //
                //      try db.execute(sql: "PRAGMA journal_mode=WAL")
                //
                // It is thus important that we consume *all* rows.
                continue
                
            case SQLITE_DONE:
                try database.updateStatementDidExecute(self)
                return
                
            case let code:
                try database.updateStatementDidFail(self)
                throw DatabaseError(resultCode: code, message: database.lastErrorMessage, sql: sql, arguments: self.arguments) // Error uses self.arguments, not the optional arguments parameter.
            }
        }
    }
}

// MARK: - StatementArguments

/// StatementArguments provide values to argument placeholders in raw
/// SQL queries.
///
/// Placeholders can take several forms (see https://www.sqlite.org/lang_expr.html#varparam
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
public struct StatementArguments: CustomStringConvertible, Equatable, ExpressibleByArrayLiteral, ExpressibleByDictionaryLiteral {
    private(set) var values: [DatabaseValue] = []
    private(set) var namedValues: [String: DatabaseValue] = [:]
    
    public var isEmpty: Bool {
        return values.isEmpty && namedValues.isEmpty
    }
    
    
    // MARK: Empty Arguments
    
    /// Creates empty StatementArguments.
    public init() {
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
    }
    
    /// Creates statement arguments from a sequence of optional values.
    ///
    ///     let values: [String] = ["foo", "bar"]
    ///     db.execute(sql: "INSERT ... (?,?)", arguments: StatementArguments(values))
    ///
    /// - parameter sequence: A sequence of DatabaseValueConvertible values.
    /// - returns: A StatementArguments.
    public init<Sequence: Swift.Sequence>(_ sequence: Sequence) where Sequence.Element: DatabaseValueConvertible {
        values = sequence.map { $0.databaseValue }
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
    }
    
    /// Creates statement arguments from a sequence of (key, value) pairs, such
    /// as a dictionary.
    ///
    ///     let values: [String: DatabaseValueConvertible?] = ["firstName": nil, "lastName": "Miller"]
    ///     db.execute(sql: "INSERT ... (:firstName, :lastName)", arguments: StatementArguments(values))
    ///
    /// - parameter sequence: A sequence of (key, value) pairs
    /// - returns: A StatementArguments.
    public init<Sequence: Swift.Sequence>(_ sequence: Sequence) where Sequence.Element == (String, DatabaseValueConvertible?) {
        namedValues = Dictionary(uniqueKeysWithValues: sequence.map { ($0.0, $0.1?.databaseValue ?? .null) })
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
        GRDBPrecondition(replacedValues.isEmpty, "already defined statement argument: \(replacedValues.keys.joined(separator: ", "))")
    }
    
    
    // MARK: Not Public
    
    mutating func extractBindings(forStatement statement: Statement, allowingRemainingValues: Bool) throws -> [DatabaseValue] {
        let initialValuesCount = values.count
        let bindings = try statement.sqliteArgumentNames.map { argumentName -> DatabaseValue in
            if let argumentName = argumentName {
                if let dbValue = namedValues[argumentName] {
                    return dbValue
                } else if values.isEmpty {
                    throw DatabaseError(resultCode: .SQLITE_MISUSE, message: "missing statement argument: \(argumentName)", sql: statement.sql, arguments: nil)
                } else {
                    return values.removeFirst()
                }
            } else {
                if values.isEmpty {
                    throw DatabaseError(resultCode: .SQLITE_MISUSE, message: "wrong number of statement arguments: \(initialValuesCount)", sql: statement.sql, arguments: nil)
                } else {
                    return values.removeFirst()
                }
            }
        }
        if !allowingRemainingValues && !values.isEmpty {
            throw DatabaseError(resultCode: .SQLITE_MISUSE, message: "wrong number of statement arguments: \(initialValuesCount)", sql: statement.sql, arguments: nil)
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
        let valuesDescriptions = values.map { $0.description }
        let namedValuesDescriptions = namedValues.map { (key, value) -> String in
            return "\(String(reflecting: key)): \(value)"
        }
        return "[" + (namedValuesDescriptions + valuesDescriptions).joined(separator: ", ") + "]"
    }
}
