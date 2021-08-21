import Foundation

// MARK: - DatabaseValue

/// DatabaseValue is the intermediate type between SQLite and your values.
///
/// See <https://www.sqlite.org/datatype3.html>
public struct DatabaseValue: Hashable, CustomStringConvertible, DatabaseValueConvertible, SQLSpecificExpressible {
    /// The SQLite storage
    public let storage: Storage
    
    /// The NULL DatabaseValue.
    public static let null = DatabaseValue(storage: .null)
    
    /// An SQLite storage (NULL, INTEGER, REAL, TEXT, BLOB).
    @frozen
    public enum Storage: Equatable {
        /// The NULL storage class.
        case null
        
        /// The INTEGER storage class, wrapping an Int64.
        case int64(Int64)
        
        /// The REAL storage class, wrapping a Double.
        case double(Double)
        
        /// The TEXT storage class, wrapping a String.
        case string(String)
        
        /// The BLOB storage class, wrapping Data.
        case blob(Data)
        
        /// Returns Int64, Double, String, Data or nil.
        public var value: DatabaseValueConvertible? {
            switch self {
            case .null:
                return nil
            case .int64(let int64):
                return int64
            case .double(let double):
                return double
            case .string(let string):
                return string
            case .blob(let data):
                return data
            }
        }
        
        /// Return true if the storages are identical.
        ///
        /// Unlike DatabaseValue equality that considers the integer 1 to be
        /// equal to the 1.0 double (as SQLite does), int64 and double storages
        /// are never equal.
        public static func == (_ lhs: Storage, _ rhs: Storage) -> Bool {
            switch (lhs, rhs) {
            case (.null, .null): return true
            case let (.int64(lhs), .int64(rhs)): return lhs == rhs
            case let (.double(lhs), .double(rhs)): return lhs == rhs
            case let (.string(lhs), .string(rhs)): return lhs == rhs
            case let (.blob(lhs), .blob(rhs)): return lhs == rhs
            default: return false
            }
        }
    }
    
    /// Creates a DatabaseValue from Any.
    ///
    /// The result is nil unless object adopts DatabaseValueConvertible.
    public init?(value: Any) {
        guard let convertible = value as? DatabaseValueConvertible else {
            return nil
        }
        self = convertible.databaseValue
    }
    
    // MARK: - Extracting Value
    
    /// Returns true if databaseValue is NULL.
    public var isNull: Bool {
        switch storage {
        case .null:
            return true
        default:
            return false
        }
    }
    
    // MARK: - Not Public
    
    init(storage: Storage) {
        self.storage = storage
    }
    
    // SQLite function argument
    init(sqliteValue: SQLiteValue) {
        switch sqlite3_value_type(sqliteValue) {
        case SQLITE_NULL:
            storage = .null
        case SQLITE_INTEGER:
            storage = .int64(sqlite3_value_int64(sqliteValue))
        case SQLITE_FLOAT:
            storage = .double(sqlite3_value_double(sqliteValue))
        case SQLITE_TEXT:
            storage = .string(String(cString: sqlite3_value_text(sqliteValue)!))
        case SQLITE_BLOB:
            if let bytes = sqlite3_value_blob(sqliteValue) {
                let count = Int(sqlite3_value_bytes(sqliteValue))
                storage = .blob(Data(bytes: bytes, count: count)) // copy bytes
            } else {
                storage = .blob(Data())
            }
        case let type:
            // Assume a GRDB bug: there is no point throwing any error.
            fatalError("Unexpected SQLite value type: \(type)")
        }
    }
    
    /// Returns a DatabaseValue initialized from a raw SQLite statement pointer.
    init(sqliteStatement: SQLiteStatement, index: Int32) {
        switch sqlite3_column_type(sqliteStatement, index) {
        case SQLITE_NULL:
            storage = .null
        case SQLITE_INTEGER:
            storage = .int64(sqlite3_column_int64(sqliteStatement, index))
        case SQLITE_FLOAT:
            storage = .double(sqlite3_column_double(sqliteStatement, index))
        case SQLITE_TEXT:
            storage = .string(String(cString: sqlite3_column_text(sqliteStatement, index)))
        case SQLITE_BLOB:
            if let bytes = sqlite3_column_blob(sqliteStatement, index) {
                let count = Int(sqlite3_column_bytes(sqliteStatement, index))
                storage = .blob(Data(bytes: bytes, count: count)) // copy bytes
            } else {
                storage = .blob(Data())
            }
        case let type:
            // Assume a GRDB bug: there is no point throwing any error.
            fatalError("Unexpected SQLite column type: \(type)")
        }
    }
}

extension DatabaseValue: StatementBinding {
    public func bind(to sqliteStatement: SQLiteStatement, at index: CInt) -> CInt {
        switch storage {
        case .null:
            return sqlite3_bind_null(sqliteStatement, index)
        case .int64(let int64):
            return int64.bind(to: sqliteStatement, at: index)
        case .double(let double):
            return double.bind(to: sqliteStatement, at: index)
        case .string(let string):
            return string.bind(to: sqliteStatement, at: index)
        case .blob(let data):
            return data.bind(to: sqliteStatement, at: index)
        }
    }
}

// MARK: - Hashable & Equatable

// Hashable
extension DatabaseValue {
    
    /// :nodoc:
    public func hash(into hasher: inout Hasher) {
        switch storage {
        case .null:
            hasher.combine(0)
        case .int64(let int64):
            // 1 == 1.0, hence 1 and 1.0 must have the same hash:
            hasher.combine(Double(int64))
        case .double(let double):
            hasher.combine(double)
        case .string(let string):
            hasher.combine(string)
        case .blob(let data):
            hasher.combine(data)
        }
    }
    
    /// Returns whether two DatabaseValues are equal.
    ///
    ///     1.databaseValue == "foo".databaseValue // false
    ///     1.databaseValue == 1.databaseValue     // true
    ///
    /// When comparing integers and doubles, the result is true if and only
    /// values are equal, and if converting one type to the other does
    /// not lose information:
    ///
    ///     1.databaseValue == 1.0.databaseValue   // true
    ///
    /// For a comparison that distinguishes integer and doubles, compare
    /// storages instead:
    ///
    ///     1.databaseValue.storage == 1.0.databaseValue.storage // false
    public static func == (lhs: DatabaseValue, rhs: DatabaseValue) -> Bool {
        switch (lhs.storage, rhs.storage) {
        case (.null, .null):
            return true
        case let (.int64(lhs), .int64(rhs)):
            return lhs == rhs
        case let (.double(lhs), .double(rhs)):
            return lhs == rhs
        case let (.int64(lhs), .double(rhs)):
            return Int64(exactly: rhs) == lhs
        case let (.double(lhs), .int64(rhs)):
            return rhs == Int64(exactly: lhs)
        case let (.string(lhs), .string(rhs)):
            return lhs == rhs
        case let (.blob(lhs), .blob(rhs)):
            return lhs == rhs
        default:
            return false
        }
    }
}

// DatabaseValueConvertible
extension DatabaseValue {
    /// Returns self
    public var databaseValue: DatabaseValue {
        self
    }
    
    /// Returns the database value
    public static func fromDatabaseValue(_ dbValue: DatabaseValue) -> DatabaseValue? {
        dbValue
    }
}

// SQLExpressible
extension DatabaseValue {
    public var sqlExpression: SQLExpression {
        .databaseValue(self)
    }
}

// CustomStringConvertible
extension DatabaseValue {
    /// :nodoc:
    public var description: String {
        switch storage {
        case .null:
            return "NULL"
        case .int64(let int64):
            return String(int64)
        case .double(let double):
            return String(double)
        case .string(let string):
            return String(reflecting: string)
        case .blob(let data):
            return "Data(\(data.description))"
        }
    }
}

/// Compares DatabaseValue like SQLite.
///
/// See RxGRDB for tests.
///
/// This comparison is not public because it does not handle text collations,
/// and may be dangerous when put in user hands.
///
/// So far, the only goal of this sorting method so far is aesthetic, and
/// easier testing.
func < (lhs: DatabaseValue, rhs: DatabaseValue) -> Bool {
    switch (lhs.storage, rhs.storage) {
    case let (.int64(lhs), .int64(rhs)):
        return lhs < rhs
    case let (.double(lhs), .double(rhs)):
        return lhs < rhs
    case let (.int64(lhs), .double(rhs)):
        return Double(lhs) < rhs
    case let (.double(lhs), .int64(rhs)):
        return lhs < Double(rhs)
    case let (.string(lhs), .string(rhs)):
        return lhs.utf8.lexicographicallyPrecedes(rhs.utf8)
    case let (.blob(lhs), .blob(rhs)):
        return lhs.lexicographicallyPrecedes(rhs, by: <)
    case (.blob, _):
        return false
    case (_, .blob):
        return true
    case (.string, _):
        return false
    case (_, .string):
        return true
    case (.int64, _), (.double, _):
        return false
    case (_, .int64), (_, .double):
        return true
    case (.null, _):
        return false
    case (_, .null):
        return true
    }
}
