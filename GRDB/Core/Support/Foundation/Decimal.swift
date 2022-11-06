#if !os(Linux)
import Foundation

/// Decimal adopts DatabaseValueConvertible
extension Decimal: DatabaseValueConvertible {
    /// Returns a TEXT decimal value.
    public var databaseValue: DatabaseValue {
        NSDecimalNumber(decimal: self)
            .description(withLocale: Locale(identifier: "en_US_POSIX"))
            .databaseValue
    }
    
    /// Creates an `Decimal` with the specified database value.
    ///
    /// If the database value contains a integer or a double, returns a
    /// `Decimal` initialized from this number.
    ///
    /// If the database value contains a string, parses the string with the
    /// `en_US_POSIX` locale.
    ///
    /// Otherwise, returns nil.
    public static func fromDatabaseValue(_ dbValue: DatabaseValue) -> Self? {
        switch dbValue.storage {
        case .int64(let int64):
            return self.init(int64)
        case .double(let double):
            return self.init(double)
        case let .string(string):
            // Must match NSNumber.fromDatabaseValue(_:)
            return self.init(string: string, locale: _posixLocale)
        default:
            return nil
        }
    }
}

/// Decimal adopts StatementColumnConvertible
extension Decimal: StatementColumnConvertible {
    @inline(__always)
    @inlinable
    public init?(sqliteStatement: SQLiteStatement, index: CInt) {
        switch sqlite3_column_type(sqliteStatement, index) {
        case SQLITE_INTEGER:
            self.init(sqlite3_column_int64(sqliteStatement, index))
        case SQLITE_FLOAT:
            self.init(sqlite3_column_double(sqliteStatement, index))
        case SQLITE_TEXT:
            self.init(
                string: String(cString: sqlite3_column_text(sqliteStatement, index)!),
                locale: _posixLocale)
        default:
            return nil
        }
    }
}

@usableFromInline
let _posixLocale = Locale(identifier: "en_US_POSIX")
#endif
