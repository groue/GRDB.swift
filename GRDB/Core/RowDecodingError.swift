/// A key that is used to decode a value in a row
@usableFromInline
enum RowKey: Hashable {
    /// A column name
    case columnName(String)
    
    /// A column index
    case columnIndex(Int)
    
    /// A scope
    case scope(String)
    
    /// A key of prefetched rows
    case prefetchKey(String)
}

/// A decoding error
@usableFromInline
enum RowDecodingError: Error {
    @usableFromInline
    struct Context: CustomDebugStringConvertible {
        /// A description of what went wrong, for debugging purposes.
        @usableFromInline
        let debugDescription: String
        
        /// The row that could not be decoded
        let row: Row
        
        /// Nil for RowDecodingError.keyNotFound, in order to avoid redundancy
        let key: RowKey?
        
        /// The SQL query
        let sql: String?
        
        /// The SQL query arguments
        let statementArguments: StatementArguments?
        
        init(decodingContext: RowDecodingContext, debugDescription: String) {
            self.debugDescription = debugDescription
            self.row = decodingContext.row
            self.key = decodingContext.key
            self.sql = decodingContext.sql
            self.statementArguments = decodingContext.statementArguments
        }
    }
    
    case keyNotFound(RowKey, Context)
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
            RowDecodingError.Context(decodingContext: context, debugDescription: """
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
        keyNotFound(
            .columnName(columnName),
            RowDecodingError.Context(decodingContext: context, debugDescription: """
                column not found: \(String(reflecting: columnName))
                """))
    }
}

@usableFromInline
struct RowDecodingContext {
    /// The row that is decoded
    let row: Row
    
    let key: RowKey?
    
    /// The SQL query
    let sql: String?
    
    /// The SQL query arguments
    let statementArguments: StatementArguments?
    
    @usableFromInline
    init(row: Row, key: RowKey? = nil) {
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

extension RowDecodingError: CustomStringConvertible {
    @usableFromInline
    var description: String {
        let context = self.context
        let row = context.row
        var chunks: [String] = []
        
        if let key = context.key {
            switch key {
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
                    // column name is already mentionned in context.debugDescription
                }
                
            case .prefetchKey:
                // key is already mentionned in context.debugDescription
                break
                
            case .scope:
                // scope is already mentionned in context.debugDescription
                break
            }
        }
        
        chunks.append("row: \(row.description)")
        
        if let sql = context.sql {
            chunks.append("sql: `\(sql)`")
        }
        
        if let statementArguments = context.statementArguments {
            chunks.append("arguments: \(statementArguments)")
        }
        
        return "\(context.debugDescription) - \(chunks.joined(separator: ", "))"
    }
}
