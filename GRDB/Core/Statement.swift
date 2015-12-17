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
    
    /// The query arguments
    public var arguments: StatementArguments? {
        didSet {
            validateArguments()
            reset() // necessary before applying new arguments
            clearBindings()
            if let arguments = arguments {
                arguments.bindInStatement(self)
            }
        }
    }
    
    // MARK: - Not public
    
    /// The database
    let database: Database
    
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
            fatalError("Invalid SQL string: multiple statements found. To execute multiple statements, use Database.executeMultiStatement() instead.")
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
    
    
    // MARK: - Arguments
    
    private var argumentCount: Int {
        return Int(sqlite3_bind_parameter_count(sqliteStatement))
    }
    
    private lazy var sqliteArgumentNames: Set<String> = { [unowned self] in
        let sqliteStatement = self.sqliteStatement
        var argumentNames = Set<String>()
        for i in 1...self.argumentCount {
            if let name = String.fromCString(sqlite3_bind_parameter_name(sqliteStatement, Int32(i))) {
                argumentNames.insert(name)
            }
        }
        return argumentNames
    }()
    
    func validateArguments() {
        if let argumentsKind = arguments?.kind {
            switch argumentsKind {
            case .Default:
                fatalError("Invalid StatementArguments.Default arguments in `\(sql)`.")
            case .Array(count: let count):
                if count != argumentCount {
                    fatalError("SQLite statement arguments mismatch: got \(count) argument(s) instead of \(argumentCount) in `\(sql)`.")
                }
            case .Dictionary(keys: let keys):
                let inputArgumentNames = keys.map { ":\($0)" }
                if Set(inputArgumentNames) != sqliteArgumentNames {
                    func caseInsensitiveSort(strings: [String]) -> [String] {
                        return strings
                            .map { ($0.lowercaseString, $0) }
                            .sort { $0.0 < $1.0 }
                            .map { $0.1 }
                    }
                    let input = caseInsensitiveSort(inputArgumentNames).joinWithSeparator(",")
                    let expected = caseInsensitiveSort(Array(sqliteArgumentNames)).joinWithSeparator(",")
                    fatalError("SQLite statement argument names mismatch: got [\(input)] instead of [\(expected)] in `\(sql)`.")
                }
            }
        } else if argumentCount > 0 {
            fatalError("SQLite statement arguments mismatch: got 0 argument(s) instead of \(argumentCount) in `\(sql)`.")
        }
    }
    
    // Exposed for StatementArguments. Don't make this one public unless we keep
    // the arguments property in sync.
    //
    // As in sqlite3_bind_xxx methods, index is one-based.
    final func setArgument(value: DatabaseValueConvertible?, atIndex index: Int) {
        let databaseValue = value?.databaseValue ?? .Null
        let code: Int32
        
        switch databaseValue.storage {
        case .Null:
            code = sqlite3_bind_null(sqliteStatement, Int32(index))
        case .Int64(let int64):
            code = sqlite3_bind_int64(sqliteStatement, Int32(index), int64)
        case .Double(let double):
            code = sqlite3_bind_double(sqliteStatement, Int32(index), double)
        case .String(let string):
            code = sqlite3_bind_text(sqliteStatement, Int32(index), string, -1, SQLITE_TRANSIENT)
        case .Blob(let data):
            code = sqlite3_bind_blob(sqliteStatement, Int32(index), data.bytes, Int32(data.length), SQLITE_TRANSIENT)
        }
        
        if code != SQLITE_OK {
            fatalError(DatabaseError(code: code, message: database.lastErrorMessage, sql: sql).description)
        }
    }
    
    // Exposed for StatementArguments. Don't make this one public unless we keep
    // the arguments property in sync.
    final func setArgument(value: DatabaseValueConvertible?, forKey key: String) {
        let argumentName = ":\(key)"
        let index = Int(sqlite3_bind_parameter_index(sqliteStatement, argumentName))
        precondition(index > 0, "Argument not found in SQLite statement: `\(argumentName)`")
        setArgument(value, atIndex: index)
    }
    
    // Don't make this one public unless we keep the arguments property in sync.
    private func clearBindings() {
        let code = sqlite3_clear_bindings(sqliteStatement)
        if code != SQLITE_OK {
            fatalError(DatabaseError(code: code, message: database.lastErrorMessage, sql: sql).description)
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
