import Foundation

/// NSNull adopts DatabaseValueConvertible
extension NSNull: DatabaseValueConvertible {
    
    /// Returns DatabaseValue.Null.
    public var databaseValue: DatabaseValue {
        return .Null
    }
    
    /// Returns nil.
    public static func fromDatabaseValue(databaseValue: DatabaseValue) -> Self? {
        return nil
    }
}
