import Foundation

#if !os(Linux)
/// NSURL stores its absoluteString in the database.
extension NSURL: DatabaseValueConvertible {
    
    /// Returns a value that can be stored in the database.
    /// (the URL's absoluteString).
    public var databaseValue: DatabaseValue {
        absoluteString?.databaseValue ?? .null
    }
    
    /// Returns an NSURL initialized from *dbValue*, if possible.
    public static func fromDatabaseValue(_ dbValue: DatabaseValue) -> Self? {
        guard let string = String.fromDatabaseValue(dbValue) else {
            return nil
        }
        return cast(URL(string: string))
    }
}
#endif

/// URL stores its absoluteString in the database.
extension URL: DatabaseValueConvertible { }
