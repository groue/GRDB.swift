/// A Database Blob
public final class Blob : Equatable {
    
    /// A pointer to the blob's contents.
    public let bytes: UnsafePointer<Void>

    /// The number of bytes in the blob.
    public let length: Int

    let freeWhenDone: Bool
    
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
            self.bytes = nil
            self.length = 0
            self.freeWhenDone = false
            return nil
        }
        
        let copy = UnsafeMutablePointer<RawByte>.alloc(length)
        copy.initializeFrom(unsafeBitCast(bytes, UnsafeMutablePointer<RawByte>.self), count: length)
        self.bytes = unsafeBitCast(copy, UnsafePointer<Void>.self)
        self.length = length
        self.freeWhenDone = true
    }

    /**
    Returns a Blob containing *length* bytes from the buffer *bytes*.
    
    Returns nil if length is zero (SQLite can't store empty blobs).
    
    - parameter bytes: A buffer containing blob data.
    - parameter length: The number of bytes. If zero, the result is nil.
    - parameter freeWhenDone: If true, the returned object takes ownership of
                the bytes pointer and frees it on deallocation.
    */
    public init?(bytesNoCopy bytes: UnsafePointer<Void>, length: Int, freeWhenDone: Bool) {
        guard length > 0 else {
            // SQLite can't store empty blobs
            self.bytes = nil
            self.length = 0
            self.freeWhenDone = false
            return nil
        }
        
        self.bytes = bytes
        self.length = length
        self.freeWhenDone = freeWhenDone
    }
    
    deinit {
        if freeWhenDone {
            unsafeBitCast(bytes, UnsafeMutablePointer<RawByte>.self).dealloc(length)
        }
    }
}


// MARK: - DatabaseValueConvertible

/// Blob adopts DatabaseValueConvertible and MetalType.
extension Blob : DatabaseValueConvertible, MetalType {
    
    /// Metal Blob does not copy, does not take ownership of statement bytes.
    public convenience init(sqliteStatement: SQLiteStatement, index: Int32) {
        let bytes = sqlite3_column_blob(sqliteStatement, index)
        let length = sqlite3_column_bytes(sqliteStatement, index)
        self.init(bytesNoCopy: bytes, length: Int(length), freeWhenDone: false)!
    }
    
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
