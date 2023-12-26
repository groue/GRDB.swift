/// A format that prints one line per database row, formatting values
/// as SQL literals.
///
/// For example:
///
/// ```swift
/// // 'Arthur',500
/// // 'Barbara',1000
/// // 'Craig',200
/// try db.dumpRequest(Player.all(), format: .quote())
/// ```
public struct QuoteDumpFormat {
    /// A boolean value indicating if column labels are printed as the first
    /// line of output.
    public var header: Bool
    
    /// The separator between values.
    public var separator: String
    
    var firstRow = true
    
    /// Creates a `QuoteDumpFormat`.
    ///
    /// - Parameters:
    ///   - header: A boolean value indicating if column labels are printed
    ///     as the first line of output.
    ///   - separator: The separator between values.
    public init(
        header: Bool = false,
        separator: String = ",")
    {
        self.header = header
        self.separator = separator
    }
}

extension QuoteDumpFormat: DumpFormat {
    public mutating func writeRow(
        _ db: Database,
        statement: Statement,
        to stream: inout DumpStream)
    {
        if firstRow {
            firstRow = false
            if header {
                stream.writeln(statement.columnNames
                    .map { try! $0.sqlExpression.quotedSQL(db) }
                    .joined(separator: separator))
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
            
            let dbValue = DatabaseValue(sqliteStatement: sqliteStatement, index: index)
            try! stream.write(dbValue.sqlExpression.quotedSQL(db))
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
}

extension DumpFormat where Self == QuoteDumpFormat {
    /// A format that prints one line per database row, formatting values
    /// as SQL literals.
    ///
    /// For example:
    ///
    /// ```swift
    /// // 'Arthur',500
    /// // 'Barbara',1000
    /// // 'Craig',200
    /// try db.dumpRequest(Player.all(), format: .quote())
    /// ```
    ///
    /// - Parameters:
    ///   - header: A boolean value indicating if column labels are printed
    ///     as the first line of output.
    ///   - separator: The separator between values.
    public static func quote(header: Bool = false, separator: String = ",") -> Self {
        QuoteDumpFormat(header: header, separator: separator)
    }
}
