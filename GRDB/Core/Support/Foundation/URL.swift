import Foundation

/// NSURL stores its absoluteString in the database.
extension NSURL : DatabaseValueConvertible {
    
    /// Returns a value that can be stored in the database.
    /// (the URL's absoluteString).
    public var databaseValue: DatabaseValue {
        #if os(Linux)
            return absoluteString.databaseValue
        #else
            return absoluteString?.databaseValue ?? .null
        #endif
    }
    
    /// Returns an NSURL initialized from *databaseValue*, if possible.
    public static func fromDatabaseValue(_ databaseValue: DatabaseValue) -> Self? {
        guard let string = String.fromDatabaseValue(databaseValue) else {
            return nil
        }
        #if os(Linux)
            // Avoid "constructing an object of class type 'Self' with a
            // metatype value must use a 'required' initializer" error with
            // self.init(...)
            return cast(NSURL(string: string))
        #else
            return self.init(string: string)
        #endif
    }
}

/// URL stores its absoluteString in the database.
extension URL : DatabaseValueConvertible {
    // ReferenceConvertible support on not available on Linux: we need explicit
    // DatabaseValueConvertible adoption.
    #if os(Linux)
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
        return URL(string: string)
    }
    #endif
}
