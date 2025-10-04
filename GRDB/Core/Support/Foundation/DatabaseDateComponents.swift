// Import C SQLite functions
#if GRDBCIPHER
import SQLCipher
#elseif SWIFT_PACKAGE
import GRDBSQLite
#elseif !GRDBCUSTOMSQLITE && !GRDBCIPHER
import SQLite3
#endif

import Foundation

/// A database value that holds date components.
public struct DatabaseDateComponents: Sendable {
    
    /// The SQLite formats for date components.
    public enum Format: String, Sendable {
        
        /// The format "yyyy-MM-dd".
        case YMD = "yyyy-MM-dd"
        
        /// The format "yyyy-MM-dd HH:mm".
        ///
        /// This format is lexically comparable with SQLite's CURRENT_TIMESTAMP.
        case YMD_HM = "yyyy-MM-dd HH:mm"
        
        /// The format "yyyy-MM-dd HH:mm:ss".
        ///
        /// This format is lexically comparable with SQLite's CURRENT_TIMESTAMP.
        case YMD_HMS = "yyyy-MM-dd HH:mm:ss"
        
        /// The format "yyyy-MM-dd HH:mm:ss.SSS".
        ///
        /// This format is lexically comparable with SQLite's CURRENT_TIMESTAMP.
        case YMD_HMSS = "yyyy-MM-dd HH:mm:ss.SSS"
        
        /// The format "HH:mm".
        case HM = "HH:mm"
        
        /// The format "HH:mm:ss".
        case HMS = "HH:mm:ss"
        
        /// The format "HH:mm:ss.SSS".
        case HMSS = "HH:mm:ss.SSS"
        
        var hasYMDComponents: Bool {
            switch self {
            case .YMD, .YMD_HM, .YMD_HMS, .YMD_HMSS:
                return true
            case .HM, .HMS, .HMSS:
                return false
            }
        }
    }
    
    /// The date components
    public let dateComponents: DateComponents
    
    /// The database format
    public let format: Format
    
    /// Creates a DatabaseDateComponents from a DateComponents and a format.
    ///
    /// - parameters:
    ///     - dateComponents: An optional DateComponents.
    ///     - format: The format used for storing the date components in
    ///       the database.
    public init(_ dateComponents: DateComponents, format: Format) {
        self.format = format
        self.dateComponents = dateComponents
    }
}

extension DatabaseDateComponents: StatementColumnConvertible {
    /// Returns a value initialized from a raw SQLite statement pointer.
    ///
    /// - parameters:
    ///     - sqliteStatement: A pointer to an SQLite statement.
    ///     - index: The column index.
    @inline(__always)
    @inlinable
    public init?(sqliteStatement: SQLiteStatement, index: CInt) {
        guard let cString = sqlite3_column_text(sqliteStatement, index) else {
            return nil
        }
        let length = Int(sqlite3_column_bytes(sqliteStatement, index)) // avoid an strlen
        let components = cString.withMemoryRebound(
            to: CChar.self,
            capacity: length + 1 /* trailing \0 */) { cString in
            SQLiteDateParser().components(cString: cString, length: length)
        }
        guard let components else {
            return nil
        }
        self.init(components.dateComponents, format: components.format)
    }
}

extension DatabaseDateComponents: DatabaseValueConvertible {
    /// Returns a TEXT database value.
    public var databaseValue: DatabaseValue {
        let dateString: String?
        switch format {
        case .YMD_HM, .YMD_HMS, .YMD_HMSS, .YMD:
            let year = dateComponents.year ?? 0
            let month = dateComponents.month ?? 1
            let day = dateComponents.day ?? 1
            dateString = String(format: "%04d-%02d-%02d", year, month, day)
        default:
            dateString = nil
        }
        
        let timeString: String?
        switch format {
        case .YMD_HM, .HM:
            let hour = dateComponents.hour ?? 0
            let minute = dateComponents.minute ?? 0
            timeString = String(format: "%02d:%02d", hour, minute)
        case .YMD_HMS, .HMS:
            let hour = dateComponents.hour ?? 0
            let minute = dateComponents.minute ?? 0
            let second = dateComponents.second ?? 0
            timeString = String(format: "%02d:%02d:%02d", hour, minute, second)
        case .YMD_HMSS, .HMSS:
            let hour = dateComponents.hour ?? 0
            let minute = dateComponents.minute ?? 0
            let second = dateComponents.second ?? 0
            let nanosecond = dateComponents.nanosecond ?? 0
            timeString = String(
                format: "%02d:%02d:%02d.%03d",
                hour, minute, second, Int(round(Double(nanosecond) / 1_000_000.0)))
        default:
            timeString = nil
        }
        
        return [dateString, timeString].compactMap { $0 }.joined(separator: " ").databaseValue
    }
    
    /// Creates a `DatabaseDateComponents` from the specified database value.
    ///
    /// The supported formats are:
    ///
    /// - `YYYY-MM-DD`
    /// - `YYYY-MM-DD HH:MM`
    /// - `YYYY-MM-DD HH:MM:SS`
    /// - `YYYY-MM-DD HH:MM:SS.SSS`
    /// - `YYYY-MM-DDTHH:MM`
    /// - `YYYY-MM-DDTHH:MM:SS`
    /// - `YYYY-MM-DDTHH:MM:SS.SSS`
    /// - `HH:MM`
    /// - `HH:MM:SS`
    /// - `HH:MM:SS.SSS`
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/lang_datefunc.html>
    public static func fromDatabaseValue(_ dbValue: DatabaseValue) -> DatabaseDateComponents? {
        guard let string = String.fromDatabaseValue(dbValue) else {
            return nil
        }
        
        return SQLiteDateParser().components(from: string)
    }
}

extension DatabaseDateComponents: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let stringValue = try container.decode(String.self)
        guard let decodedValue = DatabaseDateComponents.fromDatabaseValue(stringValue.databaseValue) else {
            throw DecodingError.dataCorruptedError(in: container,
                                                   debugDescription: "Unable to initialise databaseDateComponent")
        }
        self = decodedValue
    }
}

extension DatabaseDateComponents: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(String.fromDatabaseValue(databaseValue)!)
    }
}
