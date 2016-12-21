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
    #elseif os(watchOS)
        #if (arch(i386) || arch(x86_64))
            import SQLiteWatchSimulator
        #else
            import SQLiteWatchOS
        #endif
    #endif
#endif

/// A raw SQLite statement, suitable for the SQLite C API.
public typealias SQLiteStatement = OpaquePointer

/// A statement represents an SQL query.
///
/// It is the base class of UpdateStatement that executes *update statements*,
/// and SelectStatement that fetches rows.
public class Statement {
    
    /// The raw SQLite statement, suitable for the SQLite C API.
    public let sqliteStatement: SQLiteStatement
    
    /// The SQL query
    public var sql: String {
        return String(cString: sqlite3_sql(sqliteStatement))
    }
    
    /// The database
    unowned let database: Database
    
    init(database: Database, sqliteStatement: SQLiteStatement) {
        self.database = database
        self.sqliteStatement = sqliteStatement
    }
    
    fileprivate init(database: Database, sql: String, observer: StatementCompilationObserver) throws {
        SchedulingWatchdog.preconditionValidQueue(database)
        
        observer.start()
        defer { observer.stop() }
        
        let sqlCodeUnits = sql.utf8CString
        var sqliteStatement: SQLiteStatement? = nil
        var code: Int32 = 0
        var remainingSQL = ""
        sqlCodeUnits.withUnsafeBufferPointer { codeUnits in
            let sqlStart = UnsafePointer<Int8>(codeUnits.baseAddress)!
            var sqlEnd: UnsafePointer<Int8>? = nil
            code = sqlite3_prepare_v2(database.sqliteConnection, sqlStart, -1, &sqliteStatement, &sqlEnd)
            let remainingData = Data(bytesNoCopy: UnsafeMutableRawPointer(mutating: sqlEnd!), count: sqlStart + sqlCodeUnits.count - sqlEnd! - 1, deallocator: .none)
            remainingSQL = String(data: remainingData, encoding: .utf8)!.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        guard code == SQLITE_OK else {
            throw DatabaseError(code: code, message: database.lastErrorMessage, sql: sql)
        }
        
        guard remainingSQL.isEmpty else {
            sqlite3_finalize(sqliteStatement)
            throw DatabaseError(code: SQLITE_MISUSE, message: "Multiple statements found. To execute multiple statements, use Database.execute() instead.", sql: sql, arguments: nil)
        }
        
        self.database = database
        self.sqliteStatement = sqliteStatement!
        
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
            fatalError(DatabaseError(code: code, message: database.lastErrorMessage, sql: sql).description)
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
            return String(String(cString: cString).characters.dropFirst()) // Drop initial ":", "@", "$"
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
        for (index, argumentName) in sqliteArgumentNames.enumerated() {
            if let argumentName = argumentName, let value = arguments.namedValues[argumentName] {
                bind(databaseValue: value, at: index)
            } else if let value = valuesIterator.next() {
                bind(databaseValue: value, at: index)
            } else {
                bind(databaseValue: .null, at: index)
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
        for (index, databaseValue) in bindings.enumerated() {
            bind(databaseValue: databaseValue, at: index)
        }
    }
    
    // 0-based index
    private func bind(databaseValue: DatabaseValue, at index: Int) {
        let code: Int32
        switch databaseValue.storage {
        case .null:
            code = sqlite3_bind_null(sqliteStatement, Int32(index + 1))
        case .int64(let int64):
            code = sqlite3_bind_int64(sqliteStatement, Int32(index + 1), int64)
        case .double(let double):
            code = sqlite3_bind_double(sqliteStatement, Int32(index + 1), double)
        case .string(let string):
            code = sqlite3_bind_text(sqliteStatement, Int32(index + 1), string, -1, SQLITE_TRANSIENT)
        case .blob(let data):
            code = data.withUnsafeBytes { bytes in
                sqlite3_bind_blob(sqliteStatement, Int32(index + 1), bytes, Int32(data.count), SQLITE_TRANSIENT)
            }
        }
        
        // It looks like sqlite3_bind_xxx() functions do not access the file system.
        // They should thus succeed, unless a GRDB bug: there is no point throwing any error.
        guard code == SQLITE_OK else {
            fatalError(DatabaseError(code: code, message: database.lastErrorMessage, sql: sql).description)
        }
    }
    
    // Don't make this one public unless we keep the arguments property in sync.
    private func clearBindings() {
        // It looks like sqlite3_clear_bindings() does not access the file system.
        // This function call should thus succeed, unless a GRDB bug: there is
        // no point throwing any error.
        let code = sqlite3_clear_bindings(sqliteStatement)
        guard code == SQLITE_OK else {
            fatalError(DatabaseError(code: code, message: database.lastErrorMessage, sql: sql).description)
        }
    }

    fileprivate func prepare(withArguments arguments: StatementArguments?) throws {
        if let arguments = arguments {
            try setArgumentsWithValidation(arguments)
        } else if argumentsNeedValidation {
            try validate(arguments: self.arguments)
        }
    }
}


// MARK: - SelectStatement

/// A subclass of Statement that fetches database rows.
///
/// You create SelectStatement with the Database.makeSelectStatement() method:
///
///     try dbQueue.inDatabase { db in
///         let statement = try db.makeSelectStatement("SELECT COUNT(*) FROM persons WHERE age > ?")
///         let moreThanTwentyCount = try Int.fetchOne(statement, arguments: [20])!
///         let moreThanThirtyCount = try Int.fetchOne(statement, arguments: [30])!
///     }
public final class SelectStatement : Statement {
    private(set) var selectionInfo: SelectionInfo
    
    init(database: Database, sql: String) throws {
        self.selectionInfo = SelectionInfo()
        let observer = StatementCompilationObserver(database)
        try super.init(database: database, sql: sql, observer: observer)
        Database.preconditionValidSelectStatement(sql: sql, observer: observer)
        self.selectionInfo = observer.selectionInfo
    }
    
    /// The number of columns in the resulting rows.
    public lazy var columnCount: Int = {
        Int(sqlite3_column_count(self.sqliteStatement))
    }()
    
    /// The column names, ordered from left to right.
    public lazy var columnNames: [String] = {
        let sqliteStatement = self.sqliteStatement
        return (0..<self.columnCount).map { (index: Int) -> String in String(cString: sqlite3_column_name(sqliteStatement, Int32(index))) }
    }()
    
    /// Cache for indexOfColumn(). Keys are lowercase.
    private lazy var columnIndexes: [String: Int] = {
        return Dictionary(keyValueSequence: self.columnNames.enumerated().map { ($1.lowercased(), $0) }.reversed())
    }()
    
    /// Returns the index of the leftmost column named `name`, in a
    /// case-insensitive way.
    func index(ofColumn name: String) -> Int? {
        return columnIndexes[name.lowercased()]
    }
    
    /// Creates a DatabaseCursor
    func fetchCursor<Element>(arguments: StatementArguments? = nil, element: @escaping () throws -> Element) -> DatabaseCursor<Element> {
        // Check that cursor is built on a valid queue.
        SchedulingWatchdog.preconditionValidQueue(database, "Database was not used on the correct thread.")
        
        // Force arguments validity: it is a programmer error to provide
        // arguments that do not match the statement.
        try! prepare(withArguments: arguments)
        
        reset()
        return DatabaseCursor(statement: self, element: element)
    }
    
    /// Creates a cursor whose results are ignored
    func fetchCursor(arguments: StatementArguments? = nil) -> DatabaseCursor<Void> {
        return fetchCursor(arguments: arguments) { }
    }

    /// Allows inspection of table and columns read by a SelectStatement
    struct SelectionInfo {
        mutating func insert(column: String, ofTable table: String) {
            if selection[table] != nil {
                selection[table]!.insert(column)
            } else {
                selection[table] = [column]
            }
        }
        
        func contains(anyColumnFrom table: String) -> Bool {
            return selection.index(forKey: table) != nil
        }
        
        func contains(anyColumnIn columns: Set<String>, from table: String) -> Bool {
            return !(selection[table]?.isDisjoint(with: columns) ?? true)
        }
        
        private var selection: [String: Set<String>] = [:]  // [TableName: Set<ColumnName>]
    }
}

/// A cursor on a statement
public final class DatabaseCursor<Element> : Cursor {
    fileprivate let statement: SelectStatement
    private let sqliteStatement: SQLiteStatement
    private let element: () throws -> Element?
    private var done = false
    
    // Fileprivate so that only SelectStatement can instantiate a database cursor
    fileprivate init(statement: SelectStatement, element: @escaping () throws -> Element?) {
        self.statement = statement
        self.sqliteStatement = statement.sqliteStatement
        self.element = element
    }
    
    /// Advances to the next element and returns it, or `nil` if no next element
    /// exists. Once nil has been returned, all subsequent calls return nil.
    ///
    ///     let rows = try Row.fetchCursor(db, "SELECT ...") // DatabaseCursor<Row>
    ///     while let row = try rows.next() { // Row
    ///         let id: Int64 = row.value(atIndex: 0)
    ///         let name: String = row.value(atIndex: 1)
    ///     }
    public func next() throws -> Element? {
        if done {
            return nil
        }
        
        switch sqlite3_step(sqliteStatement) {
        case SQLITE_DONE:
            done = true
            return nil
        case SQLITE_ROW:
            return try element()
        case let errorCode:
            statement.database.selectStatementDidFail(statement)
            throw DatabaseError(code: errorCode, message: statement.database.lastErrorMessage, sql: statement.sql, arguments: statement.arguments)
        }
    }
}


// MARK: - UpdateStatement

/// A subclass of Statement that executes SQL queries.
///
/// You create UpdateStatement with the Database.makeUpdateStatement() method:
///
///     try dbQueue.inTransaction { db in
///         let statement = try db.makeUpdateStatement("INSERT INTO persons (name) VALUES (?)")
///         try statement.execute(arguments: ["Arthur"])
///         try statement.execute(arguments: ["Barbara"])
///         return .commit
///     }
public final class UpdateStatement : Statement {
    enum TransactionStatementInfo {
        enum SavepointAction : String {
            case begin = "BEGIN"
            case release = "RELEASE"
            case rollback = "ROLLBACK"
        }
        
        enum TransactionAction : String {
            case begin = "BEGIN"
            case commit = "COMMIT"
            case rollback = "ROLLBACK"
        }
        
        case transaction(action: TransactionAction)
        case savepoint(name: String, action: SavepointAction)
    }
    
    /// If true, the database schema cache gets invalidated after this statement
    /// is executed.
    private(set) var invalidatesDatabaseSchemaCache: Bool
    private(set) var transactionStatementInfo: TransactionStatementInfo?
    private(set) var databaseEventKinds: [DatabaseEventKind]
    
    init(database: Database, sqliteStatement: SQLiteStatement, invalidatesDatabaseSchemaCache: Bool, transactionStatementInfo: TransactionStatementInfo?, databaseEventKinds: [DatabaseEventKind]) {
        self.invalidatesDatabaseSchemaCache = invalidatesDatabaseSchemaCache
        self.transactionStatementInfo = transactionStatementInfo
        self.databaseEventKinds = databaseEventKinds
        super.init(database: database, sqliteStatement: sqliteStatement)
    }
    
    init(database: Database, sql: String) throws {
        self.invalidatesDatabaseSchemaCache = false
        self.databaseEventKinds = []
        
        let observer = StatementCompilationObserver(database)
        try super.init(database: database, sql: sql, observer: observer)
        self.invalidatesDatabaseSchemaCache = observer.invalidatesDatabaseSchemaCache
        self.transactionStatementInfo = observer.transactionStatementInfo
        self.databaseEventKinds = observer.databaseEventKinds
    }
    
    /// Executes the SQL query.
    ///
    /// - parameter arguments: Statement arguments.
    /// - throws: A DatabaseError whenever an SQLite error occurs.
    public func execute(arguments: StatementArguments? = nil) throws {
        SchedulingWatchdog.preconditionValidQueue(database)
        
        // Force arguments validity: it is a programmer error to provide
        // arguments that do not match the statement.
        try! prepare(withArguments: arguments)
        
        reset()
        database.updateStatementWillExecute(self)
        
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
                database.updateStatementDidExecute(self)
                return
                
            case let errorCode:
                // Failure
                //
                // Let database rethrow eventual transaction observer error:
                try database.updateStatementDidFail(self)
                
                throw DatabaseError(code: errorCode, message: database.lastErrorMessage, sql: sql, arguments: self.arguments) // Error uses self.arguments, not the optional arguments parameter.
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
///         "INSERT ... (:name, :age)",
///         arguments: StatementArguments(["name": "Arthur", "age": 41]))
///
///     // Dictionary literals are automatically converted:
///     db.execute(
///         "INSERT ... (:name, :age)",
///         arguments: ["name": "Arthur", "age": 41])
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
    
    public var isEmpty: Bool {
        return values.isEmpty && namedValues.isEmpty
    }
    
    
    // MARK: Positional Arguments
    
    /// Initializes arguments from a sequence of optional values.
    ///
    ///     let values: [DatabaseValueConvertible?] = ["foo", 1, nil]
    ///     db.execute("INSERT ... (?,?,?)", arguments: StatementArguments(values))
    ///
    /// - parameter sequence: A sequence of DatabaseValueConvertible values.
    /// - returns: A StatementArguments.
    public init<Sequence: Swift.Sequence>(_ sequence: Sequence) where Sequence.Iterator.Element == DatabaseValueConvertible? {
        values = sequence.map { $0?.databaseValue ?? .null }
    }
    
    /// Initializes arguments from a sequence of optional values.
    ///
    ///     let values: [String] = ["foo", "bar"]
    ///     db.execute("INSERT ... (?,?)", arguments: StatementArguments(values))
    ///
    /// - parameter sequence: A sequence of DatabaseValueConvertible values.
    /// - returns: A StatementArguments.
    public init<Sequence: Swift.Sequence>(_ sequence: Sequence) where Sequence.Iterator.Element: DatabaseValueConvertible {
        values = sequence.map { $0.databaseValue }
    }
    
    /// Initializes arguments from [Any].
    ///
    /// The result is nil unless all objects adopt DatabaseValueConvertible.
    ///
    /// - parameter array: An array
    /// - returns: A StatementArguments.
    public init?(_ array: [Any]) {
        var values = [DatabaseValueConvertible?]()
        for value in array {
            guard let databaseValue = DatabaseValue(value: value) else {
                return nil
            }
            values.append(databaseValue)
        }
        self.init(values)
    }
    
    
    // MARK: Named Arguments
    
    /// Initializes arguments from a sequence of (key, value) dictionary, such as
    /// a dictionary.
    ///
    ///     let values: [String: DatabaseValueConvertible?] = ["firstName": nil, "lastName": "Miller"]
    ///     db.execute("INSERT ... (:firstName, :lastName)", arguments: StatementArguments(values))
    ///
    /// - parameter sequence: A sequence of (key, value) pairs
    /// - returns: A StatementArguments.
    public init(_ dictionary: [String: DatabaseValueConvertible?]) {
        namedValues = Dictionary(keys: dictionary.keys) { dictionary[$0]!?.databaseValue ?? .null }
    }
    
    /// Initializes arguments from a sequence of (key, value) pairs, such as
    /// a dictionary.
    ///
    ///     let values: [String: DatabaseValueConvertible?] = ["firstName": nil, "lastName": "Miller"]
    ///     db.execute("INSERT ... (:firstName, :lastName)", arguments: StatementArguments(values))
    ///
    /// - parameter sequence: A sequence of (key, value) pairs
    /// - returns: A StatementArguments.
    public init<Sequence: Swift.Sequence>(_ sequence: Sequence) where Sequence.Iterator.Element == (String, DatabaseValueConvertible?) {
        namedValues = Dictionary(keyValueSequence: sequence.map { ($0, $1?.databaseValue ?? .null) })
    }
    
    /// Initializes arguments from [AnyHashable: Any].
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
            guard let databaseValue = DatabaseValue(value: value) else {
                return nil
            }
            initDictionary[columnName] = databaseValue
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
    
    var values: [DatabaseValue] = []
    var namedValues: [String: DatabaseValue] = [:]
    
    init() {
    }
    
    mutating func consume(_ statement: Statement, allowingRemainingValues: Bool) throws -> [DatabaseValue] {
        let initialValuesCount = values.count
        let bindings = try statement.sqliteArgumentNames.map { argumentName -> DatabaseValue in
            if let argumentName = argumentName {
                if let databaseValue = namedValues[argumentName] {
                    return databaseValue
                } else if values.isEmpty {
                    throw DatabaseError(code: SQLITE_MISUSE, message: "missing statement argument: \(argumentName)", sql: statement.sql, arguments: nil)
                } else {
                    return values.removeFirst()
                }
            } else {
                if values.isEmpty {
                    throw DatabaseError(code: SQLITE_MISUSE, message: "wrong number of statement arguments: \(initialValuesCount)", sql: statement.sql, arguments: nil)
                } else {
                    return values.removeFirst()
                }
            }
        }
        if !allowingRemainingValues && !values.isEmpty {
            throw DatabaseError(code: SQLITE_MISUSE, message: "wrong number of statement arguments: \(initialValuesCount)", sql: statement.sql, arguments: nil)
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
    ///     db.selectRows("SELECT ...", arguments: ["name": "Arthur", "age": 41])
    public init(dictionaryLiteral elements: (String, DatabaseValueConvertible?)...) {
        self.init(elements)
    }
}

extension StatementArguments : CustomStringConvertible {
    /// A textual representation of `self`.
    public var description: String {
        let valuesDescriptions = values.map { $0.description }
        let namedValuesDescriptions = namedValues.map { (key, value) -> String in
            return "\(String(reflecting: key)): \(value)"
        }
        return "[" + (namedValuesDescriptions + valuesDescriptions).joined(separator: ", ") + "]"
    }
}
