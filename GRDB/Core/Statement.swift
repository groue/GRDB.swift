import Foundation
#if SWIFT_PACKAGE
    import CSQLite
#elseif !GRDBCUSTOMSQLITE && !GRDBCIPHER
    import SQLite3
#endif

/// A raw SQLite statement, suitable for the SQLite C API.
public typealias SQLiteStatement = OpaquePointer

/// An error emitted when one tries to compile an empty statement.
struct EmptyStatementError : Error {
}

/// A common protocol for UpdateStatement and SelectStatement
protocol AuthorizedStatement {
    init(
        database: Database,
        statementStart: UnsafePointer<Int8>,
        statementEnd: UnsafeMutablePointer<UnsafePointer<Int8>?>,
        prepFlags: Int32,
        authorizer: StatementCompilationAuthorizer) throws
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
            .trimmingCharacters(in: CharacterSet(charactersIn: ";").union(.whitespacesAndNewlines))
    }
    
    /// The database
    unowned let database: Database
    
    /// Creates a prepared statement.
    ///
    /// - parameter database: A database connection.
    /// - parameter statementStart: A pointer to a UTF-8 encoded C string
    ///   containing SQL.
    /// - parameter statementEnd: Upon success, the pointer to the next
    ///   statement in the C string.
    /// - parameter prepFlags: Flags for sqlite3_prepare_v3 (available from
    ///   SQLite 3.20.0, see http://www.sqlite.org/c3ref/prepare.html)
    /// - throws: DatabaseError in case of compilation error, and
    ///   EmptyStatementError if the compiled string is blank or empty.
    init(
        database: Database,
        statementStart: UnsafePointer<Int8>,
        statementEnd: UnsafeMutablePointer<UnsafePointer<Int8>?>,
        prepFlags: Int32) throws
    {
        SchedulingWatchdog.preconditionValidQueue(database)
        
        var sqliteStatement: SQLiteStatement? = nil
        // sqlite3_prepare_v3 was introduced in SQLite 3.20.0 http://www.sqlite.org/changes.html#version_3_20
        #if GRDBCUSTOMSQLITE
            let code = sqlite3_prepare_v3(database.sqliteConnection, statementStart, -1, UInt32(bitPattern: prepFlags), &sqliteStatement, statementEnd)
        #else
            let code = sqlite3_prepare_v2(database.sqliteConnection, statementStart, -1, &sqliteStatement, statementEnd)
        #endif
        
        guard code == SQLITE_OK else {
            throw DatabaseError(resultCode: code, message: database.lastErrorMessage, sql: String(cString: statementStart))
        }
        
        guard let statement = sqliteStatement else {
            // Sanity check: verify that the string contains only whitespace
            assert(String(data: Data(bytesNoCopy: UnsafeMutableRawPointer(mutating: statementStart), count: statementEnd.pointee! - statementStart, deallocator: .none), encoding: .utf8)!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            
            // I wish we could simply return nil, and make this initializer failable.
            //
            // Unfortunately, there is a Swift bug with failable+throwing initializers:
            // https://bugs.swift.org/browse/SR-6067
            //
            // We thus use sentinel error for empty statements.
            throw EmptyStatementError()
        }
        
        self.database = database
        self.sqliteStatement = statement
    }
    
    deinit {
        sqlite3_finalize(sqliteStatement)
    }
    
    final func reset() {
        // It looks like sqlite3_reset() does not access the file system.
        // This function call should thus succeed, unless a GRDB bug, or a
        // programmer error (reusing a failed statement): there is no point
        // throwing any error.
        let code = sqlite3_reset(sqliteStatement)
        guard code == SQLITE_OK else {
            fatalError(DatabaseError(resultCode: code, message: database.lastErrorMessage, sql: sql).description)
        }
    }
    
    
    // MARK: Arguments
    
    var argumentsNeedValidation = true
    var _arguments: StatementArguments = []
    
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
        _ = try arguments.consume(self, allowingRemainingValues: false)
    }
    
    /// Set arguments without any validation. Trades safety for performance.
    public func unsafeSetArguments(_ arguments: StatementArguments) {
        _arguments = arguments
        argumentsNeedValidation = false
        
        reset()
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
        let bindings = try arguments.consume(self, allowingRemainingValues: false)
        argumentsNeedValidation = false
        
        // Apply
        reset()
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
            code = data.withUnsafeBytes { bytes in
                sqlite3_bind_blob(sqliteStatement, index, bytes, Int32(data.count), SQLITE_TRANSIENT)
            }
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


// MARK: - SelectStatement

/// A subclass of Statement that fetches database rows.
///
/// You create SelectStatement with the Database.makeSelectStatement() method:
///
///     try dbQueue.inDatabase { db in
///         let statement = try db.makeSelectStatement("SELECT COUNT(*) FROM players WHERE score > ?")
///         let moreThanTwentyCount = try Int.fetchOne(statement, arguments: [20])!
///         let moreThanThirtyCount = try Int.fetchOne(statement, arguments: [30])!
///     }
public final class SelectStatement : Statement, AuthorizedStatement {
    /// Information about the table and columns read by a SelectStatement
    public private(set) var selectionInfo: SelectionInfo
    
    /// Creates a prepared statement.
    ///
    /// - parameter database: A database connection.
    /// - parameter statementStart: A pointer to a UTF-8 encoded C string
    ///   containing SQL.
    /// - parameter statementEnd: Upon success, the pointer to the next
    ///   statement in the C string.
    /// - parameter prepFlags: Flags for sqlite3_prepare_v3 (available from
    ///   SQLite 3.20.0, see http://www.sqlite.org/c3ref/prepare.html)
    /// - authorizer: A StatementCompilationAuthorizer
    /// - throws: DatabaseError in case of compilation error, and
    ///   EmptyStatementError if the compiled string is blank or empty.
    init(
        database: Database,
        statementStart: UnsafePointer<Int8>,
        statementEnd: UnsafeMutablePointer<UnsafePointer<Int8>?>,
        prepFlags: Int32,
        authorizer: StatementCompilationAuthorizer) throws
    {
        self.selectionInfo = SelectionInfo()
        try super.init(
            database: database,
            statementStart: statementStart,
            statementEnd: statementEnd,
            prepFlags: prepFlags)
        
        GRDBPrecondition(authorizer.invalidatesDatabaseSchemaCache == false, "Invalid statement type for query \(String(reflecting: sql)): use UpdateStatement instead.")
        GRDBPrecondition(authorizer.transactionEffect == nil, "Invalid statement type for query \(String(reflecting: sql)): use UpdateStatement instead.")
        
        self.selectionInfo = authorizer.selectionInfo
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
    
    /// Creates a cursor over the statement. This cursor does not produce any
    /// value, and is only intended to give access to the sqlite3_step()
    /// low-level function.
    func cursor(arguments: StatementArguments? = nil) -> StatementCursor {
        return StatementCursor(statement: self, arguments: arguments)
    }
    
    /// Utility function for cursors
    func cursorReset(arguments: StatementArguments? = nil) {
        SchedulingWatchdog.preconditionValidQueue(database)
        prepare(withArguments: arguments)
        reset()
    }
    
    /// Information about the table and columns read by a SelectStatement
    public struct SelectionInfo : CustomStringConvertible {
        /// Selection is unknown when a statement uses the COUNT function,
        /// and SQLite version < 3.19:
        ///
        /// `SELECT COUNT(*) FROM t1` -> unknown selection
        private let isUnknown: Bool
        
        /// `SELECT a, b FROM t1` -> ["t1": ["a", "b"]]
        private var columns: [String: Set<String>] = [:]
        
        /// `SELECT COUNT(*) FROM t1` -> ["t1"]
        private var tables: Set<String> = []
        
        /// The unknown selection
        static let unknown = SelectionInfo(isUnknown: true)
        
        mutating func insert(allColumnsOfTable table: String) {
            tables.insert(table)
        }
        
        mutating func insert(column: String, ofTable table: String) {
            columns[table, default: []].insert(column)
        }
        
        /// Returns true if isUnknown is true
        func contains(anyColumnFrom table: String) -> Bool {
            if isUnknown { return true }
            return tables.contains(table) || columns.index(forKey: table) != nil
        }
        
        /// Returns true if isUnknown is true
        func contains(anyColumnIn columns: Set<String>, from table: String) -> Bool {
            if isUnknown { return true }
            return tables.contains(table) || !(self.columns[table]?.isDisjoint(with: columns) ?? true)
        }
        
        init() {
            self.init(isUnknown: false)
        }
        
        private init(isUnknown: Bool) {
            self.isUnknown = isUnknown
        }
        
        public var description: String {
            if isUnknown {
                return "unknown"
            }
            return tables.union(columns.keys)
                .sorted()
                .map { table -> String in
                    if let columns = columns[table] {
                        return "\(table)(\(columns.sorted().joined(separator: ",")))"
                    } else {
                        return "\(table)(*)"
                    }
                }
                .joined(separator: ",")
        }
    }
}

/// A cursor that iterates a database statement without producing any value.
/// For example:
///
///     try dbQueue.inDatabase { db in
///         let statement = db.makeSelectStatement("SELECT * FROM players")
///         let cursor: StatementCursor = statement.cursor()
///     }
public final class StatementCursor: Cursor {
    public let statement: SelectStatement
    private let sqliteStatement: SQLiteStatement
    private var done = false
    
    // Use SelectStatement.cursor() instead
    fileprivate init(statement: SelectStatement, arguments: StatementArguments? = nil) {
        self.statement = statement
        self.sqliteStatement = statement.sqliteStatement
        statement.cursorReset(arguments: arguments)
    }
    
    public func next() throws -> Void? {
        if done { return nil }
        switch sqlite3_step(sqliteStatement) {
        case SQLITE_DONE:
            done = true
            return nil
        case SQLITE_ROW:
            return .some(())
        case let code:
            statement.database.selectStatementDidFail(statement)
            throw DatabaseError(resultCode: code, message: statement.database.lastErrorMessage, sql: statement.sql, arguments: statement.arguments)
        }
    }
}


// MARK: - UpdateStatement

/// A subclass of Statement that executes SQL queries.
///
/// You create UpdateStatement with the Database.makeUpdateStatement() method:
///
///     try dbQueue.inTransaction { db in
///         let statement = try db.makeUpdateStatement("INSERT INTO players (name) VALUES (?)")
///         try statement.execute(arguments: ["Arthur"])
///         try statement.execute(arguments: ["Barbara"])
///         return .commit
///     }
public final class UpdateStatement : Statement, AuthorizedStatement {
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
    private(set) var invalidatesDatabaseSchemaCache: Bool
    
    /// If true, the statement needs support from TruncateOptimizationBlocker
    /// when executed
    private(set) var needsTruncateOptimizationPreventionDuringExecution: Bool

    private(set) var transactionEffect: TransactionEffect?
    private(set) var databaseEventKinds: [DatabaseEventKind]
    
    /// Creates a prepared statement.
    ///
    /// - parameter database: A database connection.
    /// - parameter statementStart: A pointer to a UTF-8 encoded C string
    ///   containing SQL.
    /// - parameter statementEnd: Upon success, the pointer to the next
    ///   statement in the C string.
    /// - parameter prepFlags: Flags for sqlite3_prepare_v3 (available from
    ///   SQLite 3.20.0, see http://www.sqlite.org/c3ref/prepare.html)
    /// - authorizer: A StatementCompilationAuthorizer
    /// - throws: DatabaseError in case of compilation error, and
    ///   EmptyStatementError if the compiled string is blank or empty.
    init(
        database: Database,
        statementStart: UnsafePointer<Int8>,
        statementEnd: UnsafeMutablePointer<UnsafePointer<Int8>?>,
        prepFlags: Int32,
        authorizer: StatementCompilationAuthorizer) throws
    {
        self.invalidatesDatabaseSchemaCache = false
        self.needsTruncateOptimizationPreventionDuringExecution = false
        self.databaseEventKinds = []
        try super.init(
            database: database,
            statementStart: statementStart,
            statementEnd: statementEnd,
            prepFlags: prepFlags)
        self.invalidatesDatabaseSchemaCache = authorizer.invalidatesDatabaseSchemaCache
        self.needsTruncateOptimizationPreventionDuringExecution = authorizer.needsTruncateOptimizationPreventionDuringExecution
        self.transactionEffect = authorizer.transactionEffect
        self.databaseEventKinds = authorizer.databaseEventKinds
    }
    
    /// Executes the SQL query.
    ///
    /// - parameter arguments: Statement arguments.
    /// - throws: A DatabaseError whenever an SQLite error occurs.
    public func execute(arguments: StatementArguments? = nil) throws {
        SchedulingWatchdog.preconditionValidQueue(database)
        prepare(withArguments: arguments)
        reset()
        database.updateStatementWillExecute(self)
        
        if needsTruncateOptimizationPreventionDuringExecution {
            database.authorizer = TruncateOptimizationBlocker()
        }
        
        while true {
            switch sqlite3_step(sqliteStatement) {
            case SQLITE_ROW:
                // The statement did return a row, and the user ignores the
                // content of this row:
                //
                //     try db.execute("SELECT ...")
                //
                // That's OK: maybe the selected rows perform side effects.
                // For example:
                //
                //      try db.execute("SELECT sqlcipher_export(...)")
                //
                // Or maybe the user doesn't know that the executed statement
                // return rows (https://github.com/groue/GRDB.swift/issues/15);
                //
                //      try db.execute("PRAGMA journal_mode=WAL")
                //
                // It is thus important that we consume *all* rows.
                continue
                
            case SQLITE_DONE:
                database.authorizer = nil
                database.updateStatementDidExecute(self)
                return
                
            case let code:
                database.authorizer = nil
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
///         "INSERT ... (?, ?)",
///         arguments: StatementArguments(["Arthur", 41]))
///
///     // Array literals are automatically converted:
///     db.execute(
///         "INSERT ... (?, ?)",
///         arguments: ["Arthur", 41])
///
/// ## Named Arguments
///
/// To fill named arguments, feed StatementArguments with a dictionary:
///
///     db.execute(
///         "INSERT ... (:name, :score)",
///         arguments: StatementArguments(["name": "Arthur", "score": 41]))
///
///     // Dictionary literals are automatically converted:
///     db.execute(
///         "INSERT ... (:name, :score)",
///         arguments: ["name": "Arthur", "score": 41])
///
/// ## Concatenating Arguments
///
/// Several arguments can be concatenated and mixed with the
/// `append(contentsOf:)` method and the `+`, `&+`, `+=` operators:
///
///     var arguments: StatementArguments = ["Arthur"]
///     arguments += [41]
///     db.execute("INSERT ... (?, ?)", arguments: arguments)
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
/// When a statement consumes a mix of named and positional arguments, it
/// prefers named arguments over positional ones. For example:
///
///     let sql = "SELECT ?2 AS two, :foo AS foo, ?1 AS one, :foo AS foo2, :bar AS bar"
///     let row = try Row.fetchOne(db, sql, arguments: [1, 2, "bar"] + ["foo": "foo"])!
///     print(row)
///     // Prints <Row two:2 foo:"foo" one:1 foo2:"foo" bar:"bar">
public struct StatementArguments {
    var values: [DatabaseValue] = []
    var namedValues: [String: DatabaseValue] = [:]
    
    public var isEmpty: Bool {
        return values.isEmpty && namedValues.isEmpty
    }
    
    
    // MARK: Empty Arguments
    
    /// Creates empty StatementArguments.
    init() {
    }
    
    // MARK: Positional Arguments
    
    /// Creates statement arguments from a sequence of optional values.
    ///
    ///     let values: [DatabaseValueConvertible?] = ["foo", 1, nil]
    ///     db.execute("INSERT ... (?,?,?)", arguments: StatementArguments(values))
    ///
    /// - parameter sequence: A sequence of DatabaseValueConvertible values.
    /// - returns: A StatementArguments.
    public init<Sequence: Swift.Sequence>(_ sequence: Sequence) where Sequence.Element == DatabaseValueConvertible? {
        values = sequence.map { $0?.databaseValue ?? .null }
    }
    
    /// Creates statement arguments from a sequence of optional values.
    ///
    ///     let values: [String] = ["foo", "bar"]
    ///     db.execute("INSERT ... (?,?)", arguments: StatementArguments(values))
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
    ///     db.execute("INSERT ... (:firstName, :lastName)", arguments: StatementArguments(values))
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
    ///     db.execute("INSERT ... (:firstName, :lastName)", arguments: StatementArguments(values))
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
    
    mutating func consume(_ statement: Statement, allowingRemainingValues: Bool) throws -> [DatabaseValue] {
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

extension StatementArguments : ExpressibleByArrayLiteral {
    /// Returns a StatementArguments from an array literal:
    ///
    ///     db.selectRows("SELECT ...", arguments: ["Arthur", 41])
    public init(arrayLiteral elements: DatabaseValueConvertible?...) {
        self.init(elements)
    }
}

extension StatementArguments : ExpressibleByDictionaryLiteral {
    /// Returns a StatementArguments from a dictionary literal:
    ///
    ///     db.selectRows("SELECT ...", arguments: ["name": "Arthur", "score": 41])
    public init(dictionaryLiteral elements: (String, DatabaseValueConvertible?)...) {
        self.init(elements)
    }
}

extension StatementArguments : CustomStringConvertible {
    public var description: String {
        let valuesDescriptions = values.map { $0.description }
        let namedValuesDescriptions = namedValues.map { (key, value) -> String in
            return "\(String(reflecting: key)): \(value)"
        }
        return "[" + (namedValuesDescriptions + valuesDescriptions).joined(separator: ", ") + "]"
    }
}

extension StatementArguments : Equatable {
    public static func == (lhs: StatementArguments, rhs: StatementArguments) -> Bool {
        if lhs.values != rhs.values { return false }
        if lhs.namedValues != rhs.namedValues { return false }
        return true
    }
}

/// A thread-unsafe statement cache
struct StatementCache {
    unowned let db: Database
    private var selectStatements: [String: SelectStatement] = [:]
    private var updateStatements: [String: UpdateStatement] = [:]
    
    init(database: Database) {
        self.db = database
    }
    
    mutating func selectStatement(_ sql: String) throws -> SelectStatement {
        if let statement = selectStatements[sql] {
            return statement
        }
        
        #if GRDBCUSTOMSQLITE
            // http://www.sqlite.org/c3ref/c_prepare_persistent.html#sqlitepreparepersistent
            // > The SQLITE_PREPARE_PERSISTENT flag is a hint to the query
            // > planner that the prepared statement will be retained for a long
            // > time and probably reused many times.
            //
            // This looks like a perfect match for cached statements.
            //
            // However SQLITE_PREPARE_PERSISTENT was only introduced in
            // SQLite 3.20.0 http://www.sqlite.org/changes.html#version_3_20
            let statement = try db.makeSelectStatement(sql, prepFlags: SQLITE_PREPARE_PERSISTENT)
        #else
            let statement = try db.makeSelectStatement(sql)
        #endif
        selectStatements[sql] = statement
        return statement
    }

    mutating func updateStatement(_ sql: String) throws -> UpdateStatement {
        if let statement = updateStatements[sql] {
            return statement
        }
        
        #if GRDBCUSTOMSQLITE
            // http://www.sqlite.org/c3ref/c_prepare_persistent.html#sqlitepreparepersistent
            // > The SQLITE_PREPARE_PERSISTENT flag is a hint to the query
            // > planner that the prepared statement will be retained for a long
            // > time and probably reused many times.
            //
            // This looks like a perfect match for cached statements.
            //
            // However SQLITE_PREPARE_PERSISTENT was only introduced in
            // SQLite 3.20.0 http://www.sqlite.org/changes.html#version_3_20
            let statement = try db.makeUpdateStatement(sql, prepFlags: SQLITE_PREPARE_PERSISTENT)
        #else
            let statement = try db.makeUpdateStatement(sql)
        #endif
        updateStatements[sql] = statement
        return statement
    }
    
    mutating func clear() {
        updateStatements = [:]
        selectStatements = [:]
    }
    
    mutating func remove(_ statement: SelectStatement) {
        if let index = selectStatements.index(where: { $0.1 === statement }) {
            selectStatements.remove(at: index)
        }
    }
    
    mutating func remove(_ statement: UpdateStatement) {
        if let index = updateStatements.index(where: { $0.1 === statement }) {
            updateStatements.remove(at: index)
        }
    }
}
