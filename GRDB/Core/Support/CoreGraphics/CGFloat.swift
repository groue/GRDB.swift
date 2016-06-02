import CoreGraphics

/// CGFloat adopts DatabaseValueConvertible
extension CGFloat : DatabaseValueConvertible {

    /// Returns a value that can be stored in the database.
    public var databaseValue: DatabaseValue {
        return Double(self).databaseValue
    }
    
    /// Returns a CGFloat initialized from *databaseValue*, if possible.
    public static func fromDatabaseValue(_ databaseValue: DatabaseValue) -> CGFloat? {
        guard let double = Double.fromDatabaseValue(databaseValue) else {
            return nil
        }
        return CGFloat(double)
    }
}
