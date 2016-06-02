import Foundation

/// NSData is convertible to and from DatabaseValue.
extension NSData : DatabaseValueConvertible {
    /// Returns a value that can be stored in the database.
    public var databaseValue: DatabaseValue {
        // SQLite cant' store zero-length blobs.
        guard length > 0 else {
            return .null
        }
        return DatabaseValue(storage: .blob(self))
    }
    
    /// Returns an NSData initialized from *databaseValue*, if it contains
    /// a Blob.
    public static func fromDatabaseValue(_ databaseValue: DatabaseValue) -> Self? {
        switch databaseValue.storage {
        case .blob(let data):
            return self.init(data: data)
        default:
            return nil
        }
    }
}
