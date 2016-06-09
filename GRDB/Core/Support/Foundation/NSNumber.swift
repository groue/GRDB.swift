import Foundation

private let integerRoundingBehavior = NSDecimalNumberHandler(roundingMode: .RoundPlain, scale: 0, raiseOnExactness: false, raiseOnOverflow: false, raiseOnUnderflow: false, raiseOnDivideByZero: false)

/// NSNumber adopts DatabaseValueConvertible
extension NSNumber: DatabaseValueConvertible {
    
    /// Returns a value that can be stored in the database.
    public var databaseValue: DatabaseValue {
        // Don't lose precision: store integers that fits in Int64 as Int64
        if let decimal = self as? NSDecimalNumber
            where decimal == decimal.decimalNumberByRoundingAccordingToBehavior(integerRoundingBehavior) // integer
                && decimal.compare(NSDecimalNumber(longLong: Int64.max)) != .OrderedDescending   // decimal <= Int64.max
                && decimal.compare(NSDecimalNumber(longLong: Int64.min)) != .OrderedAscending    // decimal >= Int64.min
        {
            return longLongValue.databaseValue
        }
        
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
            let uint = unsignedLongValue
            GRDBPrecondition(UInt64(uint) <= UInt64(Int64.max), "could not convert \(uint) to an Int64 that can be stored in the database")
            return Int64(uint).databaseValue
        case "q":
            return Int64(longLongValue).databaseValue
        case "Q":
            let uint64 = unsignedLongLongValue
            GRDBPrecondition(uint64 <= UInt64(Int64.max), "could not convert \(uint64) to an Int64 that can be stored in the database")
            return Int64(uint64).databaseValue
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
