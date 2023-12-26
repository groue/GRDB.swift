import Foundation

/// A format that prints one line per database row. All blob values
/// are interpreted as strings.
///
/// On each line, database values are separated by a separator (`|`
/// by default). Blob values are interpreted as UTF8 strings.
///
/// For example:
///
/// ```swift
/// // Arthur|500
/// // Barbara|1000
/// // Craig|200
/// try db.dumpRequest(Player.all(), format: .list())
/// ```
public struct ListDumpFormat {
    /// A boolean value indicating if column labels are printed as the first
    /// line of output.
    public var header: Bool
    
    /// The separator between values.
    public var separator: String
    
    /// The string to print for NULL values.
    public var nullValue: String
    
    private var firstRow = true
    
    /// Creates a `ListDumpFormat`.
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

extension ListDumpFormat: DumpFormat {
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
    
    func formattedValue(
        _ db: Database,
        in sqliteStatement: SQLiteStatement,
        at index: CInt)
    -> String
    {
        switch sqlite3_column_type(sqliteStatement, index) {
        case SQLITE_NULL:
            return nullValue
            
        case SQLITE_INTEGER:
            return Int64(sqliteStatement: sqliteStatement, index: index).description
            
        case SQLITE_FLOAT:
            return Double(sqliteStatement: sqliteStatement, index: index).description
            
        case SQLITE_BLOB, SQLITE_TEXT:
            return String(sqliteStatement: sqliteStatement, index: index)
            
        default:
            return ""
        }
    }
}

extension DumpFormat where Self == ListDumpFormat {
    /// A format that prints one line per database row. All blob values
    /// are interpreted as strings.
    ///
    /// On each line, database values are separated by a separator (`|`
    /// by default). Blob values are interpreted as UTF8 strings.
    ///
    /// For example:
    ///
    /// ```swift
    /// // Arthur|500
    /// // Barbara|1000
    /// // Craig|200
    /// try db.dumpRequest(Player.all(), format: .list())
    /// ```
    ///
    /// - Parameters:
    ///   - header: A boolean value indicating if column labels are printed
    ///     as the first line of output.
    ///   - separator: The separator between values.
    ///   - nullValue: The string to print for NULL values.
    public static func list(
        header: Bool = false,
        separator: String = "|",
        nullValue: String = "")
    -> Self
    {
        ListDumpFormat(header: header, separator: separator, nullValue: nullValue)
    }
}
