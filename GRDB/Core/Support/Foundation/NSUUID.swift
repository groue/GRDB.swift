import Foundation

/// NSUUID adopts DatabaseValueConvertible
extension NSUUID: DatabaseValueConvertible {
    
    /// Returns a value that can be stored in the database.
    public var databaseValue: DatabaseValue {
        var uuidBytes = ContiguousArray(count: 16, repeatedValue: UInt8(0))
        return uuidBytes.withUnsafeMutableBufferPointer { buffer in
            getUUIDBytes(buffer.baseAddress)
            return NSData(bytes: buffer.baseAddress, length: 16).databaseValue
        }
    }
    
    /// Returns an NSUUID initialized from *databaseValue*, if possible.
    public static func fromDatabaseValue(databaseValue: DatabaseValue) -> Self? {
        guard let data = NSData.fromDatabaseValue(databaseValue) where data.length == 16 else {
            return nil
        }
        return self.init(UUIDBytes: UnsafePointer<UInt8>(data.bytes))
    }
}
