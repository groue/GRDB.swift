import Foundation

#if !os(Linux)
/// NSUUID adopts DatabaseValueConvertible
extension NSUUID : DatabaseValueConvertible {
    
    /// Returns a value that can be stored in the database.
    public var databaseValue: DatabaseValue {
        var uuidBytes = ContiguousArray(repeating: UInt8(0), count: 16)
        return uuidBytes.withUnsafeMutableBufferPointer { buffer in
            getBytes(buffer.baseAddress!)
            return Data(buffer: buffer).databaseValue
        }
    }
    
    /// Returns an NSUUID initialized from *dbValue*, if possible.
    public static func fromDatabaseValue(_ dbValue: DatabaseValue) -> Self? {
        guard let data = Data.fromDatabaseValue(dbValue), data.count == 16 else {
            return nil
        }
        return data.withUnsafeBytes { buffer in
            self.init(uuidBytes: buffer)
        }
    }
}
#endif

/// UUID adopts DatabaseValueConvertible
extension UUID : DatabaseValueConvertible { }
