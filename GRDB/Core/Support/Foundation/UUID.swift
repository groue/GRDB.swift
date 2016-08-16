import Foundation

/// NSUUID adopts DatabaseValueConvertible
extension UUID: DatabaseValueConvertible {
    
    /// Returns a value that can be stored in the database.
    public var databaseValue: DatabaseValue {
        var uuid = self.uuid
        return withUnsafePointer(to: &uuid) { pointer in
            return NSData(bytes: pointer, length: 16).databaseValue
        }
    }
    
    /// Returns an NSUUID initialized from *databaseValue*, if possible.
    public static func fromDatabaseValue(_ databaseValue: DatabaseValue) -> UUID? {
        guard let data = Data.fromDatabaseValue(databaseValue), data.count == 16 else {
            return nil
        }
        return data.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) in
            let uuid = (
                bytes[0], bytes[1], bytes[2], bytes[3],
                bytes[4], bytes[5], bytes[6], bytes[7],
                bytes[8], bytes[9], bytes[10], bytes[11],
                bytes[12], bytes[13], bytes[14], bytes[15])
            return UUID(uuid: uuid)
        }
    }
}
