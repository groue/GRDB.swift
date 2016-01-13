/// A raw SQLite statement, suitable for the SQLite C API.
public typealias SQLiteStatement = COpaquePointer

/// A statement represents a SQL query.
///
/// It is the base class of UpdateStatement that executes *update statements*,
/// and SelectStatement that fetches rows.
public class Statement {
    
    /// The raw SQLite statement, suitable for the SQLite C API.
    public let sqliteStatement: SQLiteStatement
    
    /// The SQL query
    public let sql: String
    
    /// The statement arguments
    public var arguments: StatementArguments {
        get { return _arguments }
        set { try! setArgumentsWithValidation(newValue) }
    }
    
    
    // MARK: Not public
    
    /// The database
    let database: Database
    
    init(database: Database, sql: String, sqliteStatement: SQLiteStatement) {
        self.database = database
        self.sql = sql
        self.sqliteStatement = sqliteStatement
    }
    
    init(database: Database, sql: String) throws {
        database.preconditionValidQueue()
        
        // See https://www.sqlite.org/c3ref/prepare.html
        
        let sqlCodeUnits = sql.nulTerminatedUTF8
        var sqliteStatement: SQLiteStatement = nil
        var consumedCharactersCount: Int = 0
        var code: Int32 = 0
        sqlCodeUnits.withUnsafeBufferPointer { codeUnits in
            let sqlHead = UnsafePointer<Int8>(codeUnits.baseAddress)
            var sqlTail: UnsafePointer<Int8> = nil
            code = sqlite3_prepare_v2(database.sqliteConnection, sqlHead, -1, &sqliteStatement, &sqlTail)
            consumedCharactersCount = sqlTail - sqlHead + 1
        }
        
        self.database = database
        self.sql = sql
        self.sqliteStatement = sqliteStatement
        
        guard code == SQLITE_OK else {
            throw DatabaseError(code: code, message: database.lastErrorMessage, sql: sql)
        }
        
        guard consumedCharactersCount == sqlCodeUnits.count else {
            throw DatabaseError(code: SQLITE_MISUSE, message: "Invalid SQL string: multiple statements found. To execute multiple statements, use Database.execute() instead.", sql: sql, arguments: nil)
        }
    }
    
    deinit {
        if sqliteStatement != nil {
            sqlite3_finalize(sqliteStatement)
        }
    }
    
    // Not public until a need for it.
    final func reset() {
        let code = sqlite3_reset(sqliteStatement)
        if code != SQLITE_OK {
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
    private lazy var sqliteArgumentNames: [String?] = {
        guard self.sqliteArgumentCount > 0 else {
            return []
        }
        return (1...self.sqliteArgumentCount).map {
            guard let parameterName = String.fromCString(sqlite3_bind_parameter_name(self.sqliteStatement, Int32($0))) else {
                return nil
            }
            return String(parameterName.characters.dropFirst()) // Drop initial ":"
        }
    }()
    
    /// Set arguments without any validation. Trades safety for performance.
    func unsafeSetArguments(arguments: StatementArguments) {
        _arguments = arguments
        argumentsNeedValidation = false
        
        // Apply
        reset()
        clearBindings()
        
        switch arguments.kind {
        case .Values(let values):
            for (index, value) in values.enumerate() {
                try! bindDatabaseValue(value?.databaseValue ?? .Null, atIndex: Int32(index + 1))
            }
            break
        case .NamedValues(let namedValues):
            // TODO: test
            for (index, argumentName) in sqliteArgumentNames.enumerate() {
                if let argumentName = argumentName {
                    for (name, value) in namedValues where name == argumentName {
                        try! bindDatabaseValue(value?.databaseValue ?? .Null, atIndex: Int32(index + 1))
                        break
                    }
                }
            }
        }
    }
    
    private func setArgumentsWithValidation(arguments: StatementArguments) throws {
        // Validate
        let bindings = try validatedBindings(arguments)
        _arguments = arguments
        argumentsNeedValidation = false
        
        // Apply
        reset()
        clearBindings()
        for (index, databaseValue) in bindings.enumerate() {
            try bindDatabaseValue(databaseValue, atIndex: Int32(index + 1))
        }
    }
    
    private func bindDatabaseValue(databaseValue: DatabaseValue, atIndex index: Int32) throws {
        let code: Int32
        switch databaseValue.storage {
        case .Null:
            code = sqlite3_bind_null(sqliteStatement, index)
        case .Int64(let int64):
            code = sqlite3_bind_int64(sqliteStatement, index, int64)
        case .Double(let double):
            code = sqlite3_bind_double(sqliteStatement, index, double)
        case .String(let string):
            code = sqlite3_bind_text(sqliteStatement, index, string, -1, SQLITE_TRANSIENT)
        case .Blob(let data):
            code = sqlite3_bind_blob(sqliteStatement, index, data.bytes, Int32(data.length), SQLITE_TRANSIENT)
        }
        
        if code != SQLITE_OK {
            throw DatabaseError(code: code, message: database.lastErrorMessage, sql: sql)
        }
    }
    
    /// Throws a DatabaseError of code SQLITE_ERROR if arguments don't fill all
    /// statement arguments.
    public func validateArguments(arguments: StatementArguments) throws {
        let _ = try validatedBindings(arguments)
    }
    
    // Returns a validated array of as many DatabaseValue as there are
    // parameters in the statement.
    @warn_unused_result
    private func validatedBindings(arguments: StatementArguments) throws -> [DatabaseValue] {
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
            case .Values(let values):
                var keyValueBindings: [(String?, DatabaseValue?)] = []
                var argumentNameGen = sqliteArgumentNames.generate()
                var valuesGen = values.map { $0?.databaseValue ?? .Null }.generate()
                var argumentNameOpt = argumentNameGen.next()
                var valueOpt = valuesGen.next()
                outer: while true {
                    switch (argumentNameOpt, valueOpt) {
                    case (let argumentName?, let value?):
                        keyValueBindings.append((argumentName, value))
                        argumentNameOpt = argumentNameGen.next()
                        valueOpt = valuesGen.next()
                    case (nil, let value?):
                        keyValueBindings.append((nil, value))
                        valueOpt = valuesGen.next()
                    case (let argumentName?, nil):
                        keyValueBindings.append((argumentName, nil))
                        argumentNameOpt = argumentNameGen.next()
                    case (nil, nil):
                        break outer
                    }
                }
                return keyValueBindings
                
            case .NamedValues(let namedValues):
                return sqliteArgumentNames.map { argumentName in
                    if let argumentName = argumentName {
                        for (name, value) in namedValues where name == argumentName {
                            return (argumentName, value?.databaseValue ?? .Null)
                        }
                        return (argumentName, nil)
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
                func caseInsensitiveSort(strings: [String]) -> [String] {
                    return strings
                        .map { ($0.lowercaseString, $0) }
                        .sort { $0.0 < $1.0 }
                        .map { $0.1 }
                }
                throw DatabaseError(code: SQLITE_MISUSE, message: "missing statement argument(s): \(caseInsensitiveSort(namedMissingKeys).joinWithSeparator(", "))", sql: sql, arguments: nil)
            } else {
                throw DatabaseError(code: SQLITE_MISUSE, message: "wrong number of statement arguments: \(sqliteArgumentCount - missingKeys.count)", sql: sql, arguments: nil)
            }
        }
        
        return keyValueBindings.map { $0.1! }
    }
    
    // Don't make this one public unless we keep the arguments property in sync.
    private func clearBindings() {
        let code = sqlite3_clear_bindings(sqliteStatement)
        if code != SQLITE_OK {
            fatalError(DatabaseError(code: code, message: database.lastErrorMessage, sql: sql).description)
        }
    }

    private func prepareWithArguments(arguments: StatementArguments?) throws {
        if let arguments = arguments {
            try setArgumentsWithValidation(arguments)
        } else if argumentsNeedValidation {
            try validateArguments(self.arguments)
        }
    }
}


// MARK: - SelectStatement

/// A subclass of Statement that fetches database rows.
///
/// You create SelectStatement with the Database.selectStatement() method:
///
///     dbQueue.inDatabase { db in
///         let statement = db.selectStatement("SELECT * FROM persons WHERE age > ?")
///         let moreThanTwentyCount = Int.fetchOne(statement, arguments: [20])!
///         let moreThanThirtyCount = Int.fetchOne(statement, arguments: [30])!
///     }
public final class SelectStatement : Statement {
    
    /// The number of columns in the resulting rows.
    public lazy var columnCount: Int = {
        Int(sqlite3_column_count(self.sqliteStatement))
    }()
    
    /// The column names, ordered from left to right.
    public lazy var columnNames: [String] = {
        (0..<self.columnCount).map { String.fromCString(sqlite3_column_name(self.sqliteStatement, Int32($0)))! }
    }()
    
    
    // MARK: Not public
    
    /// The DatabaseSequence builder.
    func fetch<T>(arguments arguments: StatementArguments?, yield: () -> T) -> DatabaseSequence<T> {
        try! prepareWithArguments(arguments)
        return DatabaseSequence(statement: self, yield: yield)
    }
    
    /// The column index, case insensitive.
    func indexForColumn(named name: String) -> Int? {
        // This is faster than dictionary lookup
        for (index, column) in columnNames.enumerate() {
            if column == name {
                return index
            }
        }
        for (index, column) in columnNames.enumerate() {
            if column.lowercaseString == name.lowercaseString {
                return index
            }
        }
        return nil
    }
}

/// A sequence of elements fetched from the database.
public struct DatabaseSequence<T>: SequenceType {
    private let generateImpl: () -> DatabaseGenerator<T>
    
    private init(statement: SelectStatement, yield: () -> T) {
        generateImpl = {
            let preconditionValidQueue = statement.database.preconditionValidQueue
            let sqliteStatement = statement.sqliteStatement
            
            // Check that sequence is built on a valid queue.
            preconditionValidQueue()
            
            // DatabaseSequence can be restarted:
            statement.reset()
            
            return DatabaseGenerator {
                // Check that generator is used on a valid queue.
                preconditionValidQueue()
                
                let code = sqlite3_step(sqliteStatement)
                switch code {
                case SQLITE_DONE:
                    return nil
                case SQLITE_ROW:
                    return yield()
                default:
                    fatalError(DatabaseError(code: code, message: statement.database.lastErrorMessage, sql: statement.sql, arguments: statement.arguments).description)
                }
            }
        }
    }
    
    init() {
        generateImpl = { return DatabaseGenerator { return nil } }
    }
    
    /// Return a *generator* over the elements of this *sequence*.
    @warn_unused_result
    public func generate() -> DatabaseGenerator<T> {
        return generateImpl()
    }
}

/// A generator of elements fetched from the database.
public struct DatabaseGenerator<T>: GeneratorType {
    private let nextImpl: () -> T?
    public func next() -> T? {
        return nextImpl()
    }
}


// MARK: - UpdateStatement

/// A subclass of Statement that executes SQL queries.
///
/// You create UpdateStatement with the Database.updateStatement() method:
///
///     try dbQueue.inTransaction { db in
///         let statement = try db.updateStatement("INSERT INTO persons (name) VALUES (?)")
///         try statement.execute(arguments: ["Arthur"])
///         try statement.execute(arguments: ["Barbara"])
///         return .Commit
///     }
public final class UpdateStatement : Statement {
    
    /// Executes the SQL query.
    ///
    /// - parameter arguments: Statement arguments.
    /// - returns: A DatabaseChanges.
    /// - throws: A DatabaseError whenever a SQLite error occurs.
    public func execute(arguments arguments: StatementArguments? = nil) throws -> DatabaseChanges {
        try! prepareWithArguments(arguments)    // Crash on invalid arguments
        reset()
        
        let changes: DatabaseChanges
        let code = sqlite3_step(sqliteStatement)
        
        switch code {
        case SQLITE_DONE:
            let changedRowCount = Int(sqlite3_changes(database.sqliteConnection))
            let lastInsertedRowID = sqlite3_last_insert_rowid(database.sqliteConnection)
            let insertedRowID: Int64? = (lastInsertedRowID == 0) ? nil : lastInsertedRowID
            changes = DatabaseChanges(changedRowCount: changedRowCount, insertedRowID: insertedRowID)
            
        case SQLITE_ROW:
            // A row? The UpdateStatement is not supposed to return any...
            //
            // What are our options?
            //
            // 1. throw a DatabaseError with code SQLITE_ROW.
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
            // So let's just silently ignore the row, and return successfully.
            changes = DatabaseChanges(changedRowCount: 0, insertedRowID: nil)
            
        default:
            // This error may be a consequence of an error thrown by
            // TransactionObserverType.transactionWillCommit().
            // Let database handle this case, before throwing a error:
            try database.updateStatementDidFail()
            let errorArguments = self.arguments // self.arguments, not the arguments parameter.
            throw DatabaseError(code: code, message: database.lastErrorMessage, sql: sql, arguments: errorArguments)
        }
        
        // Now that changes information has been loaded, we can trigger database
        // transaction delegate callbacks that may eventually perform more
        // changes to the database.
        database.updateStatementDidExecute()
        
        return changes
    }
}

/// Represents the various changes made to the database via execution of one or
/// more SQL statements.
public struct DatabaseChanges {
    
    /// The number of rows affected by the statement(s)
    public let changedRowCount: Int
    
    /// The inserted Row ID.
    ///
    /// This value is only relevant after the execution of a single INSERT
    /// statement, via Database.execute() or UpdateStatement.execute().
    public let insertedRowID: Int64?
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
    
    // MARK: Positional Arguments
    
    /// Initializes arguments from a sequence of optional values.
    ///
    ///     let values: [String?] = ["foo", "bar", nil]
    ///     db.execute("INSERT ... (?,?,?)", arguments: StatementArguments(values))
    ///
    /// - parameter sequence: A sequence of optional values that adopt the
    ///   DatabaseValueConvertible protocol.
    /// - returns: A StatementArguments.
    public init<Sequence: SequenceType where Sequence.Generator.Element == Optional<DatabaseValueConvertible>>(_ sequence: Sequence) {
        kind = .Values(Array(sequence))
    }
    
    
    // MARK: Named Arguments
    
    /// Initializes arguments from a dictionary of optional values.
    ///
    ///     let values: [String: String?] = ["firstName": nil, "lastName": "Miller"]
    ///     db.execute("INSERT ... (:firstName, :lastName)", arguments: StatementArguments(values))
    ///
    /// - parameter dictionary: A dictionary of optional values that adopt the
    ///   DatabaseValueConvertible protocol.
    /// - returns: A StatementArguments.
//    public init(_ dictionary: [String: DatabaseValueConvertible?]) {
//        kind = .Pairs(dictionary.map({ ($0, $1) }))
//    }
    
    public init<KeyValueSequence: SequenceType where KeyValueSequence.Generator.Element == (String, DatabaseValueConvertible?)>(_ sequence: KeyValueSequence) {
        kind = .NamedValues(Array(sequence))
    }
    
    public var isEmpty: Bool {
        switch kind {
        case .Values(let values):
            return values.isEmpty
        case .NamedValues(let namedValues):
            return namedValues.isEmpty
        }
    }
    
    
    // MARK: Not Public
    
    enum Kind {
        case Values([DatabaseValueConvertible?])
        case NamedValues([(String, DatabaseValueConvertible?)])
    }
    
    let kind: Kind
    
    private init(kind: Kind) {
        self.kind = kind
    }
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
//        var dictionary = [String: DatabaseValueConvertible?]()
//        for (key, value) in elements {
//            dictionary[key] = value
//        }
//        self.init(dictionary)
    }
}

extension StatementArguments : CustomStringConvertible {
    /// A textual representation of `self`.
    public var description: String {
        switch kind {
        case .Values(let values):
            return "["
                + values
                    .map { value in
                        if let value = value {
                            return String(reflecting: value)
                        } else {
                            return "nil"
                        }
                    }
                    .joinWithSeparator(", ")
                + "]"
            
        case .NamedValues(let namedValues):
            return "["
                + namedValues.map { (key, value) in
                    if let value = value {
                        return "\(key):\(String(reflecting: value))"
                    } else {
                        return "\(key):nil"
                    }
                    }
                    .joinWithSeparator(", ")
                + "]"
        }
    }
}


// MARK: - SQLite identifier quoting

extension String {
    /// Returns the receiver, quoted for safe insertion as an identifier in an
    /// SQL query.
    ///
    ///     db.execute("SELECT * FROM \(tableName.quotedDatabaseIdentifier)")
    public var quotedDatabaseIdentifier: String {
        // See https://www.sqlite.org/lang_keywords.html
        return "\"\(self)\""
    }
}
