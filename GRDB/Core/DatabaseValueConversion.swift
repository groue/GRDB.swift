#if SWIFT_PACKAGE
import CSQLite
#elseif GRDBCIPHER
import SQLCipher
#elseif !GRDBCUSTOMSQLITE && !GRDBCIPHER
import SQLite3
#endif

// MARK: - Conversion Context and Errors

/// A type that helps the user understanding value conversion errors
struct ValueConversionContext: KeyPathRefining {
    private enum Column {
        case columnIndex(Int)
        case columnName(String)
    }
    
    var row: Row?
    var sql: String?
    var arguments: StatementArguments?
    private var column: Column?
    
    func atColumn(_ columnIndex: Int) -> ValueConversionContext {
        return with(\.column, .columnIndex(columnIndex))
    }
    
    func atColumn(_ columnName: String) -> ValueConversionContext {
        return with(\.column, .columnName(columnName))
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
            let sql = String(cString: sqlite3_sql(sqliteStatement)).trimmingCharacters(in: .sqlStatementSeparators)
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
}

/// The canonical conversion error message
///
/// - parameter dbValue: nil means "missing column"
func conversionErrorMessage<T>(
    to: T.Type,
    from dbValue: DatabaseValue?,
    conversionContext: ValueConversionContext?)
    -> String
{
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
func fatalConversionError<T>(
    to: T.Type,
    from dbValue: DatabaseValue?,
    conversionContext: ValueConversionContext?,
    file: StaticString = #file,
    line: UInt = #line)
    -> Never
{
    fatalError(
        conversionErrorMessage(
            to: T.self,
            from: dbValue,
            conversionContext: conversionContext),
        file: file,
        line: line)
}

@usableFromInline
func fatalConversionError<T>(
    to: T.Type,
    from dbValue: DatabaseValue?,
    in row: Row,
    atColumn columnName: String,
    file: StaticString = #file,
    line: UInt = #line)
    -> Never
{
    fatalConversionError(
        to: T.self,
        from: dbValue,
        conversionContext: ValueConversionContext(row).atColumn(columnName))
}

@usableFromInline
func fatalConversionError<T>(
    to: T.Type,
    sqliteStatement: SQLiteStatement,
    index: Int32,
    file: StaticString = #file,
    line: UInt = #line)
    -> Never
{
    let row = Row(sqliteStatement: sqliteStatement)
    fatalConversionError(
        to: T.self,
        from: DatabaseValue(sqliteStatement: sqliteStatement, index: index),
        conversionContext: ValueConversionContext(row).atColumn(Int(index)))
}

@usableFromInline
func fatalConversionError<T>(
    to: T.Type,
    from dbValue: DatabaseValue?,
    sqliteStatement: SQLiteStatement,
    index: Int32,
    file: StaticString = #file,
    line: UInt = #line)
    -> Never
{
    let row = Row(sqliteStatement: sqliteStatement)
    fatalConversionError(
        to: T.self,
        from: dbValue,
        conversionContext: ValueConversionContext(row).atColumn(Int(index)))
}

// MARK: - DatabaseValueConvertible

/// Lossless conversions from database values and rows
extension DatabaseValueConvertible {
    @usableFromInline
    static func decode(from sqliteStatement: SQLiteStatement, atUncheckedIndex index: Int32) -> Self {
        let dbValue = DatabaseValue(sqliteStatement: sqliteStatement, index: index)
        if let value = fromDatabaseValue(dbValue) {
            return value
        } else {
            fatalConversionError(to: Self.self, from: dbValue, sqliteStatement: sqliteStatement, index: index)
        }
    }
    
    static func decode(
        from dbValue: DatabaseValue,
        conversionContext: @autoclosure () -> ValueConversionContext?)
        -> Self
    {
        if let value = fromDatabaseValue(dbValue) {
            return value
        } else {
            fatalConversionError(to: Self.self, from: dbValue, conversionContext: conversionContext())
        }
    }
    
    @usableFromInline
    static func decode(from row: Row, atUncheckedIndex index: Int) -> Self {
        return decode(
            from: row.impl.databaseValue(atUncheckedIndex: index),
            conversionContext: ValueConversionContext(row).atColumn(index))
    }
    
    @usableFromInline
    static func decodeIfPresent(from sqliteStatement: SQLiteStatement, atUncheckedIndex index: Int32) -> Self? {
        let dbValue = DatabaseValue(sqliteStatement: sqliteStatement, index: index)
        if let value = fromDatabaseValue(dbValue) {
            return value
        } else if dbValue.isNull {
            return nil
        } else {
            fatalConversionError(to: Self.self, from: dbValue, sqliteStatement: sqliteStatement, index: index)
        }
    }
    
    static func decodeIfPresent(
        from dbValue: DatabaseValue,
        conversionContext: @autoclosure () -> ValueConversionContext?)
        -> Self?
    {
        // Use fromDatabaseValue before checking for null: this allows DatabaseValue to convert NULL to .null.
        if let value = fromDatabaseValue(dbValue) {
            return value
        } else if dbValue.isNull {
            return nil
        } else {
            fatalConversionError(to: Self.self, from: dbValue, conversionContext: conversionContext())
        }
    }
    
    @usableFromInline
    static func decodeIfPresent(from row: Row, atUncheckedIndex index: Int) -> Self? {
        return decodeIfPresent(
            from: row.impl.databaseValue(atUncheckedIndex: index),
            conversionContext: ValueConversionContext(row).atColumn(index))
    }
}

// MARK: - DatabaseValueConvertible & StatementColumnConvertible

/// Lossless conversions from database values and rows
extension DatabaseValueConvertible where Self: StatementColumnConvertible {
    @inlinable
    static func fastDecode(from sqliteStatement: SQLiteStatement, atUncheckedIndex index: Int32) -> Self {
        if sqlite3_column_type(sqliteStatement, index) == SQLITE_NULL {
            fatalConversionError(to: Self.self, sqliteStatement: sqliteStatement, index: index)
        }
        return self.init(sqliteStatement: sqliteStatement, index: index)
    }
    
    @inlinable
    static func fastDecode(from row: Row, atUncheckedIndex index: Int) -> Self {
        if let sqliteStatement = row.sqliteStatement {
            return fastDecode(from: sqliteStatement, atUncheckedIndex: Int32(index))
        }
        return row.fastDecode(Self.self, atUncheckedIndex: index)
    }
    
    @inlinable
    static func fastDecodeIfPresent(from sqliteStatement: SQLiteStatement, atUncheckedIndex index: Int32) -> Self? {
        if sqlite3_column_type(sqliteStatement, index) == SQLITE_NULL {
            return nil
        }
        return self.init(sqliteStatement: sqliteStatement, index: index)
    }
    
    @inlinable
    static func fastDecodeIfPresent(from row: Row, atUncheckedIndex index: Int) -> Self? {
        if let sqliteStatement = row.sqliteStatement {
            return fastDecodeIfPresent(from: sqliteStatement, atUncheckedIndex: Int32(index))
        }
        return row.fastDecodeIfPresent(Self.self, atUncheckedIndex: index)
    }
}

// Support for @inlinable decoding
extension Row {
    @usableFromInline
    func fastDecode<Value: DatabaseValueConvertible & StatementColumnConvertible>(
        _ type: Value.Type,
        atUncheckedIndex index: Int)
        -> Value
    {
        return impl.fastDecode(type, atUncheckedIndex: index)
    }
    
    @usableFromInline
    func fastDecodeIfPresent<Value: DatabaseValueConvertible & StatementColumnConvertible>(
        _ type: Value.Type,
        atUncheckedIndex index: Int)
        -> Value?
    {
        return impl.fastDecodeIfPresent(type, atUncheckedIndex: index)
    }
}
