/// NSData is convertible to and from DatabaseValue.
extension NSData : DatabaseValueConvertible {
    /// Returns a value that can be stored in the database.
    public var databaseValue: DatabaseValue {
        if let blob = Blob(data: self) {
            return DatabaseValue.Blob(blob)
        } else {
            return .Null
        }
    }
    
    /// Create an instance initialized to `databaseValue`.
    public static func fromDatabaseValue(databaseValue: DatabaseValue) -> Self? {
        switch databaseValue {
        case .Blob(let blob):
            // error: cannot convert return expression of type 'NSData' to return type 'Self?'
            return self.init(data: blob.data)
            //            return self.init(data: blob.data)   // Return a copy in order to comply to the `Self` return type.
        default:
            return nil
        }
    }
}

extension Blob {
    /// Creates a Blob from NSData. Returns nil if and only if *data* is nil or
    /// zero-length (SQLite can't store empty blobs).
    public init?(data: NSData?) {
        // SQLite can't store empty blobs
        if let data = data where data.length > 0 {
            impl = NSDataImpl(data: data)
        } else {
            return nil
        }
    }
    
    /// Returns an NSData
    public var data: NSData {
        switch impl {
        case let impl as NSDataImpl:
            // Avoid copy
            return impl.data
        default:
            return NSData(bytes: impl.bytes, length: impl.length)
        }
    }
    
    /// A BlobImpl that stores NSData
    private struct NSDataImpl : BlobImpl {
        let data: NSData
        
        var bytes: UnsafePointer<Void> {
            return data.bytes
        }
        
        var length: Int {
            return data.length
        }
    }
}
