import Foundation
#if SWIFT_PACKAGE
    import CSQLite
#elseif !GRDBCUSTOMSQLITE && !GRDBCIPHER
    import SQLite3
#endif

/// Data is convertible to and from DatabaseValue.
extension Data : DatabaseValueConvertible, StatementColumnConvertible {
    public init(sqliteStatement: SQLiteStatement, index: Int32) {
        if let bytes = sqlite3_column_blob(sqliteStatement, Int32(index)) {
            let count = Int(sqlite3_column_bytes(sqliteStatement, Int32(index)))
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
        guard case .blob(let data) = dbValue.storage else {
            // Check to see if data is String, if so then pass is through JSONSerialization
            // to confirm if contains JSON, if so then this is a nested type stored as JSON,
            // so return string as Data so that it can be decoded
            if let valueIsString = dbValue.storage.value as? String, let dataUtf8 = valueIsString.data(using: .utf8) {
                do {
                    try JSONSerialization.jsonObject(with: dataUtf8, options: [])
                    return dataUtf8
                } catch {
                    return nil
                }
            }
            return nil
        }
        return data
    }
}
