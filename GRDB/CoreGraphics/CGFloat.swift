import CoreGraphics

/// CGFloat adopts DatabaseValueConvertible
extension CGFloat : DatabaseValueConvertible {

    /// Returns a value that can be stored in the database.
    public var databaseValue: DatabaseValue {
        return DatabaseValue(double: Double(self))
    }
    
    /// Returns an instance initialized from *databaseValue*, if possible.
    ///
    /// - parameter databaseValue: A DatabaseValue.
    /// - returns: An optional CGFloat.
    public static func fromDatabaseValue(databaseValue: DatabaseValue) -> CGFloat? {
        guard let double = Double.fromDatabaseValue(databaseValue) else {
            return nil
        }
        return CGFloat(double)
    }
}
