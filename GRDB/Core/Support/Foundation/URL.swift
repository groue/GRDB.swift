import Foundation

/// NSURL stores its absoluteString in the database.
extension NSURL: DatabaseValueConvertible {

    /// Returns a TEXT database value containing the absolute URL.
    public var databaseValue: DatabaseValue {
        #if !canImport(Darwin)
            absoluteString.databaseValue
        #else
            absoluteString?.databaseValue ?? .null
        #endif
    }

    public static func fromDatabaseValue(_ dbValue: DatabaseValue) -> Self? {
        guard let string = String.fromDatabaseValue(dbValue) else {
            return nil
        }
        return cast(URL(string: string))
    }
}

/// URL stores its absoluteString in the database.
extension URL: DatabaseValueConvertible {}
