#if canImport(CoreGraphics)
import CoreGraphics

/// CGFloat adopts DatabaseValueConvertible
extension CGFloat: DatabaseValueConvertible {
    /// Returns a REAL database value.
    public var databaseValue: DatabaseValue {
        Double(self).databaseValue
    }
    
    public static func fromDatabaseValue(_ dbValue: DatabaseValue) -> CGFloat? {
        guard let double = Double.fromDatabaseValue(dbValue) else {
            return nil
        }
        return CGFloat(double)
    }
}
#endif
