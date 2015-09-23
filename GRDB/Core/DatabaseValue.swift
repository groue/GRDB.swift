// MARK: - DatabaseValue

/**
DatabaseValue is the intermediate type between SQLite and your values.

It has five cases that match the SQLite "storage classes":
https://www.sqlite.org/datatype3.html
*/
public struct DatabaseValue : Equatable {
    
    // MARK: - Creating DatabaseValue
    
    /**
    TODO
    */
    public static let Null = DatabaseValue(type: Type.DetachedValue(DetachedValue.Null))
    
    /**
    TODO
    */
    public init(int64: Int64) {
        self.type = .DetachedValue(DetachedValue.Int64(int64))
    }
    
    /**
    TODO
    */
    public init(double: Double) {
        self.type = .DetachedValue(DetachedValue.Double(double))
    }
    
    /**
    TODO
    */
    public init(string: String) {
        self.type = .DetachedValue(DetachedValue.String(string))
    }
    
    /**
    TODO
    */
    public init(blob: Blob) {
        self.type = .DetachedValue(DetachedValue.Blob(blob))
    }
    
    
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
        switch detachedValue {
        case .Null:
            return nil
        case .Int64(let int64):
            return int64
        case .Double(let double):
            return double
        case .String(let string):
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
    (see [rdar://21676393](http://openradar.appspot.com/radar?id=4951414862249984)):
    
        databaseValue.value()! as Int   // OK: Int
        databaseValue.value() as Int?   // OK: Int?
        databaseValue.value() as! Int   // NO NO NO DON'T DO THAT!
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
    
    /**
    TODO
    */
    public func value<Value: protocol<DatabaseValueConvertible, MetalType>>() -> Value? {
        switch type {
        case .MetalValue(let sqliteStatement, let index):
            if sqlite3_column_type(sqliteStatement, Int32(index)) == SQLITE_NULL {
                return nil
            } else {
                return Value(sqliteStatement: sqliteStatement, index: Int32(index))
            }
        case .DetachedValue:
            return Value.fromDatabaseValue(self)
        }
    }
    
    /**
    TODO
    */
    public func value<Value: DatabaseValueConvertible>() -> Value {
        return Value.fromDatabaseValue(self)!
    }
    
    /**
    TODO
    */
    public func value<Value: protocol<DatabaseValueConvertible, MetalType>>() -> Value {
        switch type {
        case .MetalValue(let sqliteStatement, let index):
            return Value(sqliteStatement: sqliteStatement, index: Int32(index))
        case .DetachedValue:
            return Value.fromDatabaseValue(self)!
        }
    }
    
    
    // MARK: - Not Public
    
    enum DetachedValue {
        /// The NULL storage class.
        case Null
        
        /// The INTEGER storage class, wrapping an Int64.
        case Int64(Swift.Int64)
        
        /// The REAL storage class, wrapping a Double.
        case Double(Swift.Double)
        
        /// The TEXT storage class, wrapping a String.
        case String(Swift.String)
        
        /// The BLOB storage class, wrapping a Blob.
        case Blob(GRDB.Blob)
        
        init(sqliteStatement: SQLiteStatement, index: Int) {
            switch sqlite3_column_type(sqliteStatement, Int32(index)) {
            case SQLITE_NULL:
                self = .Null
            case SQLITE_INTEGER:
                self = .Int64(sqlite3_column_int64(sqliteStatement, Int32(index)))
            case SQLITE_FLOAT:
                self = .Double(sqlite3_column_double(sqliteStatement, Int32(index)))
            case SQLITE_TEXT:
                let cString = UnsafePointer<Int8>(sqlite3_column_text(sqliteStatement, Int32(index)))
                self = .String(Swift.String.fromCString(cString)!)
            case SQLITE_BLOB:
                let bytes = sqlite3_column_blob(sqliteStatement, Int32(index))
                let length = sqlite3_column_bytes(sqliteStatement, Int32(index))
                self = .Blob(GRDB.Blob(bytes: bytes, length: Int(length))!) // copy bytes
            default:
                fatalError("Unexpected SQLite column type")
            }
        }
    }
    
    private enum Type {
        case DetachedValue(DatabaseValue.DetachedValue)
        case MetalValue(sqliteStatement: SQLiteStatement, index: Int)
    }
    
    private let type: Type
    
    var detachedValue: DetachedValue {
        switch type {
        case .DetachedValue(let detachedValue):
            return detachedValue
        case .MetalValue(let sqliteStatement, let index):
            return DetachedValue(sqliteStatement: sqliteStatement, index: index)
        }
    }

    init(sqliteStatement: SQLiteStatement, index: Int) {
        self.type = .MetalValue(sqliteStatement: sqliteStatement, index: index)
    }
    
    init(detachedSqliteStatement sqliteStatement: SQLiteStatement, index: Int) {
        self.type = .DetachedValue(DetachedValue(sqliteStatement: sqliteStatement, index: index))
    }
    
    private init(type: Type) {
        self.type = type
    }
}


// MARK: - Equatable

/// DatabaseValue adopts Equatable.
public func ==(lhs: DatabaseValue, rhs: DatabaseValue) -> Bool {
    switch (lhs.detachedValue, rhs.detachedValue) {
    case (.Null, .Null):
        return true
    case (.Int64(let lhs), .Int64(let rhs)):
        return lhs == rhs
    case (.Double(let lhs), .Double(let rhs)):
        return lhs == rhs
    case (.Int64(let lhs), .Double(let rhs)):
        return int64EqualDouble(lhs, rhs)
    case (.Double(let lhs), .Int64(let rhs)):
        return int64EqualDouble(rhs, lhs)
    case (.String(let lhs), .String(let rhs)):
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
        switch detachedValue {
        case .Null:
            return "NULL"
        case .Int64(let integer):
            return String(integer)
        case .Double(let double):
            return String(double)
        case .String(let string):
            return String(reflecting: string)
        case .Blob(let blob):
            return blob.description
        }
    }
}
