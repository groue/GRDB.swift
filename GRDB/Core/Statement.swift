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
    
    final func reset() throws {
        let code = sqlite3_reset(sqliteStatement)
        guard code == SQLITE_OK else {
            throw DatabaseError(code: code, message: database.lastErrorMessage, sql: sql)
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
            return String(String(cString: cString).characters.dropFirst()) // Drop initial ":"
        }
    }()
    
    /// The statement arguments.
    public var arguments: StatementArguments {
        get { return _arguments }
        set { try! setArgumentsWithValidation(newValue) }
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
        
        // Apply
        try! reset()
        try! clearBindings()
        
        var valuesIterator = arguments.values.makeIterator()
        for (index, argumentName) in sqliteArgumentNames.enumerated() {
            if let argumentName = argumentName, let value = arguments.namedValues[argumentName] {
                try! bind(databaseValue: value, at: index)
            } else if let value = valuesIterator.next() {
                try! bind(databaseValue: value, at: index)
            } else {
                try! bind(databaseValue: .null, at: index)
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
        try! reset()
        try! clearBindings()
        for (index, databaseValue) in bindings.enumerated() {
            try bind(databaseValue: databaseValue, at: index)
        }
    }
    
    // 0-based index
    private func bind(databaseValue: DatabaseValue, at index: Int) throws {
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
        
        guard code == SQLITE_OK else {
            throw DatabaseError(code: code, message: database.lastErrorMessage, sql: sql)
        }
    }
    
    // Don't make this one public unless we keep the arguments property in sync.
    private func clearBindings() throws {
        let code = sqlite3_clear_bindings(sqliteStatement)
        guard code == SQLITE_OK else {
            throw DatabaseError(code: code, message: database.lastErrorMessage, sql: sql)
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
///     dbQueue.inDatabase { db in
///         let statement = db.makeSelectStatement("SELECT COUNT(*) FROM persons WHERE age > ?")
///         let moreThanTwentyCount = Int.fetchOne(statement, arguments: [20])!
///         let moreThanThirtyCount = Int.fetchOne(statement, arguments: [30])!
///     }
public final class SelectStatement : Statement {
    /// A dictionary [tablename: Set<columnName>] of columns read by a statement
    typealias ReadInfo = [String: Set<String>]
    
    private(set) var readInfo: ReadInfo
    
    init(database: Database, sql: String) throws {
        self.readInfo = [:]
        let observer = StatementCompilationObserver(database)
        try super.init(database: database, sql: sql, observer: observer)
        Database.preconditionValidSelectStatement(sql: sql, observer: observer)
        self.readInfo = observer.readInfo
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
    
    // This method MUST be case-insensitive, and returns the index of the
    // leftmost column that matches *name*.
    func index(ofColumn name: String) -> Int? {
        return columnIndexes[name.lowercased()]
    }
    
    /// Creates a DatabaseSequence
    func fetchSequence<Element>(arguments: StatementArguments? = nil, element: @escaping () -> Element) -> DatabaseSequence<Element> {
        // Force arguments validity. See UpdateStatement.execute(), and Database.execute()
        try! prepare(withArguments: arguments)
        return DatabaseSequence(statement: self, element: element)
    }
}

/// A sequence of elements fetched from the database.
public struct DatabaseSequence<Element>: Sequence {
    private let makeIteratorImpl: () throws -> DatabaseIterator<Element>
    
    // Statement sequence
    fileprivate init(statement: SelectStatement, element: @escaping () -> Element) {
        self.makeIteratorImpl = {
            // Check that iterator is built on a valid queue.
            SchedulingWatchdog.preconditionValidQueue(statement.database, "Database was not used on the correct thread. Iterate sequences in a protected dispatch queue, or consider using an array returned by fetchAll() instead.")
            
            // Support multiple sequence iterations
            try statement.reset()
            
            let statementRef = Unmanaged.passRetained(statement)
            return DatabaseIterator(statementRef: statementRef) { (sqliteStatement, statementRef) in
                switch sqlite3_step(sqliteStatement) {
                case SQLITE_DONE:
                    return nil
                case SQLITE_ROW:
                    return element()
                case let errorCode:
                    let statement = statementRef.takeUnretainedValue()
                    throw DatabaseError(code: errorCode, message: statement.database.lastErrorMessage, sql: statement.sql, arguments: statement.arguments)
                }
            }
        }
    }
    
    // Empty sequence
    static func makeEmptySequence(inDatabase database: Database) -> DatabaseSequence {
        // Empty sequence is just as strict as statement sequence, and requires
        // to be used on the database queue.
        return DatabaseSequence() {
            // Check that iterator is built on a valid queue.
            SchedulingWatchdog.preconditionValidQueue(database, "Database was not used on the correct thread. Iterate sequences in a protected dispatch queue, or consider using an array returned by fetchAll() instead.")
            return DatabaseIterator()
        }
    }
    
    private init(_ makeIteratorImpl: @escaping () throws -> DatabaseIterator<Element>) {
        self.makeIteratorImpl = makeIteratorImpl
    }
    
    /// Return a *iterator* over the elements of this *sequence*.
    public func makeIterator() -> DatabaseIterator<Element> {
        return try! makeIteratorImpl()
    }
}

/// A iterator of elements fetched from the database.
public final class DatabaseIterator<Element>: IteratorProtocol {
    private let statementRef: Unmanaged<SelectStatement>?
    private let sqliteStatement: SQLiteStatement?
    private let element: ((SQLiteStatement, Unmanaged<SelectStatement>) throws -> Element?)?
    
    // Iterator takes ownership of statementRef
    init(statementRef: Unmanaged<SelectStatement>, element: @escaping (SQLiteStatement, Unmanaged<SelectStatement>) throws -> Element?) {
        self.statementRef = statementRef
        self.sqliteStatement = statementRef.takeUnretainedValue().sqliteStatement
        self.element = element
    }
    
    init() {
        self.statementRef = nil
        self.sqliteStatement = nil
        self.element = nil
    }
    
    deinit {
        statementRef?.release()
    }
    
    public func step() throws -> Element? {
        guard let element = element else { return nil }
        return try element(sqliteStatement.unsafelyUnwrapped, statementRef.unsafelyUnwrapped)
    }
    
    public func next() -> Element? {
        return try! step()
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
    /// If true, the database schema cache gets invalidated after this statement
    /// is executed.
    private(set) var invalidatesDatabaseSchemaCache: Bool
    private(set) var savepointAction: (name: String, action: SavepointActionKind)?
    private(set) var databaseEventKinds: [DatabaseEventKind]
    
    init(database: Database, sqliteStatement: SQLiteStatement, invalidatesDatabaseSchemaCache: Bool, savepointAction: (name: String, action: SavepointActionKind)?, databaseEventKinds: [DatabaseEventKind]) {
        self.invalidatesDatabaseSchemaCache = invalidatesDatabaseSchemaCache
        self.savepointAction = savepointAction
        self.databaseEventKinds = databaseEventKinds
        super.init(database: database, sqliteStatement: sqliteStatement)
    }
    
    init(database: Database, sql: String) throws {
        self.invalidatesDatabaseSchemaCache = false
        self.databaseEventKinds = []
        
        let observer = StatementCompilationObserver(database)
        try super.init(database: database, sql: sql, observer: observer)
        self.invalidatesDatabaseSchemaCache = observer.invalidatesDatabaseSchemaCache
        self.savepointAction = observer.savepointAction
        self.databaseEventKinds = observer.databaseEventKinds
    }
    
    /// Executes the SQL query.
    ///
    /// - parameter arguments: Statement arguments.
    /// - throws: A DatabaseError whenever an SQLite error occurs.
    public func execute(arguments: StatementArguments? = nil) throws {
        SchedulingWatchdog.preconditionValidQueue(database)
        
        // Force arguments validity. See SelectStatement.fetchSequence(), and Database.execute()
        try! prepare(withArguments: arguments)
        try! reset()
        
        database.updateStatementWillExecute(self)
        
        switch sqlite3_step(sqliteStatement) {
        case SQLITE_DONE, SQLITE_ROW:
            // When SQLITE_ROW, the statement did return a row. That's
            // unexpected from an update statement.
            //
            // What are our options?
            //
            // 1. throw a DatabaseError.
            // 2. raise a fatal error.
            // 3. log a warning about the ignored row, and return successfully.
            // 4. silently ignore the row, and return successfully.
            //
            // The problem with 1 is that this error is uneasy to understand.
            // See https://github.com/groue/GRDB.swift/issues/15 where both the
            // user and I were stupidly stuck in front of `PRAGMA journal_mode=WAL`.
            //
            // The problem with 2 is that the user would be forced to load a
            // value he does not care about (even if he should, but we can't
            // judge).
            //
            // The problem with 3 is that there is no way to avoid this warning.
            //
            // So let's just silently ignore the row, and behave just like
            // SQLITE_DONE: this is a success.
            database.updateStatementDidExecute(self)
            
        case let errorCode:
            // Failure
            //
            // Let database rethrow eventual transaction observer error:
            try database.updateStatementDidFail(self)
            
            throw DatabaseError(code: errorCode, message: database.lastErrorMessage, sql: sql, arguments: self.arguments) // Error uses self.arguments, not the optional arguments parameter.
        }
    }
}


// MARK: - StatementArguments

/// SQL statements can have arguments:
///
///     INSERT INTO persons (name, age) VALUES (?, ?)
///     INSERT INTO persons (name, age) VALUES (:name, :age)
///
/// To fill question mark arguments, feed StatementArguments with an array:
///
///     db.execute("INSERT ... (?, ?)", arguments: StatementArguments(["Arthur", 41]))
///
/// Array literals are automatically converted to StatementArguments:
///
///     db.execute("INSERT ... (?, ?)", arguments: ["Arthur", 41])
///
/// To fill named arguments, feed StatementArguments with a dictionary:
///
///     db.execute("INSERT ... (:name, :age)", arguments: StatementArguments(["name": "Arthur", "age": 41]))
///
/// Dictionary literals are automatically converted to StatementArguments:
///
///     db.execute("INSERT ... (:name, :age)", arguments: ["name": "Arthur", "age": 41])
///
/// See https://www.sqlite.org/lang_expr.html#varparam for more information.
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
            return "\(key):\(value))"
        }
        return "[" + (valuesDescriptions + namedValuesDescriptions).joined(separator: ", ") + "]"
    }
}
