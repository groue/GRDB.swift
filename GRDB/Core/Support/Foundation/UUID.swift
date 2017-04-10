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
        // Error: constructing an object of class type 'Self' with a metatype value must use a 'required' initializer
        //return self.init(UUIDBytes: UnsafePointer<UInt8>(OpaquePointer(data.bytes)))
        // Workaround:
        let coder = NSCoder()
        let uuid = NSUUID(uuidBytes: data.bytes.assumingMemoryBound(to: UInt8.self))
        uuid.encode(with: coder)
        return self.init(coder: coder)
        #else
        return self.init(uuidBytes: data.bytes.assumingMemoryBound(to: UInt8.self))
        #endif
    }
}

/// UUID adopts DatabaseValueConvertible
extension UUID : DatabaseValueConvertible { }
