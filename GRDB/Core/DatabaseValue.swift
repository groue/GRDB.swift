import Foundation

// MARK: - DatabaseValue

/// DatabaseValue is the intermediate type between SQLite and your values.
///
/// See https://www.sqlite.org/datatype3.html
public struct DatabaseValue {
    
    /// An SQLite storage (NULL, INTEGER, REAL, TEXT, BLOB).
    public enum Storage {
        /// The NULL storage class.
        case Null
        
        /// The INTEGER storage class, wrapping an Int64.
        case Int64(Swift.Int64)
        
        /// The REAL storage class, wrapping a Double.
        case Double(Swift.Double)
        
        /// The TEXT storage class, wrapping a String.
        case String(Swift.String)
        
        /// The BLOB storage class, wrapping NSData.
        case Blob(NSData)
    }
    
    /// The SQLite storage
    public let storage: Storage
    
    /// The NULL DatabaseValue.
    public static let Null = DatabaseValue(storage: .Null)
    
    
    // MARK: - Extracting Value
    
    /// Returns true if databaseValue is NULL.
    public var isNull: Bool {
        switch storage {
        case .Null:
            return true
        default:
            return false
        }
    }
    
    /// Returns Int64, Double, String, NSData or nil.
    public func value() -> DatabaseValueConvertible? {
        switch storage {
        case .Null:
            return nil
        case .Int64(let int64):
            return int64
        case .Double(let double):
            return double
        case .String(let string):
            return string
        case .Blob(let data):
            return data
        }
    }
    
    /// Returns the value, converted to the requested type.
    ///
    /// The result is nil if the SQLite value is NULL, or if the SQLite value
    /// can not be converted to `Value`.
    ///
    /// Successful conversions include:
    ///
    /// - Integer and real SQLite values to Swift Int, Int32, Int64, Double and
    ///   Bool (zero is the only false boolean).
    /// - Text SQLite values to Swift String.
    /// - Blob SQLite values to NSData.
    ///
    /// Types that adopt DatabaseValueConvertible can provide more conversions.
    ///
    /// - returns: An optional *Value*.
    public func value<Value: DatabaseValueConvertible>() -> Value? {
        return Value.fromDatabaseValue(self)
    }
    
    /// Returns the value, converted to the requested type.
    ///
    /// This method crashes if the SQLite value is NULL, or if the SQLite value
    /// can not be converted to `Value`.
    ///
    /// Successful conversions include:
    ///
    /// - Integer and real SQLite values to Swift Int, Int32, Int64, Double and
    ///   Bool (zero is the only false boolean).
    /// - Text SQLite values to Swift String.
    /// - Blob SQLite values to NSData.
    ///
    /// Types that adopt DatabaseValueConvertible can provide more conversions.
    ///
    /// - returns: A *Value*.
    public func value<Value: DatabaseValueConvertible>() -> Value {
        guard let value = Value.fromDatabaseValue(self) as Value? else {
            fatalError("could not convert \(self) to \(Value.self).")
        }
        return value
    }
    
    
    // MARK: - Not Public
    
    init(storage: Storage) {
        // This initializer is not public because Storage is not a safe type:
        // one can create a Storage of zero-length NSData, which is invalid
        // because SQLite can't store zero-length blobs.
        self.storage = storage
    }
    
    // SQLite function argument
    init(sqliteValue: SQLiteValue) {
        switch sqlite3_value_type(sqliteValue) {
        case SQLITE_NULL:
            storage = .Null
        case SQLITE_INTEGER:
            storage = .Int64(sqlite3_value_int64(sqliteValue))
        case SQLITE_FLOAT:
            storage = .Double(sqlite3_value_double(sqliteValue))
        case SQLITE_TEXT:
            let cString = UnsafePointer<Int8>(sqlite3_value_text(sqliteValue))
            storage = .String(Swift.String.fromCString(cString)!)
        case SQLITE_BLOB:
            let bytes = sqlite3_value_blob(sqliteValue)
            let length = sqlite3_value_bytes(sqliteValue)
            storage = .Blob(NSData(bytes: bytes, length: Int(length))) // copy bytes
        case let type:
            fatalError("Unexpected SQLite value type: \(type)")
        }
    }
}


// MARK: - Hashable & Equatable

/// DatabaseValue adopts Hashable.
extension DatabaseValue : Hashable {
    
    /// The hash value
    public var hashValue: Int {
        switch storage {
        case .Null:
            return 0
        case .Int64(let int64):
            // 1 == 1.0, hence 1 and 1.0 must have the same hash:
            return Double(int64).hashValue
        case .Double(let double):
            return double.hashValue
        case .String(let string):
            return string.hashValue
        case .Blob(let data):
            return data.hashValue
        }
    }
}

/// DatabaseValue adopts Equatable.
public func ==(lhs: DatabaseValue, rhs: DatabaseValue) -> Bool {
    switch (lhs.storage, rhs.storage) {
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

/// Returns true if i and d hold exactly the same value, and if converting one
/// type into the other does not lose any information.
private func int64EqualDouble(i: Int64, _ d: Double) -> Bool {
    // See http://stackoverflow.com/questions/33719132/how-to-test-for-lossless-double-integer-conversion/33784296#33784296
    return (d >= Double(Int64.min))
        && (d < Double(Int64.max))
        && (round(d) == d)
        && (i == Int64(d))
}


// MARK: - DatabaseValueConvertible

/// DatabaseValue adopts DatabaseValueConvertible.
extension DatabaseValue : DatabaseValueConvertible {
    /// Returns self
    public var databaseValue: DatabaseValue {
        return self
    }
    
    /// Returns *databaseValue*, or nil for NULL input.
    public static func fromDatabaseValue(databaseValue: DatabaseValue) -> DatabaseValue? {
        // Follow protocol semantics: DatabaseValueConvertible types turn NULL
        // into nil:
        //
        //     DatabaseValue.fetchOne(db, "SELECT NULL") // nil
        return databaseValue.isNull ? nil : databaseValue
    }
}


// MARK: - StatementColumnConvertible

extension DatabaseValue : StatementColumnConvertible {
    
    /// Returns a DatabaseValue initialized from a raw SQLite statement pointer.
    public init(sqliteStatement: SQLiteStatement, index: Int32) {
        switch sqlite3_column_type(sqliteStatement, Int32(index)) {
        case SQLITE_NULL:
            storage = .Null
        case SQLITE_INTEGER:
            storage = .Int64(sqlite3_column_int64(sqliteStatement, Int32(index)))
        case SQLITE_FLOAT:
            storage = .Double(sqlite3_column_double(sqliteStatement, Int32(index)))
        case SQLITE_TEXT:
            let cString = UnsafePointer<Int8>(sqlite3_column_text(sqliteStatement, Int32(index)))
            storage = .String(String.fromCString(cString)!)
        case SQLITE_BLOB:
            let bytes = sqlite3_column_blob(sqliteStatement, Int32(index))
            let length = sqlite3_column_bytes(sqliteStatement, Int32(index))
            storage = .Blob(NSData(bytes: bytes, length: Int(length))) // copy bytes
        case let type:
            fatalError("Unexpected SQLite column type: \(type)")
        }
    }
}


// MARK: - CustomStringConvertible

/// DatabaseValue adopts CustomStringConvertible.
extension DatabaseValue : CustomStringConvertible {
    /// A textual representation of `self`.
    public var description: String {
        switch storage {
        case .Null:
            return "NULL"
        case .Int64(let int64):
            return String(int64)
        case .Double(let double):
            return String(double)
        case .String(let string):
            return String(reflecting: string)
        case .Blob(let data):
            return data.description
        }
    }
}
