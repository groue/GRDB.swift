/// NSData is convertible to and from DatabaseValue.
extension NSData : DatabaseValueConvertible {
    /// Returns a value that can be stored in the database.
    public var databaseValue: DatabaseValue {
        if let blob = Blob(data: self) {
            return DatabaseValue(blob: blob)
        } else {
            return DatabaseValue.Null
        }
    }
    
    /**
    Returns an NSData initialized from *databaseValue*, if it contains a Blob.
    
    The data is *copied*.
    
    - parameter databaseValue: A DatabaseValue.
    - returns: An optional NSData.
    */
    public static func fromDatabaseValue(databaseValue: DatabaseValue) -> Self? {
        if let blob = Blob.fromDatabaseValue(databaseValue) {
            return self.init(data: NSData(bytes: blob.bytes, length: blob.length))
        } else {
            return nil
        }
    }
}

/// Blob support for NSData
extension Blob {
    
    /**
    Creates a Blob from NSData.

    Returns nil if and only if *data* is nil or zero-length (SQLite can't store
    empty blobs).
    
    The data is *copied*.
    
    - parameter data: An NSData
    */
    public convenience init?(data: NSData?) {
        guard let data = data where data.length > 0 else {  // oddly enough, if data.length is not tested here, we have a runtime crash.
            return nil
        }
        self.init(bytes: data.bytes, length: data.length)
    }
    
    /**
    Returns an NSData.
    
    The data is *copied*. See NSData(bytesNoCopy:length:freeWhenDone:) for more
    precise memory management.
    */
    public var data: NSData {
        return NSData(bytes: bytes, length: length)
    }
}
