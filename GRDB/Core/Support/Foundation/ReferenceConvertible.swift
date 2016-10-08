/// Support for Mustache rendering of ReferenceConvertible types.
extension ReferenceConvertible where Self: DatabaseValueConvertible, Self.ReferenceType: DatabaseValueConvertible {
    
    /// Returns a value that can be stored in the database.
    public var databaseValue: DatabaseValue {
        return (self as! ReferenceType).databaseValue
    }
    
    /// Returns a value initialized from *databaseValue*, if possible.
    public static func fromDatabaseValue(_ databaseValue: DatabaseValue) -> Self? {
        return ReferenceType.fromDatabaseValue(databaseValue).flatMap { cast($0) }
    }
}
