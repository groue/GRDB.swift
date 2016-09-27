import Foundation

/// NSDate is stored in the database using the format
/// "yyyy-MM-dd HH:mm:ss.SSS", in the UTC time zone.
extension NSDate : DatabaseValueConvertible {
    
    /// Returns a value that can be stored in the database.
    public var databaseValue: DatabaseValue {
        return (self as Date).databaseValue
    }
    
    /// Returns an NSDate initialized from *databaseValue*, if possible.
    public static func fromDatabaseValue(_ databaseValue: DatabaseValue) -> Self? {
        guard let date = Date.fromDatabaseValue(databaseValue) else {
            return nil
        }
        return cast(date)
    }
}
