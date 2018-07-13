// All primitive value conversion methods.

/// An alternative to try!, preferred for conversion methods.
@inline(__always)
func require<T>(file: StaticString = #file, line: UInt = #line, block: () throws -> T) -> T {
    do {
        return try block()
    } catch {
        fatalError(String(describing: error), file: file, line: line)
    }
}

/// A type that helps the user understanding value conversion errors
struct ValueConversionDebuggingInfo {
    private var _statement: SelectStatement?
    private var _row: Row?
    private var _columnIndex: Int?
    private var _columnName: String?
    
    init(statement: SelectStatement? = nil, row: Row? = nil, columnIndex: Int? = nil, columnName: String? = nil) {
        _statement = statement
        _row = row
        _columnIndex = columnIndex
        _columnName = columnName
    }
    
    var statement: SelectStatement? {
        return _statement ?? _row?.statement
    }
    
    var row: Row? {
        return _row ?? _statement.map { Row(statement: $0) }
    }
    
    var columnIndex: Int? {
        if let columnIndex = _columnIndex {
            return columnIndex
        }
        if let columnName = _columnName, let row = row {
            return row.index(ofColumn: columnName)
        }
        return nil
    }
    
    var columnName: String? {
        if let columnName = _columnName {
            return columnName
        }
        if let columnIndex = _columnIndex, let row = row {
            let rowIndex = row.index(row.startIndex, offsetBy: columnIndex)
            return row[rowIndex].0
        }
        return nil
    }
}

/// A conversion error
struct ValueConversionError<T>: Error, CustomStringConvertible {
    var dbValue: DatabaseValue
    var debugInfo: ValueConversionDebuggingInfo
    
    var description: String {
        var error = "could not convert database value \(dbValue) to \(T.self)"
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
        if let statement = debugInfo.statement {
            extras.append("statement: `\(statement.sql)`")
            if statement.arguments.isEmpty == false {
                extras.append("arguments: \(statement.arguments)")
            }
        }
        if extras.isEmpty == false {
            error += " (" + extras.joined(separator: ", ") + ")"
        }
        return error
    }
}

extension DatabaseValueConvertible {
    /// Performs lossless conversion from a database value.
    ///
    /// - throws: ValueConversionError<Self>
    static func decode(from dbValue: DatabaseValue, debugInfo: @autoclosure () -> ValueConversionDebuggingInfo) throws -> Self {
        if let value = fromDatabaseValue(dbValue) {
            return value
        } else {
            throw ValueConversionError<Self>(dbValue: dbValue, debugInfo: debugInfo())
        }
    }
    
    /// Performs lossless conversion from a database value.
    ///
    /// - throws: ValueConversionError<Self>
    static func decodeIfPresent(from dbValue: DatabaseValue, debugInfo: @autoclosure () -> ValueConversionDebuggingInfo) throws -> Self? {
        // Use fromDatabaseValue before checking for null: this allows DatabaseValue to convert NULL to .null.
        if let value = fromDatabaseValue(dbValue) {
            return value
        } else if dbValue.isNull {
            return nil
        } else {
            throw ValueConversionError<Self>(dbValue: dbValue, debugInfo: debugInfo())
        }
    }
}

extension DatabaseValueConvertible where Self: StatementColumnConvertible {
    
    /// Performs lossless conversion from a statement value.
    ///
    /// - throws: ValueConversionError<Self>
    @inline(__always)
    static func decode(from sqliteStatement: SQLiteStatement, index: Int32, debugInfo: @autoclosure () -> ValueConversionDebuggingInfo) throws -> Self {
        if sqlite3_column_type(sqliteStatement, index) == SQLITE_NULL {
            throw ValueConversionError<Self>(dbValue: .null, debugInfo: debugInfo())
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
        debugInfo: @autoclosure () -> ValueConversionDebuggingInfo) throws -> Value?
    {
        return try Value.decodeIfPresent(from: impl.databaseValue(atUncheckedIndex: index), debugInfo: debugInfo)
    }
    
    @inline(__always)
    func decode<Value: DatabaseValueConvertible>(
        _ type: Value.Type,
        atUncheckedIndex index: Int,
        debugInfo: @autoclosure () -> ValueConversionDebuggingInfo) throws -> Value
    {
        return try Value.decode(from: impl.databaseValue(atUncheckedIndex: index), debugInfo: debugInfo)
    }
    
    @inline(__always)
    func fastDecodeIfPresent<Value: DatabaseValueConvertible & StatementColumnConvertible>(
        _ type: Value.Type,
        atUncheckedIndex index: Int,
        debugInfo: @autoclosure () -> ValueConversionDebuggingInfo) throws -> Value?
    {
        if let sqliteStatement = sqliteStatement {
            return Value.decodeIfPresent(from: sqliteStatement, index: Int32(index))
        }
        return try impl.fastDecodeIfPresent(Value.self, atUncheckedIndex: index, debugInfo: debugInfo)
    }
    
    @inline(__always)
    func fastDecode<Value: DatabaseValueConvertible & StatementColumnConvertible>(
        _ type: Value.Type,
        atUncheckedIndex index: Int,
        debugInfo: @autoclosure () -> ValueConversionDebuggingInfo) throws -> Value
    {
        if let sqliteStatement = sqliteStatement {
            return try Value.decode(from: sqliteStatement, index: Int32(index), debugInfo: debugInfo)
        }
        return try impl.fastDecode(Value.self, atUncheckedIndex: index, debugInfo: debugInfo)
    }
}
