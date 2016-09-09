import Foundation

/// NSURL adopts DatabaseValueConvertible.
extension NSURL : DatabaseValueConvertible {
    
    /// Returns a value that can be stored in the database.
    /// (the URL's absoluteString).
    public var databaseValue: DatabaseValue {
        guard let absoluteString = absoluteString else {
            fatalError("Can't store NSURL with nil absoluteString in the database: \(self)")
        }
        return absoluteString.databaseValue
    }
    
    /// Returns an NSURL initialized from *databaseValue*, if possible.
    public static func fromDatabaseValue(databaseValue: DatabaseValue) -> Self? {
        guard let string = String.fromDatabaseValue(databaseValue) else {
            return nil
        }
        return self.init(string: string)
    }
}
