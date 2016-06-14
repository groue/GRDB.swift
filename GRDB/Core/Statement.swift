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
    
    private init(database: Database, sql: String, observer: StatementCompilationObserver) throws {
        DatabaseScheduler.preconditionValidQueue(database)
        
        observer.start()
        defer { observer.stop() }
        
        let sqlCodeUnits = sql.nulTerminatedUTF8
        var sqliteStatement: SQLiteStatement? = nil
        var code: Int32 = 0
        var remainingSQL = ""
        sqlCodeUnits.withUnsafeBufferPointer { codeUnits in
            let sqlStart = UnsafePointer<Int8>(codeUnits.baseAddress)!
            var sqlEnd: UnsafePointer<Int8>? = nil
            code = sqlite3_prepare_v2(database.sqliteConnection, sqlStart, -1, &sqliteStatement, &sqlEnd)
            let remainingData = Data(bytesNoCopy: UnsafeMutablePointer<Void>(sqlEnd!), length: sqlStart + sqlCodeUnits.count - sqlEnd! - 1, freeWhenDone: false)
            remainingSQL = String(data: remainingData, encoding: .utf8)!.trimmingCharacters(in: .whitespacesAndNewlines())
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
    private lazy var sqliteArgumentNames: [String?] = {
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
        _ = try validatedBindings(arguments)
    }
    
    /// Set arguments without any validation. Trades safety for performance.
    public func unsafeSetArguments(_ arguments: StatementArguments) {
        _arguments = arguments
        argumentsNeedValidation = false
        
        // Apply
        try! reset()
        try! clearBindings()
        
        switch arguments.kind {
        case .values(let values):
            for (index, value) in values.enumerated() {
                try! bind(databaseValue: value?.databaseValue ?? .null, at: Int32(index + 1))
            }
            break
        case .namedValues(let namedValues):
            for (index, argumentName) in sqliteArgumentNames.enumerated() {
                if let argumentName = argumentName, let value = namedValues[argumentName] {
                    try! bind(databaseValue: value?.databaseValue ?? .null, at: Int32(index + 1))
                }
            }
        }
    }
    
    func setArgumentsWithValidation(_ arguments: StatementArguments) throws {
        // Validate
        let bindings = try validatedBindings(arguments)
        _arguments = arguments
        argumentsNeedValidation = false
        
        // Apply
        try! reset()
        try! clearBindings()
        for (index, databaseValue) in bindings.enumerated() {
            try bind(databaseValue: databaseValue, at: Int32(index + 1))
        }
    }
    
    private func bind(databaseValue: DatabaseValue, at index: Int32) throws {
        let code: Int32
        switch databaseValue.storage {
        case .null:
            code = sqlite3_bind_null(sqliteStatement, index)
        case .int64(let int64):
            code = sqlite3_bind_int64(sqliteStatement, index, int64)
        case .double(let double):
            code = sqlite3_bind_double(sqliteStatement, index, double)
        case .string(let string):
            code = sqlite3_bind_text(sqliteStatement, index, string, -1, SQLITE_TRANSIENT)
        case .blob(let data):
            code = sqlite3_bind_blob(sqliteStatement, index, data.bytes, Int32(data.length), SQLITE_TRANSIENT)
        }
        
        guard code == SQLITE_OK else {
            throw DatabaseError(code: code, message: database.lastErrorMessage, sql: sql)
        }
    }
    
    // Returns a validated array of as many DatabaseValue as there are
    // parameters in the statement.
    private func validatedBindings(_ arguments: StatementArguments) throws -> [DatabaseValue] {
        // An array of (key, value) pairs.
        //
        // The key is not nil if the statement has a named parameter at given index.
        // The value is not nil if the arguments have a value at given index.
        //
        // The array may be longer than the number of arguments in the statement.
        //
        // If the returned array is longer than the number of arguments in the statement,
        // then we have extra arguments.
        //
        // If one of the values is nil, then we have a missing argument.
        let keyValueBindings: [(String?, DatabaseValue?)] = {
            switch arguments.kind {
            case .values(let values):
                var keyValueBindings: [(String?, DatabaseValue?)] = []
                var argumentNameIter = sqliteArgumentNames.makeIterator()
                var valuesIter = values.map { $0?.databaseValue ?? .null }.makeIterator()
                var argumentNameOpt = argumentNameIter.next()
                var valueOpt = valuesIter.next()
                outer: while true {
                    switch (argumentNameOpt, valueOpt) {
                    case (let argumentName?, let value?):
                        keyValueBindings.append((argumentName, value))
                        argumentNameOpt = argumentNameIter.next()
                        valueOpt = valuesIter.next()
                    case (nil, let value?):
                        keyValueBindings.append((nil, value))
                        valueOpt = valuesIter.next()
                    case (let argumentName?, nil):
                        keyValueBindings.append((argumentName, nil))
                        argumentNameOpt = argumentNameIter.next()
                    case (nil, nil):
                        break outer
                    }
                }
                return keyValueBindings
                
            case .namedValues(let namedValues):
                return sqliteArgumentNames.map { argumentName in
                    if let argumentName = argumentName {
                        if let value = namedValues[argumentName] {
                            return (argumentName, value?.databaseValue ?? .null)
                        } else {
                            return (argumentName, nil)
                        }
                    }
                    return (nil, nil)
                }
            }
            }()

        assert(keyValueBindings.count >= sqliteArgumentCount)
        
        if keyValueBindings.count > sqliteArgumentCount {
            throw DatabaseError(code: SQLITE_MISUSE, message: "wrong number of statement arguments: \(keyValueBindings.count)", sql: sql, arguments: nil)
        }
        
        if case let missingKeys = keyValueBindings.filter({ $0.1 == nil }).map({ $0.0 }) where !missingKeys.isEmpty {
            if case let namedMissingKeys = missingKeys.flatMap({ $0 }) where namedMissingKeys.count == missingKeys.count {
                func caseInsensitiveSort(_ strings: [String]) -> [String] {
                    return strings
                        .map { ($0.lowercased(), $0) }
                        .sorted { $0.0 < $1.0 }
                        .map { $0.1 }
                }
                throw DatabaseError(code: SQLITE_MISUSE, message: "missing statement argument(s): \(caseInsensitiveSort(namedMissingKeys).joined(separator: ", "))", sql: sql, arguments: nil)
            } else {
                throw DatabaseError(code: SQLITE_MISUSE, message: "wrong number of statement arguments: \(sqliteArgumentCount - missingKeys.count)", sql: sql, arguments: nil)
            }
        }
        
        return keyValueBindings.map { $0.1! }
    }
    
    // Don't make this one public unless we keep the arguments property in sync.
    private func clearBindings() throws {
        let code = sqlite3_clear_bindings(sqliteStatement)
        guard code == SQLITE_OK else {
            throw DatabaseError(code: code, message: database.lastErrorMessage, sql: sql)
        }
    }

    private func prepare(withArguments arguments: StatementArguments?) throws {
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
    /// The tables this statement feeds on.
    var sourceTables: Set<String>
    
    init(database: Database, sql: String) throws {
        self.sourceTables = []
        
        let observer = StatementCompilationObserver(database)
        try super.init(database: database, sql: sql, observer: observer)
        Database.preconditionValidSelectStatement(sql: sql, observer: observer)
        self.sourceTables = observer.sourceTables
    }
    
    /// The number of columns in the resulting rows.
    public lazy var columnCount: Int = {
        Int(sqlite3_column_count(self.sqliteStatement))
    }()
    
    /// The column names, ordered from left to right.
    public lazy var columnNames: [String] = {
        let sqliteStatement = self.sqliteStatement
        return (0..<self.columnCount).map { String(cString: sqlite3_column_name(sqliteStatement, Int32($0))) }
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
    func fetchSequence<Element>(arguments: StatementArguments?, element: () -> Element) -> DatabaseSequence<Element> {
        // Force arguments validity. See UpdateStatement.execute(), and Database.execute()
        try! prepare(withArguments: arguments)
        return DatabaseSequence(statement: self, element: element)
    }
}

/// A sequence of elements fetched from the database.
public struct DatabaseSequence<Element>: Sequence {
    private let makeIteratorImpl: () throws -> DatabaseIterator<Element>
    
    // Statement sequence
    private init(statement: SelectStatement, element: () -> Element) {
        self.makeIteratorImpl = {
            // Check that iterator is built on a valid queue.
            DatabaseScheduler.preconditionValidQueue(statement.database, "Database was not used on the correct thread. Iterate sequences in a protected dispatch queue, or consider using an array returned by fetchAll() instead.")
            
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
                    try! { throw DatabaseError(code: errorCode, message: statement.database.lastErrorMessage, sql: statement.sql, arguments: statement.arguments) }()
                    preconditionFailure()
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
            DatabaseScheduler.preconditionValidQueue(database, "Database was not used on the correct thread. Iterate sequences in a protected dispatch queue, or consider using an array returned by fetchAll() instead.")
            return DatabaseIterator()
        }
    }
    
    private init(_ makeIteratorImpl: () throws -> DatabaseIterator<Element>) {
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
    private let element: ((SQLiteStatement, Unmanaged<SelectStatement>) -> Element?)?
    
    // Iterator takes ownership of statementRef
    init(statementRef: Unmanaged<SelectStatement>, element: (SQLiteStatement, Unmanaged<SelectStatement>) -> Element?) {
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
    
    public func next() -> Element? {
        guard let element = element else {
            return nil
        }
        return element(sqliteStatement.unsafelyUnwrapped, statementRef.unsafelyUnwrapped)
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
    
    init(database: Database, sqliteStatement: SQLiteStatement, invalidatesDatabaseSchemaCache: Bool, savepointAction: (name: String, action: SavepointActionKind)?) {
        self.invalidatesDatabaseSchemaCache = invalidatesDatabaseSchemaCache
        self.savepointAction = savepointAction
        super.init(database: database, sqliteStatement: sqliteStatement)
    }
    
    init(database: Database, sql: String) throws {
        self.invalidatesDatabaseSchemaCache = false
        
        let observer = StatementCompilationObserver(database)
        try super.init(database: database, sql: sql, observer: observer)
        self.invalidatesDatabaseSchemaCache = observer.invalidatesDatabaseSchemaCache
        self.savepointAction = observer.savepointAction
    }
    
    /// Executes the SQL query.
    ///
    /// - parameter arguments: Statement arguments.
    /// - throws: A DatabaseError whenever an SQLite error occurs.
    public func execute(arguments: StatementArguments? = nil) throws {
        DatabaseScheduler.preconditionValidQueue(database)
        
        // Force arguments validity. See SelectStatement.fetchSequence(), and Database.execute()
        try! prepare(withArguments: arguments)
        try! reset()
        
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
        switch kind {
        case .values(let values):
            return values.isEmpty
        case .namedValues(let namedValues):
            return namedValues.isEmpty
        }
    }
    
    
    // MARK: Positional Arguments
    
    /// Initializes arguments from a sequence of optional values.
    ///
    ///     let values: [DatabaseValueConvertible?] = ["foo", 1, nil]
    ///     db.execute("INSERT ... (?,?,?)", arguments: StatementArguments(values))
    ///
    /// - parameter sequence: A sequence of DatabaseValueConvertible values.
    /// - returns: A StatementArguments.
    public init<Sequence: Swift.Sequence where Sequence.Iterator.Element == DatabaseValueConvertible?>(_ sequence: Sequence) {
        kind = .values(Array(sequence))
    }
    
    /// Initializes arguments from a sequence of optional values.
    ///
    ///     let values: [String] = ["foo", "bar"]
    ///     db.execute("INSERT ... (?,?)", arguments: StatementArguments(values))
    ///
    /// - parameter sequence: A sequence of DatabaseValueConvertible values.
    /// - returns: A StatementArguments.
    public init<Sequence: Swift.Sequence where Sequence.Iterator.Element: DatabaseValueConvertible>(_ sequence: Sequence) {
        kind = .values(sequence.map { $0 })
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
        kind = .namedValues(dictionary)
    }
    
    /// Initializes arguments from a sequence of (key, value) pairs, such as
    /// a dictionary.
    ///
    ///     let values: [String: DatabaseValueConvertible?] = ["firstName": nil, "lastName": "Miller"]
    ///     db.execute("INSERT ... (:firstName, :lastName)", arguments: StatementArguments(values))
    ///
    /// - parameter sequence: A sequence of (key, value) pairs
    /// - returns: A StatementArguments.
    public init<Sequence: Swift.Sequence where Sequence.Iterator.Element == (String, DatabaseValueConvertible?)>(_ sequence: Sequence) {
        kind = .namedValues(Dictionary(keyValueSequence: sequence))
    }
    
    
    // MARK: Not Public
    
    /// Returns a double optional
    func value(named name: String) -> DatabaseValueConvertible?? {
        switch kind {
        case .values:
            return nil
        case .namedValues(let dictionary):
            return dictionary[name]
        }
    }
    
    enum Kind {
        case values([DatabaseValueConvertible?])
        case namedValues(Dictionary<String, DatabaseValueConvertible?>)
    }
    
    let kind: Kind
}

extension StatementArguments : ArrayLiteralConvertible {
    /// Returns a StatementArguments from an array literal:
    ///
    ///     db.selectRows("SELECT ...", arguments: ["Arthur", 41])
    public init(arrayLiteral elements: DatabaseValueConvertible?...) {
        self.init(elements)
    }
}

extension StatementArguments : DictionaryLiteralConvertible {
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
        switch kind {
        case .values(let values):
            return "["
                + values
                    .map { value in
                        if let value = value {
                            return String(reflecting: value)
                        } else {
                            return "nil"
                        }
                    }
                    .joined(separator: ", ")
                + "]"
            
        case .namedValues(let namedValues):
            return "["
                + namedValues.map { (key, value) in
                    if let value = value {
                        return "\(key):\(String(reflecting: value))"
                    } else {
                        return "\(key):nil"
                    }
                    }
                    .joined(separator: ", ")
                + "]"
        }
    }
}
