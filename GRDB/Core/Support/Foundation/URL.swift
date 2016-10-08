import Foundation

/// NSURL stores its absoluteString in the database.
extension NSURL : DatabaseValueConvertible {
    
    /// Returns a value that can be stored in the database.
    /// (the URL's absoluteString).
    public var databaseValue: DatabaseValue {
        return absoluteString?.databaseValue ?? .null
    }
    
    /// Returns an NSURL initialized from *databaseValue*, if possible.
    public static func fromDatabaseValue(_ databaseValue: DatabaseValue) -> Self? {
        guard let string = String.fromDatabaseValue(databaseValue) else {
            return nil
        }
        return cast(URL(string: string))
    }
}

/// URL stores its absoluteString in the database.
extension URL : DatabaseValueConvertible { }
