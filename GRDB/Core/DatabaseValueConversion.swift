#if SWIFT_PACKAGE
    import CSQLite
#elseif !GRDBCUSTOMSQLITE && !GRDBCIPHER
    import SQLite3
#endif

// All primitive value conversion methods.

/// A type that helps the user understanding value conversion errors
struct ValueConversionDebuggingInfo {
    enum Source {
        case statement(SelectStatement)
        case sql(String, StatementArguments)
        case row(Row)
    }
    enum Column {
        case columnIndex(Int)
        case columnName(String)
    }
    private var source: Source?
    private var column: Column?
    
    init(_ source: Source? = nil, _ column: Column? = nil) {
        self.source = source
        self.column = column
    }
    
    var sql: String? {
        guard let source = source else { return nil }
        switch source {
        case .statement(let statement):
            return statement.sql
        case .row(let row):
            return row.statement?.sql
        case .sql(let sql, _):
            return sql
        }
    }
    
    var arguments: StatementArguments? {
        guard let source = source else { return nil }
        switch source {
        case .statement(let statement):
            return statement.arguments
        case .row(let row):
            return row.statement?.arguments
        case .sql(_, let arguments):
            return arguments
        }
    }
    
    var row: Row? {
        guard let source = source else { return nil }
        switch source {
        case .statement(let statement):
            return Row(statement: statement)
        case .row(let row):
            return row
        case .sql:
            return nil
        }
    }
    
    var columnIndex: Int? {
        guard let column = column else { return nil }
        switch column {
        case .columnIndex(let index):
            return index
        case .columnName(let name):
            return row?.index(ofColumn: name)
        }
    }
    
    var columnName: String? {
        guard let column = column else { return nil }
        switch column {
        case .columnIndex(let index):
            guard let row = row else { return nil }
            let rowIndex = row.index(row.startIndex, offsetBy: index)
            return row[rowIndex].0
        case .columnName(let name):
            return name
        }
    }
}

/// The canonical conversion error message
func conversionErrorMessage<T>(to: T.Type, from dbValue: DatabaseValue, debugInfo: ValueConversionDebuggingInfo) -> String {
    var message = "could not convert database value \(dbValue) to \(T.self)"
    var extras: [String] = []
    if let columnName = debugInfo.columnName {
        extras.append("column: `\(columnName)`")
    }
    if let columnIndex = debugInfo.columnIndex {
        extras.append("column index: \(columnIndex)")
    }
    if let row = debugInfo.row {
        extras.append("row: \(row)")
    }
    if let sql = debugInfo.sql {
        extras.append("statement: `\(sql)`")
        if let arguments = debugInfo.arguments, arguments.isEmpty == false {
            extras.append("arguments: \(arguments)")
        }
    }
    if extras.isEmpty == false {
        message += " (" + extras.joined(separator: ", ") + ")"
    }
    return message
}

/// The canonical conversion fatal error
func fatalConversionError<T>(to: T.Type, from dbValue: DatabaseValue, debugInfo: ValueConversionDebuggingInfo, file: StaticString = #file, line: UInt = #line) -> Never {
    fatalError(conversionErrorMessage(to: T.self, from: dbValue, debugInfo: debugInfo), file: file, line: line)
}

extension DatabaseValueConvertible {
    /// Performs lossless conversion from a database value.
    static func decode(from dbValue: DatabaseValue, debugInfo: @autoclosure () -> ValueConversionDebuggingInfo) -> Self {
        if let value = fromDatabaseValue(dbValue) {
            return value
        } else {
            fatalConversionError(to: Self.self, from: dbValue, debugInfo: debugInfo())
        }
    }
    
    /// Performs lossless conversion from a database value.
    static func decodeIfPresent(from dbValue: DatabaseValue, debugInfo: @autoclosure () -> ValueConversionDebuggingInfo) -> Self? {
        // Use fromDatabaseValue before checking for null: this allows DatabaseValue to convert NULL to .null.
        if let value = fromDatabaseValue(dbValue) {
            return value
        } else if dbValue.isNull {
            return nil
        } else {
            fatalConversionError(to: Self.self, from: dbValue, debugInfo: debugInfo())
        }
    }
}

extension DatabaseValueConvertible where Self: StatementColumnConvertible {
    
    /// Performs lossless conversion from a statement value.
    @inline(__always)
    static func decode(from sqliteStatement: SQLiteStatement, index: Int32, debugInfo: @autoclosure () -> ValueConversionDebuggingInfo) -> Self {
        if sqlite3_column_type(sqliteStatement, index) == SQLITE_NULL {
            fatalConversionError(to: Self.self, from: .null, debugInfo: debugInfo())
        }
        return self.init(sqliteStatement: sqliteStatement, index: index)
    }
    
    /// Performs lossless conversion from a statement value.
    @inline(__always)
    static func decodeIfPresent(from sqliteStatement: SQLiteStatement, index: Int32) -> Self? {
        if sqlite3_column_type(sqliteStatement, index) == SQLITE_NULL {
            return nil
        }
        return self.init(sqliteStatement: sqliteStatement, index: index)
    }
}

extension Row {
    
    @inline(__always)
    func decodeIfPresent<Value: DatabaseValueConvertible>(
        _ type: Value.Type,
        atUncheckedIndex index: Int,
        debugInfo: @autoclosure () -> ValueConversionDebuggingInfo) -> Value?
    {
        return Value.decodeIfPresent(from: impl.databaseValue(atUncheckedIndex: index), debugInfo: debugInfo)
    }
    
    @inline(__always)
    func decode<Value: DatabaseValueConvertible>(
        _ type: Value.Type,
        atUncheckedIndex index: Int,
        debugInfo: @autoclosure () -> ValueConversionDebuggingInfo) -> Value
    {
        return Value.decode(from: impl.databaseValue(atUncheckedIndex: index), debugInfo: debugInfo)
    }
    
    @inline(__always)
    func fastDecodeIfPresent<Value: DatabaseValueConvertible & StatementColumnConvertible>(
        _ type: Value.Type,
        atUncheckedIndex index: Int,
        debugInfo: @autoclosure () -> ValueConversionDebuggingInfo) -> Value?
    {
        if let sqliteStatement = sqliteStatement {
            return Value.decodeIfPresent(from: sqliteStatement, index: Int32(index))
        }
        return impl.fastDecodeIfPresent(Value.self, atUncheckedIndex: index, debugInfo: debugInfo)
    }
    
    @inline(__always)
    func fastDecode<Value: DatabaseValueConvertible & StatementColumnConvertible>(
        _ type: Value.Type,
        atUncheckedIndex index: Int,
        debugInfo: @autoclosure () -> ValueConversionDebuggingInfo) -> Value
    {
        if let sqliteStatement = sqliteStatement {
            return Value.decode(from: sqliteStatement, index: Int32(index), debugInfo: debugInfo)
        }
        return impl.fastDecode(Value.self, atUncheckedIndex: index, debugInfo: debugInfo)
    }
}
