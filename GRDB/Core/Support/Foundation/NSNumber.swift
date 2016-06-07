import Foundation

/// NSNumber adopts DatabaseValueConvertible
extension NSNumber: DatabaseValueConvertible {
    
    /// Returns a value that can be stored in the database.
    public var databaseValue: DatabaseValue {
        switch String(cString: objCType) {
        case "c":
            return Int64(int8Value).databaseValue
        case "C":
            return Int64(uint8Value).databaseValue
        case "s":
            return Int64(int16Value).databaseValue
        case "S":
            return Int64(uint16Value).databaseValue
        case "i":
            return Int64(int32Value).databaseValue
        case "I":
            return Int64(uint32Value).databaseValue
        case "l":
            return Int64(intValue).databaseValue
        case "L":
            let uint = uintValue
            GRDBPrecondition(UInt64(uint) <= UInt64(Int64.max), "could not convert \(uint) to an Int64 that can be stored in the database")
            return Int64(uint).databaseValue
        case "q":
            return Int64(int64Value).databaseValue
        case "Q":
            let uint64 = uint64Value
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
    public static func fromDatabaseValue(_ databaseValue: DatabaseValue) -> Self? {
        switch databaseValue.storage {
        case .int64(let int64):
            return self.init(value: int64)
        case .double(let double):
            return self.init(value: double)
        default:
            return nil
        }
    }
}
