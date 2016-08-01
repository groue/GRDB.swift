import Foundation

/// URL adopts DatabaseValueConvertible.
extension URL : DatabaseValueConvertible {
    
    /// Returns a value that can be stored in the database.
    /// (the URL's absoluteString).
    public var databaseValue: DatabaseValue {
        return absoluteString.databaseValue
    }
    
    /// Returns an NSURL initialized from *databaseValue*, if possible.
    public static func fromDatabaseValue(_ databaseValue: DatabaseValue) -> URL? {
        guard let string = String.fromDatabaseValue(databaseValue) else {
            return nil
        }
        return self.init(string: string)
    }
}
