import Foundation

#if !os(Linux)
/// `NSURL` is a database value.
///
/// `NSURL` stores its `absoluteString` in the database.
extension NSURL: DatabaseValueConvertible {
    
    /// Returns a TEXT database value containing the absolute URL.
    public var databaseValue: DatabaseValue {
        absoluteString?.databaseValue ?? .null
    }
    
    public static func fromDatabaseValue(_ dbValue: DatabaseValue) -> Self? {
        guard let string = String.fromDatabaseValue(dbValue) else {
            return nil
        }
        return cast(URL(string: string))
    }
}
#endif

/// `URL` is a database value.
///
/// `URL` stores its `absoluteString` in the database.
extension URL: DatabaseValueConvertible { }
