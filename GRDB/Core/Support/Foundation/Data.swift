import Foundation
#if SWIFT_PACKAGE
    import CSQLite
#elseif !GRDBCUSTOMSQLITE && !GRDBCIPHER
    import SQLite3
#endif

/// Data is convertible to and from DatabaseValue.
extension Data : DatabaseValueConvertible, StatementColumnConvertible {
    public init(sqliteStatement: SQLiteStatement, index: Int32) {
        let bytes = unsafeBitCast(sqlite3_column_blob(sqliteStatement, Int32(index)), to: UnsafePointer<UInt8>.self)
        let count = Int(sqlite3_column_bytes(sqliteStatement, Int32(index)))
        self.init(bytes: bytes, count: count) // copy bytes
    }
    
    /// Returns a value that can be stored in the database.
    public var databaseValue: DatabaseValue {
        // SQLite cant' store zero-length blobs.
        guard count > 0 else {
            return .null
        }
        return DatabaseValue(storage: .blob(self))
    }
    
    /// Returns a Data initialized from *dbValue*, if it contains
    /// a Blob.
    public static func fromDatabaseValue(_ dbValue: DatabaseValue) -> Data? {
        guard case .blob(let data) = dbValue.storage else {
            return nil
        }
        return data
    }
}
