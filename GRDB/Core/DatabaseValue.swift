import Foundation

/// A value stored in a database table.
///
/// To get `DatabaseValue` instances, you can:
///
/// - Fetch `DatabaseValue` from a ``Database`` instace:
///
///     ```swift
///     try dbQueue.read { db in
///         let dbValue = try DatabaseValue.fetchOne(db, sql: """
///             SELECT name FROM player
///             """)
///     }
///     ```
///
/// - Extract `DatabaseValue` from a database ``Row``:
///
///     ```swift
///     try dbQueue.read { db in
///         if let row = try Row.fetchOne(db, sql: """
///             SELECT name FROM player
///             """)
///         {
///             let dbValue = row[0] as DatabaseValue
///         }
///     }
///     ```
///
/// -  Use the ``DatabaseValueConvertible/databaseValue-1ob9k`` property on a
///   ``DatabaseValueConvertible`` value:
///
///     ```swift
///     let dbValue = DatabaseValue.null
///     let dbValue = 1.databaseValue
///     let dbValue = "Arthur".databaseValue
///     let dbValue = Date().databaseValue
///     ```
///
/// Related SQLite documentation: <https://www.sqlite.org/datatype3.html>
///
/// ## Topics
///
/// ### Creating a DatabaseValue
///
/// - ``init(value:)``
/// - ``null``
///
/// ### Accessing the SQLite storage
///
/// - ``isNull``
/// - ``storage-swift.property``
/// - ``Storage-swift.enum``
public struct DatabaseValue: Hashable {
    /// The SQLite storage.
    public let storage: Storage
    
    /// The NULL DatabaseValue.
    public static let null = DatabaseValue(storage: .null)
    
    /// A value stored in a database table, with its exact SQLite storage
    /// (NULL, INTEGER, REAL, TEXT, BLOB).
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/datatype3.html#storage_classes_and_datatypes>
    @frozen
    public enum Storage {
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
        
        /// Returns `Int64`, `Double`, `String`, `Data` or nil.
        public var value: (any DatabaseValueConvertible)? {
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
    }
    
    /// Creates a `DatabaseValue` from any value.
    ///
    /// The result is nil unless `value` adopts ``DatabaseValueConvertible``.
    public init?(value: Any) {
        guard let convertible = value as? any DatabaseValueConvertible else {
            return nil
        }
        self = convertible.databaseValue
    }
    
    // MARK: - Extracting Value
    
    /// A boolean value indicating is the database value is `NULL`.
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
    
    /// Creates a `DatabaseValue` initialized from a raw SQLite statement pointer.
    init(sqliteStatement: SQLiteStatement, index: CInt) {
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
    
    /// Calls the given closure after binding a statement argument.
    ///
    /// The binding is valid only during the execution of this method.
    ///
    /// - parameter sqliteStatement: An SQLite statement.
    /// - parameter index: 1-based index to statement arguments.
    /// - parameter body: The closure to execute when argument is bound.
    func withBinding<T>(to sqliteStatement: SQLiteStatement, at index: CInt, do body: () throws -> T) throws -> T {
        switch storage {
        case .null:
            let code = sqlite3_bind_null(sqliteStatement, index)
            try checkBindingSuccess(code: code, sqliteStatement: sqliteStatement)
            return try body()
        case .int64(let int64):
            let code = int64.bind(to: sqliteStatement, at: index)
            try checkBindingSuccess(code: code, sqliteStatement: sqliteStatement)
            return try body()
        case .double(let double):
            let code = double.bind(to: sqliteStatement, at: index)
            try checkBindingSuccess(code: code, sqliteStatement: sqliteStatement)
            return try body()
        case .string(let string):
            return try string.withBinding(to: sqliteStatement, at: index, do: body)
        case .blob(let data):
            return try data.withBinding(to: sqliteStatement, at: index, do: body)
        }
    }
}

extension DatabaseValue: Sendable { }

// @unchecked Sendable because Data is not Sendable in all target OS
extension DatabaseValue.Storage: @unchecked Sendable { }

// MARK: - Hashable & Equatable

extension DatabaseValue.Storage: Equatable {
    /// Return true if the storages are identical.
    ///
    /// Unlike ``DatabaseValue`` equality that considers the integer 1 as
    /// equal to the 1.0 double (as SQLite does), int64 and double storages
    /// are never equal.
    public static func == (_ lhs: Self, _ rhs: Self) -> Bool {
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

extension DatabaseValue: Equatable {
    /// Returns whether two ``DatabaseValue`` are equal.
    ///
    /// For example:
    ///
    /// ```swift
    /// 1.databaseValue == "foo".databaseValue // false
    /// 1.databaseValue == 1.databaseValue     // true
    /// ```
    ///
    /// When comparing integers and doubles, the result is true if and only
    /// values are equal, and if converting one type to the other does
    /// not lose information:
    ///
    /// ```swift
    /// 1.databaseValue == 1.0.databaseValue   // true
    /// ```
    ///
    /// For a comparison that distinguishes integer and doubles, compare
    /// storages instead:
    ///
    /// ```swift
    /// 1.databaseValue.storage == 1.0.databaseValue.storage // false
    /// ```
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

extension DatabaseValue {
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
}

extension DatabaseValue: DatabaseValueConvertible {
    /// Returns self
    public var databaseValue: DatabaseValue {
        self
    }
    
    /// Returns the database value
    public static func fromDatabaseValue(_ dbValue: DatabaseValue) -> DatabaseValue? {
        dbValue
    }
}

extension DatabaseValue: SQLSpecificExpressible {
    public var sqlExpression: SQLExpression {
        .databaseValue(self)
    }
}

extension DatabaseValue: CustomStringConvertible {
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
