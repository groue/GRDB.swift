import Foundation

/// A format that prints one line per database value. All blob values
/// are interpreted as strings.
///
/// For example:
///
/// ```swift
/// //  name = Arthur
/// // score = 500
/// //
/// //  name = Barbara
/// // score = 1000
/// try db.dumpRequest(Player.all(), format: .line())
/// ```
public struct LineDumpFormat {
    /// The string to print for NULL values.
    public var nullValue: String
    
    var firstRow = true
    
    /// Creates a `LineDumpFormat`.
    ///
    /// - Parameters:
    ///   - nullValue: The string to print for NULL values.
    public init(
        nullValue: String = "")
    {
        self.nullValue = nullValue
    }
}

extension LineDumpFormat: DumpFormat {
    public mutating func writeRow(
        _ db: Database,
        statement: Statement,
        to stream: inout DumpStream)
    {
        var lines: [(column: String, value: String)] = []
        let sqliteStatement = statement.sqliteStatement
        for index in 0..<sqlite3_column_count(sqliteStatement) {
            // Don't log GRDB columns
            let column = String(cString: sqlite3_column_name(sqliteStatement, index))
            if column.starts(with: "grdb_") { continue }
            
            lines.append((
                column: column,
                value: formattedValue(db, in: sqliteStatement, at: index)))
        }
        
        if lines.isEmpty { return }
        
        if firstRow {
            firstRow = false
        } else {
            stream.write("\n")
        }
        
        let columnWidth = lines.map(\.column.count).max()!
        for line in lines {
            stream.write(line.column.leftPadding(toLength: columnWidth, withPad: " "))
            stream.write(" = ")
            stream.writeln(line.value)
        }
    }
    
    public mutating func finalize(
        _ db: Database,
        statement: Statement,
        to stream: inout DumpStream)
    {
        if firstRow == false {
            stream.margin()
        }
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

extension DumpFormat where Self == LineDumpFormat {
    /// A format that prints one line per database value. All blob values
    /// are interpreted as strings.
    ///
    /// On each line, database values are separated by a separator (`|`
    /// by default). Blob values are interpreted as UTF8 strings.
    ///
    /// For example:
    ///
    /// ```swift
    /// //  name = Arthur
    /// // score = 500
    /// //
    /// //  name = Barbara
    /// // score = 1000
    /// try db.dumpRequest(Player.all(), format: .line())
    /// ```
    ///
    /// - Parameters:
    ///   - nullValue: The string to print for NULL values.
    public static func line(
        nullValue: String = "")
    -> Self
    {
        LineDumpFormat(nullValue: nullValue)
    }
}
