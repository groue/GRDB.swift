import Foundation
#if SWIFT_PACKAGE
    import CSQLite
#elseif !GRDBCUSTOMSQLITE && !GRDBCIPHER
    import SQLite3
#endif

// MARK: - DatabaseValue

/// DatabaseValue is the intermediate type between SQLite and your values.
///
/// See https://www.sqlite.org/datatype3.html
public struct DatabaseValue {
    /// The SQLite storage
    public let storage: Storage
    
    /// The NULL DatabaseValue.
    public static let null = DatabaseValue(storage: .null)
    
    /// An SQLite storage (NULL, INTEGER, REAL, TEXT, BLOB).
    public enum Storage : Equatable {
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
            case (.int64(let lhs), .int64(let rhs)): return lhs == rhs
            case (.double(let lhs), .double(let rhs)): return lhs == rhs
            case (.string(let lhs), .string(let rhs)): return lhs == rhs
            case (.blob(let lhs), .blob(let rhs)): return lhs == rhs
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
        switch sqlite3_column_type(sqliteStatement, Int32(index)) {
        case SQLITE_NULL:
            storage = .null
        case SQLITE_INTEGER:
            storage = .int64(sqlite3_column_int64(sqliteStatement, Int32(index)))
        case SQLITE_FLOAT:
            storage = .double(sqlite3_column_double(sqliteStatement, Int32(index)))
        case SQLITE_TEXT:
            storage = .string(String(cString: sqlite3_column_text(sqliteStatement, Int32(index))))
        case SQLITE_BLOB:
            if let bytes = sqlite3_column_blob(sqliteStatement, Int32(index)) {
                let count = Int(sqlite3_column_bytes(sqliteStatement, Int32(index)))
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

extension DatabaseValue : Hashable {
    
    /// The hash value
    public var hashValue: Int {
        switch storage {
        case .null:
            return 0
        case .int64(let int64):
            // 1 == 1.0, hence 1 and 1.0 must have the same hash:
            return Double(int64).hashValue
        case .double(let double):
            return double.hashValue
        case .string(let string):
            return string.hashValue
        case .blob(let data):
            return data.hashValue
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
        case (.int64(let lhs), .int64(let rhs)):
            return lhs == rhs
        case (.double(let lhs), .double(let rhs)):
            return lhs == rhs
        case (.int64(let lhs), .double(let rhs)):
            return Int64(exactly: rhs) == lhs
        case (.double(let lhs), .int64(let rhs)):
            return rhs == Int64(exactly: lhs)
        case (.string(let lhs), .string(let rhs)):
            return lhs == rhs
        case (.blob(let lhs), .blob(let rhs)):
            return lhs == rhs
        default:
            return false
        }
    }
}

// MARK: - Lossless conversions

extension DatabaseValue {
    /// Converts the database value to the type T.
    ///
    ///     let dbValue = "foo".databaseValue
    ///     let string = dbValue.losslessConvert() as String // "foo"
    ///
    /// Conversion is successful if and only if T.fromDatabaseValue returns a
    /// non-nil value.
    ///
    /// This method crashes with a fatal error when conversion fails.
    ///
    ///     let dbValue = "foo".databaseValue
    ///     let int = dbValue.losslessConvert() as Int // fatalError
    ///
    /// - parameters:
    ///     - sql: Optional SQL statement that enhances the eventual
    ///       conversion error
    ///     - arguments: Optional statement arguments that enhances the eventual
    ///       conversion error
    public func losslessConvert<T>(sql: String? = nil, arguments: StatementArguments? = nil) -> T where T : DatabaseValueConvertible {
        if let value = T.fromDatabaseValue(self) {
            return value
        }
        // Failed conversion: this is data loss, a programmer error.
        var error = "could not convert database value \(self) to \(T.self)"
        if let sql = sql {
            error += " with statement `\(sql)`"
        }
        if let arguments = arguments, !arguments.isEmpty {
            error += " arguments \(arguments)"
        }
        fatalError(error)
    }
    
    /// Converts the database value to the type Optional<T>.
    ///
    ///     let dbValue = "foo".databaseValue
    ///     let string = dbValue.losslessConvert() as String? // "foo"
    ///     let null = DatabaseValue.null.losslessConvert() as String? // nil
    ///
    /// Conversion is successful if and only if T.fromDatabaseValue returns a
    /// non-nil value.
    ///
    /// This method crashes with a fatal error when conversion fails.
    ///
    ///     let dbValue = "foo".databaseValue
    ///     let int = dbValue.losslessConvert() as Int? // fatalError
    ///
    /// - parameters:
    ///     - sql: Optional SQL statement that enhances the eventual
    ///       conversion error
    ///     - arguments: Optional statement arguments that enhances the eventual
    ///       conversion error
    public func losslessConvert<T>(sql: String? = nil, arguments: StatementArguments? = nil) -> T? where T : DatabaseValueConvertible {
        // Use fromDatabaseValue first: this allows DatabaseValue to convert NULL to .null.
        if let value = T.fromDatabaseValue(self) {
            return value
        }
        if isNull {
            // Failed conversion from null: ok
            return nil
        } else {
            // Failed conversion from a non-null database value: this is data
            // loss, a programmer error.
            var error = "could not convert database value \(self) to \(T.self)"
            if let sql = sql {
                error += " with statement `\(sql)`"
            }
            if let arguments = arguments, !arguments.isEmpty {
                error += " arguments \(arguments)"
            }
            fatalError(error)
        }
    }
}

extension DatabaseValue : DatabaseValueConvertible {
    /// Returns self
    public var databaseValue: DatabaseValue {
        return self
    }
    
    /// Returns the database value
    public static func fromDatabaseValue(_ dbValue: DatabaseValue) -> DatabaseValue? {
        return dbValue
    }
}

extension DatabaseValue : SQLExpressible {
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    public var sqlExpression: SQLExpression {
        return self
    }
}

extension DatabaseValue : SQLExpression {
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    public func expressionSQL(_ arguments: inout StatementArguments?) -> String {
        // fast path for NULL
        if isNull {
            return "NULL"
        }
        
        if arguments != nil {
            arguments!.values.append(self)
            return "?"
        } else {
            // Correctness above all: use SQLite to quote the value.
            // Assume that the Quote function always succeeds
            return DatabaseQueue().inDatabase { try! String.fetchOne($0, "SELECT QUOTE(?)", arguments: [self])! }
        }
    }
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
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
            // SELECT NOT X'31' -- 0 (because X'31' is turned into the string '1', then into integer 1, which is negated into 0)
            // SELECT NOT X'30' -- 1 (because X'30' is turned into the string '0', then into integer 0, which is negated into 1)
            return SQLExpressionNot(self)
        }
    }
}

extension DatabaseValue : CustomStringConvertible {
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
            return data.description
        }
    }
}
