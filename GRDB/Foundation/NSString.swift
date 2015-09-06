/// NSString adopts DatabaseValueConvertible
extension NSString: DatabaseValueConvertible {
    
    /// Returns a value that can be stored in the database.
    public var databaseValue: DatabaseValue {
        return .Text(self as String)
    }
    
    /// Create an instance initialized to `databaseValue`.
    public static func fromDatabaseValue(databaseValue: DatabaseValue) -> Self? {
        if let string = String.fromDatabaseValue(databaseValue) {
            return self.init(string: string)
        } else {
            return nil
        }
    }
}
