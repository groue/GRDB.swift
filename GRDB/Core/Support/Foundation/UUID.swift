import Foundation

/// NSUUID adopts DatabaseValueConvertible
extension NSUUID : DatabaseValueConvertible {
    
    /// Returns a value that can be stored in the database.
    public var databaseValue: DatabaseValue {
        var uuidBytes = ContiguousArray(repeating: UInt8(0), count: 16)
        return uuidBytes.withUnsafeMutableBufferPointer { buffer in
            #if os(Linux)
                getBytes(buffer.baseAddress!)
            #else
                getBytes(buffer.baseAddress)
            #endif
            return NSData(bytes: buffer.baseAddress, length: 16).databaseValue
        }
    }
    
    /// Returns an NSUUID initialized from *databaseValue*, if possible.
    public static func fromDatabaseValue(_ databaseValue: DatabaseValue) -> Self? {
        guard let data = NSData.fromDatabaseValue(databaseValue), data.length == 16 else {
            return nil
        }
        #if os(Linux)
            return cast(NSUUID.init(uuidBytes: data.bytes.assumingMemoryBound(to: UInt8.self)))
        #else
            return self.init(uuidBytes: data.bytes.assumingMemoryBound(to: UInt8.self))
        #endif
    }
}

/// UUID adopts DatabaseValueConvertible
extension UUID : DatabaseValueConvertible {
    // ReferenceConvertible support on not available on Linux: we need explicit
    // DatabaseValueConvertible adoption.
    #if os(Linux)
    /// Returns a value that can be stored in the database.
    public var databaseValue: DatabaseValue {
        var uuid = self.uuid
        return withUnsafePointer(to: &uuid) { pointer in
            return NSData(bytes: pointer, length: 16).databaseValue
        }
    }
    
    /// Returns a UUID initialized from *databaseValue*, if possible.
    public static func fromDatabaseValue(_ databaseValue: DatabaseValue) -> UUID? {
        guard let data = Data.fromDatabaseValue(databaseValue), data.count == 16 else {
            return nil
        }
        var uuid: uuid_t = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
        withUnsafeMutableBytes(of: &uuid) { buffer in
            buffer.copyBytes(from: data)
        }
        return UUID(uuid: uuid)
    }
    #endif
}
