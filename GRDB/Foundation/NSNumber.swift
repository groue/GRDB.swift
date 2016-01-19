import Foundation

/// NSNumber adopts DatabaseValueConvertible
extension NSNumber: DatabaseValueConvertible {
    
    /// Returns a value that can be stored in the database.
    public var databaseValue: DatabaseValue {
        switch String.fromCString(objCType)! {
        case "c":
            return Int64(charValue).databaseValue
        case "C":
            return Int64(unsignedCharValue).databaseValue
        case "s":
            return Int64(shortValue).databaseValue
        case "S":
            return Int64(unsignedShortValue).databaseValue
        case "i":
            return Int64(intValue).databaseValue
        case "I":
            return Int64(unsignedIntValue).databaseValue
        case "l":
            return Int64(longValue).databaseValue
        case "L":
            return Int64(unsignedLongValue).databaseValue
        case "q":
            return Int64(longLongValue).databaseValue
        case "Q":
            return Int64(unsignedLongLongValue).databaseValue
        case "f":
            return Double(floatValue).databaseValue
        case "d":
            return doubleValue.databaseValue
        case "B":
            return boolValue.databaseValue
        case let objCType:
            fatalError("DatabaseValueConvertible: Unsupported NSNumber type: \(objCType)")
        }
    }
    
    /// Returns an NSNumber initialized from *databaseValue*, if possible.
    public static func fromDatabaseValue(databaseValue: DatabaseValue) -> Self? {
        switch databaseValue.storage {
        case .Int64(let int64):
            return self.init(longLong: int64)
        case .Double(let double):
            return self.init(double: double)
        default:
            return nil
        }
    }
}
