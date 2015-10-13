/// NSData is convertible to and from DatabaseValue.
extension NSData : DatabaseValueConvertible {
    /// Returns a value that can be stored in the database.
    public var databaseValue: DatabaseValue {
        return DatabaseValue(data: self)
    }
    
    /**
    Returns an NSData initialized from *databaseValue*, if it contains a Blob.
    
    The data is *copied*.
    
    - parameter databaseValue: A DatabaseValue.
    - returns: An optional NSData.
    */
    public static func fromDatabaseValue(databaseValue: DatabaseValue) -> Self? {
        switch databaseValue.storage {
        case .Blob(let data):
            return self.init(data: data)
        default:
            return nil
        }
    }
}
