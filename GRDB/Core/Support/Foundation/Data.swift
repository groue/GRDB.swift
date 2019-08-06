import Foundation
#if SWIFT_PACKAGE
import CSQLite
#elseif GRDBCIPHER
import SQLCipher
#elseif !GRDBCUSTOMSQLITE && !GRDBCIPHER
import SQLite3
#endif

/// Data is convertible to and from DatabaseValue.
extension Data: DatabaseValueConvertible, StatementColumnConvertible {
    @inlinable
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
        return DatabaseValue(storage: .blob(self))
    }
    
    /// Returns a Data initialized from *dbValue*, if it contains
    /// a Blob.
    public static func fromDatabaseValue(_ dbValue: DatabaseValue) -> Data? {
        switch dbValue.storage {
        case .blob(let data):
            return data
        case .string(let string):
            // Implicit conversion from string to blob, just as SQLite does
            // See https://www.sqlite.org/c3ref/column_blob.html
            return string.data(using: .utf8)
        default:
            return nil
        }
    }
}
