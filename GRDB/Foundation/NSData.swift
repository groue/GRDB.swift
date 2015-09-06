/// NSData is convertible to and from DatabaseValue.
extension NSData : DatabaseValueConvertible {
    /// Returns a value that can be stored in the database.
    public var databaseValue: DatabaseValue {
        if let blob = Blob(self) {
            return DatabaseValue.Blob(blob)
        } else {
            return .Null
        }
    }
    
    /// Create an instance initialized to `databaseValue`.
    public static func fromDatabaseValue(databaseValue: DatabaseValue) -> Self? {
        switch databaseValue {
        case .Blob(let blob):
            // error: cannot convert return expression of type 'NSData' to return type 'Self?'
            return self.init(data: blob.data)
            //            return self.init(data: blob.data)   // Return a copy in order to comply to the `Self` return type.
        default:
            return nil
        }
    }
}
