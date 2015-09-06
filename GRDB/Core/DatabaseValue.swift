// MARK: - DatabaseValue

/**
DatabaseValue is the intermediate type between SQLite and your values.

It has five cases that match the SQLite "storage classes":
https://www.sqlite.org/datatype3.html
*/
public enum DatabaseValue : Equatable {
    
    /// The NULL storage class.
    case Null
    
    /// The INTEGER storage class, wrapping an Int64.
    case Integer(Int64)
    
    /// The REAL storage class, wrapping a Double.
    case Real(Double)
    
    /// The TEXT storage class, wrapping a String.
    case Text(String)
    
    /// The BLOB storage class, wrapping a Blob.
    case Blob(GRDB.Blob)
    
    
    // MARK: - Extracting Swift Value
    
    /**
    Returns the wrapped value.
    
    If not nil (for the database NULL), its type is guaranteed to be one of the
    following: Int64, Double, String, and Blob.
    
    let value = databaseValue.value()
    */
    public func value() -> DatabaseValueConvertible? {
        // IMPLEMENTATION NOTE
        // This method has a single know use case: checking if the value is nil,
        // as in:
        //
        //     if dbv.value() != nil { ... }
        //
        // Without this method, the code above would not compile.
        switch self {
        case .Null:
            return nil
        case .Integer(let int64):
            return int64
        case .Real(let double):
            return double
        case .Text(let string):
            return string
        case .Blob(let blob):
            return blob
        }
    }
    
    /**
    Returns the wrapped value, converted to the requested type.
    
    The conversion returns nil if the SQLite value is NULL, or can't be
    converted to the requested type:
    
        let value: Bool? = databaseValue.value()
        let value: Int? = databaseValue.value()
        let value: Double? = databaseValue.value()
    
    **WARNING**: type casting requires a very careful use of the `as` operator
    (see [rdar://problem/21676393](http://openradar.appspot.com/radar?id=4951414862249984)):
    
        databaseValue.value()! as Int   // OK: Int
        databaseValue.value() as Int?   // OK: Int?
        databaseValue.value() as? Int   // NO NO NO DON'T DO THAT!
    
    Your custom types that adopt the DatabaseValueConvertible protocol handle
    their own conversion from raw SQLite values. Yet, here is the reference for
    built-in types:
    
    SQLite value: | NULL    INTEGER         REAL            TEXT        BLOB
    --------------|---------------------------------------------------------
    Bool          | nil     false if 0      false if 0.0    nil         nil
    Int           | nil     Int(*)          Int(*)          nil         nil
    Int64         | nil     Int64           Int64(*)        nil         nil
    Double        | nil     Double          Double          nil         nil
    String        | nil     nil             nil             String      nil
    Blob          | nil     nil             nil             nil         Blob
    
    (*) Conversions to Int and Int64 crash if the value is too big.
    
    */
    public func value<Value: DatabaseValueConvertible>() -> Value? {
        return Value.fromDatabaseValue(self)
    }
}


// MARK: - Equatable

/// DatabaseValue adopts Equatable.
public func ==(lhs: DatabaseValue, rhs: DatabaseValue) -> Bool {
    switch (lhs, rhs) {
    case (.Null, .Null):
        return true
    case (.Integer(let lhs), .Integer(let rhs)):
        return lhs == rhs
    case (.Real(let lhs), .Real(let rhs)):
        return lhs == rhs
    case (.Integer(let lhs), .Real(let rhs)):
        return int64EqualDouble(lhs, rhs)
    case (.Real(let lhs), .Integer(let rhs)):
        return int64EqualDouble(rhs, lhs)
    case (.Text(let lhs), .Text(let rhs)):
        return lhs == rhs
    case (.Blob(let lhs), .Blob(let rhs)):
        return lhs == rhs
    default:
        return false
    }
}

private func int64EqualDouble(i: Int64, _ d: Double) -> Bool {
    if d >= Double(Int64.min) && d < Double(Int64.max) {
        return round(d) == d && i == Int64(d)
    } else {
        return false
    }
}


// MARK: - DatabaseValueConvertible

/// DatabaseValue adopts DatabaseValueConvertible.
extension DatabaseValue : DatabaseValueConvertible {
    /// Returns self
    public var databaseValue: DatabaseValue {
        return self
    }
    
    /**
    Returns *databaseValue*.
    
    - parameter databaseValue: A DatabaseValue.
    - returns: *databaseValue*.
    */
    public static func fromDatabaseValue(databaseValue: DatabaseValue) -> DatabaseValue? {
        return databaseValue
    }
}


// MARK: - CustomStringConvertible

/// DatabaseValue adopts CustomStringConvertible.
extension DatabaseValue : CustomStringConvertible {
    /// A textual representation of `self`.
    public var description: String {
        switch self {
        case .Null:
            return "NULL"
        case .Integer(let integer):
            return String(integer)
        case .Real(let double):
            return String(double)
        case .Text(let string):
            return String(reflecting: string)
        case .Blob(let blob):
            return blob.description
        }
    }
}
