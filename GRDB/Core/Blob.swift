/// A Database Blob
public struct Blob : Equatable {
    
    /// A pointer to the blob's contents.
    var bytes: UnsafePointer<Void> {
        return impl.bytes
    }
    
    /// The number of bytes in the blob.
    var length: Int {
        return impl.length
    }

    /**
    Returns a Blob containing *length* bytes copied from the buffer *bytes*.
    
    Returns nil if length is zero (SQLite can't store empty blobs).
    
    - parameter bytes: A buffer containing blob data.
    - parameter length: The number of bytes to copy from *bytes*. This value
      must not exceed the length of bytes. If zero, the result is nil.
    */
    public init?(bytes: UnsafePointer<Void>, length: Int) {
        guard length > 0 else {
            // SQLite can't store empty blobs
            return nil
        }
        impl = Buffer(bytes: bytes, length: length)
    }
    
    /// The Blob implementation
    let impl: BlobImpl
    
    /// A Blob Implementation that owns a buffer.
    private class Buffer: BlobImpl {
        let bytes: UnsafePointer<Void>
        let length: Int
        
        init(bytes: UnsafePointer<Void>, length: Int) {
            // Copy memory
            let copy = UnsafeMutablePointer<RawByte>.alloc(length)
            copy.initializeFrom(unsafeBitCast(bytes, UnsafeMutablePointer<RawByte>.self), count: length)
            self.bytes = unsafeBitCast(copy, UnsafePointer<Void>.self)
            self.length = length
        }
        
        deinit {
            unsafeBitCast(bytes, UnsafeMutablePointer<RawByte>.self).dealloc(length)
        }
    }
}


// MARK: - DatabaseValueConvertible

/// Blob adopts DatabaseValueConvertible
extension Blob : DatabaseValueConvertible {
    
    /// Returns a value that can be stored in the database.
    public var databaseValue: DatabaseValue {
        return .Blob(self)
    }
    
    /**
    Returns the Blob contained in *databaseValue*, if any.
    
    - parameter databaseValue: A DatabaseValue.
    - returns: An optional Blob.
    */
    public static func fromDatabaseValue(databaseValue: DatabaseValue) -> Blob? {
        switch databaseValue {
        case .Blob(let blob):
            return blob
        default:
            return nil
        }
    }
}


// MARK: - BlobImpl

// The protocol for Blob underlying implementation
protocol BlobImpl {
    var bytes: UnsafePointer<Void> { get }
    var length: Int { get }
}


// MARK: - CustomString

/// DatabaseValue adopts CustomStringConvertible.
extension Blob : CustomStringConvertible {
    /// A textual representation of `self`.
    public var description: String {
        return "Blob(\(length) bytes)"
    }
}

// MARK: - Equatable

/// DatabaseValue adopts Equatable.
public func ==(lhs: Blob, rhs: Blob) -> Bool {
    guard lhs.length == rhs.length else {
        return false
    }
    return memcmp(lhs.bytes, rhs.bytes, lhs.length) == 0
}
