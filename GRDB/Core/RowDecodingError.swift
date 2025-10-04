// Import C SQLite functions
#if GRDBCIPHER // CocoaPods (SQLCipher subspec)
import SQLCipher
#elseif GRDBFRAMEWORK // GRDB.xcodeproj or CocoaPods (standard subspec)
import SQLite3
#elseif GRDBCUSTOMSQLITE // GRDBCustom Framework
// #elseif SomeTrait
// import ...
#else // Default SPM trait must be the default. It impossible to detect from Xcode.
import GRDBSQLite
#endif

/// A key that is used to decode a value in a row
@usableFromInline
enum RowKey: Hashable, Sendable {
    /// A column name
    case columnName(String)
    
    /// A column index
    case columnIndex(Int)
    
    /// A scope
    case scope(String)
    
    /// A key of prefetched rows
    case prefetchKey(String)
}

/// A decoding error thrown when decoding a database row.
///
/// For example:
///
/// ```swift
/// let row = try Row.fetchOne(db, sql: "SELECT NULL AS name")!
/// // RowDecodingError: could not decode String from database value NULL.
/// let name = try row.decode(String.self, forColumn: "name")
/// ```
public struct RowDecodingError: Error {
    enum Impl {
        case keyNotFound(RowKey, Context)
        case valueMismatch(Any.Type, Context)
    }
    
    @usableFromInline
    struct Context: CustomDebugStringConvertible, Sendable {
        /// A description of what went wrong, for debugging purposes.
        @usableFromInline
        let debugDescription: String
        
        let rowImpl: ArrayRowImpl // Sendable
        
        /// The row that could not be decoded
        var row: Row { Row(impl: rowImpl) }
        
        /// Nil for RowDecodingError.keyNotFound, in order to avoid redundancy
        let key: RowKey?
        
        /// The SQL query
        let sql: String?
        
        /// The SQL query arguments
        let statementArguments: StatementArguments?
        
        init(decodingContext: RowDecodingContext, debugDescription: String) {
            self.debugDescription = debugDescription
            self.rowImpl = ArrayRowImpl(columns: decodingContext.row)
            self.key = decodingContext.key
            self.sql = decodingContext.sql
            self.statementArguments = decodingContext.statementArguments
        }
    }
    
    var impl: Impl
    var context: Context {
        switch impl {
        case .keyNotFound(_, let context),
             .valueMismatch(_, let context):
            return context
        }
    }
    
    static func valueMismatch(_ type: Any.Type, _ context: Context) -> Self {
        self.init(impl: .valueMismatch(type, context))
    }
    
    /// Convenience method that builds the
    /// `could not decode <Type> from database value <value>` error message.
    static func valueMismatch(
        _ type: Any.Type,
        context: RowDecodingContext,
        databaseValue: DatabaseValue)
    -> Self
    {
        let context = RowDecodingError.Context(decodingContext: context, debugDescription: """
            could not decode \(type) from database value \(databaseValue)
            """)
        return self.init(impl: .valueMismatch(type, context))
    }
    
    /// Convenience method that builds the
    /// `could not decode <Type> from database value <value>` error message.
    @usableFromInline
    static func valueMismatch(
        _ type: Any.Type,
        sqliteStatement: SQLiteStatement,
        index: CInt,
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
            databaseValue: DatabaseValue(sqliteStatement: statement.sqliteStatement, index: CInt(index)))
    }
    
    /// Convenience method that builds the `column not found: <column>`
    /// error message.
    @usableFromInline
    static func columnNotFound(_ columnName: String, context: RowDecodingContext) -> Self {
        self.init(impl: .keyNotFound(
            .columnName(columnName),
            RowDecodingError.Context(decodingContext: context, debugDescription: """
                column not found: \(String(reflecting: columnName))
                """)))
    }
    
    static func keyNotFound(_ rowKey: RowKey, _ context: Context) -> Self {
        self.init(impl: .keyNotFound(rowKey, context))
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
            self.sql = String(cString: sqlite3_sql(sqliteStatement)).trimmedSQLStatement
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
    public var description: String {
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
                    // column name is already mentioned in context.debugDescription
                }
                
            case .prefetchKey:
                // key is already mentioned in context.debugDescription
                break
                
            case .scope:
                // scope is already mentioned in context.debugDescription
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
