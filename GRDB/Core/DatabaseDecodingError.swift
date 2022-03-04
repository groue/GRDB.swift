/// An error that occurs during the decoding of database values.
public enum DatabaseDecodingError: Error {
    /// The context in which the error occurred.
    public struct Context: CustomDebugStringConvertible, Sendable {
        /// A description of what went wrong, for debugging purposes.
        public let debugDescription: String
        
        /// The row that could not be decoded.
        public var row: Row { Row(impl: rowImpl) }
        
        /// The eventual SQL query
        public let sql: String?
        
        /// The eventual SQL query arguments
        public let statementArguments: StatementArguments?
        
        let rowImpl: ArrayRowImpl // Sendable
        let key: RowDecodingKey
        
        init(decodingContext: RowDecodingContext, debugDescription: String) {
            self.debugDescription = debugDescription
            self.rowImpl = ArrayRowImpl(columns: decodingContext.row)
            self.key = decodingContext.key
            self.sql = decodingContext.sql
            self.statementArguments = decodingContext.statementArguments
        }
    }
    
    /// The key that was not found in the database row.
    public enum Key: CustomStringConvertible {
        /// A column was not found
        case column(String)
        
        /// A scope was not found
        ///
        /// When decoding an associated record, no association was found with
        /// a matching association key.
        case scope(String)
        
        /// A prefetch key was not found
        ///
        /// When decoding a collection of associated records, no association was
        /// found with a matching association key.
        case prefetchKey(String)
        
        /// A `DatabaseColumnDecodingStrategy` could not
        /// match a database column with the provided coding key.
        case codingKey(CodingKey)
        
        public var description: String {
            switch self {
            case .column(let column):
                return "column \(String(reflecting: column))"
            case .scope(let scope):
                return "scope \(String(reflecting: scope))"
            case .prefetchKey(let prefetchKey):
                return "prefetch key \(String(reflecting: prefetchKey))"
            case .codingKey(let codingKey):
                return "coding key \(codingKey)"
            }
        }
    }
    
    /// Decoding failed because a key was not found.
    case keyNotFound(Key, Context)
    
    /// Decoding failed because the database value does not match the
    /// decoded type.
    case valueMismatch(Any.Type, Context)
    
    var context: Context {
        switch self {
        case .keyNotFound(_, let context),
             .valueMismatch(_, let context):
            return context
        }
    }
    
    /// Convenience method that builds the
    /// `could not decode <Type> from database value <value>` error message.
    static func valueMismatch(
        _ type: Any.Type,
        context: RowDecodingContext,
        databaseValue: DatabaseValue)
    -> Self
    {
        valueMismatch(
            type,
            DatabaseDecodingError.Context(decodingContext: context, debugDescription: """
                could not decode \(type) from database value \(databaseValue)
                """))
    }
    
    /// Convenience method that builds the
    /// `could not decode <Type> from database value <value>` error message.
    @usableFromInline
    static func valueMismatch(
        _ type: Any.Type,
        sqliteStatement: SQLiteStatement,
        index: Int32,
        context: RowDecodingContext)
    -> Self
    {
        valueMismatch(
            type,
            context: context,
            databaseValue: DatabaseValue(sqliteStatement: sqliteStatement, index: index))
    }
    
    /// Convenience method that builds the
    /// `could not decode <Type> from database value <value>` error message.
    static func valueMismatch(
        _ type: Any.Type,
        statement: Statement,
        index: Int)
    -> Self
    {
        valueMismatch(
            type,
            context: RowDecodingContext(statement: statement, index: index),
            databaseValue: DatabaseValue(sqliteStatement: statement.sqliteStatement, index: Int32(index)))
    }
    
    /// Convenience method that builds the `column not found: <column>`
    /// error message.
    @usableFromInline
    static func columnNotFound(_ columnName: String, context: RowDecodingContext) -> Self {
        let columns = context.row.columnNames
        if columns.isEmpty {
            return keyNotFound(.column(columnName), DatabaseDecodingError.Context(
                decodingContext: context,
                debugDescription: """
                    column not found: \(String(reflecting: columnName))
                    """))
        } else {
            return keyNotFound(.column(columnName), DatabaseDecodingError.Context(
                decodingContext: context,
                debugDescription: """
                    column not found: \(String(reflecting: columnName)) - \
                    available columns: \(columns.sorted())
                    """))
        }
    }
}

/// A key that is used to decode a value in a row
@usableFromInline
enum RowDecodingKey: Hashable, Sendable {
    /// A column name
    case columnName(String)
    
    /// A column index
    case columnIndex(Int)
    
    /// A row scope
    case scope(String)
    
    /// A prefetch key
    case prefetchKey(String)
}

@usableFromInline
struct RowDecodingContext {
    /// The row that is decoded
    let row: Row
    
    /// The key that could not be decoded
    let key: RowDecodingKey
    
    /// The SQL query
    let sql: String?
    
    /// The SQL query arguments
    let statementArguments: StatementArguments?
    
    @usableFromInline
    init(row: Row, key: RowDecodingKey) {
        if let statement = row.statement {
            self.key = key
            self.row = row.copy()
            self.sql = statement.sql
            self.statementArguments = statement.arguments
        } else if let sqliteStatement = row.sqliteStatement {
            self.key = key
            self.row = row.copy()
            self.sql = String(cString: sqlite3_sql(sqliteStatement)).trimmingCharacters(in: .sqlStatementSeparators)
            self.statementArguments = nil // Can't rebuild them
        } else {
            self.key = key
            self.row = row.copy()
            self.sql = nil
            self.statementArguments = nil
        }
    }
    
    /// Convenience initializer
    @usableFromInline
    init(statement: Statement, index: Int) {
        self.key = .columnIndex(index)
        self.row = Row(copiedFromSQLiteStatement: statement.sqliteStatement, statement: statement)
        self.sql = statement.sql
        self.statementArguments = statement.arguments
    }
}

extension DatabaseDecodingError: CustomStringConvertible {
    public var description: String {
        _description(publicStatementArguments: false)
    }
    
    /// The error description, where statement arguments, if present,
    /// are visible.
    ///
    /// - warning: It is your responsibility to prevent sensitive
    ///   information from leaking in unexpected locations, so use this
    ///   property with care.
    public var expandedDescription: String {
        _description(publicStatementArguments: true)
    }
    
    /// The error description, with or without statement arguments.
    private func _description(publicStatementArguments: Bool) -> String {
        let context = self.context
        let row = context.row
        var chunks: [String] = []
        
        switch context.key {
        case let .columnIndex(columnIndex):
            let rowIndex = row.index(row.startIndex, offsetBy: columnIndex)
            let columnName = row.columnNames[rowIndex]
            chunks.append("column: \(String(reflecting: columnName))")
            chunks.append("column index: \(columnIndex)")
            
        case let .columnName(columnName):
            if let columnIndex = row.index(forColumn: columnName) {
                chunks.append("column: \(String(reflecting: columnName))")
                chunks.append("column index: \(columnIndex)")
            } else {
                // column name is already mentioned in context.debugDescription
            }
            
        case .prefetchKey:
            // key is already mentioned in context.debugDescription
            break
            
        case .scope:
            // scope is already mentioned in context.debugDescription
            break
        }
        
        chunks.append("row: \(row.description)")
        
        if let sql = context.sql {
            chunks.append("sql: `\(sql)`")
        }
        
        if publicStatementArguments, let statementArguments = context.statementArguments {
            chunks.append("arguments: \(statementArguments)")
        }
        
        return "\(context.debugDescription) - \(chunks.joined(separator: ", "))"
    }
}
