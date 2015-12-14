import Foundation

/// NSData is convertible to and from DatabaseValue.
extension NSData : DatabaseValueConvertible {
    /// Returns a value that can be stored in the database.
    public var databaseValue: DatabaseValue {
        return DatabaseValue(data: self)
    }
    
    /// Returns an NSData initialized from *databaseValue*, if it contains
    /// a Blob.
    ///
    /// Whether the data is copied or not depends on the behavior of
    /// `Self.init(data: NSData)`. For NSData itself, the data is *not copied*.
    ///
    /// - parameter databaseValue: A DatabaseValue.
    /// - returns: An optional NSData.
    public static func fromDatabaseValue(databaseValue: DatabaseValue) -> Self? {
        switch databaseValue.storage {
        case .Blob(let data):
            return self.init(data: data)    // When Self is NSData, the buffer is not copied.
        default:
            return nil
        }
    }
    
    public static func fromRow(row: Row) -> Self {
        // TODO: test
        guard let data = fromDatabaseValue(row.databaseValues.first!) else {
            fatalError("Could not convert \(row.databaseValues.first!) to NSData.")
        }
        return data
    }
}
