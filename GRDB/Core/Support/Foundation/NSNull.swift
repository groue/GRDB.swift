import Foundation

/// NSNull adopts DatabaseValueConvertible
extension NSNull: DatabaseValueConvertible {
    
    /// Returns DatabaseValue.null.
    public var databaseValue: DatabaseValue {
        return .null
    }
    
    /// Returns nil.
    public static func fromDatabaseValue(_ dbValue: DatabaseValue) -> Self? {
        return nil
    }
}
