import Foundation

/// A format that prints database rows as a JSON array.
///
/// For example:
///
/// ```swift
/// // [{"name":"Arthur","score":500},
/// // {"name":"Barbara","score":1000}]
/// try db.dumpRequest(Player.all(), format: .json())
/// ```
///
/// For a pretty-printed output, customize the JSON encoder:
///
/// ```swift
/// // [
/// //   {
/// //     "name": "Arthur",
/// //     "score": 500
/// //   },
/// //   {
/// //     "name": "Barbara",
/// //     "score": 1000
/// //   }
/// // ]
/// let encoder = JSONDumpFormat.defaultEncoder
/// encoder.outputFormatting = .prettyPrinted
/// try db.dumpRequest(Player.all(), format: .json(encoder))
/// ```
public struct JSONDumpFormat {
    /// The default `JSONEncoder` for database values.
    ///
    /// It is configured so that blob values (`Data`) are encoded in the
    /// base64 format, and Non-conforming floats are encoded as "inf",
    /// "-inf" and "nan".
    ///
    /// It uses the output formatting option
    /// `JSONEncoder.OutputFormatting.withoutEscapingSlashes` when available.
    ///
    /// Modifying the returned encoder does not affect any encoder returned
    /// by future calls to this method. It is always safe to use the
    /// returned encoder as a starting point for additional customization.
    public static var defaultEncoder: JSONEncoder {
        // This encoder MUST NOT CHANGE, because some people rely on this format.
        let encoder = JSONEncoder()
        if #available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *) {
            encoder.outputFormatting = .withoutEscapingSlashes
        }
        encoder.nonConformingFloatEncodingStrategy = .convertToString(
            positiveInfinity: "inf",
            negativeInfinity: "-inf",
            nan: "nan")
        encoder.dataEncodingStrategy = .base64
        return encoder
    }
    
    /// The JSONEncoder that formats individual database values.
    public var encoder: JSONEncoder
    
    var firstRow = true
    
    /// Creates a `JSONDumpFormat`.
    ///
    /// - Parameter encoder: The JSONEncoder that formats individual
    ///   database values. If the outputFormatting` options contain
    ///   `.prettyPrinted`, the printed array has one value per line.
    public init(encoder: JSONEncoder = JSONDumpFormat.defaultEncoder) {
        self.encoder = encoder
    }
}

extension JSONDumpFormat: DumpFormat {
    public mutating func writeRow(
        _ db: Database,
        statement: Statement,
        to stream: inout DumpStream)
    throws {
        if firstRow {
            firstRow = false
            stream.write("[")
            if encoder.outputFormatting.contains(.prettyPrinted) {
                stream.write("\n")
            }
        } else {
            stream.write(",\n")
        }
        
        if encoder.outputFormatting.contains(.prettyPrinted) {
            stream.write("  ")
        }
        stream.write("{")
        let sqliteStatement = statement.sqliteStatement
        var first = true
        for index in 0..<sqlite3_column_count(sqliteStatement) {
            // Don't log GRDB columns
            let column = String(cString: sqlite3_column_name(sqliteStatement, index))
            if column.starts(with: "grdb_") {
                continue
            }
            
            if first {
                first = false
            } else {
                stream.write(",")
            }
            
            if encoder.outputFormatting.contains(.prettyPrinted) {
                stream.write("\n    ")
            }
            try stream.write(formattedValue(column))
            stream.write(":")
            try stream.write(formattedValue(db, in: sqliteStatement, at: index))
        }
        if encoder.outputFormatting.contains(.prettyPrinted) {
            stream.write("\n  ")
        }
        stream.write("}")
    }
    
    public mutating func finalize(
        _ db: Database,
        statement: Statement,
        to stream: inout DumpStream)
    {
        if firstRow {
            if !statement.columnNames.isEmpty {
                stream.writeln("[]")
            }
        } else {
            if encoder.outputFormatting.contains(.prettyPrinted) {
                stream.write("\n")
            }
            stream.writeln("]")
        }
        firstRow = true
    }
    
    private func formattedValue(_ db: Database, in sqliteStatement: SQLiteStatement, at index: CInt) throws -> String {
        switch sqlite3_column_type(sqliteStatement, index) {
        case SQLITE_NULL:
            return "null"
            
        case SQLITE_INTEGER:
            return try formattedValue(Int64(sqliteStatement: sqliteStatement, index: index))
            
        case SQLITE_FLOAT:
            return try formattedValue(Double(sqliteStatement: sqliteStatement, index: index))
            
        case SQLITE_BLOB:
            return try formattedValue(Data(sqliteStatement: sqliteStatement, index: index))
            
        case SQLITE_TEXT:
            return try formattedValue(String(sqliteStatement: sqliteStatement, index: index))
            
        default:
            return ""
        }
    }
    
    private func formattedValue(_ value: some Encodable) throws -> String {
        let data = try encoder.encode(value)
        guard let string = String(data: data, encoding: .utf8) else {
            throw EncodingError.invalidValue(data, .init(codingPath: [], debugDescription: "Invalid JSON data"))
        }
        return string
    }
}

extension DumpFormat where Self == JSONDumpFormat {
    /// A format that prints database rows as a JSON array.
    ///
    /// For example:
    ///
    /// ```swift
    /// // [{"name":"Arthur","score":500},
    /// // {"name":"Barbara","score":1000}]
    /// try db.dumpRequest(Player.all(), format: .json())
    /// ```
    ///
    /// For a pretty-printed output, customize the JSON encoder:
    ///
    /// ```swift
    /// // [
    /// //   {
    /// //     "name": "Arthur",
    /// //     "score": 500
    /// //   },
    /// //   {
    /// //     "name": "Barbara",
    /// //     "score": 1000
    /// //   }
    /// // ]
    /// let encoder = JSONDumpFormat.defaultEncoder
    /// encoder.outputFormatting = .prettyPrinted
    /// try db.dumpRequest(Player.all(), format: .json(encoder))
    /// ```
    ///
    /// - Parameter encoder: The JSONEncoder that formats individual
    ///   database values. If the outputFormatting` options contain
    ///   `.prettyPrinted`, the printed array has one value per line.
    public static func json(encoder: JSONEncoder = JSONDumpFormat.defaultEncoder) -> Self {
        JSONDumpFormat(encoder: encoder)
    }
}
