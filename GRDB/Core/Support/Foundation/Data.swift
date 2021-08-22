import Foundation

/// Data is convertible to and from DatabaseValue.
extension Data: DatabaseValueConvertible, StatementColumnConvertible {
    public init(sqliteStatement: SQLiteStatement, index: Int32) {
        if let bytes = sqlite3_column_blob(sqliteStatement, index) {
            let count = Int(sqlite3_column_bytes(sqliteStatement, index))
            self.init(bytes: bytes, count: count) // copy bytes
        } else {
            self.init()
        }
    }
    
    /// Returns a value that can be stored in the database.
    public var databaseValue: DatabaseValue {
        DatabaseValue(storage: .blob(self))
    }
    
    /// Returns a Data initialized from *dbValue*, if it contains
    /// a Blob.
    public static func fromDatabaseValue(_ dbValue: DatabaseValue) -> Data? {
        switch dbValue.storage {
        case .blob(let data):
            return data
        case .string(let string):
            // Implicit conversion from string to blob, just as SQLite does
            // See <https://www.sqlite.org/c3ref/column_blob.html>
            return string.data(using: .utf8)
        default:
            return nil
        }
    }
    
    public func bind(to sqliteStatement: SQLiteStatement, at index: CInt) -> CInt {
        withUnsafeBytes {
            sqlite3_bind_blob(sqliteStatement, index, $0.baseAddress, Int32($0.count), SQLITE_TRANSIENT)
        }
    }
}

// MARK: - Conversions

extension Data {
    static func fastDecodeNoCopy(
        fromStatement sqliteStatement: SQLiteStatement,
        atUncheckedIndex index: Int32,
        context: @autoclosure () -> RowDecodingContext)
    throws -> Data
    {
        guard sqlite3_column_type(sqliteStatement, Int32(index)) != SQLITE_NULL else {
            throw RowDecodingError.valueMismatch(
                Data.self,
                sqliteStatement: sqliteStatement,
                index: index,
                context: context())
        }
        guard let bytes = sqlite3_column_blob(sqliteStatement, Int32(index)) else {
            return Data()
        }
        let count = Int(sqlite3_column_bytes(sqliteStatement, Int32(index)))
        return Data(bytesNoCopy: UnsafeMutableRawPointer(mutating: bytes), count: count, deallocator: .none)
    }
    
    static func fastDecodeNoCopy(
        fromRow row: Row,
        atUncheckedIndex index: Int)
    throws -> Data
    {
        if let sqliteStatement = row.sqliteStatement {
            return try fastDecodeNoCopy(
                fromStatement: sqliteStatement,
                atUncheckedIndex: Int32(index),
                context: RowDecodingContext(row: row, key: .columnIndex(index)))
        }
        // Support for fast decoding from adapted rows
        return try row.fastDecodeDataNoCopy(atUncheckedIndex: index)
    }

    static func fastDecodeNoCopyIfPresent(
        fromStatement sqliteStatement: SQLiteStatement,
        atUncheckedIndex index: Int32,
        context: @autoclosure () -> RowDecodingContext)
    -> Data?
    {
        guard sqlite3_column_type(sqliteStatement, Int32(index)) != SQLITE_NULL else {
            return nil
        }
        guard let bytes = sqlite3_column_blob(sqliteStatement, Int32(index)) else {
            return Data()
        }
        let count = Int(sqlite3_column_bytes(sqliteStatement, Int32(index)))
        return Data(bytesNoCopy: UnsafeMutableRawPointer(mutating: bytes), count: count, deallocator: .none)
    }

    static func fastDecodeNoCopyIfPresent(
        fromRow row: Row,
        atUncheckedIndex index: Int)
    throws -> Data?
    {
        if let sqliteStatement = row.sqliteStatement {
            return fastDecodeNoCopyIfPresent(
                fromStatement: sqliteStatement,
                atUncheckedIndex: Int32(index),
                context: RowDecodingContext(row: row, key: .columnIndex(index)))
        }
        // Support for fast decoding from adapted rows
        return try row.fastDecodeDataNoCopyIfPresent(atUncheckedIndex: index)
    }
}
