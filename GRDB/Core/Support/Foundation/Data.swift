import Foundation

/// Data is convertible to and from DatabaseValue.
extension Data : DatabaseValueConvertible {
    /// Returns a value that can be stored in the database.
    public var databaseValue: DatabaseValue {
        // SQLite cant' store zero-length blobs.
        guard count > 0 else {
            return .null
        }
        return DatabaseValue(storage: .blob(self))
    }
    
    /// Returns a Data initialized from *databaseValue*, if it contains
    /// a Blob.
    public static func fromDatabaseValue(_ databaseValue: DatabaseValue) -> Data? {
        guard case .blob(let data) = databaseValue.storage else {
            return nil
        }
        return data
    }
}
