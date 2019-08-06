import Foundation
#if SWIFT_PACKAGE
import CSQLite
#elseif GRDBCIPHER
import SQLCipher
#elseif !GRDBCUSTOMSQLITE && !GRDBCIPHER
import SQLite3
#endif

// MARK: - DatabaseValue

/// DatabaseValue is the intermediate type between SQLite and your values.
///
/// See https://www.sqlite.org/datatype3.html
public struct DatabaseValue: Hashable, CustomStringConvertible, DatabaseValueConvertible, SQLExpression {
    /// The SQLite storage
    public let storage: Storage
    
    /// The NULL DatabaseValue.
    public static let null = DatabaseValue(storage: .null)
    
    /// An SQLite storage (NULL, INTEGER, REAL, TEXT, BLOB).
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
        return self
    }
    
    /// Returns the database value
    public static func fromDatabaseValue(_ dbValue: DatabaseValue) -> DatabaseValue? {
        return dbValue
    }
}

// SQLExpressible
extension DatabaseValue {
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    /// :nodoc:
    public var sqlExpression: SQLExpression {
        return self
    }
}

// SQLExpression
extension DatabaseValue {
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    /// :nodoc:
    public func expressionSQL(_ context: inout SQLGenerationContext, wrappedInParenthesis: Bool) -> String {
        // fast path for NULL
        if isNull {
            return "NULL"
        }
        
        if context.append(arguments: [self]) {
            return "?"
        } else {
            // Correctness above all: use SQLite to quote the value.
            // Assume that the Quote function always succeeds
            return DatabaseQueue().inDatabase { try! String.fetchOne($0, sql: "SELECT QUOTE(?)", arguments: [self])! }
        }
    }
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    /// :nodoc:
    public var negated: SQLExpression {
        switch storage {
        case .null:
            // SELECT NOT NULL -- NULL
            return DatabaseValue.null
        case .int64(let int64):
            return (int64 == 0).sqlExpression
        case .double(let double):
            return (double == 0.0).sqlExpression
        case .string:
            // We can't assume all strings are true, and return false:
            //
            // SELECT NOT '1' -- 0 (because '1' is turned into the integer 1, which is negated into 0)
            // SELECT NOT '0' -- 1 (because '0' is turned into the integer 0, which is negated into 1)
            return SQLExpressionNot(self)
        case .blob:
            // We can't assume all blobs are true, and return false:
            //
            // SELECT NOT X'31' -- 0 (because X'31' is turned into the string '1',
            //  then into integer 1, which is negated into 0)
            // SELECT NOT X'30' -- 1 (because X'30' is turned into the string '0',
            //  then into integer 0, which is negated into 1)
            return SQLExpressionNot(self)
        }
    }
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    /// :nodoc:
    public func qualifiedExpression(with alias: TableAlias) -> SQLExpression {
        return self
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
