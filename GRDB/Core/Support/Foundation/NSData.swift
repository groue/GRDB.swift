import Foundation

/// NSData is convertible to and from DatabaseValue.
extension NSData : DatabaseValueConvertible {
    
    /// Returns a value that can be stored in the database.
    public var databaseValue: DatabaseValue {
        #if os(Linux)
        return Data._unconditionallyBridgeFromObjectiveC(self).databaseValue
        #else
        return (self as Data).databaseValue
        #endif
    }
    
    /// Returns an NSData initialized from *databaseValue*, if it contains
    /// a Blob.
    public static func fromDatabaseValue(_ databaseValue: DatabaseValue) -> Self? {
        guard let data = Data.fromDatabaseValue(databaseValue) else {
            return nil
        }
        return cast(data)
    }
}
