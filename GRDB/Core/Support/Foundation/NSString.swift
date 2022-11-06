#if !os(Linux)
import Foundation

/// NSString adopts DatabaseValueConvertible
extension NSString: DatabaseValueConvertible {
    
    /// Returns a TEXT database value.
    public var databaseValue: DatabaseValue {
        (self as String).databaseValue
    }
    
    /// Returns a `NSString` from the specified database value.
    ///
    /// If the database value contains a string, returns it.
    ///
    /// If the database value contains a data blob, parses this data as an
    /// UTF8 string.
    ///
    /// Otherwise, returns nil.
    public static func fromDatabaseValue(_ dbValue: DatabaseValue) -> Self? {
        guard let string = String.fromDatabaseValue(dbValue) else {
            return nil
        }
        return self.init(string: string)
    }
}
#endif
