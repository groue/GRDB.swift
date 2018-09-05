#if SWIFT_PACKAGE
    import CSQLite
#elseif !GRDBCUSTOMSQLITE && !GRDBCIPHER
    import SQLite3
#endif

// MARK: - Conversion Context and Errors

/// A type that helps the user understanding value conversion errors
struct ValueConversionContext {
    private enum Column {
        case columnIndex(Int)
        case columnName(String)
    }
    var row: Row?
    var sql: String?
    var arguments: StatementArguments?
    private var column: Column?
    
    func atColumn(_ columnIndex: Int) -> ValueConversionContext {
        var result = self
        result.column = .columnIndex(columnIndex)
        return result
    }
    
    func atColumn(_ columnName: String) -> ValueConversionContext {
        var result = self
        result.column = .columnName(columnName)
        return result
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
            return Array(row.columnNames)[index]
        case .columnName(let name):
            return name
        }
    }
}

extension ValueConversionContext {
    init(_ statement: SelectStatement) {
        self.init(
            row: Row(statement: statement).copy(),
            sql: statement.sql,
            arguments: statement.arguments,
            column: nil)
    }
    
    init(_ row: Row) {
        if let statement = row.statement {
            self.init(
                row: row.copy(),
                sql: statement.sql,
                arguments: statement.arguments,
                column: nil)
        } else if let sqliteStatement = row.sqliteStatement {
            let sql = String(cString: sqlite3_sql(sqliteStatement)).trimmingCharacters(in: statementSeparatorCharacterSet)
            self.init(
                row: row.copy(),
                sql: sql,
                arguments: nil,
                column: nil)
        } else {
            self.init(
                row: row.copy(),
                sql: nil,
                arguments: nil,
                column: nil)
        }
    }
    
    init(sql: String, arguments: StatementArguments?) {
        self.init(
            row: nil,
            sql: sql,
            arguments: arguments,
            column: nil)
    }
}

/// The canonical conversion error message
///
/// - parameter dbValue: nil means "missing column"
func conversionErrorMessage<T>(to: T.Type, from dbValue: DatabaseValue?, conversionContext: ValueConversionContext?) -> String {
    var message: String
    var extras: [String] = []
    
    if let dbValue = dbValue {
        message = "could not convert database value \(dbValue) to \(T.self)"
        if let columnName = conversionContext?.columnName {
            extras.append("column: `\(columnName)`")
        }
        if let columnIndex = conversionContext?.columnIndex {
            extras.append("column index: \(columnIndex)")
        }
    } else {
        message = "could not read \(T.self) from missing column"
        if let columnName = conversionContext?.columnName {
            message += " `\(columnName)`"
        }
    }
    
    if let row = conversionContext?.row {
        extras.append("row: \(row)")
    }
    
    if let sql = conversionContext?.sql {
        extras.append("sql: `\(sql)`")
        if let arguments = conversionContext?.arguments, arguments.isEmpty == false {
            extras.append("arguments: \(arguments)")
        }
    }
    
    if extras.isEmpty == false {
        message += " (" + extras.joined(separator: ", ") + ")"
    }
    return message
}

/// The canonical conversion fatal error
///
/// - parameter dbValue: nil means "missing column", for consistency with (row["missing"] as DatabaseValue? == nil)
func fatalConversionError<T>(to: T.Type, from dbValue: DatabaseValue?, conversionContext: ValueConversionContext?, file: StaticString = #file, line: UInt = #line) -> Never {
    fatalError(conversionErrorMessage(to: T.self, from: dbValue, conversionContext: conversionContext), file: file, line: line)
}

func fatalConversionError<T>(to: T.Type, sqliteStatement: SQLiteStatement, index: Int32) -> Never {
    let row = Row(sqliteStatement: sqliteStatement)
    fatalConversionError(
        to: T.self,
        from: DatabaseValue(sqliteStatement: sqliteStatement, index: index),
        conversionContext: ValueConversionContext(row).atColumn(Int(index)))
}

// MARK: - DatabaseValueConvertible

/// Lossless conversions from database values and rows
extension DatabaseValueConvertible {
    @inline(__always)
    static func decode(from dbValue: DatabaseValue, conversionContext: @autoclosure () -> ValueConversionContext?) -> Self {
        if let value = fromDatabaseValue(dbValue) {
            return value
        } else {
            fatalConversionError(to: Self.self, from: dbValue, conversionContext: conversionContext())
        }
    }
    
    @inline(__always)
    static func decode(from row: Row, atUncheckedIndex index: Int) -> Self {
        return decode(
            from: row.impl.databaseValue(atUncheckedIndex: index),
            conversionContext: ValueConversionContext(row).atColumn(index))
    }
    
    @inline(__always)
    static func decodeIfPresent(from dbValue: DatabaseValue, conversionContext: @autoclosure () -> ValueConversionContext?) -> Self? {
        // Use fromDatabaseValue before checking for null: this allows DatabaseValue to convert NULL to .null.
        if let value = fromDatabaseValue(dbValue) {
            return value
        } else if dbValue.isNull {
            return nil
        } else {
            fatalConversionError(to: Self.self, from: dbValue, conversionContext: conversionContext())
        }
    }
    
    @inline(__always)
    static func decodeIfPresent(from row: Row, atUncheckedIndex index: Int) -> Self? {
        return decodeIfPresent(
            from: row.impl.databaseValue(atUncheckedIndex: index),
            conversionContext: ValueConversionContext(row).atColumn(index))
    }
}

// MARK: - DatabaseValueConvertible & StatementColumnConvertible

/// Lossless conversions from database values and rows
extension DatabaseValueConvertible where Self: StatementColumnConvertible {
    @inline(__always)
    static func fastDecode(from sqliteStatement: SQLiteStatement, index: Int32) -> Self {
        if sqlite3_column_type(sqliteStatement, index) == SQLITE_NULL {
            fatalConversionError(
                to: Self.self,
                from: .null,
                conversionContext: ValueConversionContext(Row(sqliteStatement: sqliteStatement)).atColumn(Int(index)))
        }
        return self.init(sqliteStatement: sqliteStatement, index: index)
    }
    
    @inline(__always)
    static func fastDecode(from row: Row, atUncheckedIndex index: Int) -> Self {
        if let sqliteStatement = row.sqliteStatement {
            return fastDecode(from: sqliteStatement, index: Int32(index))
        }
        return row.impl.fastDecode(Self.self, atUncheckedIndex: index)
    }
    
    @inline(__always)
    static func fastDecodeIfPresent(from sqliteStatement: SQLiteStatement, atUncheckedIndex index: Int32) -> Self? {
        if sqlite3_column_type(sqliteStatement, index) == SQLITE_NULL {
            return nil
        }
        return self.init(sqliteStatement: sqliteStatement, index: index)
    }
    
    @inline(__always)
    static func fastDecodeIfPresent(from row: Row, atUncheckedIndex index: Int) -> Self? {
        if let sqliteStatement = row.sqliteStatement {
            return fastDecodeIfPresent(from: sqliteStatement, atUncheckedIndex: Int32(index))
        }
        return row.impl.fastDecodeIfPresent(Self.self, atUncheckedIndex: index)
    }
}
