import CoreGraphics

/// CGFloat adopts DatabaseValueConvertible
extension CGFloat : DatabaseValueConvertible {

    /// Returns a value that can be stored in the database.
    public var databaseValue: DatabaseValue {
        return Double(self).databaseValue
    }
    
    /// Returns a CGFloat initialized from *dbValue*, if possible.
    public static func fromDatabaseValue(_ dbValue: DatabaseValue) -> CGFloat? {
        guard let double = Double.fromDatabaseValue(dbValue) else {
            return nil
        }
        return CGFloat(double)
    }
}
