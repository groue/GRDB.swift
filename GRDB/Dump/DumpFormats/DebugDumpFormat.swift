import Foundation

/// A format that prints one line per database row, suitable
/// for debugging.
///
/// This format may change in future releases. It is not suitable for
/// processing by other programs, or testing.
///
/// On each line, database values are separated by a separator (`|`
/// by default).
///
/// For example:
///
/// ```swift
/// // Arthur|500
/// // Barbara|1000
/// // Craig|200
/// try db.dumpRequest(Player.all(), format: .debug())
/// ```
public struct DebugDumpFormat {
    /// A boolean value indicating if column labels are printed as the first
    /// line of output.
    public var header: Bool
    
    /// The separator between values.
    public var separator: String
    
    /// The string to print for NULL values.
    public var nullValue: String
    
    private var firstRow = true
    
    /// Creates a `DebugDumpFormat`.
    ///
    /// - Parameters:
    ///   - header: A boolean value indicating if column labels are printed
    ///     as the first line of output.
    ///   - separator: The separator between values.
    ///   - nullValue: The string to print for NULL values.
    public init(
        header: Bool = false,
        separator: String = "|",
        nullValue: String = "")
    {
        self.header = header
        self.separator = separator
        self.nullValue = nullValue
    }
}

extension DebugDumpFormat: DumpFormat {
    public mutating func writeRow(
        _ db: Database,
        statement: Statement,
        to stream: inout DumpStream)
    {
        if firstRow {
            firstRow = false
            if header {
                stream.writeln(statement.columnNames.joined(separator: separator))
            }
        }
        
        let sqliteStatement = statement.sqliteStatement
        var first = true
        for index in 0..<sqlite3_column_count(sqliteStatement) {
            // Don't log GRDB columns
            let column = String(cString: sqlite3_column_name(sqliteStatement, index))
            if column.starts(with: "grdb_") { continue }
            
            if first {
                first = false
            } else {
                stream.write(separator)
            }
            
            stream.write(formattedValue(db, in: sqliteStatement, at: index))
        }
        stream.write("\n")
    }
    
    public mutating func finalize(
        _ db: Database,
        statement: Statement,
        to stream: inout DumpStream)
    {
        firstRow = true
    }
    
    private func formattedValue(_ db: Database, in sqliteStatement: SQLiteStatement, at index: CInt) -> String {
        switch sqlite3_column_type(sqliteStatement, index) {
        case SQLITE_NULL:
            return nullValue
            
        case SQLITE_INTEGER:
            return Int64(sqliteStatement: sqliteStatement, index: index).description
            
        case SQLITE_FLOAT:
            return Double(sqliteStatement: sqliteStatement, index: index).description
            
        case SQLITE_BLOB:
            let data = Data(sqliteStatement: sqliteStatement, index: index)
            if let string = String(data: data, encoding: .utf8) {
                return string
            } else if data.count == 16, let blob = sqlite3_column_blob(sqliteStatement, index) {
                let uuid = UUID(uuid: blob.assumingMemoryBound(to: uuid_t.self).pointee)
                return uuid.uuidString
            } else {
                return try! data.sqlExpression.quotedSQL(db)
            }
            
        case SQLITE_TEXT:
            return String(sqliteStatement: sqliteStatement, index: index)
            
        default:
            return ""
        }
    }
}

extension DumpFormat where Self == DebugDumpFormat {
    /// A format that prints one line per database row, suitable
    /// for debugging.
    ///
    /// This format may change in future releases. It is not suitable for
    /// processing by other programs, or testing.
    ///
    /// On each line, database values are separated by a separator (`|`
    /// by default).
    ///
    /// For example:
    ///
    /// ```swift
    /// // Arthur|500
    /// // Barbara|1000
    /// // Craig|200
    /// try db.dumpRequest(Player.all(), format: .debug())
    /// ```
    ///
    /// - Parameters:
    ///   - header: A boolean value indicating if column labels are printed
    ///     as the first line of output.
    ///   - separator: The separator between values.
    ///   - nullValue: The string to print for NULL values.
    public static func debug(
        header: Bool = false,
        separator: String = "|",
        nullValue: String = "")
    -> Self
    {
        DebugDumpFormat(header: header, separator: separator, nullValue: nullValue)
    }
}
