import Foundation

/// NSData is convertible to and from DatabaseValue.
extension NSData : DatabaseValueConvertible {
    
    /// Returns a value that can be stored in the database.
    public var databaseValue: DatabaseValue {
        return (self as Data).databaseValue
    }
    
    /// Returns an NSData initialized from *dbValue*, if it contains
    /// a Blob.
    public static func fromDatabaseValue(_ dbValue: DatabaseValue) -> Self? {
        guard let data = Data.fromDatabaseValue(dbValue) else {
            return nil
        }
        return cast(data)
    }
}
