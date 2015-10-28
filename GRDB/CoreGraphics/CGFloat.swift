import CoreGraphics

/// CGFloat adopts DatabaseValueConvertible
extension CGFloat : DatabaseValueConvertible {

    public var databaseValue: DatabaseValue {
        return DatabaseValue(double: Double(self))
    }
    
    public static func fromDatabaseValue(databaseValue: DatabaseValue) -> CGFloat? {
        guard let double = Double.fromDatabaseValue(databaseValue) else {
            return nil
        }
        return CGFloat(double)
    }
}
