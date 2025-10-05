#if canImport(CoreGraphics)
import CoreGraphics
#elseif !canImport(Darwin)
import Foundation
#endif

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
